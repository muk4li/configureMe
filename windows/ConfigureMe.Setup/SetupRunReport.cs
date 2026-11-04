using System.Text;
using System.Text.Json;

namespace ConfigureMe.Setup;

internal sealed class SetupRunReport
{
    private readonly Dictionary<string, JsonElement> _packages = new(StringComparer.Ordinal);
    private readonly HashSet<string> _manualSteps = new(StringComparer.Ordinal);
    private readonly string _startedAt = DateTime.UtcNow.ToString("o");
    private JsonElement? _operatingSystem;
    private bool _completed;
    private string? _finishedAt;

    public SetupRunReport(string? reportRoot = null)
    {
        var directory = Path.Combine(reportRoot ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "configureMe", "Reports"),
            Guid.NewGuid().ToString("N"));
        EngineBundle.CreateSafeDirectory(directory);
        JsonPath = Path.Combine(directory, "setup-report.json");
    }

    public string JsonPath { get; }

    public void Record(string id, string name, string status, string? notes = null, string? detectedVersion = null)
    {
        _packages[id] = JsonSerializer.SerializeToElement(new
        {
            Id = id, Name = name, Status = status, Notes = notes, DetectedVersion = detectedVersion,
            ErrorCode = status == "Failed" ? "gui-operation-error" : null
        });
    }

    public string? StatusOf(string id) => _packages.TryGetValue(id, out var package)
        ? PowerShellWorkerClient.ReadString(package, "Status") : null;

    public void RecordFailureIfPending(string id, string name, string notes)
    {
        if (StatusOf(id) is null or "Pending") Record(id, name, "Failed", notes);
    }

    public IReadOnlyList<string> MarkPending(string status, string notes)
    {
        var pending = _packages.Where(item => PowerShellWorkerClient.ReadString(item.Value, "Status") == "Pending")
            .Select(item => (item.Key, PowerShellWorkerClient.ReadString(item.Value, "Name") ?? item.Key)).ToArray();
        foreach (var (id, name) in pending) Record(id, name, status, notes);
        return pending.Select(item => item.Key).ToArray();
    }

    public void Apply(WorkerEvent item)
    {
        if (item.Type == "system-detected" && item.Data.ValueKind == JsonValueKind.Object &&
            item.Data.TryGetProperty("operatingSystem", out var os))
            _operatingSystem = os.Clone();
        if (item.Type == "package-installation-completed" && item.PackageId is { } id && item.Data.ValueKind == JsonValueKind.Object)
            _packages[id] = item.Data.Clone();
        if (item.Type == "operation-completed" && item.Data.ValueKind == JsonValueKind.Object &&
            item.Data.TryGetProperty("ManualSteps", out var steps) && steps.ValueKind == JsonValueKind.Array)
        {
            foreach (var step in steps.EnumerateArray())
                if (step.GetString() is { } text) _manualSteps.Add(text);
        }
    }

    public void Write(bool completed = false)
    {
        if (completed && !_completed)
        {
            _completed = true;
            _finishedAt = DateTime.UtcNow.ToString("o");
        }
        var packages = _packages.Values.ToArray();
        var errors = packages.Where(item => PowerShellWorkerClient.ReadString(item, "Status") == "Failed")
            .Select(item => $"{PowerShellWorkerClient.ReadString(item, "Name")}: {PowerShellWorkerClient.ReadString(item, "Notes")}").ToArray();
        var summary = !_completed ? "In progress" : errors.Length > 0 ? "Completed with failures" :
            packages.Any(item => PowerShellWorkerClient.ReadString(item, "Status") == "Dry run") ? "Dry run complete" :
            packages.Any(item => PowerShellWorkerClient.ReadString(item, "Status") is "Skipped by user" or "Requires user action") || _manualSteps.Count > 0
                ? "Completed with manual steps" : "Completed";
        var report = new
        {
            BootstrapVersion = "0.3.0", ProfileId = "windows-server-2022-developer",
            OperatingSystem = _operatingSystem,
            Architecture = _operatingSystem.HasValue ? PowerShellWorkerClient.ReadString(_operatingSystem.Value, "Architecture") : null,
            StartedAt = _startedAt,
            FinishedAt = _finishedAt,
            Summary = summary, Packages = packages, Errors = errors, ManualSteps = _manualSteps.ToArray()
        };
        WriteAtomic(JsonPath, JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));
        var lines = new List<string> { "configureMe Setup", $"Status: {summary}", $"Started: {_startedAt}", "Package results:" };
        lines.AddRange(packages.Select(item => $"- {PowerShellWorkerClient.ReadString(item, "Name")}: {PowerShellWorkerClient.ReadString(item, "Status")}; {PowerShellWorkerClient.ReadString(item, "DetectedVersion")}; {PowerShellWorkerClient.ReadString(item, "Notes")}"));
        lines.AddRange(_manualSteps.Select(step => $"Manual: {step}"));
        lines.AddRange(errors.Select(error => $"Error: {error}"));
        WriteAtomic(Path.ChangeExtension(JsonPath, ".txt"), string.Join(Environment.NewLine, lines));
    }

    private static void WriteAtomic(string path, string contents)
    {
        EngineBundle.ValidatePath(path);
        var temporaryPath = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var output = new FileStream(temporaryPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (var writer = new StreamWriter(output, new UTF8Encoding(false))) writer.Write(contents);
            EngineBundle.ValidatePath(path);
            File.Move(temporaryPath, path, overwrite: true);
        }
        finally { if (File.Exists(temporaryPath)) File.Delete(temporaryPath); }
    }
}
