namespace ConfigureMe.Setup;

internal static class InstallPlanResolver
{
    public static IReadOnlyList<string> Resolve(IEnumerable<string> packageIds, IReadOnlyDictionary<string, PackageDefinition> packages)
    {
        var result = new List<string>();
        var added = new HashSet<string>(StringComparer.Ordinal);
        var visiting = new HashSet<string>(StringComparer.Ordinal);

        void Visit(string id)
        {
            if (added.Contains(id))
            {
                return;
            }

            if (!visiting.Add(id))
            {
                throw new InvalidOperationException($"Package dependency cycle includes '{id}'.");
            }

            if (!packages.TryGetValue(id, out var package) || !package.Platforms.TryGetValue("windows", out _))
            {
                throw new InvalidOperationException($"Package '{id}' is not in the trusted Windows catalog.");
            }

            foreach (var dependency in package.Dependencies)
            {
                Visit(dependency);
            }

            visiting.Remove(id);
            added.Add(id);
            result.Add(id);
        }

        foreach (var packageId in packageIds.Distinct(StringComparer.Ordinal))
        {
            Visit(packageId);
        }

        return result;
    }
}
