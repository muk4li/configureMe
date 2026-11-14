using System.Security.Cryptography;
using System.Text.Json;

namespace ConfigureMe.Setup;

internal enum ImportedReviewState { Validated, Reviewing, Reviewed, Cancelled, Invalid }
internal enum ImportedPackageDisposition { DetectedPresent, Candidate, RightsRequired, Manual, Unsupported, DetectionUnclear }
internal sealed record ImportedPackageReview(string Id, ImportedPackageDisposition Disposition, string? DetectedVersion,
    bool RequiresAdministrator, bool AdministratorAvailable);

// Unregistered preparation. Produces review data only: no install/download/consent API exists.
internal sealed class ImportedPlanExecutionReview
{
    private readonly byte[] _snapshot;
    private readonly byte[] _catalog;
    private readonly NativePlanTarget _target;
    private int _generation;
    private readonly object _gate = new();
    public ImportedReviewState State { get; private set; } = ImportedReviewState.Validated;
    public IReadOnlyList<ImportedPackageReview> Packages { get; private set; } = Array.Empty<ImportedPackageReview>();
    public string SnapshotSha256 { get; }
    public string CatalogSha256 { get; }

    public ImportedPlanExecutionReview(ReadOnlyMemory<byte> snapshot, ReadOnlySpan<byte> catalog, NativePlanTarget target)
    {
        if (snapshot.Length > SetupPlanContract.MaxBytes) throw new InvalidDataException("The setup plan is too large.");
        _snapshot = snapshot.ToArray(); _catalog = catalog.ToArray(); _target = target;
        SetupPlanContract.Validate(_snapshot, _catalog, target);
        SnapshotSha256 = Convert.ToHexStringLower(SHA256.HashData(_snapshot));
        CatalogSha256 = Convert.ToHexStringLower(SHA256.HashData(_catalog));
    }

    public void Cancel()
    {
        lock (_gate)
        {
            _generation++; State = ImportedReviewState.Cancelled;
            Packages = Array.Empty<ImportedPackageReview>();
        }
    }

    public async Task ReviewAsync(ReadOnlyMemory<byte> currentCatalog, NativePlanTarget currentTarget,
        Func<string, IReadOnlyList<string>, bool, Task<WorkerRunResult>> readOnlyWorker)
    {
        int generation;
        lock (_gate)
        {
            if (State is not (ImportedReviewState.Validated or ImportedReviewState.Reviewed))
                throw new InvalidOperationException("This review must be recreated after cancellation, failure or an active review.");
            State = ImportedReviewState.Reviewing; Packages = Array.Empty<ImportedPackageReview>();
            generation = ++_generation;
        }
        try
        {
            if (currentTarget != _target || !currentCatalog.Span.SequenceEqual(_catalog))
                throw new InvalidDataException("Catalog or target changed; import and review again.");
            var plan = SetupPlanContract.Validate(_snapshot, currentCatalog.Span, currentTarget);
            var result = await SetupPlanDryRun.RunAsync(plan, async (action, ids, confirmed) =>
            {
                lock (_gate)
                    if (_generation != generation || State == ImportedReviewState.Cancelled)
                        throw new InvalidOperationException("Review cancelled.");
                var observed = await readOnlyWorker(action, Array.AsReadOnly(ids.ToArray()), confirmed);
                lock (_gate)
                    if (_generation != generation || State == ImportedReviewState.Cancelled)
                        throw new InvalidOperationException("Review cancelled.");
                return observed;
            });
            var rows = ValidateObservations(plan, result.Events);
            lock (_gate)
            {
                if (_generation != generation || State == ImportedReviewState.Cancelled)
                    throw new InvalidOperationException("Review cancelled; late results cannot restore it.");
                Packages = Array.AsReadOnly(rows); State = ImportedReviewState.Reviewed;
            }
        }
        catch
        {
            lock (_gate)
            {
                if (State != ImportedReviewState.Cancelled) State = ImportedReviewState.Invalid;
                Packages = Array.Empty<ImportedPackageReview>();
            }
            throw;
        }
    }

    private ImportedPackageReview[] ValidateObservations(ValidatedSetupPlan plan, IReadOnlyList<WorkerEvent> events)
    {
        var ids = plan.PackageIds.ToHashSet(StringComparer.Ordinal);
        var detections = new Dictionary<string, WorkerEvent>(StringComparer.Ordinal);
        WorkerEvent? preview = null;
        foreach (var item in events)
        {
            if (item.Type == "package-detected")
            {
                if (item.PackageId is null || !ids.Contains(item.PackageId) || !detections.TryAdd(item.PackageId, item))
                    throw new InvalidDataException("Unexpected or duplicate detection result.");
            }
            else if (item.Type == "install-plan")
            {
                if (preview is not null || item.Data.ValueKind != JsonValueKind.Array)
                    throw new InvalidDataException("Ambiguous offline plan.");
                preview = item;
            }
            else if (item.Type is not ("system-detected" or "log" or "operation-completed"))
                throw new InvalidDataException("Unexpected event at the read-only boundary.");
        }
        if (detections.Count != ids.Count || preview is null)
            throw new InvalidDataException("Detection or offline plan is incomplete.");
        var strategies = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
        foreach (var entry in preview.Data.EnumerateArray())
        {
            var id = PowerShellWorkerClient.ReadString(entry, "id");
            if (id is null || !ids.Contains(id) || !strategies.TryAdd(id, entry))
                throw new InvalidDataException("Unexpected or duplicate offline package.");
        }
        if (strategies.Count != ids.Count) throw new InvalidDataException("Offline plan is incomplete.");
        var catalog = JsonSerializer.Deserialize<CatalogDocument>(_catalog)!.Packages.ToDictionary(item => item.Id, StringComparer.Ordinal);
        return plan.PackageIds.Select(id =>
        {
            var detection = detections[id]; var strategy = strategies[id];
            var action = PowerShellWorkerClient.ReadString(strategy, "action");
            if (action is not ("install" or "manual-action" or "detection-only") ||
                (action == "install" && catalog[id].WindowsMode != "automatic") ||
                !strategy.TryGetProperty("requiresAdministrator", out var requires) || requires.ValueKind is not (JsonValueKind.True or JsonValueKind.False) ||
                !strategy.TryGetProperty("administratorAvailable", out var available) || available.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                throw new InvalidDataException("Unsupported or malformed offline strategy.");
            var version = PowerShellWorkerClient.ReadString(detection.Data, "detectedVersion");
            if (version?.Length > 240) throw new InvalidDataException("Detection value exceeds the review limit.");
            var hasVersionField = detection.Data.ValueKind == JsonValueKind.Object &&
                detection.Data.TryGetProperty("detectedVersion", out var versionField) &&
                versionField.ValueKind is JsonValueKind.String or JsonValueKind.Null;
            var disposition = (hasVersionField ? detection.Status : null) switch
            {
                "installed" when !string.IsNullOrWhiteSpace(version) => ImportedPackageDisposition.DetectedPresent,
                "missing" when string.IsNullOrWhiteSpace(version) => action switch
                {
                    "detection-only" => ImportedPackageDisposition.Unsupported,
                    "manual-action" => ImportedPackageDisposition.Manual,
                    _ => requires.GetBoolean() && !available.GetBoolean() ? ImportedPackageDisposition.RightsRequired : ImportedPackageDisposition.Candidate
                },
                _ => ImportedPackageDisposition.DetectionUnclear
            };
            return new ImportedPackageReview(id, disposition, version, requires.GetBoolean(), available.GetBoolean());
        }).ToArray();
    }
}
