using System.Diagnostics;
using System.ComponentModel;
using System.Text.Json;

namespace ConfigureMe.Setup;

internal sealed record WorkerRunResult(int ExitCode, IReadOnlyList<WorkerEvent> Events, string StandardError);

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
        var events = new List<WorkerEvent>();
        var errorsTask = process.StandardError.ReadToEndAsync();
        while (await process.StandardOutput.ReadLineAsync().ConfigureAwait(false) is { } line)
        {
            WorkerEvent workerEvent;
            try
            {
                workerEvent = JsonSerializer.Deserialize<WorkerEvent>(line, JsonOptions)
                    ?? throw new JsonException("The worker emitted an empty event.");
            }
            catch (JsonException exception)
            {
                process.Kill(entireProcessTree: true);
                throw new InvalidDataException("The PowerShell worker emitted a malformed status event.", exception);
            }

            events.Add(workerEvent);
            onEvent?.Invoke(workerEvent);
        }

        await process.WaitForExitAsync().ConfigureAwait(false);
        var standardError = await errorsTask.ConfigureAwait(false);
        cancellationToken.ThrowIfCancellationRequested();
        if (process.ExitCode != 0 && events.All(item => item.Type != "worker-error"))
        {
            throw new InvalidOperationException(
                string.IsNullOrWhiteSpace(standardError)
                    ? $"The PowerShell worker exited with code {process.ExitCode}."
                    : $"The PowerShell worker exited with code {process.ExitCode}: {standardError.Trim()}");
        }

        return new WorkerRunResult(process.ExitCode, events, standardError);
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
