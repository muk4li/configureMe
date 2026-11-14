using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class ImportedPlanExecutionReviewTests
{
    private static readonly NativePlanTarget Target = new("windows-server-2022", "x64");
    private static (ImportedPlanExecutionReview Review, byte[] Catalog, byte[] Snapshot) Create(TestApplicationData data)
    {
        var engine = EngineBundle.ExtractVerified(data.Root);
        var catalog = File.ReadAllBytes(engine.CatalogPath);
        var snapshot = File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "PlanFixtures", "valid-server.json"));
        return (new(snapshot, catalog, Target), catalog, snapshot);
    }
    private static WorkerEvent Detected(string id, string status = "missing", string? version = null) =>
        new("package-detected", id, status, null, JsonSerializer.SerializeToElement(new { detectedVersion = version }));
    private static WorkerEvent Preview(params object[] entries) => new("install-plan", null, null, null, JsonSerializer.SerializeToElement(entries));
    private static object Strategy(string id, bool requires = false, bool available = true, string action = "install") =>
        new { id, action, requiresAdministrator = requires, administratorAvailable = available };
    private static Task<WorkerRunResult> Worker(string action, IReadOnlyList<string> ids, bool confirmed)
    {
        Assert.False(confirmed); Assert.Equal(new[] { "git", "github-cli" }, ids);
        Assert.Throws<NotSupportedException>(() => ((IList<string>)ids)[0] = "python");
        return Task.FromResult(new WorkerRunResult(0, action switch
        {
            "detect" => [Detected("git", "installed", "2.50.0"), Detected("github-cli")],
            "plan" => [Preview(Strategy("git"), Strategy("github-cli", requires: true, available: false))],
            _ => throw new InvalidOperationException("Only read-only actions allowed.")
        }, ""));
    }

    [Fact]
    public async Task ReviewsCopiedSnapshotsUsingOnlyExistingReadOnlyActions()
    {
        using var data = new TestApplicationData();
        var (review, catalog, snapshot) = Create(data);
        snapshot[0] = 0; // The imported byte snapshot is owned, not this caller's later mutation.
        await review.ReviewAsync(catalog, Target, Worker);
        Assert.Equal(ImportedReviewState.Reviewed, review.State);
        Assert.Equal(ImportedPackageDisposition.DetectedPresent, review.Packages[0].Disposition);
        Assert.Equal(ImportedPackageDisposition.RightsRequired, review.Packages[1].Disposition);
        Assert.Equal("2.50.0", review.Packages[0].DetectedVersion);
        Assert.Equal(64, review.SnapshotSha256.Length);
        Assert.Throws<NotSupportedException>(() => ((IList<ImportedPackageReview>)review.Packages)[0] = review.Packages[1]);
    }

    [Fact]
    public async Task PreservesManualAndUnsupportedPackagesAndRejectsPromotion()
    {
        using var data = new TestApplicationData();
        var catalog = File.ReadAllBytes(EngineBundle.ExtractVerified(data.Root).CatalogPath);
        var snapshot = File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "PlanFixtures", "valid-nonautomatic-modes.json"));
        var review = new ImportedPlanExecutionReview(snapshot, catalog, Target);
        Task<WorkerRunResult> Observe(string action, IReadOnlyList<string> ids, bool confirmed) => Task.FromResult(new WorkerRunResult(0,
            action == "detect" ? ids.Select(id => Detected(id)).ToArray() : [Preview(
                Strategy("docker-desktop", action: "detection-only"), Strategy("github-copilot-cli", action: "manual-action"), Strategy("teams", action: "manual-action"))], ""));
        await review.ReviewAsync(catalog, Target, Observe);
        Assert.Equal(new[] { ImportedPackageDisposition.Unsupported, ImportedPackageDisposition.Manual, ImportedPackageDisposition.Manual },
            review.Packages.Select(item => item.Disposition));
        var forged = new ImportedPlanExecutionReview(snapshot, catalog, Target);
        await Assert.ThrowsAsync<InvalidDataException>(() => forged.ReviewAsync(catalog, Target, (action, ids, confirmed) =>
            Task.FromResult(new WorkerRunResult(0, action == "detect" ? ids.Select(id => Detected(id)).ToArray() :
                [Preview(ids.Select(id => Strategy(id)).ToArray())], ""))));
    }

    [Fact]
    public async Task MissingVersionFieldCannotBecomeMissingSoftware()
    {
        using var data = new TestApplicationData(); var (review, catalog, _) = Create(data);
        await review.ReviewAsync(catalog, Target, (action, ids, confirmed) => Task.FromResult(new WorkerRunResult(0,
            action == "detect" ? [new("package-detected", "git", "missing", null, JsonSerializer.SerializeToElement(new { })), Detected("github-cli")] :
                [Preview(Strategy("git"), Strategy("github-cli"))], "")));
        Assert.Equal(ImportedPackageDisposition.DetectionUnclear, review.Packages[0].Disposition);
    }

    [Theory]
    [InlineData("error", null)]
    [InlineData("installed", null)]
    [InlineData("missing", "unexpected-version")]
    [InlineData("arbitrary", null)]
    public async Task UnclearDetectionNeverBecomesAnInstallCandidate(string status, string? version)
    {
        using var data = new TestApplicationData(); var (review, catalog, _) = Create(data);
        await review.ReviewAsync(catalog, Target, (action, ids, confirmed) => Task.FromResult(new WorkerRunResult(0,
            action == "detect" ? [Detected("git", status, version), Detected("github-cli")] :
            [Preview(Strategy("git"), Strategy("github-cli"))], "")));
        Assert.Equal(ImportedPackageDisposition.DetectionUnclear, review.Packages[0].Disposition);
        Assert.Equal(ImportedPackageDisposition.Candidate, review.Packages[1].Disposition);
    }

    [Theory]
    [InlineData("missing-detection")]
    [InlineData("duplicate-detection")]
    [InlineData("unexpected-detection")]
    [InlineData("missing-plan")]
    [InlineData("duplicate-plan")]
    [InlineData("unexpected-plan")]
    [InlineData("duplicate-preview")]
    [InlineData("execution-event")]
    [InlineData("unknown-action")]
    [InlineData("malformed-rights")]
    public async Task RejectsForgedOrIncompleteWorkerObservations(string scenario)
    {
        using var data = new TestApplicationData(); var (review, catalog, _) = Create(data);
        var detect = new List<WorkerEvent> { Detected("git"), Detected("github-cli") };
        var entries = new List<object> { Strategy("git"), Strategy("github-cli") };
        if (scenario == "missing-detection") detect.RemoveAt(1);
        if (scenario == "duplicate-detection") detect.Add(Detected("git"));
        if (scenario == "unexpected-detection") detect.Add(Detected("unknown"));
        if (scenario == "missing-plan") entries.RemoveAt(1);
        if (scenario == "duplicate-plan") entries.Add(Strategy("git"));
        if (scenario == "unexpected-plan") entries.Add(Strategy("unknown"));
        if (scenario == "unknown-action") entries[0] = Strategy("git", action: "shell");
        if (scenario == "malformed-rights") entries[0] = new { id = "git", action = "install", requiresAdministrator = "false", administratorAvailable = true };
        var plan = new List<WorkerEvent> { Preview(entries.ToArray()) };
        if (scenario == "duplicate-preview") plan.Add(Preview(entries.ToArray()));
        if (scenario == "execution-event") plan.Add(new("installation-started", "git", null, null, default));
        await Assert.ThrowsAsync<InvalidDataException>(() => review.ReviewAsync(catalog, Target,
            (action, ids, confirmed) => Task.FromResult(new WorkerRunResult(0, action == "detect" ? detect : plan, ""))));
        Assert.Equal(ImportedReviewState.Invalid, review.State); Assert.Empty(review.Packages);
        await Assert.ThrowsAsync<InvalidOperationException>(() => review.ReviewAsync(catalog, Target, Worker));
    }

    [Fact]
    public async Task ChangedCatalogOrTargetInvalidatesBeforeWorkerCalls()
    {
        using var data = new TestApplicationData(); var (review, catalog, _) = Create(data);
        catalog[^1] ^= 1;
        await Assert.ThrowsAsync<InvalidDataException>(() => review.ReviewAsync(catalog, Target,
            (_, _, _) => throw new InvalidOperationException("Worker must not run.")));
        Assert.Equal(ImportedReviewState.Invalid, review.State);
        var (other, original, _) = Create(data);
        await Assert.ThrowsAsync<InvalidDataException>(() => other.ReviewAsync(original, new("windows-11", "x64"), Worker));
    }

    [Fact]
    public async Task CancellationPreventsLateResultsAndLaterPlanCalls()
    {
        using var data = new TestApplicationData(); var (review, catalog, _) = Create(data);
        var complete = new TaskCompletionSource<WorkerRunResult>(TaskCreationOptions.RunContinuationsAsynchronously);
        var actions = new List<string>();
        var running = review.ReviewAsync(catalog, Target, (action, _, _) => { actions.Add(action); return complete.Task; });
        Assert.Equal(ImportedReviewState.Reviewing, review.State);
        await Assert.ThrowsAsync<InvalidOperationException>(() => review.ReviewAsync(catalog, Target, Worker));
        review.Cancel(); complete.SetResult(new(0, [Detected("git"), Detected("github-cli")], ""));
        await Assert.ThrowsAsync<InvalidOperationException>(() => running);
        Assert.Equal(new[] { "detect" }, actions);
        Assert.Equal(ImportedReviewState.Cancelled, review.State); Assert.Empty(review.Packages);
        await Assert.ThrowsAsync<InvalidOperationException>(() => review.ReviewAsync(catalog, Target, Worker));
    }

    [Fact]
    public async Task RepeatedReviewRefreshesPresenceWithoutGrantingPermission()
    {
        using var data = new TestApplicationData(); var (review, catalog, _) = Create(data);
        await review.ReviewAsync(catalog, Target, Worker);
        await review.ReviewAsync(catalog, Target, (action, _, confirmed) =>
        {
            Assert.False(confirmed);
            return Task.FromResult(new WorkerRunResult(0, action == "detect" ? [Detected("git"), Detected("github-cli")] :
                [Preview(Strategy("git"), Strategy("github-cli"))], ""));
        });
        Assert.All(review.Packages, item => Assert.Equal(ImportedPackageDisposition.Candidate, item.Disposition));
        Assert.DoesNotContain(typeof(ImportedPlanExecutionReview).GetMethods(), method => method.Name is "Install" or "Execute" or "Authorize");
    }
}
