using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class InstallPlanResolverTests
{
    [Fact]
    public void ExpandsDependenciesOnceInDependencyOrder()
    {
        var catalog = CreateCatalog();
        var result = InstallPlanResolver.Resolve(["github-cli", "git"], catalog);

        Assert.Equal(["git", "github-cli"], result);
    }

    [Fact]
    public void RejectsPackagesOutsideTheWindowsCatalog()
    {
        var catalog = CreateCatalog();

        Assert.Throws<InvalidOperationException>(() => InstallPlanResolver.Resolve(["unknown"], catalog));
    }

    [Fact]
    public void RejectsDependencyCycles()
    {
        var catalog = CreateCatalog();
        catalog["git"].Dependencies = ["github-cli"];

        Assert.Throws<InvalidOperationException>(() => InstallPlanResolver.Resolve(["github-cli"], catalog));
    }

    private static Dictionary<string, PackageDefinition> CreateCatalog()
    {
        const string json = """
            {
              "schemaVersion": 1,
              "version": "1",
              "packages": [
                { "id": "git", "name": "Git", "description": "", "category": "", "website": "https://git-scm.com", "windowsMode": "automatic", "platforms": { "windows": { "id": "Git.Git", "supported": true, "label": "Installer" } } },
                { "id": "github-cli", "name": "GitHub CLI", "description": "", "category": "", "website": "https://cli.github.com", "windowsMode": "automatic", "dependencies": ["git"], "platforms": { "windows": { "id": "GitHub.cli", "supported": true, "label": "Installer" } } }
              ]
            }
            """;
        var catalog = JsonSerializer.Deserialize<CatalogDocument>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        return catalog.Packages.ToDictionary(item => item.Id, StringComparer.Ordinal);
    }
}
