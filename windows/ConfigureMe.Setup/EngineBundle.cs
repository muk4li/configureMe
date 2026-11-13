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
    private readonly Dictionary<string, (string Hash, long Size)> _files;

    private EngineBundle(string engineRoot, Dictionary<string, (string Hash, long Size)> files)
    {
        _engineRoot = engineRoot;
        _files = files;
    }

    public string BootstrapPath => Path.Combine(_engineRoot, "bootstrap.ps1");
    public string CatalogPath => Path.Combine(_engineRoot, "config", "catalog.json");
    public string ProfilePath => Path.Combine(_engineRoot, "config", "windows-server-2022-developer.json");

    public static EngineBundle ExtractVerified(string? applicationDataRoot = null, Action<string>? beforePublish = null)
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
        var files = new Dictionary<string, (string Hash, long Size)>(StringComparer.OrdinalIgnoreCase);
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
            if (!File.Exists(targetPath))
            {
                var temporaryPath = targetPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
                try
                {
                    using (var output = new FileStream(temporaryPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                    {
                        output.Write(bytes);
                    }
                    // Test seam at the publication boundary; normal callers supply no callback.
                    beforePublish?.Invoke(targetPath);
                    ValidatePath(targetPath);
                    try
                    {
                        File.Move(temporaryPath, targetPath); // Never replace another instance's file.
                    }
                    catch (IOException) when (File.Exists(targetPath))
                    {
                        // Another instance may have published first. Existence is not trust:
                        // the same path/size/hash checks below apply to every winner.
                    }
                }
                finally
                {
                    if (File.Exists(temporaryPath))
                    {
                        ValidatePath(temporaryPath);
                        File.Delete(temporaryPath); // Only our uniquely named unpublished file.
                    }
                }
            }
            VerifyFile(targetPath, actualHash, file.SizeBytes);
            files.Add(targetPath, (actualHash, file.SizeBytes));
        }

        return new EngineBundle(destination, files);
    }

    public void VerifyUnchanged()
    {
        foreach (var (path, expected) in _files)
        {
            VerifyFile(path, expected.Hash, expected.Size);
        }
    }

    private static void VerifyFile(string path, string expectedHash, long expectedSize)
    {
        ValidatePath(path);
        // On Windows, disallow writers/deletion while verifying these exact bytes.
        using var input = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        ValidatePath(path);
        if (input.Length != expectedSize ||
            !Convert.ToHexString(SHA256.HashData(input)).Equals(expectedHash, StringComparison.OrdinalIgnoreCase))
        {
            throw new IOException($"The extracted engine file '{path}' was modified; refusing to run it.");
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
