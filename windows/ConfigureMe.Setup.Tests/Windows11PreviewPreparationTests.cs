using System.Text.Json.Nodes;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class Windows11PreviewPreparationTests
{
    private static readonly Windows11HostEvidence Host = new("Microsoft Windows 11 Pro", 26100, "Client", "x64");
    private static byte[] Fixture => File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "PlanFixtures", "valid-windows11-contract-only.json"));

    private static byte[] CandidateFixture()
    {
        var plan = JsonNode.Parse(Fixture)!.AsObject();
        plan["planning"]!["requestedPackageIds"] = new JsonArray("python", "seven-zip", "vscode");
        plan["packages"] = new JsonArray(new[] { "python", "seven-zip", "vscode" }.Select(id => (JsonNode)new JsonObject
        {
            ["id"] = id, ["mode"] = "winget", ["dependsOn"] = new JsonArray()
        }).ToArray());
        return System.Text.Encoding.UTF8.GetBytes(plan.ToJsonString());
    }

    [Theory]
    [InlineData("Microsoft Windows 10 Pro", 19045, "Client", "x64")]
    [InlineData("Microsoft Windows 11 Pro", 21999, "Client", "x64")]
    [InlineData("Microsoft Windows Server 2022 Datacenter", 20348, "Server", "x64")]
    [InlineData("Microsoft Windows 11 Pro", 26100, "Server", "x64")]
    [InlineData("Microsoft Windows 11 Pro", 26100, "Client", "arm64")]
    [InlineData("Microsoft Windows 11 Pro", 26100, "Client", "x86")]
    public void DoesNotConflateClientsServersBuildsOrArchitectures(string caption, int build, string installation, string architecture)
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        Assert.Throws<InvalidDataException>(() => Windows11PreviewPreparation.Create(Fixture,
            File.ReadAllBytes(engine.CatalogPath), new(caption, build, installation, architecture)));
    }

    [Fact]
    public void RetainsUnsupportedDependenciesWithoutActivatingNativeImport()
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var catalog = File.ReadAllBytes(engine.CatalogPath);
        var prepared = Windows11PreviewPreparation.Create(Fixture, catalog, Host);
        Assert.False(prepared.NativeActivationAllowed); Assert.False(prepared.InstallationAllowed);
        Assert.Equal(new[] { "git", "github-cli" }, prepared.Packages.Select(item => item.Id));
        Assert.All(prepared.Packages, item => { Assert.False(item.DetectionCandidate); Assert.Equal("winget", item.Strategy); });
        Assert.Equal(new[] { "github-cli" }, prepared.Packages[0].RequiredBy);
        Assert.False(prepared.Packages[0].Requested);
        Assert.True(prepared.Packages[1].Requested);
        Assert.Throws<InvalidDataException>(() => SetupPlanContract.Validate(Fixture, catalog, new("windows-11", "x64")));
    }

    [Fact]
    public async Task CandidateObservationsPreserveFailuresAndRejectX86InstalledClaims()
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var prepared = Windows11PreviewPreparation.Create(CandidateFixture(), File.ReadAllBytes(engine.CatalogPath), Host);
        var result = await prepared.ObserveFixtureAsync(ids =>
        {
            Assert.Equal(new[] { "python", "seven-zip", "vscode" }, ids);
            return Task.FromResult<IReadOnlyList<Windows11FixtureObservation>>([
                new("python", Windows11ObservationStatus.Installed, "3.14.0 (x64; pip verified)", "x64"),
                new("seven-zip", Windows11ObservationStatus.Installed, "25.01", "x86"),
                new("vscode", Windows11ObservationStatus.Failed)
            ]);
        });
        Assert.Equal(Windows11ObservationStatus.Installed, result[0].Observation);
        Assert.Equal(Windows11ObservationStatus.Failed, result[1].Observation);
        Assert.Equal(Windows11ObservationStatus.Failed, result[2].Observation);
        Assert.False(prepared.InstallationAllowed);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task RefusesUnknownAndDuplicateObservations(bool duplicate)
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var prepared = Windows11PreviewPreparation.Create(Fixture, File.ReadAllBytes(engine.CatalogPath), Host);
        await Assert.ThrowsAsync<InvalidDataException>(() => prepared.ObserveFixtureAsync(_ =>
            Task.FromResult<IReadOnlyList<Windows11FixtureObservation>>(duplicate
                ? [new("git", Windows11ObservationStatus.Missing), new("git", Windows11ObservationStatus.Missing)]
                : [new("unknown", Windows11ObservationStatus.Missing)])));
    }

    [Fact]
    public async Task OwnsImmutableInputsAndTreatsIncompleteOrThrownDetectionAsUncertain()
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var snapshot = CandidateFixture(); var catalog = File.ReadAllBytes(engine.CatalogPath);
        var prepared = Windows11PreviewPreparation.Create(snapshot, catalog, Host);
        Array.Fill(snapshot, (byte)0); Array.Fill(catalog, (byte)0);
        var incomplete = await prepared.ObserveFixtureAsync(_ => Task.FromResult<IReadOnlyList<Windows11FixtureObservation>>([]));
        Assert.All(incomplete, item => Assert.Equal(Windows11ObservationStatus.Unknown, item.Observation));
        var failed = await prepared.ObserveFixtureAsync(_ => throw new IOException("fixture-private-detail"));
        Assert.All(failed, item => { Assert.Equal(Windows11ObservationStatus.Failed, item.Observation); Assert.DoesNotContain("fixture-private-detail", item.Reason); });
        Assert.False(prepared.NativeActivationAllowed);
    }

    [Fact]
    public void RevalidatesTheWholeSnapshotAndTrustedCatalog()
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var catalog = File.ReadAllBytes(engine.CatalogPath);
        Assert.Throws<InvalidDataException>(() => Windows11PreviewPreparation.Create(Fixture, "{}"u8.ToArray(), Host));
        var corrupted = JsonNode.Parse(Fixture)!;
        corrupted["packages"]![1]!["dependsOn"] = new JsonArray();
        Assert.Throws<InvalidDataException>(() => Windows11PreviewPreparation.Create(
            System.Text.Encoding.UTF8.GetBytes(corrupted.ToJsonString()), catalog, Host));
    }
}
