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
}
