using System.Diagnostics;
using System.Drawing;
using System.Reflection;
using System.Text.Json;
using System.Threading;
using System.Windows.Forms;

namespace ConfigureMe.Setup;

internal sealed class SetupForm : Form
{
    private static readonly Color WindowColor = Color.FromArgb(25, 29, 35);
    private static readonly Color PanelColor = Color.FromArgb(34, 39, 47);
    private static readonly Color MutedColor = Color.FromArgb(177, 186, 197);
    private static readonly Color AccentColor = Color.FromArgb(82, 156, 255);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly EngineBundle _engine;
    private readonly PowerShellWorkerClient _worker;
    private readonly List<PackageDefinition> _packages;
    private readonly Dictionary<string, PackageDefinition> _packageById;
    private readonly Dictionary<string, PackageViewState> _states = new(StringComparer.Ordinal);
    private readonly Dictionary<string, CheckBox> _selection = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Label> _statusLabels = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Button> _packageButtons = new(StringComparer.Ordinal);
    private readonly HashSet<string> _developerProfileIds;
    private readonly PackageInstallQueue _installQueue;
    private readonly Label _systemLabel = new();
    private readonly Label _currentActionLabel = new();
    private readonly ProgressBar _progressBar = new();
    private readonly RichTextBox _log = new();
    private readonly Button _installSelectedButton = new();
    private readonly Button _cancelButton = new();
    private readonly ToolTip _toolTip = new();
    private CancellationTokenSource? _downloadCancellation;
    private string? _reportPath;
    private bool _isPreparingDownloads;

    public SetupForm()
    {
        _engine = EngineBundle.ExtractVerified();
        _worker = new PowerShellWorkerClient(_engine);
        var catalog = JsonSerializer.Deserialize<CatalogDocument>(File.ReadAllText(_engine.CatalogPath), JsonOptions)
            ?? throw new InvalidDataException("The configureMe package catalog could not be loaded.");
        if (catalog.SchemaVersion != 1)
        {
            throw new InvalidDataException("The configureMe package catalog version is not supported.");
        }

        _packages = catalog.Packages
            .Where(item => item.WindowsMode != "catalog-only" && item.Platforms.TryGetValue("windows", out var strategy) && strategy.Supported)
            .OrderBy(item => item.Category, StringComparer.CurrentCulture)
            .ThenBy(item => item.Name, StringComparer.CurrentCulture)
            .ToList();
        _packageById = _packages.ToDictionary(item => item.Id, StringComparer.Ordinal);
        foreach (var package in _packages)
        {
            _states.Add(package.Id, new PackageViewState());
        }
        _developerProfileIds = LoadDeveloperProfile(_engine.ProfilePath);
        _installQueue = new PackageInstallQueue(InstallOnePackageAsync);
        _installQueue.PackageStarted += id => PostToUi(() => QueuePackageStarted(id));
        _installQueue.PackageCompleted += id => PostToUi(() => QueuePackageFinished(id, null));
        _installQueue.PackageFailed += (id, exception) => PostToUi(() => QueuePackageFinished(id, exception));

        InitializeWindow();
        BuildLayout();
        BuildPackageList();
        Shown += async (_, _) =>
        {
            await CheckSystemAsync();
            LoadDeveloperProfileSelection();
        };
    }

    private void InitializeWindow()
    {
        Text = "configureMe Setup";
        MinimumSize = new Size(900, 700);
        Size = new Size(1180, 900);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = WindowColor;
        ForeColor = Color.White;
        Font = new Font("Segoe UI", 9F);
        AutoScaleMode = AutoScaleMode.Dpi;
        DoubleBuffered = true;
    }

    private void BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 6,
            Padding = new Padding(20),
            BackColor = WindowColor
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 90));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 90));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 145));
        Controls.Add(root);

        var header = new Panel { Dock = DockStyle.Fill };
        var title = new Label
        {
            Text = "configureMe Setup",
            Font = new Font("Segoe UI Semibold", 21F, FontStyle.Bold),
            ForeColor = Color.White,
            AutoSize = true,
            Location = new Point(0, 2)
        };
        var subtitle = new Label
        {
            Text = "Windows Server 2022 Developer Workstation",
            ForeColor = MutedColor,
            AutoSize = true,
            Location = new Point(2, 39)
        };
        var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "development";
        var versionLabel = new Label
        {
            Text = $"Setup version {version}",
            ForeColor = MutedColor,
            AutoSize = true,
            Anchor = AnchorStyles.Top | AnchorStyles.Right
        };
        header.Controls.Add(title);
        header.Controls.Add(subtitle);
        header.Controls.Add(versionLabel);
        header.Resize += (_, _) => versionLabel.Location = new Point(Math.Max(0, header.ClientSize.Width - versionLabel.Width), 10);
        root.Controls.Add(header, 0, 0);

        _systemLabel.Dock = DockStyle.Fill;
        _systemLabel.Text = "System und installierte Programme werden geprüft …";
        _systemLabel.ForeColor = MutedColor;
        _systemLabel.TextAlign = ContentAlignment.MiddleLeft;
        root.Controls.Add(_systemLabel, 0, 1);

        var listPanel = new Panel { Dock = DockStyle.Fill, BackColor = WindowColor };
        var packageList = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoScroll = true,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            BackColor = WindowColor,
            Padding = new Padding(0, 5, 8, 5)
        };
        listPanel.Controls.Add(packageList);
        root.Controls.Add(listPanel, 0, 2);
        _packageList = packageList;

        var actionPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            Padding = new Padding(0, 8, 0, 0),
            BackColor = WindowColor
        };
        actionPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        actionPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        var selectionActions = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false };
        selectionActions.Controls.Add(CreateButton("Alle auswählen", (_, _) => SelectAll(true)));
        selectionActions.Controls.Add(CreateButton("Auswahl aufheben", (_, _) => SelectAll(false)));
        selectionActions.Controls.Add(CreateButton("Nur fehlende", (_, _) => SelectMissing()));
        selectionActions.Controls.Add(CreateButton("Developer-Profil", (_, _) => LoadDeveloperProfileSelection()));
        actionPanel.Controls.Add(selectionActions, 0, 0);

        var mainActions = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false };
        mainActions.Controls.Add(CreateButton("System prüfen", async (_, _) => await CheckSystemAsync()));
        mainActions.Controls.Add(CreateButton("Dry-Run", async (_, _) => await ShowDryRunAsync()));
        _installSelectedButton.Text = "Ausgewählte installieren";
        StyleButton(_installSelectedButton, primary: true);
        _installSelectedButton.Click += async (_, _) => await InstallSelectedAsync();
        mainActions.Controls.Add(_installSelectedButton);
        _cancelButton.Text = "Installation abbrechen";
        StyleButton(_cancelButton, primary: false);
        _cancelButton.Click += (_, _) => CancelPending();
        mainActions.Controls.Add(_cancelButton);
        mainActions.Controls.Add(CreateButton("Report exportieren", (_, _) => ExportReport()));
        actionPanel.Controls.Add(mainActions, 0, 1);
        root.Controls.Add(actionPanel, 0, 3);

        var progressPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            BackColor = PanelColor,
            Padding = new Padding(10)
        };
        progressPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 25));
        progressPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        _currentActionLabel.Text = "Bereit";
        _currentActionLabel.ForeColor = MutedColor;
        _currentActionLabel.Dock = DockStyle.Fill;
        progressPanel.Controls.Add(_currentActionLabel, 0, 0);
        _progressBar.Style = ProgressBarStyle.Blocks;
        _progressBar.Dock = DockStyle.Fill;
        _progressBar.Visible = false;
        progressPanel.Controls.Add(_progressBar, 0, 1);
        root.Controls.Add(progressPanel, 0, 4);

        _log.ReadOnly = true;
        _log.BackColor = PanelColor;
        _log.ForeColor = Color.FromArgb(225, 231, 238);
        _log.BorderStyle = BorderStyle.None;
        _log.Dock = DockStyle.Fill;
        root.Controls.Add(_log, 0, 5);
        _toolTip.AutoPopDelay = 10000;
        _toolTip.InitialDelay = 400;
        _toolTip.ReshowDelay = 100;
    }

    private FlowLayoutPanel _packageList = new();

    private void BuildPackageList()
    {
        foreach (var category in _packages.GroupBy(item => item.Category))
        {
            var group = new Panel
            {
                Width = Math.Max(500, _packageList.ClientSize.Width - 20),
                AutoSize = true,
                BackColor = WindowColor,
                Margin = new Padding(0, 0, 0, 12)
            };
            var heading = new Label
            {
                Text = category.Key,
                Font = new Font("Segoe UI Semibold", 11F, FontStyle.Bold),
                ForeColor = AccentColor,
                Height = 30,
                Dock = DockStyle.Top,
                TextAlign = ContentAlignment.MiddleLeft
            };
            group.Controls.Add(heading);
            foreach (var package in category)
            {
                group.Controls.Add(CreatePackageRow(package));
            }
            _packageList.Controls.Add(group);
        }

        _packageList.SizeChanged += (_, _) =>
        {
            foreach (Control control in _packageList.Controls)
            {
                control.Width = Math.Max(500, _packageList.ClientSize.Width - 25);
            }
        };
    }

    private Control CreatePackageRow(PackageDefinition package)
    {
        var row = new TableLayoutPanel
        {
            ColumnCount = 4,
            RowCount = 1,
            Height = 76,
            Width = Math.Max(500, _packageList.ClientSize.Width - 20),
            Dock = DockStyle.Top,
            BackColor = PanelColor,
            Margin = new Padding(0, 2, 0, 2),
            Padding = new Padding(10, 6, 8, 6)
        };
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 34));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 46));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 34));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 132));

        var checkBox = new CheckBox
        {
            Dock = DockStyle.Fill,
            AutoSize = false,
            Text = "",
            TextAlign = ContentAlignment.MiddleCenter,
            CheckAlign = ContentAlignment.MiddleCenter
        };
        _selection.Add(package.Id, checkBox);
        row.Controls.Add(checkBox, 0, 0);

        var description = new Label
        {
            Dock = DockStyle.Fill,
            Text = $"{package.Name}\n{package.Description}",
            ForeColor = Color.White,
            AutoEllipsis = true,
            TextAlign = ContentAlignment.MiddleLeft
        };
        row.Controls.Add(description, 1, 0);

        var status = new Label
        {
            Dock = DockStyle.Fill,
            Text = "Nicht geprüft",
            ForeColor = MutedColor,
            AutoEllipsis = true,
            TextAlign = ContentAlignment.MiddleLeft
        };
        _statusLabels.Add(package.Id, status);
        row.Controls.Add(status, 2, 0);

        var action = new Button
        {
            Text = package.WindowsMode == "automatic" ? "Installieren" : package.WindowsMode == "web-fallback" ? "Öffnen" : "Details",
            Dock = DockStyle.Fill,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(48, 57, 68),
            ForeColor = Color.White
        };
        action.FlatAppearance.BorderColor = Color.FromArgb(71, 82, 96);
        action.Click += async (_, _) =>
        {
            if (package.WindowsMode == "automatic")
            {
                await InstallOneWithConfirmationAsync(package.Id);
            }
            else if (package.WindowsMode == "web-fallback")
            {
                OpenOfficialWebsite(package);
            }
            else
            {
                ShowPackageDetails(package);
            }
        };
        _packageButtons.Add(package.Id, action);
        row.Controls.Add(action, 3, 0);
        _toolTip.SetToolTip(row, package.WindowsMode switch
        {
            "detection-only" => "Nur Erkennung. Docker Desktop wird auf Windows Server nicht neu installiert.",
            "web-fallback" => "Öffnet die offizielle Web-Anwendung; dies ist keine Desktop-Installation.",
            "manual" => "Manueller Installationsweg; configureMe führt keinen ungeprüften Installer aus.",
            _ => package.Platforms["windows"].Label
        });
        return row;
    }

    private Button CreateButton(string text, EventHandler click)
    {
        var button = new Button { Text = text, AutoSize = true, Height = 34, Margin = new Padding(0, 0, 8, 0) };
        StyleButton(button, primary: false);
        button.Click += click;
        return button;
    }

    private static void StyleButton(Button button, bool primary)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = primary ? AccentColor : Color.FromArgb(71, 82, 96);
        button.BackColor = primary ? Color.FromArgb(37, 105, 190) : Color.FromArgb(48, 57, 68);
        button.ForeColor = Color.White;
        button.Padding = new Padding(8, 2, 8, 2);
        button.Margin = new Padding(0, 0, 8, 0);
        button.Height = Math.Max(button.Height, 34);
    }

    private async Task CheckSystemAsync()
    {
        SetBusyState(true, "System und Programme werden geprüft …", marquee: true);
        try
        {
            await _worker.RunAsync("detect", _packages.Select(item => item.Id).ToArray(), false, HandleWorkerEvent);
            _currentActionLabel.Text = "Systemprüfung abgeschlossen.";
        }
        catch (Exception exception)
        {
            AppendLog($"Systemprüfung fehlgeschlagen: {exception.Message}", error: true);
            MessageBox.Show(this, exception.Message, "Systemprüfung fehlgeschlagen", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        finally
        {
            SetBusyState(false, _currentActionLabel.Text, marquee: false);
        }
    }

    private async Task ShowDryRunAsync()
    {
        var selected = SelectedPackageIds();
        if (selected.Count == 0)
        {
            MessageBox.Show(this, "Wähle mindestens ein Programm aus.", "Dry-Run", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        await ShowPlanAsync(selected, dryRun: true);
    }

    private async Task InstallSelectedAsync()
    {
        var selected = SelectedPackageIds();
        if (selected.Count == 0)
        {
            MessageBox.Show(this, "Wähle mindestens ein Programm aus.", "Installation", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        await ShowPlanAsync(selected, dryRun: false);
    }

    private async Task InstallOneWithConfirmationAsync(string packageId)
    {
        await ShowPlanAsync([packageId], dryRun: false);
    }

    private async Task ShowPlanAsync(IReadOnlyList<string> packageIds, bool dryRun)
    {
        IReadOnlyList<string> ordered;
        try
        {
            ordered = InstallPlanResolver.Resolve(packageIds, _packageById);
        }
        catch (Exception exception)
        {
            MessageBox.Show(this, exception.Message, "Ungültiger Installationsplan", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        var toInstall = ordered.Where(id => !_states[id].IsInstalled).ToArray();
        if (toInstall.Length == 0 && !dryRun)
        {
            MessageBox.Show(this, "Alle ausgewählten Programme sind bereits installiert.", "Installationsplan", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        SetBusyState(true, "Installationsplan wird vorbereitet …", marquee: true);
        try
        {
            var result = await _worker.RunAsync("plan", ordered, false, HandleWorkerEvent);
            var planEvent = result.Events.LastOrDefault(item => item.Type == "install-plan");
            var summary = FormatPlan(planEvent?.Data, ordered);
            if (dryRun)
            {
                MessageBox.Show(this, summary, "Dry-Run — keine Änderungen", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            var confirmation = MessageBox.Show(
                this,
                $"{summary}\n\nInstallationen laufen nacheinander. Installationsprogramme werden nicht beendet, wenn du die Warteschlange abbrichst. Fortfahren?",
                "Installationsplan bestätigen",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning,
                MessageBoxDefaultButton.Button2);
            if (confirmation != DialogResult.Yes)
            {
                return;
            }

            var automaticPackages = toInstall.Where(id => _packageById[id].WindowsMode == "automatic").ToArray();
            var downloaded = await DownloadSelectedPackagesAsync(automaticPackages);
            if (downloaded is null)
            {
                return;
            }

            var queueIds = toInstall.Where(id =>
                _packageById[id].WindowsMode != "automatic" ||
                downloaded.Contains(id, StringComparer.Ordinal)).ToArray();
            foreach (var id in queueIds)
            {
                _states[id].Status = _packageById[id].WindowsMode == "automatic" ? "Wartet auf Installation" : "Manuelle Aktion erforderlich";
                UpdatePackageRow(id);
            }
            var added = _installQueue.Enqueue(queueIds);
            AppendLog($"{added} Paket(e) zur Warteschlange hinzugefügt. Installationen laufen seriell.");
            if (added == 0)
            {
                AppendLog("Es gibt keine weiteren Pakete zur Installation.");
            }
        }
        catch (Exception exception)
        {
            AppendLog($"Installationsplan fehlgeschlagen: {exception.Message}", error: true);
            MessageBox.Show(this, exception.Message, "Installationsplan fehlgeschlagen", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            var busy = _installQueue.IsBusy || _isPreparingDownloads;
            SetBusyState(busy, busy ? "Warteschlange läuft …" : "Bereit", marquee: busy);
        }
    }

    private async Task<HashSet<string>?> DownloadSelectedPackagesAsync(IReadOnlyList<string> packageIds)
    {
        var successful = new HashSet<string>(StringComparer.Ordinal);
        if (packageIds.Count == 0)
        {
            return successful;
        }

        using var cancellation = new CancellationTokenSource();
        _downloadCancellation = cancellation;
        _isPreparingDownloads = true;
        SetBusyState(true, $"Lade {packageIds.Count} Installer mit maximal zwei gleichzeitigen Downloads …", marquee: true);
        using var semaphore = new SemaphoreSlim(2, 2);
        try
        {
            var tasks = packageIds.Select(async id =>
            {
                try
                {
                    await semaphore.WaitAsync(cancellation.Token);
                    try
                    {
                        var result = await _worker.RunAsync(
                            "download",
                            [id],
                            confirmed: true,
                            onEvent: HandleWorkerEvent,
                            cancellationToken: cancellation.Token);
                        return (Id: id, Ready: result.ExitCode == 0);
                    }
                    finally
                    {
                        semaphore.Release();
                    }
                }
                catch (OperationCanceledException)
                {
                    return (Id: id, Ready: false);
                }
                catch (Exception exception)
                {
                    PostToUi(() =>
                    {
                        _states[id].Status = "Fehlgeschlagen";
                        _states[id].Error = exception.Message;
                        UpdatePackageRow(id);
                        AppendLog($"Download oder Sicherheitsprüfung für {PackageName(id)} fehlgeschlagen: {exception.Message}", error: true);
                    });
                    return (Id: id, Ready: false);
                }
            });
            var results = await Task.WhenAll(tasks);
            foreach (var result in results.Where(item => item.Ready))
            {
                successful.Add(result.Id);
            }
            if (cancellation.IsCancellationRequested)
            {
                return null;
            }
            return successful;
        }
        finally
        {
            _downloadCancellation = null;
            _isPreparingDownloads = false;
        }
    }

    private async Task InstallOnePackageAsync(string packageId)
    {
        PostToUi(() => _currentActionLabel.Text = $"Wird vorbereitet: {_packageById[packageId].Name}");
        await _worker.RunAsync("install", [packageId], confirmed: true, HandleWorkerEvent);
    }

    private void HandleWorkerEvent(WorkerEvent workerEvent)
    {
        PostToUi(() => ApplyWorkerEvent(workerEvent));
    }

    private void ApplyWorkerEvent(WorkerEvent workerEvent)
    {
        switch (workerEvent.Type)
        {
            case "system-detected":
                UpdateSystemHeader(workerEvent.Data);
                break;
            case "package-detected" when workerEvent.PackageId is { } detectedId && _states.TryGetValue(detectedId, out var detectedState):
                detectedState.DetectedVersion = PowerShellWorkerClient.ReadString(workerEvent.Data, "detectedVersion");
                detectedState.Status = detectedState.IsInstalled ? "Bereits installiert" : "Bereit";
                detectedState.Details = PowerShellWorkerClient.ReadString(workerEvent.Data, "details");
                UpdatePackageRow(detectedId);
                break;
            case "package-status" when workerEvent.PackageId is { } statusId && _states.TryGetValue(statusId, out var statusState):
                statusState.Status = TranslateStatus(workerEvent.Status);
                UpdatePackageRow(statusId);
                break;
            case "download-started":
                SetCurrentPackageStatus(workerEvent, "Download läuft");
                AppendLog($"Download startet: {PackageName(workerEvent.PackageId)}");
                break;
            case "download-completed":
                SetCurrentPackageStatus(workerEvent, "Download abgeschlossen");
                AppendLog($"Download abgeschlossen: {PackageName(workerEvent.PackageId)}");
                break;
            case "verification-started":
                SetCurrentPackageStatus(workerEvent, "Signatur wird geprüft");
                AppendLog($"Prüfe Installer: {PackageName(workerEvent.PackageId)}");
                break;
            case "verification-completed":
                AppendLog($"Installer-Prüfung abgeschlossen: {PackageName(workerEvent.PackageId)}");
                break;
            case "installation-started":
                SetCurrentPackageStatus(workerEvent, "Installation läuft");
                AppendLog($"Installation gestartet: {PackageName(workerEvent.PackageId)}");
                break;
            case "installation-completed":
                SetCurrentPackageStatus(workerEvent, "Verifikation läuft");
                break;
            case "package-installation-completed" when workerEvent.PackageId is { } finishedId && _states.TryGetValue(finishedId, out var finishedState):
                if (workerEvent.Data.ValueKind == JsonValueKind.Object)
                {
                    finishedState.DetectedVersion = PowerShellWorkerClient.ReadString(workerEvent.Data, "DetectedVersion") ?? finishedState.DetectedVersion;
                    finishedState.Error = PowerShellWorkerClient.ReadString(workerEvent.Data, "Notes");
                }
                finishedState.Status = TranslateStatus(workerEvent.Status);
                UpdatePackageRow(finishedId);
                AppendLog($"{PackageName(finishedId)}: {finishedState.Status}{(string.IsNullOrWhiteSpace(finishedState.Error) ? "" : $" — {finishedState.Error}")}",
                    error: workerEvent.Status == "Failed");
                break;
            case "report-written":
                _reportPath = PowerShellWorkerClient.ReadString(workerEvent.Data, "jsonPath");
                AppendLog("Abschlussbericht wurde geschrieben.");
                break;
            case "log":
                AppendLog(workerEvent.Message ?? "PowerShell-Engine", error: workerEvent.Status == "error");
                break;
            case "worker-error":
                AppendLog(workerEvent.Message ?? "Workerfehler", error: true);
                break;
        }
    }

    private void SetCurrentPackageStatus(WorkerEvent workerEvent, string status)
    {
        if (workerEvent.PackageId is { } packageId && _states.TryGetValue(packageId, out var state))
        {
            state.Status = status;
            UpdatePackageRow(packageId);
            _currentActionLabel.Text = $"{status}: {PackageName(packageId)}";
        }
    }

    private void UpdateSystemHeader(JsonElement data)
    {
        if (!data.TryGetProperty("operatingSystem", out var operatingSystem))
        {
            return;
        }
        var caption = PowerShellWorkerClient.ReadString(operatingSystem, "Caption") ?? "Windows";
        var architecture = PowerShellWorkerClient.ReadString(operatingSystem, "Architecture") ?? "unbekannt";
        var systemSupported = operatingSystem.TryGetProperty("IsSupported", out var supported) && supported.ValueKind == JsonValueKind.True;
        var administrator = data.TryGetProperty("isAdministrator", out var admin) && admin.ValueKind == JsonValueKind.True;
        var adminText = administrator ? "Administratorrechte vorhanden" : "ohne Administratorrechte";
        _systemLabel.Text = $"{caption} · {architecture} · {adminText} · {(systemSupported ? "unterstütztes Ziel" : "nicht unterstütztes Ziel")}";
        _systemLabel.ForeColor = systemSupported ? MutedColor : Color.FromArgb(255, 190, 96);
    }

    private string FormatPlan(JsonElement? data, IReadOnlyList<string> ordered)
    {
        if (!data.HasValue || data.Value.ValueKind != JsonValueKind.Array)
        {
            return string.Join(Environment.NewLine, ordered.Select(PackageName));
        }

        var lines = new List<string>();
        foreach (var entry in data.Value.EnumerateArray())
        {
            var id = PowerShellWorkerClient.ReadString(entry, "id") ?? "";
            var name = PowerShellWorkerClient.ReadString(entry, "name") ?? PackageName(id);
            var action = PowerShellWorkerClient.ReadString(entry, "action") ?? "install";
            var requiresAdmin = entry.TryGetProperty("requiresAdministrator", out var admin) && admin.ValueKind == JsonValueKind.True;
            var available = entry.TryGetProperty("administratorAvailable", out var adminAvailable) && adminAvailable.ValueKind == JsonValueKind.True;
            var method = PowerShellWorkerClient.ReadString(entry, "method");
            var detail = action switch
            {
                "detection-only" => "Nur erkennen — nicht unterstützt",
                "manual-action" => "Manuelle Aktion erforderlich",
                _ => method ?? "Automatische Installation"
            };
            if (requiresAdmin && !available)
            {
                detail += " (Administrator erforderlich; aktuell nicht erhöht)";
            }
            lines.Add($"• {name}: {detail}");
        }
        return string.Join(Environment.NewLine, lines);
    }

    private void QueuePackageStarted(string id)
    {
        _progressBar.Visible = true;
        _progressBar.Style = ProgressBarStyle.Marquee;
        _currentActionLabel.Text = $"Warteschlange: {PackageName(id)}";
        if (_states.TryGetValue(id, out var state))
        {
            state.Status = "Wird geprüft";
            UpdatePackageRow(id);
        }
    }

    private void QueuePackageFinished(string id, Exception? exception)
    {
        if (exception is not null)
        {
            _states[id].Status = "Fehlgeschlagen";
            _states[id].Error = exception.Message;
            UpdatePackageRow(id);
            AppendLog($"{PackageName(id)} fehlgeschlagen: {exception.Message}", error: true);
        }

        if (!_installQueue.IsBusy)
        {
            _progressBar.Visible = false;
            _currentActionLabel.Text = "Warteschlange abgeschlossen.";
        }
    }

    private void CancelPending()
    {
        if (_downloadCancellation is not null)
        {
            _downloadCancellation.Cancel();
            AppendLog("Laufende Downloads werden abgebrochen. Es wurde noch kein Installer gestartet.");
            return;
        }
        var canceled = _installQueue.CancelPending();
        foreach (var id in canceled)
        {
            _states[id].Status = "Abgebrochen";
            UpdatePackageRow(id);
        }
        AppendLog($"{canceled.Count} wartende Installation(en) abgebrochen. Ein bereits gestarteter Installer läuft sicher zu Ende.");
        if (!_installQueue.IsBusy)
        {
            _currentActionLabel.Text = "Bereit";
            _progressBar.Visible = false;
        }
    }

    private void SelectAll(bool selected)
    {
        foreach (var checkBox in _selection.Values)
        {
            checkBox.Checked = selected;
        }
    }

    private void SelectMissing()
    {
        foreach (var (id, checkBox) in _selection)
        {
            checkBox.Checked = !_states[id].IsInstalled;
        }
    }

    private void LoadDeveloperProfileSelection()
    {
        foreach (var (id, checkBox) in _selection)
        {
            checkBox.Checked = _developerProfileIds.Contains(id) && !_states[id].IsInstalled;
        }
    }

    private List<string> SelectedPackageIds() =>
        _selection.Where(item => item.Value.Checked).Select(item => item.Key).ToList();

    private void UpdatePackageRow(string id)
    {
        if (!_states.TryGetValue(id, out var state))
        {
            return;
        }
        _statusLabels[id].Text = string.IsNullOrWhiteSpace(state.DetectedVersion)
            ? state.Status
            : $"{state.Status} · {state.DetectedVersion}";
        _statusLabels[id].ForeColor = state.Status switch
        {
            "Fehlgeschlagen" or "Nicht unterstützt" => Color.FromArgb(255, 138, 138),
            "Erfolgreich" or "Bereits installiert" => Color.FromArgb(130, 220, 160),
            "Manuelle Aktion erforderlich" => Color.FromArgb(255, 190, 96),
            _ => MutedColor
        };
        var package = _packageById[id];
        _packageButtons[id].Enabled = !_installQueue.IsBusy || _installQueue.ActivePackageId != id;
        _selection[id].Enabled = state.Status is not ("Download läuft" or "Installation läuft" or "Verifikation läuft");
        if (_packageButtons[id].Text == "Installieren" && state.IsInstalled)
        {
            _packageButtons[id].Enabled = false;
        }
    }

    private void ShowPackageDetails(PackageDefinition package)
    {
        var modeNote = package.WindowsMode switch
        {
            "detection-only" => "Diese Anwendung wird nur erkannt. Eine Neuinstallation ist auf Windows Server nicht unterstützt.",
            "manual" => "Für dieses Programm gibt es keinen verifizierten automatischen Installationsweg.",
            _ => package.Description
        };
        var choice = MessageBox.Show(
            this,
            $"{modeNote}\n\nQuelle: {package.Website}\n\nDie GUI führt keinen ungeprüften Installer aus. Möchtest du die offizielle Website öffnen?",
            package.Name,
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Information);
        if (choice == DialogResult.Yes)
        {
            OpenOfficialWebsite(package);
        }
    }

    private void OpenOfficialWebsite(PackageDefinition package)
    {
        if (!Uri.TryCreate(package.Website, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
        {
            MessageBox.Show(this, "Die Katalog-URL ist ungültig.", package.Name, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        Process.Start(new ProcessStartInfo(uri.AbsoluteUri) { UseShellExecute = true });
    }

    private void ExportReport()
    {
        if (string.IsNullOrWhiteSpace(_reportPath) || !File.Exists(_reportPath))
        {
            MessageBox.Show(this, "Es liegt noch kein Installationsbericht vor.", "Report exportieren", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        using var dialog = new SaveFileDialog
        {
            Title = "configureMe-Bericht exportieren",
            FileName = "configureMe-setup-report.json",
            Filter = "JSON-Bericht (*.json)|*.json"
        };
        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }
        File.Copy(_reportPath, dialog.FileName, overwrite: true);
        var textPath = Path.ChangeExtension(_reportPath, ".txt");
        if (File.Exists(textPath))
        {
            File.Copy(textPath, Path.ChangeExtension(dialog.FileName, ".txt"), overwrite: true);
        }
        AppendLog($"Bericht exportiert: {dialog.FileName}");
    }

    private void SetBusyState(bool busy, string message, bool marquee)
    {
        _currentActionLabel.Text = message;
        _progressBar.Visible = busy && marquee;
        if (_progressBar.Visible)
        {
            _progressBar.Style = ProgressBarStyle.Marquee;
        }
    }

    private void AppendLog(string message, bool error = false)
    {
        if (IsDisposed)
        {
            return;
        }
        var prefix = DateTime.Now.ToString("HH:mm:ss");
        _log.SelectionStart = _log.TextLength;
        _log.SelectionColor = error ? Color.FromArgb(255, 138, 138) : MutedColor;
        _log.AppendText($"[{prefix}] {message}{Environment.NewLine}");
        _log.SelectionColor = _log.ForeColor;
        _log.ScrollToCaret();
    }

    private string PackageName(string? id) =>
        id is not null && _packageById.TryGetValue(id, out var package) ? package.Name : id ?? "System";

    private static string TranslateStatus(string? status) => status switch
    {
        "installed" or "Already installed" => "Bereits installiert",
        "already-installed" => "Bereits installiert",
        "missing" => "Bereit",
        "ready" => "Bereit",
        "Installed" => "Erfolgreich",
        "Failed" => "Fehlgeschlagen",
        "Requires user action" => "Manuelle Aktion erforderlich",
        "Not supported" or "unsupported" => "Nicht unterstützt",
        "Skipped by user" or "canceled" => "Abgebrochen",
        "installing" => "Installation läuft",
        "error" => "Fehler",
        _ => status ?? "Bereit"
    };

    private void PostToUi(Action action)
    {
        if (IsDisposed || !IsHandleCreated)
        {
            return;
        }
        BeginInvoke(action);
    }

    private static HashSet<string> LoadDeveloperProfile(string profilePath)
    {
        using var document = JsonDocument.Parse(File.ReadAllText(profilePath));
        return document.RootElement.GetProperty("packages")
            .EnumerateArray()
            .Select(item => item.GetString()!)
            .ToHashSet(StringComparer.Ordinal);
    }
}
