namespace ConfigureMe.Setup;

internal static class PackageDownloadPlan
{
    public static bool NeedsDownload(PackageDefinition package, string? installerType) =>
        package.WindowsMode == "automatic" && installerType is "msi" or "exe" or "msix";

    public static IReadOnlyList<string> SelectQueue(
        IReadOnlyList<string> missingIds,
        IReadOnlyDictionary<string, PackageDefinition> packages,
        IReadOnlyDictionary<string, string?> installerTypes,
        IReadOnlySet<string> downloaded)
    {
        return missingIds.Where(id =>
            !NeedsDownload(packages[id], installerTypes.GetValueOrDefault(id)) || downloaded.Contains(id)).ToArray();
    }
}
