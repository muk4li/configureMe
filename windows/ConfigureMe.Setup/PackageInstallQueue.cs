namespace ConfigureMe.Setup;

internal sealed class PackageInstallQueue
{
    private readonly object _gate = new();
    private readonly Queue<string> _pending = new();
    private readonly HashSet<string> _scheduled = new(StringComparer.Ordinal);
    private readonly Func<string, Task> _install;
    private Task? _processor;
    private string? _activePackageId;

    public PackageInstallQueue(Func<string, Task> install) => _install = install;

    public event Action<string>? PackageStarted;
    public event Action<string>? PackageCompleted;
    public event Action<string, Exception>? PackageFailed;

    public bool IsBusy
    {
        get { lock (_gate) return _processor is not null; }
    }

    public string? ActivePackageId
    {
        get { lock (_gate) return _activePackageId; }
    }

    public int PendingCount
    {
        get { lock (_gate) return _pending.Count; }
    }

    public int Enqueue(IEnumerable<string> packageIds)
    {
        lock (_gate)
        {
            var added = 0;
            foreach (var packageId in packageIds.Distinct(StringComparer.Ordinal))
            {
                if (!_scheduled.Add(packageId))
                {
                    continue;
                }

                _pending.Enqueue(packageId);
                added++;
            }

            if (added > 0 && _processor is null)
            {
                _processor = Task.Run(ProcessQueueAsync);
            }

            return added;
        }
    }

    public IReadOnlyList<string> CancelPending()
    {
        lock (_gate)
        {
            var canceled = new List<string>(_pending.Count);
            while (_pending.TryDequeue(out var packageId))
            {
                _scheduled.Remove(packageId);
                canceled.Add(packageId);
            }
            return canceled;
        }
    }

    private async Task ProcessQueueAsync()
    {
        while (true)
        {
            string packageId;
            lock (_gate)
            {
                if (_pending.Count == 0)
                {
                    _activePackageId = null;
                    _processor = null;
                    return;
                }
                packageId = _pending.Dequeue();
                _activePackageId = packageId;
            }

            PackageStarted?.Invoke(packageId);
            try
            {
                await _install(packageId).ConfigureAwait(false);
                PackageCompleted?.Invoke(packageId);
            }
            catch (Exception exception)
            {
                PackageFailed?.Invoke(packageId, exception);
            }
            finally
            {
                lock (_gate)
                {
                    _scheduled.Remove(packageId);
                    _activePackageId = null;
                }
            }
        }
    }
}
