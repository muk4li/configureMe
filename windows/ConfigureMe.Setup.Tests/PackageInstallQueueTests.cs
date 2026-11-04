using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class PackageInstallQueueTests
{
    [Fact]
    public async Task RunsSeriallySkipsDuplicatesAndContinuesAfterFailure()
    {
        var order = new List<string>();
        var active = 0;
        var maximumActive = 0;
        var completed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var drained = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var queue = new PackageInstallQueue(async id =>
        {
            var count = Interlocked.Increment(ref active);
            UpdateMaximum(ref maximumActive, count);
            await Task.Delay(20);
            lock (order)
            {
                order.Add(id);
            }
            Interlocked.Decrement(ref active);
            if (id == "git")
            {
                throw new InvalidOperationException("expected mock failure");
            }
        });
        queue.PackageCompleted += id =>
        {
            if (id == "vscode")
            {
                completed.TrySetResult();
            }
        };
        queue.PackageFailed += (id, _) =>
        {
            if (id == "git")
            {
                Assert.Equal(["git"], order.ToArray());
            }
        };
        queue.Drained += () => drained.TrySetResult();

        Assert.Equal(2, queue.Enqueue(["git", "github-cli", "git"]));
        Assert.Equal(0, queue.Enqueue(["github-cli"]));
        Assert.Equal(1, queue.Enqueue(["vscode"]));
        await completed.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await drained.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.Equal(["git", "github-cli", "vscode"], order);
        Assert.Equal(1, maximumActive);
    }

    [Fact]
    public async Task CancelsPendingItemsWithoutInterruptingTheActivePackage()
    {
        var started = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var completed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var drained = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var queue = new PackageInstallQueue(async id =>
        {
            if (id == "git")
            {
                started.TrySetResult();
                await release.Task;
            }
        });
        queue.PackageCompleted += _ => completed.TrySetResult();
        queue.Drained += () => drained.TrySetResult();

        Assert.Equal(2, queue.Enqueue(["git", "github-cli"]));
        await started.Task.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal(["github-cli"], queue.CancelPending());
        release.TrySetResult();
        await completed.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await drained.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.False(queue.IsBusy);
    }

    private static void UpdateMaximum(ref int maximum, int value)
    {
        int current;
        do
        {
            current = maximum;
            if (current >= value)
            {
                return;
            }
        }
        while (Interlocked.CompareExchange(ref maximum, value, current) != current);
    }
}
