using System.Text.Json;
using System.Text.RegularExpressions;

namespace ConfigureMe.Setup;

// Unregistered preparation only. This does not change native import policy or invoke a worker.
internal sealed record Windows11HostEvidence(string Caption, int Build, string InstallationType, string Architecture);
internal enum Windows11ObservationStatus { Unknown, Missing, Installed, Failed }
internal sealed record Windows11FixtureObservation(string PackageId, Windows11ObservationStatus Status,
    string? Version = null, string? Architecture = null);
internal sealed record Windows11PackagePreview(string Id, string Strategy, bool DetectionCandidate,
    bool Requested, IReadOnlyList<string> RequiredBy, Windows11ObservationStatus Observation, string? Version, string Reason);

internal sealed class Windows11PreviewPreparation
{
    private readonly byte[] _snapshot;
    private readonly byte[] _catalog;
    private readonly Windows11HostEvidence _host;
    private readonly IReadOnlyList<Windows11PackagePreview> _packages;

    // These existing detectors verify the application's x64 PE, not a bootstrapper's architecture.
    // Inclusion means a candidate for fixture preparation, never tested Windows 11 compatibility.
    private static readonly HashSet<string> DetectionCandidates = new(StringComparer.Ordinal)
        { "vscode", "python", "seven-zip" };

    public bool NativeActivationAllowed => false;
    public bool InstallationAllowed => false;
    public string Gate => "Windows 11 platform, detection and Dry-Run acceptance is required before native registration; installation needs separate authorization.";
    public IReadOnlyList<Windows11PackagePreview> Packages => _packages;

    private Windows11PreviewPreparation(byte[] snapshot, byte[] catalog, Windows11HostEvidence host)
    {
        _snapshot = snapshot;
        _catalog = catalog;
        _host = host;
        var plan = Revalidate();
        _packages = Array.AsReadOnly(plan.PackageIds.Select(id => new Windows11PackagePreview(
            id, "winget", DetectionCandidates.Contains(id), plan.RequestedIds.Contains(id, StringComparer.Ordinal),
            Array.AsReadOnly((plan.RequiredBy.GetValueOrDefault(id) ?? []).ToArray()), Windows11ObservationStatus.Unknown, null,
            DetectionCandidates.Contains(id)
                ? "Existing x64 detector is a candidate; Windows 11 strategy and host behavior remain unvalidated."
                : "No reviewed Windows 11 detection adapter; package is retained as unsupported, not silently removed.")).ToArray());
    }

    public static Windows11PreviewPreparation Create(ReadOnlyMemory<byte> snapshot, ReadOnlyMemory<byte> trustedCatalog,
        Windows11HostEvidence host)
    {
        if (snapshot.Length > SetupPlanContract.MaxBytes) throw new InvalidDataException("The setup plan is too large.");
        // Owned snapshots prevent a caller changing source buffers after validation.
        return new(snapshot.ToArray(), trustedCatalog.ToArray(), host);
    }

    private ValidatedSetupPlan Revalidate()
    {
        if (_host.Caption is null || _host.Caption.Length > 256 || _host.InstallationType != "Client" || _host.Architecture != "x64" || _host.Build < 22000 ||
            !Regex.IsMatch(_host.Caption, @"\A(?:Microsoft )?Windows 11(?: [^\r\n]+)?\z", RegexOptions.CultureInvariant,
                TimeSpan.FromMilliseconds(100)))
            throw new InvalidDataException("Preparation requires Windows 11 client/x64 evidence; Windows 10, Server and ARM are not interchangeable.");
        var plan = SetupPlanContract.Validate(_snapshot, _catalog); // Structural contract, not native activation.
        using var document = JsonDocument.Parse(_snapshot);
        if (document.RootElement.GetProperty("target").GetProperty("os").GetString() != "windows-11")
            throw new InvalidDataException("This preparation only accepts a Windows 11 plan.");
        return plan;
    }

    // Fixture observations are deliberately not a worker action/process API. In particular, the Server
    // engine's offline manufacturer-install plan must not be presented as a validated WinGet strategy.
    public async Task<IReadOnlyList<Windows11PackagePreview>> ObserveFixtureAsync(
        Func<IReadOnlyList<string>, Task<IReadOnlyList<Windows11FixtureObservation>>> observe)
    {
        var plan = Revalidate();
        IReadOnlyList<Windows11FixtureObservation> observations;
        try { observations = await observe(Array.AsReadOnly(plan.PackageIds.ToArray())); }
        catch (OperationCanceledException) { throw; }
        catch
        {
            return Array.AsReadOnly(_packages.Select(item => item with
            {
                Observation = Windows11ObservationStatus.Failed,
                Reason = "Detection observation failed; no system change or compatibility assertion is made."
            }).ToArray());
        }
        if (observations is null || observations.Count > plan.PackageIds.Length || observations.Any(item => item is null) ||
            observations.Select(item => item.PackageId).Distinct(StringComparer.Ordinal).Count() != observations.Count ||
            observations.Any(item => !plan.PackageIds.Contains(item.PackageId, StringComparer.Ordinal)))
            throw new InvalidDataException("Observations contain unknown, duplicate or extra package identities.");
        var byId = observations.ToDictionary(item => item.PackageId, StringComparer.Ordinal);
        return Array.AsReadOnly(_packages.Select(item =>
        {
            if (!byId.TryGetValue(item.Id, out var observation)) return item with { Reason = "Detection is incomplete; no installed state is asserted." };
            if (observation.Status == Windows11ObservationStatus.Failed)
                return item with { Observation = Windows11ObservationStatus.Failed, Reason = "Detection failed; retry requires a new observation." };
            if (!item.DetectionCandidate)
                return item with { Reason = "Unsupported Windows 11 detection adapter; supplied observations do not authorize compatibility." };
            if (observation.Status == Windows11ObservationStatus.Installed)
            {
                if (observation.Architecture != "x64" || observation.Version is null || observation.Version.Length > 128 ||
                    !Regex.IsMatch(observation.Version, @"\A[0-9]+\.[0-9]+(?:\.[0-9]+){0,2}(?: \(x64; pip verified\))?\z",
                        RegexOptions.CultureInvariant, TimeSpan.FromMilliseconds(100)))
                    return item with { Observation = Windows11ObservationStatus.Failed, Reason = "Installed observation lacks verified x64 architecture or a valid version." };
                return item with { Observation = Windows11ObservationStatus.Installed, Version = observation.Version,
                    Reason = "Fixture reports an x64 installed version; this is not native Windows 11 acceptance or installation permission." };
            }
            return observation.Status == Windows11ObservationStatus.Missing
                ? item with { Observation = Windows11ObservationStatus.Missing, Reason = "Fixture reports missing; installation remains disabled." }
                : item with { Reason = "Detection is unknown; no installed state is asserted." };
        }).ToArray());
    }
}
