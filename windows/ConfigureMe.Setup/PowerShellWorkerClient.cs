using System.Diagnostics;
using System.ComponentModel;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace ConfigureMe.Setup;

internal sealed record WorkerRunResult(int ExitCode, IReadOnlyList<WorkerEvent> Events, string StandardError);

internal sealed class PowerShellWorkerException : Exception
{
    public int ExitCode { get; }
    public string? PackageId { get; }
    public string? Phase { get; }
    public string? ErrorCode { get; }
    public string? StructuredMessage { get; }
    public bool HasStandardError { get; }

    public PowerShellWorkerException(int exitCode, string action, IReadOnlyList<string>? requestedIds,
        IReadOnlyList<WorkerEvent> events, bool hasStandardError)
        : base(BuildMessage(exitCode, action, requestedIds, events))
    {
        ExitCode = exitCode;
        HasStandardError = hasStandardError;
        var failure = events.LastOrDefault(IsPackageFailure)
            ?? events.LastOrDefault(item => item.Type == "worker-error")
            ?? events.LastOrDefault(item => item.Type == "operation-completed" && item.Status == "unsupported");
        PackageId = failure?.PackageId ?? requestedIds?.FirstOrDefault();
        ErrorCode = failure is null ? null : PowerShellWorkerClient.ReadString(failure.Data, "ErrorCode");
        Phase = failure is null ? null : PowerShellWorkerClient.ReadString(failure.Data, "Phase");
        Phase ??= events.LastOrDefault(item => item.PackageId == PackageId && item.Type is
            "download-started" or "download-completed" or "verification-started" or "verification-completed" or
            "installation-started" or "installation-completed")?.Type;
        StructuredMessage = SafeText(failure?.Message ?? (failure is null ? null :
            PowerShellWorkerClient.ReadString(failure.Data, "Notes")));
    }

    private static string BuildMessage(int exitCode, string action, IReadOnlyList<string>? requestedIds,
        IReadOnlyList<WorkerEvent> events)
    {
        var failure = events.LastOrDefault(IsPackageFailure)
            ?? events.LastOrDefault(item => item.Type == "worker-error");
        var id = failure?.PackageId ?? requestedIds?.FirstOrDefault() ?? action;
        var detail = SafeText(failure?.Message ?? (failure is null ? null :
            PowerShellWorkerClient.ReadString(failure.Data, "Notes")));
        return $"PowerShell-Worker für {id} beendete sich mit Code {exitCode}. " +
            (detail ?? "Es liegt keine strukturierte Fehlermeldung vor.");
    }

    public static string? SafeText(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var value = Regex.Replace(text, @"(?i)\b(token|password|secret|authorization)\b\s*[:=]\s*\S+", "$1=[ausgeblendet]");
        value = Regex.Replace(value, @"(?i)(https?://[^\s?]+)\?\S+", "$1?[Parameter ausgeblendet]");
        return value.Replace('\r', ' ').Replace('\n', ' ').Trim()[..Math.Min(value.Trim().Length, 700)];
    }

    private static bool IsPackageFailure(WorkerEvent item) =>
        item.Type is "package-installation-completed" or "package-download-failed" &&
        (item.Status == "Failed" || PowerShellWorkerClient.ReadString(item.Data, "ErrorCode") == "verification-refused");
}

internal sealed class PowerShellWorkerClient(EngineBundle engine)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<WorkerRunResult> RunAsync(
        string action,
        IReadOnlyList<string>? packageIds,
        bool confirmed,
        Action<WorkerEvent>? onEvent = null,
        CancellationToken cancellationToken = default)
    {
        engine.VerifyUnchanged();
        if (action == "install" && cancellationToken.CanBeCanceled)
        {
            throw new ArgumentException("An active installer must be allowed to finish.", nameof(cancellationToken));
        }
        var executable = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows),
            "System32",
            "WindowsPowerShell",
            "v1.0",
            "powershell.exe");
        if (!File.Exists(executable))
        {
            throw new FileNotFoundException("Windows PowerShell 5.1 is required to run the local setup engine.", executable);
        }

        var startInfo = new ProcessStartInfo(executable)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardInputEncoding = new System.Text.UTF8Encoding(false),
            StandardOutputEncoding = new System.Text.UTF8Encoding(false),
            StandardErrorEncoding = new System.Text.UTF8Encoding(false),
            WorkingDirectory = Path.GetDirectoryName(engine.BootstrapPath)!
        };
        startInfo.ArgumentList.Add("-NoLogo");
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-NonInteractive");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(engine.BootstrapPath);
        startInfo.ArgumentList.Add("-GuiWorker");

        var request = new WorkerRequest(1, action, packageIds?.ToArray(), confirmed);
        using var process = new Process { StartInfo = startInfo };
        if (!process.Start())
        {
            throw new InvalidOperationException("Windows PowerShell could not be started.");
        }

        using var cancellationRegistration = cancellationToken.Register(() =>
        {
            try
            {
                if (!process.HasExited)
                {
                    process.Kill(entireProcessTree: true);
                }
            }
            catch (InvalidOperationException)
            {
            }
            catch (Win32Exception)
            {
            }
        });
        await process.StandardInput.WriteLineAsync(JsonSerializer.Serialize(request, JsonOptions)).ConfigureAwait(false);
        process.StandardInput.Close();
        var errorsTask = process.StandardError.ReadToEndAsync();
        var (events, protocolError) = await ReadEventsAsync(process.StandardOutput, onEvent).ConfigureAwait(false);

        await process.WaitForExitAsync().ConfigureAwait(false);
        var standardError = await errorsTask.ConfigureAwait(false);
        cancellationToken.ThrowIfCancellationRequested();
        if (protocolError is not null) throw protocolError;
        if (process.ExitCode != 0)
        {
            throw new PowerShellWorkerException(process.ExitCode, action, packageIds, events,
                !string.IsNullOrWhiteSpace(standardError));
        }

        return new WorkerRunResult(process.ExitCode, events, standardError);
    }

    internal static async Task<(IReadOnlyList<WorkerEvent> Events, InvalidDataException? ProtocolError)> ReadEventsAsync(
        TextReader output, Action<WorkerEvent>? onEvent = null)
    {
        var events = new List<WorkerEvent>();
        InvalidDataException? protocolError = null;
        while (await output.ReadLineAsync().ConfigureAwait(false) is { } line)
        {
            WorkerEvent workerEvent;
            try
            {
                workerEvent = JsonSerializer.Deserialize<WorkerEvent>(line, JsonOptions)
                    ?? throw new JsonException("The worker emitted an empty event.");
            }
            catch (JsonException exception)
            {
                protocolError ??= new InvalidDataException("The PowerShell worker emitted a malformed status event.", exception);
                // Keep draining output. RunAsync waits for process exit before reporting the error.
                continue;
            }

            events.Add(workerEvent);
            onEvent?.Invoke(workerEvent);
        }
        return (events, protocolError);
    }

    public static string? ReadString(JsonElement element, string propertyName)
    {
        return element.ValueKind == JsonValueKind.Object &&
            element.TryGetProperty(propertyName, out var property) &&
            property.ValueKind == JsonValueKind.String
                ? property.GetString()
                : null;
    }
}
