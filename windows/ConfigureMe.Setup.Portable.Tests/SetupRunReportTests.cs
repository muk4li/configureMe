using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class SetupRunReportTests
{
    [Fact]
    public void ArtifactProvenanceSurvivesWorkerFailureAndAggregateSerialization()
    {
        var root = Directory.CreateTempSubdirectory("configureme-report-provenance-").FullName;
        try
        {
            var report = new SetupRunReport(root);
            var failure = new WorkerEvent("package-installation-completed", "git", "Failed", "Mock failure",
                JsonSerializer.SerializeToElement(new { Id = "git", Name = "Git", Status = "Failed", ErrorCode = "installer-error",
                    Provenance = new { PackageId = "git", SourceKind = "cached", ObservedFinalUri = (string?)null,
                        Artifact = new { Sha256 = new string('a', 64), SizeBytes = 256, Signature = new { Status = "Valid", Policy = "authenticode" } } } }));
            report.Apply(failure);
            report.RecordWorkerFailure("git", "Git", new PowerShellWorkerException(1, "install", ["git"], [failure], false));
            report.Write(completed: true);
            using var document = JsonDocument.Parse(File.ReadAllBytes(report.JsonPath));
            var item = document.RootElement.GetProperty("Packages")[0];
            Assert.Equal("Failed", item.GetProperty("Status").GetString());
            Assert.Equal(new string('a', 64), item.GetProperty("Provenance").GetProperty("Artifact").GetProperty("Sha256").GetString());
            Assert.Equal(JsonValueKind.Null, item.GetProperty("Provenance").GetProperty("ObservedFinalUri").ValueKind);
        }
        finally { Directory.Delete(root, recursive: true); }
    }

    [Fact]
    public void DryRunHasExplicitSummaryAndNoPendingInstallations()
    {
        var root = Path.Combine(Path.GetTempPath(), "configureme-report-dryrun-" + Guid.NewGuid().ToString("N"));
        try
        {
            var report = new SetupRunReport(root);
            report.Record("git", "Git", "Already installed", detectedVersion: "2.56.0");
            report.Record("github-copilot-desktop", "GitHub Copilot Desktop", "Dry run");
            report.Write(completed: true);
            using var document = JsonDocument.Parse(File.ReadAllText(report.JsonPath));
            Assert.Equal("Dry run complete", document.RootElement.GetProperty("Summary").GetString());
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, recursive: true); }
    }

    [Fact]
    public void WorkerExitEnrichesTheStructuredFailureWithoutErasingLaterPackages()
    {
        var root = Path.Combine(Path.GetTempPath(), "configureme-report-worker-" + Guid.NewGuid().ToString("N"));
        try
        {
            var report = new SetupRunReport(root);
            report.Record("seven-zip", "7-Zip", "Pending");
            report.Record("python", "Python", "Pending");
            var failed = new WorkerEvent("package-installation-completed", "seven-zip", "Failed",
                "Mock installer failed", JsonSerializer.SerializeToElement(new
                {
                    Id = "seven-zip", Name = "7-Zip", Status = "Failed", ErrorCode = "installer-error",
                    Phase = "installation-started", Notes = "Mock installer failed"
                }));
            report.Apply(failed);
            var exception = new PowerShellWorkerException(1, "install", ["seven-zip"], [failed], false);
            report.RecordWorkerFailure("seven-zip", "7-Zip", exception);
            report.Apply(new WorkerEvent("package-installation-completed", "python", "Installed", null,
                JsonSerializer.SerializeToElement(new { Id = "python", Name = "Python", Status = "Installed", DetectedVersion = "3.13.0" })));
            report.Write(completed: true);

            using var document = JsonDocument.Parse(File.ReadAllText(report.JsonPath));
            var packages = document.RootElement.GetProperty("Packages");
            Assert.Equal(1, packages[0].GetProperty("WorkerExitCode").GetInt32());
            Assert.Equal("installer-error", packages[0].GetProperty("ErrorCode").GetString());
            Assert.Equal("Installed", packages[1].GetProperty("Status").GetString());
            Assert.Equal("Completed with failures", document.RootElement.GetProperty("Summary").GetString());
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, recursive: true); }
    }

    [Fact]
    public void AggregatesOperationsAndKeepsCompletedStateAfterLateEvent()
    {
        var root = Path.Combine(Path.GetTempPath(), "configureme-report-test-" + Guid.NewGuid().ToString("N"));
        try
        {
            var report = new SetupRunReport(root);
            report.Record("git", "Git", "Pending");
            report.Record("github-copilot-desktop", "GitHub Copilot Desktop", "Pending");
            report.Record("openssh-client", "OpenSSH Client", "Pending");
            report.Apply(new WorkerEvent("package-installation-completed", "git", "Installed", null,
                JsonSerializer.SerializeToElement(new { Id = "git", Name = "Git", Status = "Installed", DetectedVersion = "2.56.0" })));
            report.Apply(new WorkerEvent("package-installation-completed", "github-copilot-desktop", "Failed", null,
                JsonSerializer.SerializeToElement(new { Id = "github-copilot-desktop", Name = "GitHub Copilot Desktop", Status = "Failed", Notes = "Signatur ungültig" })));
            report.RecordFailureIfPending("github-copilot-desktop", "GitHub Copilot Desktop", "Generic worker error");
            Assert.Equal(["openssh-client"], report.MarkPending("Skipped by user", "Queue cancelled"));
            report.Write(completed: true);
            report.Write();

            using var document = JsonDocument.Parse(File.ReadAllText(report.JsonPath));
            var body = document.RootElement;
            Assert.Equal("Completed with failures", body.GetProperty("Summary").GetString());
            Assert.Equal(3, body.GetProperty("Packages").GetArrayLength());
            Assert.Equal("Signatur ungültig", body.GetProperty("Packages")[1].GetProperty("Notes").GetString());
            Assert.Equal("Skipped by user", body.GetProperty("Packages")[2].GetProperty("Status").GetString());
            Assert.NotEqual(JsonValueKind.Null, body.GetProperty("FinishedAt").ValueKind);
            Assert.Contains("Signatur ungültig", File.ReadAllText(Path.ChangeExtension(report.JsonPath, ".txt")));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, recursive: true); }
    }

    [Fact]
    public void RefusesReportRootThroughSymbolicLink()
    {
        if (OperatingSystem.IsWindows()) return;
        var root = Path.Combine(Path.GetTempPath(), "configureme-report-link-" + Guid.NewGuid().ToString("N"));
        var destination = Path.Combine(root, "destination");
        var link = Path.Combine(root, "link");
        try
        {
            Directory.CreateDirectory(destination);
            Directory.CreateSymbolicLink(link, destination);
            Assert.Throws<IOException>(() => new SetupRunReport(link));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, recursive: true); }
    }
}
