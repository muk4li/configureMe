using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace ConfigureMe.Setup;

internal sealed record ValidatedSetupPlan(string[] RequestedIds, string[] PackageIds,
    IReadOnlyDictionary<string, string[]> RequiredBy, IReadOnlyDictionary<string, bool> Reminders);
internal sealed record NativePlanTarget(string Os, string Architecture, bool DesktopExperience = true)
{
    public static NativePlanTarget Current()
    {
        if (!OperatingSystem.IsWindows()) return new("unsupported", "unsupported", false);
        const string key = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion";
        var build = Microsoft.Win32.Registry.GetValue(key, "CurrentBuildNumber", null) as string;
        var installation = Microsoft.Win32.Registry.GetValue(key, "InstallationType", null) as string;
        return new(build == "20348" && installation == "Server" ? "windows-server-2022" : "unsupported",
            System.Runtime.InteropServices.RuntimeInformation.OSArchitecture.ToString().ToLowerInvariant(), installation == "Server");
    }
}

// Parses a bounded immutable snapshot. Import never starts a worker or grants installation rights.
internal static class SetupPlanContract
{
    private static readonly JsonElement Schema = ReadResource("ConfigureMe.Contract.schema.json");
    private static readonly JsonElement Policy = ReadResource("ConfigureMe.Contract.policy.json");
    public static int MaxBytes => Policy.GetProperty("maxBytes").GetInt32();
    public static int MaxDepth => Policy.GetProperty("maxDepth").GetInt32();

    private static JsonElement ReadResource(string name)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name)
            ?? throw new InvalidDataException("The embedded setup-plan contract is missing.");
        using var document = JsonDocument.Parse(stream);
        return document.RootElement.Clone();
    }

    public static ValidatedSetupPlan Validate(ReadOnlyMemory<byte> snapshot, ReadOnlySpan<byte> catalogBytes,
        NativePlanTarget? nativeTarget = null)
    {
        if (snapshot.Length > MaxBytes) throw new InvalidDataException("Der Setup-Plan ist zu groß.");
        using var document = JsonDocument.Parse(snapshot, new JsonDocumentOptions { MaxDepth = MaxDepth });
        var root = document.RootElement;
        CheckStructure(root, Schema);
        var expectedRevision = Schema.GetProperty("properties").GetProperty("catalogRevision").GetProperty("const").GetString();
        if (!string.Equals(Convert.ToHexStringLower(SHA256.HashData(catalogBytes)), expectedRevision, StringComparison.Ordinal))
            throw new InvalidDataException("Der Installerkatalog ist mit diesem Planvertrag nicht kompatibel.");
        var target = root.GetProperty("target");
        var os = target.GetProperty("os").GetString()!;
        if (nativeTarget is not null && (os != Policy.GetProperty("nativeTarget").GetString() ||
            nativeTarget.Os != os || nativeTarget.Architecture != "x64" || !nativeTarget.DesktopExperience))
            throw new InvalidDataException("Planimport/Dry-Run unterstützt nur Windows Server 2022 x64 Desktop Experience. Windows 11 hat noch keinen nativen Adapter.");
        var catalog = JsonSerializer.Deserialize<CatalogDocument>(catalogBytes)
            ?? throw new InvalidDataException("Der vertrauenswürdige Katalog fehlt.");
        var byId = catalog.Packages.ToDictionary(item => item.Id, StringComparer.Ordinal);
        var requested = Strings(root.GetProperty("planning").GetProperty("requestedPackageIds"));
        EnsureSorted(requested);
        EnsureSorted(Strings(root.GetProperty("planning").GetProperty("profileIds")));
        var effective = new HashSet<string>(StringComparer.Ordinal);
        var visiting = new HashSet<string>(StringComparer.Ordinal);
        var requiredBy = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        void Visit(string id)
        {
            if (effective.Contains(id)) return;
            if (!visiting.Add(id)) throw new InvalidDataException("Der Katalog enthält einen Abhängigkeitszyklus.");
            if (!byId.TryGetValue(id, out var package) || Mode(package, os) == "unavailable")
                throw new InvalidDataException("Unbekanntes oder inkompatibles Paket im Setup-Plan.");
            foreach (var dependency in package.Dependencies.Order(StringComparer.Ordinal))
            {
                if (!requiredBy.TryGetValue(dependency, out var parents)) requiredBy[dependency] = parents = [];
                parents.Add(id);
                Visit(dependency);
            }
            visiting.Remove(id); effective.Add(id);
        }
        foreach (var id in requested) Visit(id);
        var ids = effective.Order(StringComparer.Ordinal).ToArray();
        var packages = root.GetProperty("packages").EnumerateArray().ToArray();
        if (packages.Length != ids.Length) throw new InvalidDataException("Die effektive Paketauswahl ist unvollständig oder erweitert.");
        for (var i = 0; i < ids.Length; i++)
        {
            var item = packages[i]; var package = byId[ids[i]];
            if (item.GetProperty("id").GetString() != ids[i] || item.GetProperty("mode").GetString() != Mode(package, os) ||
                !Strings(item.GetProperty("dependsOn")).SequenceEqual(package.Dependencies.Order(StringComparer.Ordinal)))
                throw new InvalidDataException("Paketmodus oder Abhängigkeiten passen nicht zum vertrauenswürdigen Katalog.");
        }
        var reminders = root.GetProperty("options").EnumerateObject().ToDictionary(item => item.Name, item => item.Value.GetBoolean());
        return new(requested, ids, requiredBy.ToDictionary(item => item.Key,
            item => item.Value.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray()), reminders);
    }

    private static string Mode(PackageDefinition package, string os)
    {
        if (!package.Platforms.TryGetValue("windows", out var strategy) || !strategy.Supported || package.WindowsMode == "catalog-only") return "unavailable";
        if (os == "windows-11") return string.IsNullOrEmpty(package.WindowsPackageId) ? "unavailable" : "winget";
        return package.WindowsMode is "automatic" or "manual" or "web-fallback" or "detection-only" ? package.WindowsMode : "unavailable";
    }
    private static string[] Strings(JsonElement array) => array.EnumerateArray().Select(item => item.GetString()!).ToArray();
    private static void EnsureSorted(string[] values)
    {
        if (!values.SequenceEqual(values.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal)))
            throw new InvalidDataException("Plan-IDs müssen eindeutig und sortiert sein.");
    }

    // Deliberately limited JSON-Schema vocabulary. Unsupported keywords fail closed.
    // TypeScript uses Zod's schema importer; both consumers use the same schema and fixtures.
    private static void CheckStructure(JsonElement value, JsonElement schema)
    {
        foreach (var keyword in schema.EnumerateObject())
            if (keyword.Name is not ("$schema" or "$id" or "title" or "description" or "type" or "const" or "enum" or
                "properties" or "required" or "additionalProperties" or "items" or "minItems" or "maxItems" or "uniqueItems" or
                "minLength" or "maxLength" or "pattern")) throw new InvalidDataException("Nicht unterstütztes Contract-Schema.");
        if (schema.TryGetProperty("const", out var constant) && !JsonElement.DeepEquals(value, constant)) Fail();
        if (schema.TryGetProperty("enum", out var enumeration) && !enumeration.EnumerateArray().Any(item => JsonElement.DeepEquals(value, item))) Fail();
        if (schema.TryGetProperty("type", out var type))
        {
            var validType = type.GetString() switch
            {
                "object" => value.ValueKind == JsonValueKind.Object,
                "array" => value.ValueKind == JsonValueKind.Array,
                "string" => value.ValueKind == JsonValueKind.String,
                "boolean" => value.ValueKind is JsonValueKind.True or JsonValueKind.False,
                _ => false
            };
            if (!validType) Fail();
        }
        if (value.ValueKind == JsonValueKind.Object)
        {
            var properties = schema.GetProperty("properties");
            var names = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in value.EnumerateObject())
            {
                if (!names.Add(property.Name) || !properties.TryGetProperty(property.Name, out var child)) Fail();
                CheckStructure(property.Value, properties.GetProperty(property.Name));
            }
            foreach (var required in schema.GetProperty("required").EnumerateArray())
                if (!names.Contains(required.GetString()!)) Fail();
        }
        if (value.ValueKind == JsonValueKind.Array)
        {
            var items = value.EnumerateArray().ToArray();
            if (items.Length < schema.GetProperty("minItems").GetInt32() || items.Length > schema.GetProperty("maxItems").GetInt32()) Fail();
            for (var i = 0; i < items.Length; i++)
            {
                if (schema.GetProperty("uniqueItems").GetBoolean() && items.Take(i).Any(item => JsonElement.DeepEquals(item, items[i]))) Fail();
                CheckStructure(items[i], schema.GetProperty("items"));
            }
        }
        if (value.ValueKind == JsonValueKind.String && schema.TryGetProperty("pattern", out var pattern))
        {
            var text = value.GetString()!;
            if (text.Length < schema.GetProperty("minLength").GetInt32() || text.Length > schema.GetProperty("maxLength").GetInt32() ||
                !Regex.IsMatch(text, pattern.GetString()!, RegexOptions.CultureInvariant, TimeSpan.FromMilliseconds(100))) Fail();
        }
    }
    private static void Fail() => throw new InvalidDataException("Der Setup-Plan entspricht nicht dem unterstützten Schema (Version, Felder oder Werte).");
}
