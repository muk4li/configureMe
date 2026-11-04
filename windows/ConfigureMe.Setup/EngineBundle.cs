using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ConfigureMe.Setup;

internal sealed class EngineBundle
{
    private static readonly string[] ResourceNames =
    [
        "ConfigureMe.Engine.bootstrap.ps1",
        "ConfigureMe.Engine.config.catalog.json",
        "ConfigureMe.Engine.config.windows-server-2022-developer.json",
        "ConfigureMe.Engine.modules.Detection.psm1",
        "ConfigureMe.Engine.modules.Downloads.psm1",
        "ConfigureMe.Engine.modules.GuiWorker.psm1",
        "ConfigureMe.Engine.modules.Installation.psm1",
        "ConfigureMe.Engine.modules.Logging.psm1",
        "ConfigureMe.Engine.modules.Verification.psm1",
        "ConfigureMe.Engine.assets.firefox-bookmarks.html"
    ];

    private readonly string _engineRoot;
    private readonly Dictionary<string, string> _hashes;

    private EngineBundle(string engineRoot, Dictionary<string, string> hashes)
    {
        _engineRoot = engineRoot;
        _hashes = hashes;
    }

    public string BootstrapPath => Path.Combine(_engineRoot, "bootstrap.ps1");
    public string CatalogPath => Path.Combine(_engineRoot, "config", "catalog.json");
    public string ProfilePath => Path.Combine(_engineRoot, "config", "windows-server-2022-developer.json");

    public static EngineBundle ExtractVerified(string? applicationDataRoot = null)
    {
        var assembly = Assembly.GetExecutingAssembly();
        using var manifestStream = assembly.GetManifestResourceStream("ConfigureMe.Engine.manifest.json")
            ?? throw new InvalidDataException("The embedded PowerShell engine manifest is missing.");
        using var manifestMemory = new MemoryStream();
        manifestStream.CopyTo(manifestMemory);
        var manifestBytes = manifestMemory.ToArray();
        var manifest = JsonSerializer.Deserialize<EngineManifest>(manifestBytes, new JsonSerializerOptions(JsonSerializerDefaults.Web))
            ?? throw new InvalidDataException("The embedded PowerShell engine manifest is invalid.");
        if (manifest.SchemaVersion != 1 || manifest.Files.Count != ResourceNames.Length)
        {
            throw new InvalidDataException("The embedded PowerShell engine manifest does not match the supported layout.");
        }

        var manifestHash = Convert.ToHexString(SHA256.HashData(manifestBytes)).ToLowerInvariant();
        var appData = applicationDataRoot ?? Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var engineBase = Path.Combine(appData, "configureMe", "engine");
        CreateSafeDirectory(engineBase);
        var destination = Path.Combine(engineBase, manifestHash);
        CreateSafeDirectory(destination);

        var seen = new HashSet<string>(StringComparer.Ordinal);
        var hashes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var file in manifest.Files)
        {
            if (!ResourceNames.Contains(file.ResourceName, StringComparer.Ordinal) || !seen.Add(file.ResourceName))
            {
                throw new InvalidDataException("The PowerShell engine manifest contains an unexpected resource.");
            }

            var relativePath = file.Path.Replace('/', Path.DirectorySeparatorChar);
            if (Path.IsPathRooted(relativePath) || relativePath.Split(Path.DirectorySeparatorChar).Any(part => part is "." or ".."))
            {
                throw new InvalidDataException("The PowerShell engine manifest contains an unsafe path.");
            }

            using var resource = assembly.GetManifestResourceStream(file.ResourceName)
                ?? throw new InvalidDataException($"Embedded engine resource '{file.ResourceName}' is missing.");
            using var memory = new MemoryStream();
            resource.CopyTo(memory);
            var bytes = memory.ToArray();
            var actualHash = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
            if (!actualHash.Equals(file.Sha256, StringComparison.OrdinalIgnoreCase) || bytes.LongLength != file.SizeBytes)
            {
                throw new InvalidDataException($"Embedded engine resource '{file.Path}' failed its integrity check.");
            }

            var targetPath = Path.GetFullPath(Path.Combine(destination, relativePath));
            if (!targetPath.StartsWith(destination + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("The PowerShell engine manifest path escaped the extraction directory.");
            }

            var parent = Path.GetDirectoryName(targetPath)!;
            CreateSafeDirectory(parent);
            ValidatePath(targetPath);
            if (File.Exists(targetPath))
            {
                var existingHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(targetPath))).ToLowerInvariant();
                if (!existingHash.Equals(actualHash, StringComparison.OrdinalIgnoreCase))
                {
                    throw new IOException($"The extracted engine file '{relativePath}' was modified; refusing to run it.");
                }
            }
            else
            {
                var temporaryPath = targetPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
                try
                {
                    using (var output = new FileStream(temporaryPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                    {
                        output.Write(bytes);
                    }
                    ValidatePath(targetPath);
                    File.Move(temporaryPath, targetPath);
                }
                finally
                {
                    if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
                }
            }
            hashes.Add(targetPath, actualHash);
        }

        return new EngineBundle(destination, hashes);
    }

    public void VerifyUnchanged()
    {
        foreach (var (path, expectedHash) in _hashes)
        {
            ValidatePath(path);
            if (!Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).Equals(expectedHash, StringComparison.OrdinalIgnoreCase))
            {
                throw new IOException($"The extracted engine file '{path}' was modified; refusing to run it.");
            }
        }
    }

    internal static void CreateSafeDirectory(string path)
    {
        ValidatePath(path);
        Directory.CreateDirectory(path);
        ValidatePath(path);
    }

    internal static void ValidatePath(string path)
    {
        for (string? current = Path.GetFullPath(path); current is not null; current = Path.GetDirectoryName(current))
        {
            try
            {
                if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                {
                    throw new IOException($"The setup path '{current}' is a reparse point; refusing to use it.");
                }
            }
            catch (FileNotFoundException) { }
            catch (DirectoryNotFoundException) { }
        }
    }

    private sealed class EngineManifest
    {
        [JsonPropertyName("schemaVersion")]
        public int SchemaVersion { get; set; }

        [JsonPropertyName("files")]
        public List<EngineFile> Files { get; set; } = [];
    }

    private sealed class EngineFile
    {
        [JsonPropertyName("path")]
        public string Path { get; set; } = "";

        [JsonPropertyName("resourceName")]
        public string ResourceName { get; set; } = "";

        [JsonPropertyName("sha256")]
        public string Sha256 { get; set; } = "";

        [JsonPropertyName("sizeBytes")]
        public long SizeBytes { get; set; }
    }
}
