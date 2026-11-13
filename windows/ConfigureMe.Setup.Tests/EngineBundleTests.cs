using System.Text.Json;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class EngineBundleTests
{
    [Fact]
    public void EmbeddedEngineExtractsWithVerifiedCatalogAndBootstrap()
    {
        using var directory = new TestApplicationData();
        var engine = EngineBundle.ExtractVerified(directory.Root);

        Assert.True(File.Exists(engine.BootstrapPath));
        Assert.True(File.Exists(engine.CatalogPath));
        Assert.True(File.Exists(engine.ProfilePath));
        using var catalog = JsonDocument.Parse(File.ReadAllText(engine.CatalogPath));
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

    [Fact]
    public async Task ConcurrentExtractionsAcceptOnlyTheVerifiedWinner()
    {
        using var directory = new TestApplicationData();
        using var arrived = new CountdownEvent(2);
        using var winnerFinished = new ManualResetEventSlim();
        // Both instances see bootstrap.ps1 missing. The second cannot publish until
        // the first has completed, forcing a real no-overwrite destination conflict.
        var tasks = Enumerable.Range(0, 2).Select(index => Task.Factory.StartNew(() =>
        {
            try
            {
                return EngineBundle.ExtractVerified(directory.Root, path =>
                {
                    if (Path.GetFileName(path) != "bootstrap.ps1") return;
                    arrived.Signal();
                    if (!arrived.Wait(TimeSpan.FromSeconds(10)))
                        throw new TimeoutException("Both extractions must reach the publication boundary.");
                    if (index == 1 && !winnerFinished.Wait(TimeSpan.FromSeconds(10)))
                        throw new TimeoutException("The first extraction must publish before its competitor.");
                });
            }
            finally { if (index == 0) winnerFinished.Set(); }
        }, CancellationToken.None, TaskCreationOptions.LongRunning, TaskScheduler.Default)).ToArray();
        var engines = await Task.WhenAll(tasks);
        Assert.Equal(engines[0].BootstrapPath, engines[1].BootstrapPath);
        foreach (var engine in engines) engine.VerifyUnchanged();
        Assert.Empty(Directory.GetFiles(directory.Root, "*.tmp", SearchOption.AllDirectories));
        var bytes = File.ReadAllBytes(engines[0].BootstrapPath);
        bytes[0] ^= 0xff; // Same length: every instance must retain the expected digest.
        File.WriteAllBytes(engines[0].BootstrapPath, bytes);
        foreach (var engine in engines) Assert.Throws<IOException>(engine.VerifyUnchanged);
        Assert.Throws<IOException>(() => EngineBundle.ExtractVerified(directory.Root));
    }

    [Theory]
    [InlineData("same-length")]
    [InlineData("truncated")]
    [InlineData("directory")]
    public void RefusesConflictingDestinationWithoutReplacingOrDeletingIt(string conflict)
    {
        using var directory = new TestApplicationData();
        string? conflictingPath = null;
        byte[]? conflictingBytes = null;
        Assert.Throws<IOException>(() => EngineBundle.ExtractVerified(directory.Root, path =>
        {
            conflictingPath = path;
            if (conflict == "directory") Directory.CreateDirectory(path);
            else
            {
                conflictingBytes = conflict == "truncated" ? [0] : File.ReadAllBytes(
                    Directory.GetFiles(Path.GetDirectoryName(path)!, Path.GetFileName(path) + ".*.tmp").Single());
                conflictingBytes[0] ^= 0xff;
                File.WriteAllBytes(path, conflictingBytes);
            }
        }));
        Assert.NotNull(conflictingPath);
        if (conflict == "directory") Assert.True(Directory.Exists(conflictingPath));
        else Assert.Equal(conflictingBytes, File.ReadAllBytes(conflictingPath));
        Assert.Throws<IOException>(() => EngineBundle.ExtractVerified(directory.Root));
        Assert.Empty(Directory.GetFiles(directory.Root, "*.tmp", SearchOption.AllDirectories));
    }
}
