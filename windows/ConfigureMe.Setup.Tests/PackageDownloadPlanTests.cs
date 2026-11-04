using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class PackageDownloadPlanTests
{
    [Fact]
    public void QueuesWindowsCapabilityWithoutDownloadedInstallerAndSkipsFailedExe()
    {
        var packages = new Dictionary<string, PackageDefinition>
        {
            ["git"] = new() { Id = "git", WindowsMode = "automatic" },
            ["openssh-client"] = new() { Id = "openssh-client", WindowsMode = "automatic" },
            ["github-copilot-desktop"] = new() { Id = "github-copilot-desktop", WindowsMode = "automatic" },
            ["teams"] = new() { Id = "teams", WindowsMode = "web-fallback" }
        };
        var types = new Dictionary<string, string?>
        {
            ["git"] = "exe", ["openssh-client"] = "windows-capability",
            ["github-copilot-desktop"] = "exe", ["teams"] = "manual"
        };
        IReadOnlySet<string> downloaded = new HashSet<string> { "git" };

        Assert.False(PackageDownloadPlan.NeedsDownload(packages["openssh-client"], types["openssh-client"]));
        Assert.Equal(["git", "openssh-client", "teams"], PackageDownloadPlan.SelectQueue(
            ["git", "openssh-client", "github-copilot-desktop", "teams"], packages, types, downloaded));
    }
}
