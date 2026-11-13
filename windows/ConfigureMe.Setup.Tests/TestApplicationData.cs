namespace ConfigureMe.Setup.Tests;

// Each test owns its directory; never redirect process-wide LOCALAPPDATA in parallel tests.
internal sealed class TestApplicationData : IDisposable
{
    public string Root { get; } = Directory.CreateTempSubdirectory("configureme-test-").FullName;

    public void Dispose() => Directory.Delete(Root, recursive: true);
}
