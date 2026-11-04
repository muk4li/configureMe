using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class PowerShellWorkerClientTests
{
    [Fact]
    public async Task DrainsValidStatusEventsAfterMalformedLine()
    {
        using var output = new StringReader("invalid json\n" +
            "{\"type\":\"installation-completed\",\"packageId\":\"git\",\"status\":\"installed\",\"data\":null}\n");
        var observed = new List<WorkerEvent>();

        var (events, error) = await PowerShellWorkerClient.ReadEventsAsync(output, observed.Add);

        Assert.NotNull(error);
        Assert.Single(events);
        Assert.Single(observed);
        Assert.Equal("installation-completed", events[0].Type);
        Assert.Equal("git", events[0].PackageId);
    }
}
