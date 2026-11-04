using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class EngineBundlePathTests
{
    [Fact]
    public void RefusesSymlinkInApplicationDataAncestor()
    {
        if (OperatingSystem.IsWindows()) return;
        var root = Path.Combine(Path.GetTempPath(), "configureme-engine-link-" + Guid.NewGuid().ToString("N"));
        var destination = Path.Combine(root, "destination");
        var link = Path.Combine(root, "link");
        try
        {
            Directory.CreateDirectory(destination);
            Directory.CreateSymbolicLink(link, destination);
            Assert.Throws<IOException>(() => EngineBundle.ExtractVerified(link));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, recursive: true); }
    }
}
