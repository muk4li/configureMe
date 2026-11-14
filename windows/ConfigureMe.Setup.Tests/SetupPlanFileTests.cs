using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class SetupPlanFileTests
{
    [Theory]
    [InlineData("relative.json")]
    [InlineData(@"\\server\share\plan.json")]
    [InlineData(@"\\?\C:\plan.json")]
    [InlineData(@"C:\plan.json:payload")]
    public void RejectsProblematicPaths(string path) => Assert.Throws<IOException>(() => SetupPlanFile.ReadSnapshot(path));

    [Fact]
    public void SnapshotDoesNotReopenChangedSourceAndOversizeIsRejected()
    {
        using var data = new TestApplicationData();
        var path = Path.Combine(data.Root, "plan.json");
        var fixture = File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "PlanFixtures", "valid-server.json"));
        File.WriteAllBytes(path, fixture);
        var snapshot = SetupPlanFile.ReadSnapshot(path);
        File.WriteAllText(path, "{}");
        Assert.Equal(fixture, snapshot);
        var engine = EngineBundle.ExtractVerified(data.Root);
        Assert.NotNull(SetupPlanContract.Validate(snapshot, File.ReadAllBytes(engine.CatalogPath), new("windows-server-2022", "x64")));
        File.WriteAllBytes(path, new byte[SetupPlanContract.MaxBytes + 1]);
        Assert.Throws<InvalidDataException>(() => SetupPlanFile.ReadSnapshot(path));
    }

    [Fact]
    public void AnExistingWriterPreventsImport()
    {
        using var data = new TestApplicationData();
        var path = Path.Combine(data.Root, "plan.json");
        File.WriteAllText(path, "{}");
        using var writer = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.ReadWrite);
        Assert.Throws<IOException>(() => SetupPlanFile.ReadSnapshot(path));
    }

    [Fact]
    public void RejectsJunctionInParentWithoutRequiringSymlinkPrivilege()
    {
        using var data = new TestApplicationData();
        var actual = Directory.CreateDirectory(Path.Combine(data.Root, "actual")).FullName;
        File.WriteAllText(Path.Combine(actual, "plan.json"), "{}");
        var link = Path.Combine(data.Root, "link");
        var start = new System.Diagnostics.ProcessStartInfo("cmd.exe") { UseShellExecute = false, CreateNoWindow = true };
        foreach (var argument in new[] { "/c", "mklink", "/J", link, actual }) start.ArgumentList.Add(argument);
        using var process = System.Diagnostics.Process.Start(start)!;
        process.WaitForExit();
        Assert.Equal(0, process.ExitCode);
        try { Assert.Throws<IOException>(() => SetupPlanFile.ReadSnapshot(Path.Combine(link, "plan.json"))); }
        finally { Directory.Delete(link); }
        Assert.True(File.Exists(Path.Combine(actual, "plan.json")));
    }
}
