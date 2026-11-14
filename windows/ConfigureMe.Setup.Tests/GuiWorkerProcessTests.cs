using System.Diagnostics;
using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class GuiWorkerProcessTests
{
    [Fact]
    public async Task WebExportedContractReachesRealOfflineEnginePlanWithoutInstalling()
    {
        using var data = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(data.Root);
        var savedPath = Path.Combine(data.Root, "exported-plan.json");
        File.Copy(Path.Combine(AppContext.BaseDirectory, "PlanFixtures", "valid-server.json"), savedPath);
        var snapshot = OperatingSystem.IsWindows() ? SetupPlanFile.ReadSnapshot(savedPath) : File.ReadAllBytes(savedPath);
        var plan = SetupPlanContract.Validate(snapshot, File.ReadAllBytes(engine.CatalogPath), new("windows-server-2022", "x64"));
        // Actual embedded offline plan logic. OS-independent fixture below is used on Linux.
        if (!OperatingSystem.IsWindows())
        {
            var (exit, events) = await RunFixtureAsync("plan", plan.PackageIds, null);
            Assert.Equal(0, exit);
            Assert.Contains(events, item => PowerShellWorkerClient.ReadString(item, "type") == "install-plan");
            Assert.DoesNotContain(events, item => PowerShellWorkerClient.ReadString(item, "type") == "installation-started");
            return;
        }
        var worker = new PowerShellWorkerClient(engine);
        var result = await SetupPlanDryRun.RunAsync(plan, (action, ids, confirmed) => worker.RunAsync(action, ids, confirmed));
        var preview = Assert.Single(result.Events, item => item.Type == "install-plan");
        Assert.Equal(plan.PackageIds, preview.Data.EnumerateArray().Select(item => item.GetProperty("id").GetString()).Order(StringComparer.Ordinal));
        Assert.DoesNotContain(result.Events, item => item.Type is "download-started" or "installation-started");
    }

    [Theory]
    [InlineData(null, 0)]
    [InlineData("seven-zip", 1)]
    public async Task EmitsPackageProgressAcrossThePowerShellProcessBoundary(string? failedId, int expectedExit)
    {
        var ids = failedId is null ? new[] { "python", "dotnet-10-sdk", "seven-zip" } : new[] { "seven-zip", "python" };
        var (exitCode, events) = await RunFixtureAsync("install", ids, failedId);
        Assert.Equal(expectedExit, exitCode);
        foreach (var id in ids)
        {
            Assert.Contains(events, item => PowerShellWorkerClient.ReadString(item, "type") == "installation-started" &&
                PowerShellWorkerClient.ReadString(item, "packageId") == id);
            Assert.Contains(events, item => PowerShellWorkerClient.ReadString(item, "type") == "package-installation-completed" &&
                PowerShellWorkerClient.ReadString(item, "packageId") == id);
        }
        Assert.Contains(events, item => PowerShellWorkerClient.ReadString(item, "type") == "operation-completed");
        if (failedId is not null)
        {
            var failed = Assert.Single(events, item => PowerShellWorkerClient.ReadString(item, "type") ==
                "package-installation-completed" && PowerShellWorkerClient.ReadString(item, "packageId") == failedId);
            Assert.Equal("installer-error", PowerShellWorkerClient.ReadString(failed.GetProperty("data"), "ErrorCode"));
            Assert.Equal("installation-started", PowerShellWorkerClient.ReadString(failed.GetProperty("data"), "Phase"));
            Assert.Contains(events, item => PowerShellWorkerClient.ReadString(item, "type") == "package-installation-completed" &&
                PowerShellWorkerClient.ReadString(item, "packageId") == "python" &&
                PowerShellWorkerClient.ReadString(item, "status") == "Installed");
        }
    }

    [Theory]
    [InlineData("dotnet-10-sdk", "metadata", "metadata-error")]
    [InlineData("seven-zip", "verification", "verification-refused")]
    public async Task DownloadFailureIdentifiesPackageAndPhase(string id, string failingStage, string errorCode)
    {
        var (exitCode, events) = await RunFixtureAsync("download", [id], id, failStage: failingStage);
        Assert.Equal(1, exitCode);
        var failure = Assert.Single(events, item => PowerShellWorkerClient.ReadString(item, "type") == "package-download-failed");
        Assert.Equal(id, PowerShellWorkerClient.ReadString(failure, "packageId"));
        Assert.Equal(errorCode, PowerShellWorkerClient.ReadString(failure.GetProperty("data"), "ErrorCode"));
        Assert.DoesNotContain("fixture-private", failure.GetRawText());
        var exception = new PowerShellWorkerException(exitCode, "download", [id],
            events.Select(item => JsonSerializer.Deserialize<WorkerEvent>(item.GetRawText(),
                new JsonSerializerOptions(JsonSerializerDefaults.Web))!).ToArray(), false);
        Assert.Equal(errorCode, exception.ErrorCode);
        Assert.Equal(id, exception.PackageId);
    }

    [Fact]
    public async Task IntegrityRefusalIsAReportedFailureAndLaterPackagesStillComplete()
    {
        var (exitCode, events) = await RunFixtureAsync("install", ["seven-zip", "python"],
            "seven-zip", failStage: "verification");
        Assert.Equal(1, exitCode);
        var refusal = Assert.Single(events, item => PowerShellWorkerClient.ReadString(item, "type") ==
            "package-installation-completed" && PowerShellWorkerClient.ReadString(item, "packageId") == "seven-zip");
        Assert.Equal("verification-refused", PowerShellWorkerClient.ReadString(refusal.GetProperty("data"), "ErrorCode"));
        Assert.Equal("verification-started", PowerShellWorkerClient.ReadString(refusal.GetProperty("data"), "Phase"));
        var failure = new PowerShellWorkerException(exitCode, "install", ["seven-zip", "python"],
            events.Select(item => JsonSerializer.Deserialize<WorkerEvent>(item.GetRawText(),
                new JsonSerializerOptions(JsonSerializerDefaults.Web))!).ToArray(), false);
        Assert.Equal("verification-refused", failure.ErrorCode);
        Assert.Contains(events, item => PowerShellWorkerClient.ReadString(item, "type") == "package-installation-completed" &&
            PowerShellWorkerClient.ReadString(item, "packageId") == "python" &&
            PowerShellWorkerClient.ReadString(item, "status") == "Installed");
    }

    [Fact]
    public async Task DetectsExistingVersionsAndDoesNotReinstallThem()
    {
        var installed = new Dictionary<string, string>
        {
            ["git"] = "2.56.0.windows.4", ["github-copilot-desktop"] = "1.1.34",
            ["firefox"] = "159.0", ["docker-desktop"] = "4.97.0",
            ["vscode"] = "1.144.0", ["nodejs-lts"] = "26.13.0", ["libreoffice"] = "26.8.2.2"
        };
        var (detectExit, detection) = await RunFixtureAsync("detect", installed.Keys.ToArray(), installed: installed);
        Assert.Equal(0, detectExit);
        foreach (var (id, version) in installed)
            Assert.Contains(detection, item => PowerShellWorkerClient.ReadString(item, "type") == "package-detected" &&
                PowerShellWorkerClient.ReadString(item, "packageId") == id &&
                PowerShellWorkerClient.ReadString(item.GetProperty("data"), "detectedVersion") == version);

        var (installExit, installation) = await RunFixtureAsync("install", ["git", "github-copilot-desktop", "firefox"], installed: installed);
        Assert.Equal(0, installExit);
        Assert.DoesNotContain(installation, item => PowerShellWorkerClient.ReadString(item, "type") == "installation-started");
        Assert.All(installation.Where(item => PowerShellWorkerClient.ReadString(item, "type") == "package-installation-completed"),
            item => Assert.Equal("Already installed", PowerShellWorkerClient.ReadString(item, "status")));
    }

    [Fact]
    public async Task MissingAdministratorRightsAndDryRunNeverStartAnInstaller()
    {
        var (adminExit, adminEvents) = await RunFixtureAsync("install", ["openssh-client"]);
        Assert.Equal(0, adminExit);
        var result = Assert.Single(adminEvents, item => PowerShellWorkerClient.ReadString(item, "type") == "package-installation-completed");
        Assert.Equal("Requires user action", PowerShellWorkerClient.ReadString(result, "status"));
        Assert.Equal("administrator-required", PowerShellWorkerClient.ReadString(result.GetProperty("data"), "ErrorCode"));
        Assert.DoesNotContain(adminEvents, item => PowerShellWorkerClient.ReadString(item, "type") == "installation-started");

        var (planExit, planEvents) = await RunFixtureAsync("plan", ["python"]);
        Assert.Equal(0, planExit);
        Assert.Contains(planEvents, item => PowerShellWorkerClient.ReadString(item, "type") == "install-plan");
        Assert.DoesNotContain(planEvents, item => PowerShellWorkerClient.ReadString(item, "type") == "installation-started");

        var (refusedExit, refusedEvents) = await RunFixtureAsync("install", ["python"], confirmed: false);
        Assert.Equal(1, refusedExit);
        Assert.Contains(refusedEvents, item => PowerShellWorkerClient.ReadString(item, "type") == "worker-error");
        Assert.DoesNotContain(refusedEvents, item => PowerShellWorkerClient.ReadString(item, "type") == "installation-started");
    }

    private static async Task<(int ExitCode, JsonElement[] Events)> RunFixtureAsync(string action, string[] ids,
        string? failedId = null, Dictionary<string, string>? installed = null, bool confirmed = true,
        string? failStage = null)
    {
        var repository = FindRepositoryRoot();
        var fixture = Path.Combine(repository, "tests", "worker-callback-fixture.ps1");
        var localData = Path.Combine(Path.GetTempPath(), "configureme-worker-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(localData);
        try
        {
            var executable = OperatingSystem.IsWindows()
                ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
                : "pwsh";
            var start = new ProcessStartInfo(executable)
            {
                UseShellExecute = false,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                WorkingDirectory = repository
            };
            foreach (var argument in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-File", fixture,
                "-RepositoryRoot", repository }) start.ArgumentList.Add(argument);
            start.Environment["LOCALAPPDATA"] = localData;
            if (failedId is not null) start.Environment["CONFIGUREME_TEST_FAIL_ID"] = failedId;
            if (failStage is not null) start.Environment["CONFIGUREME_TEST_FAIL_STAGE"] = failStage;
            if (installed is not null) start.Environment["CONFIGUREME_TEST_INSTALLED_JSON"] = JsonSerializer.Serialize(installed);
            using var process = Process.Start(start) ?? throw new InvalidOperationException("PowerShell fixture did not start.");
            await process.StandardInput.WriteLineAsync(JsonSerializer.Serialize(new
            {
                schemaVersion = 1, action, packageIds = ids, confirmed
            }));
            process.StandardInput.Close();
            var outputTask = process.StandardOutput.ReadToEndAsync();
            var errorTask = process.StandardError.ReadToEndAsync();
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            await process.WaitForExitAsync(timeout.Token);
            var output = await outputTask;
            var standardError = await errorTask;
            Assert.True(string.IsNullOrWhiteSpace(standardError), standardError);
            var events = output.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                .Select(line => JsonDocument.Parse(line.TrimEnd('\r')).RootElement.Clone()).ToArray();
            return (process.ExitCode, events);
        }
        finally { if (Directory.Exists(localData)) Directory.Delete(localData, recursive: true); }
    }

    private static string FindRepositoryRoot()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
            if (File.Exists(Path.Combine(directory.FullName, "tests", "worker-callback-fixture.ps1"))) return directory.FullName;
        throw new DirectoryNotFoundException("The PowerShell worker fixture is missing from the checkout.");
    }
}
