using System.Text.Json.Serialization;

namespace ConfigureMe.Setup;

internal sealed class CatalogDocument
{
    [JsonPropertyName("schemaVersion")]
    public int SchemaVersion { get; set; }

    [JsonPropertyName("version")]
    public string Version { get; set; } = "";

    [JsonPropertyName("packages")]
    public List<PackageDefinition> Packages { get; set; } = [];
}

internal sealed class PackageDefinition
{
    [JsonPropertyName("windowsPackageId")]
    public string? WindowsPackageId { get; set; }

    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("description")]
    public string Description { get; set; } = "";

    [JsonPropertyName("category")]
    public string Category { get; set; } = "";

    [JsonPropertyName("website")]
    public string Website { get; set; } = "";

    [JsonPropertyName("windowsMode")]
    public string WindowsMode { get; set; } = "";

    [JsonPropertyName("elevated")]
    public bool Elevated { get; set; }

    [JsonPropertyName("dependencies")]
    public List<string> Dependencies { get; set; } = [];

    [JsonPropertyName("platforms")]
    public Dictionary<string, InstallStrategy> Platforms { get; set; } = [];
}

internal sealed class InstallStrategy
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("supported")]
    public bool Supported { get; set; }

    [JsonPropertyName("label")]
    public string Label { get; set; } = "";
}

internal sealed record WorkerRequest(int SchemaVersion, string Action, string[]? PackageIds = null, bool Confirmed = false);

internal sealed record WorkerEvent(
    string Type,
    string? PackageId,
    string? Status,
    string? Message,
    System.Text.Json.JsonElement Data);

internal sealed class PackageViewState
{
    public string Status { get; set; } = "Nicht geprüft";
    public string? DetectedVersion { get; set; }
    public string? Details { get; set; }
    public string? Error { get; set; }
    public string? CurrentPhase { get; set; }
    public PackageDetectionState Detection { get; set; } = PackageDetectionState.Unknown;
    public bool IsInstalled => Detection == PackageDetectionState.Installed;
}

internal enum PackageDetectionState { Unknown, Checking, Missing, Installed, Failed }
