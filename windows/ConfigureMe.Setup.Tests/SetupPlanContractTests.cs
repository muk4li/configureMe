using System.Text;
using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class SetupPlanContractTests
{
    private static string FixtureRoot => Path.Combine(AppContext.BaseDirectory, "PlanFixtures");
    public static IEnumerable<object[]> Cases()
    {
        using var document = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(FixtureRoot, "cases.json")));
        return document.RootElement.EnumerateArray().Select(item => new object[] {
            item.GetProperty("file").GetString()!, item.GetProperty("valid").GetBoolean(), item.GetProperty("native").GetBoolean()
        }).ToArray();
    }

    [Fact]
    public async Task DryRunBoundaryCanOnlyDetectAndPlanWithoutConfirmation()
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var plan = SetupPlanContract.Validate(File.ReadAllBytes(Path.Combine(FixtureRoot, "valid-server.json")),
            File.ReadAllBytes(engine.CatalogPath), new("windows-server-2022", "x64"));
        var calls = new List<string>();
        var result = await SetupPlanDryRun.RunAsync(plan, (action, ids, confirmed) =>
        {
            Assert.False(confirmed);
            Assert.Equal(new[] { "git", "github-cli" }, ids);
            Assert.Contains(action, new[] { "detect", "plan" });
            calls.Add(action);
            return Task.FromResult(new WorkerRunResult(0, [], ""));
        });
        Assert.Equal(new[] { "detect", "plan" }, calls);
        Assert.Equal(0, result.ExitCode);
    }

    [Fact]
    public async Task FailedDetectionCannotContinueToPlanningOrAnyInstallation()
    {
        var plan = new ValidatedSetupPlan(["git"], ["git"], new Dictionary<string, string[]>(), new Dictionary<string, bool>());
        var calls = new List<string>();
        await Assert.ThrowsAsync<InvalidDataException>(() => SetupPlanDryRun.RunAsync(plan, (action, ids, confirmed) =>
        {
            calls.Add(action); Assert.False(confirmed);
            return Task.FromResult(new WorkerRunResult(1, [], ""));
        }));
        Assert.Equal(new[] { "detect" }, calls);
    }

    [Theory]
    [MemberData(nameof(Cases))]
    public void BothConsumersUseTheSameContractFixtures(string file, bool valid, bool native)
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var catalog = File.ReadAllBytes(engine.CatalogPath);
        var snapshot = File.ReadAllBytes(Path.Combine(FixtureRoot, file));
        if (valid)
        {
            var plan = SetupPlanContract.Validate(snapshot, catalog);
            Assert.NotEmpty(plan.PackageIds);
            if (native) Assert.NotNull(SetupPlanContract.Validate(snapshot, catalog, new("windows-server-2022", "x64")));
            else Assert.Throws<InvalidDataException>(() => SetupPlanContract.Validate(snapshot, catalog, new("windows-11", "x64")));
        }
        else Assert.ThrowsAny<Exception>(() => SetupPlanContract.Validate(snapshot, catalog));
    }

    [Theory]
    [InlineData("windows-11", "x64", true)]
    [InlineData("windows-server-2022", "x86", true)]
    [InlineData("windows-server-2022", "x64", false)]
    [InlineData("unsupported", "x64", true)]
    public void NativeTargetMustActuallySupportThePlan(string os, string architecture, bool desktop)
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        Assert.Throws<InvalidDataException>(() => SetupPlanContract.Validate(
            File.ReadAllBytes(Path.Combine(FixtureRoot, "valid-server.json")), File.ReadAllBytes(engine.CatalogPath), new(os, architecture, desktop)));
    }

    [Fact]
    public void ChangedCatalogAndInvalidUtf8AreRejected()
    {
        var fixture = File.ReadAllBytes(Path.Combine(FixtureRoot, "valid-server.json"));
        Assert.Throws<InvalidDataException>(() => SetupPlanContract.Validate(fixture, Encoding.UTF8.GetBytes("{}")));
        Assert.ThrowsAny<Exception>(() => SetupPlanContract.Validate(new byte[] { 0xff }, Encoding.UTF8.GetBytes("{}")));
    }
}
