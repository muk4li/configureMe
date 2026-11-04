using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class EngineBundleTests
{
    [Fact]
    public void EmbeddedEngineExtractsWithVerifiedCatalogAndBootstrap()
    {
        var engine = EngineBundle.ExtractVerified();

        Assert.True(File.Exists(engine.BootstrapPath));
        Assert.True(File.Exists(engine.CatalogPath));
        Assert.True(File.Exists(engine.ProfilePath));
        var catalog = JsonDocument.Parse(File.ReadAllText(engine.CatalogPath));
        Assert.Equal(1, catalog.RootElement.GetProperty("schemaVersion").GetInt32());
        Assert.Contains(
            catalog.RootElement.GetProperty("packages").EnumerateArray(),
            package => package.GetProperty("id").GetString() == "docker-desktop" &&
                package.GetProperty("windowsMode").GetString() == "detection-only");
    }

    [Fact]
    public void RefusesChangedExtractedScriptBeforeAWorkerRuns()
    {
        var root = Path.Combine(Path.GetTempPath(), "configureme-engine-test-" + Guid.NewGuid().ToString("N"));
        try
        {
            var engine = EngineBundle.ExtractVerified(root);
            File.AppendAllText(engine.BootstrapPath, "\n# changed after verification\n");
            Assert.Throws<IOException>(engine.VerifyUnchanged);
            Assert.Throws<IOException>(() => EngineBundle.ExtractVerified(root));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, recursive: true); }
    }
}
