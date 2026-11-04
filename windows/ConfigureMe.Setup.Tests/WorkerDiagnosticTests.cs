using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class WorkerDiagnosticTests
{
    [Theory]
    [InlineData("dotnet-10-sdk", "installer-error", "Installer fehlgeschlagen")]
    [InlineData("seven-zip", "download-error", "Download fehlgeschlagen")]
    public void PreservesPackagePhaseAndStructuredCauseWithoutExposingCredentials(
        string packageId, string errorCode, string expectedGermanCategory)
    {
        var events = new[]
        {
            new WorkerEvent("installation-started", packageId, "installation-started", null, default),
            new WorkerEvent("package-installation-completed", packageId, "Failed",
                "Mock failure; token=very-private; https://example.test/file?sig=secret", JsonSerializer.SerializeToElement(new
                {
                    ErrorCode = errorCode, Phase = "installation-started", Notes = "Mock failure"
                }))
        };
        var failure = new PowerShellWorkerException(1, "install", [packageId], events, hasStandardError: true);
        var display = WorkerDiagnostic.Describe(packageId, failure.ErrorCode, failure.Phase,
            failure.StructuredMessage, failure.ExitCode);

        Assert.Equal(packageId, failure.PackageId);
        Assert.Equal(1, failure.ExitCode);
        Assert.Contains(expectedGermanCategory, display);
        Assert.Contains("Worker-Code: 1", display);
        Assert.DoesNotContain("very-private", display);
        Assert.DoesNotContain("sig=secret", display);
    }

    [Fact]
    public void DistinguishesExpectedAdministrativeAndManualOutcomesFromTechnicalFailure()
    {
        Assert.Contains("Administratorrechte erforderlich", WorkerDiagnostic.Describe(
            "OpenSSH Client", "administrator-required", "preflight", "Same account required"));
        Assert.Contains("Integritätsprüfung verweigert", WorkerDiagnostic.Describe(
            "7-Zip", "verification-refused", "verification-started", "Hash mismatch"));
        Assert.Contains("Installation konnte danach nicht verifiziert werden", WorkerDiagnostic.Describe(
            ".NET 10 SDK", "verification-failed", "post-install-verification", "No SDK found"));
    }
}
