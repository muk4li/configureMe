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
    private readonly List<(TableLayoutPanel Group, int PackageCount)> _categoryGroups = [];
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
    private bool _operationInProgress;
    private readonly List<Button> _exclusiveButtons = [];
    private SetupRunReport? _runReport;
    private WorkerEvent? _lastSystemEvent;
    private bool _reflowingPackages;
    private bool _reflowingWindow;
    private TableLayoutPanel? _layoutRoot;
    private TableLayoutPanel? _actionPanel;
    private FlowLayoutPanel? _selectionActions;
    private FlowLayoutPanel? _mainActions;
    private bool _isAdministrator;
    private string? _lastFailureText;

    public SetupForm(bool runStartupDetection = true, string? applicationDataRoot = null)
    {
        _engine = EngineBundle.ExtractVerified(applicationDataRoot);
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
        _developerProfileIds = LoadDeveloperProfile(_engine.ProfilePath, _packageById);
        _installQueue = new PackageInstallQueue(InstallOnePackageAsync);
        _installQueue.PackageStarted += id => PostToUi(() => QueuePackageStarted(id));
        _installQueue.PackageCompleted += id => PostToUi(() => QueuePackageFinished(id, null));
        _installQueue.PackageFailed += (id, exception) => PostToUi(() => QueuePackageFinished(id, exception));
        _installQueue.Drained += () => PostToUi(() =>
        {
            if (_installQueue.IsBusy) return;
            SaveRunReport(completed: true);
            SetBusyState(false, "Warteschlange abgeschlossen.", marquee: false);
        });

        InitializeWindow();
        BuildLayout();
        BuildPackageList();
        LoadDeveloperProfileSelection();
        ReflowWindowLayout();
        if (runStartupDetection) Shown += async (_, _) =>
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
        AutoScaleDimensions = new SizeF(96F, 96F);
        AutoScaleMode = AutoScaleMode.Dpi;
        DoubleBuffered = true;
        AutoScroll = true;
        Load += (_, _) => { FitWorkingArea(); ReflowWindowLayout(); };
        Shown += (_, _) => ReflowWindowLayout();
        DpiChanged += (_, _) => BeginInvoke(() => { FitWorkingArea(); ReflowWindowLayout(); });
        FormClosing += (_, args) =>
        {
            if (!_operationInProgress && !_installQueue.IsBusy) return;
            args.Cancel = true;
            MessageBox.Show(this, "Bitte zuerst die Warteschlange abbrechen und einen aktiven Installer zu Ende laufen lassen.", "Setup läuft", MessageBoxButtons.OK, MessageBoxIcon.Information);
        };
    }

    private void BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Name = "RootLayout",
            Dock = DockStyle.Top,
            ColumnCount = 1,
            RowCount = 6,
            Padding = new Padding(20),
            BackColor = WindowColor
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 90));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 145));
        _layoutRoot = root;
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

        var listPanel = new Panel { Name = "PackageViewport", Dock = DockStyle.Fill, BackColor = WindowColor };
        var packageList = new FlowLayoutPanel
        {
            Name = "PackageList",
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
            Name = "ActionPanel",
            AutoSize = false,
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            Padding = new Padding(0, 8, 0, 0),
            BackColor = WindowColor
        };
        actionPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        actionPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        actionPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        var selectionActions = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = false, WrapContents = true, Margin = new Padding(0) };
        selectionActions.Controls.Add(CreateButton("Alle auswählen", (_, _) => SelectAll(true)));
        selectionActions.Controls.Add(CreateButton("Auswahl aufheben", (_, _) => SelectAll(false)));
        selectionActions.Controls.Add(CreateButton("Nur fehlende", (_, _) => SelectMissing()));
        selectionActions.Controls.Add(CreateButton("Developer-Profil", (_, _) => LoadDeveloperProfileSelection()));
        actionPanel.Controls.Add(selectionActions, 0, 0);

        var mainActions = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = false, WrapContents = true, Margin = new Padding(0) };
        mainActions.Controls.Add(CreateButton("System prüfen", async (_, _) => await CheckSystemAsync()));
        mainActions.Controls.Add(CreateButton("Dry-Run", async (_, _) => await ShowDryRunAsync()));
        _installSelectedButton.Text = "Ausgewählte installieren";
        StyleButton(_installSelectedButton, primary: true);
        _installSelectedButton.Click += async (_, _) => await InstallSelectedAsync();
        mainActions.Controls.Add(_installSelectedButton);
        _exclusiveButtons.Add(_installSelectedButton);
        _cancelButton.Text = "Installation abbrechen";
        StyleButton(_cancelButton, primary: false);
        _cancelButton.Click += (_, _) => CancelPending();
        mainActions.Controls.Add(_cancelButton);
        mainActions.Controls.Add(CreateButton("Report exportieren", (_, _) => ExportReport()));
        actionPanel.Controls.Add(mainActions, 0, 1);
        _actionPanel = actionPanel;
        _selectionActions = selectionActions;
        _mainActions = mainActions;
        foreach (var button in selectionActions.Controls.OfType<Button>().Concat(mainActions.Controls.OfType<Button>()))
            button.TextChanged += (_, _) => ReflowWindowLayout();
        root.Controls.Add(actionPanel, 0, 3);

        var progressPanel = new TableLayoutPanel
        {
            Name = "ProgressPanel",
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

        _log.Name = "InstallationLog";
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
            var packages = category.ToArray();
            var group = new TableLayoutPanel
            {
                Name = $"Category:{category.Key}",
                ColumnCount = 1,
                RowCount = packages.Length + 1,
                AutoSize = false,
                GrowStyle = TableLayoutPanelGrowStyle.FixedSize,
                BackColor = WindowColor,
                Margin = new Padding(0, 0, 0, 12),
                Padding = new Padding(0, 0, 0, 6)
            };
            group.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            var heading = new Label
            {
                Name = $"CategoryHeading:{category.Key}",
                Text = category.Key,
                Font = new Font("Segoe UI Semibold", 11F, FontStyle.Bold),
                ForeColor = AccentColor,
                Dock = DockStyle.Fill,
                AutoEllipsis = true,
                TextAlign = ContentAlignment.MiddleLeft
            };
            group.Controls.Add(heading, 0, 0);
            for (var index = 0; index < packages.Length; index++)
            {
                group.Controls.Add(CreatePackageRow(packages[index]), 0, index + 1);
            }
            _categoryGroups.Add((group, packages.Length));
            _packageList.Controls.Add(group);
        }
        _packageList.SizeChanged += (_, _) => ReflowPackageList();
        ReflowPackageList();
    }

    private void ReflowPackageList()
    {
        if (_reflowingPackages || _categoryGroups.Count == 0) return;
        _reflowingPackages = true;
        try
        {
            _packageList.SuspendLayout();
            var rowHeight = Math.Max(82, Font.Height * 4 + 22);
            var headingHeight = Math.Max(32, Font.Height * 2 + 4);
            var width = Math.Max(480, _packageList.ClientSize.Width - _packageList.Padding.Horizontal -
                SystemInformation.VerticalScrollBarWidth - 4);
            foreach (var (group, count) in _categoryGroups)
            {
                group.SuspendLayout();
                group.Width = width;
                group.Height = headingHeight + count * rowHeight + group.Padding.Vertical;
                group.RowStyles.Clear();
                group.RowStyles.Add(new RowStyle(SizeType.Absolute, headingHeight));
                for (var index = 0; index < count; index++)
                    group.RowStyles.Add(new RowStyle(SizeType.Absolute, rowHeight));
                group.ResumeLayout(true);
            }
        }
        finally
        {
            _packageList.ResumeLayout(true);
            _reflowingPackages = false;
        }
    }

    internal void AssertPackageLayout()
    {
        var visibleRows = 0;
        foreach (var (group, count) in _categoryGroups)
        {
            if (group.Width <= 0 || group.Height <= 0 || group.RowStyles.Count != count + 1)
                throw new InvalidDataException($"Kategorie '{group.Name}' hat keine vollständige Größe.");
            var previousBottom = -1;
            for (var index = 0; index < count; index++)
            {
                var row = group.GetControlFromPosition(0, index + 1)
                    ?? throw new InvalidDataException($"In '{group.Name}' fehlt Paketzeile {index + 1}.");
                if (!group.Visible || !row.Visible || row.Height < Font.Height * 2 || row.Width < 400 || row.Top < previousBottom ||
                    row.Bottom > group.ClientSize.Height || row.Controls.Count != 4)
                    throw new InvalidDataException($"Paketzeile '{row.Name}' wird abgeschnitten oder überlagert.");
                if (row.Controls.Find(row.Name.Replace("Package:", "PackageName:"), true).Length != 1 ||
                    row.Controls.Find(row.Name.Replace("Package:", "PackageStatus:"), true).Length != 1)
                    throw new InvalidDataException($"In '{row.Name}' fehlen sichtbare Paketinformationen.");
                previousBottom = row.Bottom;
                visibleRows++;
            }
        }
        if (visibleRows != _packages.Count || visibleRows == 0)
            throw new InvalidDataException("Die Paketliste enthält nicht alle unterstützten Katalogpakete.");
        if (_packageList.ClientSize.Height < _categoryGroups.Sum(item => item.Group.Height) &&
            !_packageList.VerticalScroll.Visible)
            throw new InvalidDataException("Die lange Paketliste ist nicht vertikal scrollbar.");
    }

    private Control CreatePackageRow(PackageDefinition package)
    {
        var row = new TableLayoutPanel
        {
            Name = $"Package:{package.Id}",
            ColumnCount = 4,
            RowCount = 1,
            Dock = DockStyle.Fill,
            BackColor = PanelColor,
            Margin = new Padding(0, 2, 0, 2),
            Padding = new Padding(10, 6, 8, 6)
        };
        // An implicit AutoSize row can grow to wrapped description text even though
        // the outer category assigns a fixed row height. Keep its children inside
        // that assigned viewport; long descriptions already use AutoEllipsis.
        row.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, Math.Max(34, Font.Height * 2)));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 55));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 45));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, Math.Max(132, Font.Height * 9)));

        var checkBox = new CheckBox
        {
            Name = $"PackageSelection:{package.Id}",
            Dock = DockStyle.Fill,
            AutoSize = false,
            Text = "",
            TextAlign = ContentAlignment.MiddleCenter,
            CheckAlign = ContentAlignment.MiddleCenter
        };
        _selection.Add(package.Id, checkBox);
        row.Controls.Add(checkBox, 0, 0);

        var descriptionPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            Margin = new Padding(0),
            BackColor = PanelColor
        };
        descriptionPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        descriptionPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 48));
        descriptionPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 52));
        descriptionPanel.Controls.Add(new Label
        {
            Name = $"PackageName:{package.Id}", Text = package.Name,
            Dock = DockStyle.Fill, Font = new Font(Font, FontStyle.Bold), ForeColor = Color.White,
            AutoEllipsis = true, TextAlign = ContentAlignment.BottomLeft
        }, 0, 0);
        descriptionPanel.Controls.Add(new Label
        {
            Name = $"PackageDescription:{package.Id}", Text = package.Description,
            Dock = DockStyle.Fill, ForeColor = MutedColor,
            AutoEllipsis = true, TextAlign = ContentAlignment.TopLeft
        }, 0, 1);
        row.Controls.Add(descriptionPanel, 1, 0);

        var status = new Label
        {
            Name = $"PackageStatus:{package.Id}",
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
            Name = $"PackageAction:{package.Id}",
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

    protected override void OnLayout(LayoutEventArgs levent)
    {
        base.OnLayout(levent);
        ReflowWindowLayout();
    }

    private float LayoutScale => Math.Max(DeviceDpi / 96F, Font.SizeInPoints / 9F);

    private void ReflowWindowLayout()
    {
        if (_reflowingWindow || _layoutRoot is null || _actionPanel is null ||
            _selectionActions is null || _mainActions is null) return;
        _reflowingWindow = true;
        try
        {
            int Pixels(int value) => (int)Math.Ceiling(value * LayoutScale);
            var root = _layoutRoot;
            // Avoid nested AutoSize/Percent feedback: reserve measured action heights
            // first, then give the package viewport the remaining space. DockStyle.Top
            // allows the form to scroll the whole content on short/high-DPI desktops.
            root.Padding = new Padding(Pixels(20));
            root.PerformLayout();
            var actionWidth = Math.Max(Pixels(200), root.ClientSize.Width - root.Padding.Horizontal - _actionPanel.Margin.Horizontal);
            _actionPanel.Padding = new Padding(0, Pixels(8), 0, 0);
            var selectionHeight = MeasureActionHeight(_selectionActions, actionWidth);
            var mainHeight = MeasureActionHeight(_mainActions, actionWidth);
            _actionPanel.RowStyles[0].Height = selectionHeight;
            _actionPanel.RowStyles[1].Height = mainHeight;
            root.RowStyles[0].Height = Pixels(90);
            root.RowStyles[1].Height = Pixels(48);
            root.RowStyles[3].Height = selectionHeight + mainHeight + _actionPanel.Padding.Vertical + _actionPanel.Margin.Vertical;
            root.RowStyles[4].Height = Pixels(62);
            root.RowStyles[5].Height = Pixels(Math.Clamp((int)(ClientSize.Height / LayoutScale * .17F), 80, 145));
            var fixedHeight = root.RowStyles.Cast<RowStyle>().Where(row => row.SizeType == SizeType.Absolute).Sum(row => row.Height);
            var minimumHeight = (int)Math.Ceiling(fixedHeight) + root.Padding.Vertical + Pixels(150);
            root.Height = Math.Max(ClientSize.Height, minimumHeight);
            root.PerformLayout();
            ReflowPackageList();
        }
        finally { _reflowingWindow = false; }
    }

    private int MeasureActionHeight(FlowLayoutPanel panel, int availableWidth)
    {
        int Pixels(int value) => (int)Math.Ceiling(value * LayoutScale);
        var lineWidth = 0;
        var lineHeight = 0;
        var height = 0;
        foreach (var button in panel.Controls.OfType<Button>())
        {
            button.Padding = new Padding(Pixels(8), Pixels(2), Pixels(8), Pixels(2));
            button.Margin = new Padding(0, 0, Pixels(8), Pixels(6));
            button.MinimumSize = new Size(0, Pixels(34));
            button.Size = button.GetPreferredSize(Size.Empty);
            var width = button.Width + button.Margin.Horizontal;
            if (lineWidth > 0 && lineWidth + width > availableWidth)
            {
                height += lineHeight;
                lineWidth = 0;
                lineHeight = 0;
            }
            lineWidth += width;
            lineHeight = Math.Max(lineHeight, button.Height + button.Margin.Vertical);
        }
        return height + lineHeight;
    }

    internal void AssertMainLayout()
    {
        var root = _layoutRoot ?? throw new InvalidOperationException("Missing root layout.");
        var viewport = root.GetControlFromPosition(0, 2)!;
        if (!_packageList.Visible || _packageList.ClientSize.Height < 100 * LayoutScale || _packageList.ClientSize.Width < 400)
            throw new InvalidOperationException($"Package viewport collapsed: {_packageList.ClientSize}, scale={LayoutScale}.");
        var sections = root.Controls.Cast<Control>().ToArray();
        foreach (var section in sections)
        {
            if (!section.Visible || section.Height <= 0 || !root.ClientRectangle.Contains(section.Bounds))
                throw new InvalidOperationException($"Root section is clipped: {section.Name}, bounds={section.Bounds}, root={root.ClientSize}.");
            foreach (var sibling in sections)
                if (sibling != section && section.Bounds.IntersectsWith(sibling.Bounds))
                    throw new InvalidOperationException($"Root sections overlap: {section.Name}, {sibling.Name}.");
        }
        foreach (var panel in new[] { _selectionActions!, _mainActions! })
        {
            if (!_actionPanel!.ClientRectangle.Contains(panel.Bounds))
                throw new InvalidOperationException($"Action strip is clipped by its container: {panel.Bounds}, parent={_actionPanel.ClientSize}.");
        }
        if (!viewport.ClientRectangle.Contains(_packageList.Bounds))
            throw new InvalidOperationException("Package list is clipped by its viewport.");
        var firstGroup = _categoryGroups[0].Group;
        if (firstGroup.Height <= 0 || firstGroup.Width <= 0)
            throw new InvalidOperationException("Package categories have no usable area.");
    }

    private void FitWorkingArea()
    {
        var area = Screen.FromControl(this).WorkingArea;
        MinimumSize = new Size(Math.Min(MinimumSize.Width, area.Width), Math.Min(MinimumSize.Height, area.Height));
        Size = new Size(Math.Min(Width, area.Width), Math.Min(Height, area.Height));
    }

    internal void AssertButtonLayout()
    {
        foreach (var button in Descendants(this).OfType<Button>())
        {
            var text = TextRenderer.MeasureText(button.Text, button.Font, Size.Empty, TextFormatFlags.SingleLine);
            if (button.ClientSize.Width < text.Width + button.Padding.Horizontal + 4 ||
                button.ClientSize.Height < text.Height + button.Padding.Vertical + 4)
                throw new InvalidOperationException($"Button text is clipped: {button.Text} ({button.Size}).");
            var parent = button.Parent!;
            if (!parent.ClientRectangle.Contains(button.Bounds))
                throw new InvalidOperationException($"Button is outside its layout container: {button.Name} '{button.Text}', bounds={button.Bounds}, parent={parent.Name} client={parent.ClientRectangle}, font={button.Font.SizeInPoints}pt.");
            foreach (Control sibling in parent.Controls)
                if (sibling != button && sibling.Visible && button.Bounds.IntersectsWith(sibling.Bounds))
                    throw new InvalidOperationException($"Button overlaps another control: {button.Text}.");
        }
    }

    private static IEnumerable<Control> Descendants(Control parent)
    {
        foreach (Control child in parent.Controls)
        {
            yield return child;
            foreach (var descendant in Descendants(child)) yield return descendant;
        }
    }

    private Button CreateButton(string text, EventHandler click)
    {
        var button = new Button { Text = text, AutoSize = true, Height = 34, Margin = new Padding(0, 0, 8, 0) };
        StyleButton(button, primary: false);
        button.Click += click;
        _exclusiveButtons.Add(button);
        return button;
    }

    private static void StyleButton(Button button, bool primary)
    {
        button.AutoSize = true;
        button.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        button.MinimumSize = new Size(0, 34);
        button.UseCompatibleTextRendering = false;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = primary ? AccentColor : Color.FromArgb(71, 82, 96);
        button.BackColor = primary ? Color.FromArgb(37, 105, 190) : Color.FromArgb(48, 57, 68);
        button.ForeColor = Color.White;
        button.Padding = new Padding(8, 2, 8, 2);
        button.Margin = new Padding(0, 0, 8, 6);
        button.Height = Math.Max(button.Height, 34);
    }

    private async Task CheckSystemAsync()
    {
        if (_operationInProgress || _installQueue.IsBusy) return;
        _operationInProgress = true;
        _lastFailureText = null;
        foreach (var (id, state) in _states)
        {
            state.Detection = PackageDetectionState.Checking;
            state.Status = "Wird geprüft";
            state.Error = null;
            UpdatePackageRow(id);
        }
        SetBusyState(true, "System und Programme werden geprüft …", marquee: true);
        try
        {
            var detection = await _worker.RunAsync("detect", _packages.Select(item => item.Id).ToArray(), false);
            foreach (var item in detection.Events) ApplyWorkerEvent(item);
            _currentActionLabel.Text = "Systemprüfung abgeschlossen.";
        }
        catch (Exception exception)
        {
            ShowFailure(WorkerDiagnostic.Describe("Systemprüfung", "worker-error", "detection", exception.Message));
            foreach (var (id, state) in _states.Where(item => item.Value.Detection == PackageDetectionState.Checking))
            {
                state.Detection = string.IsNullOrWhiteSpace(state.DetectedVersion)
                    ? PackageDetectionState.Failed : PackageDetectionState.Installed;
                state.Status = state.Detection == PackageDetectionState.Installed ? "Bereits installiert" : "Erkennung fehlgeschlagen";
                state.Error = exception.Message;
                UpdatePackageRow(id);
            }
            _currentActionLabel.Text = "Systemprüfung fehlgeschlagen; Paketstatus prüfen.";
            AppendLog($"Systemprüfung fehlgeschlagen: {exception.Message}", error: true);
            MessageBox.Show(this, exception.Message, "Systemprüfung fehlgeschlagen", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        finally
        {
            _operationInProgress = false;
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
        if (_operationInProgress || _installQueue.IsBusy) return;
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

        if (!dryRun && ordered.Any(id => _packageById[id].WindowsMode == "automatic" &&
            _states[id].Detection is PackageDetectionState.Unknown or PackageDetectionState.Checking or PackageDetectionState.Failed))
        {
            MessageBox.Show(this, "Die Erkennung ist für mindestens ein automatisches Paket unvollständig. Bitte zuerst das System erneut prüfen.",
                "Erkennung erforderlich", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var toInstall = ordered.Where(id => _states[id].Detection == PackageDetectionState.Missing).ToArray();

        _runReport = null;
        _reportPath = null;
        _lastFailureText = null;
        _operationInProgress = true;
        SetBusyState(true, "Installationsplan wird vorbereitet …", marquee: true);
        try
        {
            var result = await _worker.RunAsync("plan", ordered, false, HandleWorkerEvent);
            var planEvent = result.Events.LastOrDefault(item => item.Type == "install-plan");
            if (planEvent?.Data.ValueKind != JsonValueKind.Array) throw new InvalidDataException("Der Worker hat keinen gültigen Plan geliefert.");
            var summary = FormatPlan(planEvent.Data, ordered);
            var installerTypes = planEvent.Data.EnumerateArray().ToDictionary(
                item => PowerShellWorkerClient.ReadString(item, "id")
                    ?? throw new InvalidDataException("Der Worker-Plan enthält ein Paket ohne ID."),
                item => PowerShellWorkerClient.ReadString(item, "installerType"), StringComparer.Ordinal);
            if (ordered.Any(id => !installerTypes.ContainsKey(id)))
                throw new InvalidDataException("Der Worker-Plan ist unvollständig.");
            var administratorAvailable = planEvent.Data.EnumerateArray().ToDictionary(
                item => PowerShellWorkerClient.ReadString(item, "id")!,
                item => item.TryGetProperty("administratorAvailable", out var available) && available.ValueKind == JsonValueKind.True,
                StringComparer.Ordinal);
            _runReport = new SetupRunReport();
            _reportPath = _runReport.JsonPath;
            if (_lastSystemEvent is not null) _runReport.Apply(_lastSystemEvent);
            foreach (var id in ordered)
                _runReport.Record(id, PackageName(id), _states[id].IsInstalled ? "Already installed" : dryRun ? "Dry run" : "Pending", detectedVersion: _states[id].DetectedVersion);
            _runReport.Write(completed: dryRun);
            if (dryRun)
            {
                MessageBox.Show(this, summary, "Dry-Run — keine Änderungen", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (toInstall.Length == 0)
            {
                SaveRunReport(completed: true);
                MessageBox.Show(this, "Alle ausgewählten Programme sind bereits installiert.", "Installationsplan", MessageBoxButtons.OK, MessageBoxIcon.Information);
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
                foreach (var id in toInstall) _runReport.Record(id, PackageName(id), "Skipped by user", "Plan not confirmed.");
                SaveRunReport(completed: true);
                return;
            }

            var automaticPackages = toInstall.Where(id => PackageDownloadPlan.NeedsDownload(_packageById[id], installerTypes[id]) &&
                administratorAvailable[id]).ToArray();
            var downloaded = await DownloadSelectedPackagesAsync(automaticPackages);
            if (downloaded is null)
            {
                foreach (var id in _runReport.MarkPending("Skipped by user", "Download phase cancelled; no installer started."))
                {
                    _states[id].Status = "Abgebrochen";
                    UpdatePackageRow(id);
                }
                SaveRunReport(completed: true);
                return;
            }

            var queueIds = PackageDownloadPlan.SelectQueue(toInstall, _packageById, installerTypes, administratorAvailable, downloaded);
            foreach (var id in queueIds)
            {
                _states[id].Status = !administratorAvailable[id] ? "Administratorrechte erforderlich" :
                    _packageById[id].WindowsMode == "automatic" ? "Bereit zur Installation" : "Manuelle Aktion erforderlich";
                UpdatePackageRow(id);
            }
            var added = _installQueue.Enqueue(queueIds);
            AppendLog($"{added} Paket(e) zur Warteschlange hinzugefügt. Installationen laufen seriell.");
            if (added == 0)
            {
                SaveRunReport(completed: true);
                AppendLog("Es gibt keine weiteren Pakete zur Installation.");
            }
        }
        catch (Exception exception)
        {
            _runReport?.MarkPending("Failed", exception.Message);
            SaveRunReport(completed: true);
            ShowFailure(WorkerDiagnostic.Describe("Installationsplan", "worker-error", "metadata", exception.Message));
            AppendLog($"Installationsplan fehlgeschlagen: {exception.Message}", error: true);
            MessageBox.Show(this, exception.Message, "Installationsplan fehlgeschlagen", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            _operationInProgress = false;
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
                        var failure = exception as PowerShellWorkerException;
                        var code = failure?.ErrorCode ?? (failure?.Phase == "verification-started" ? "verification-error" : "download-error");
                        var detail = WorkerDiagnostic.Describe(PackageName(id), code, failure?.Phase ?? "download-started",
                            failure?.StructuredMessage ?? exception.Message, failure?.ExitCode);
                        _states[id].Status = code == "verification-refused" ? "Integritätsprüfung verweigert" : "Fehlgeschlagen";
                        _states[id].Error = detail;
                        _runReport?.Record(id, PackageName(id), "Failed", detail,
                            errorCode: code, phase: failure?.Phase ?? "download-started", workerExitCode: failure?.ExitCode);
                        SaveRunReport();
                        UpdatePackageRow(id);
                        ShowFailure(detail);
                        AppendLog(detail, error: true);
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
                foreach (var id in packageIds)
                {
                    _states[id].Status = "Abgebrochen";
                    _runReport?.Record(id, PackageName(id), "Skipped by user", "Download phase cancelled; no installer started.");
                    UpdatePackageRow(id);
                }
                SaveRunReport(completed: true);
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

    internal void ApplyWorkerEvent(WorkerEvent workerEvent)
    {
        if (workerEvent.Type == "system-detected") _lastSystemEvent = workerEvent;
        _runReport?.Apply(workerEvent);
        if (workerEvent.Type is "package-installation-completed" or "operation-completed") SaveRunReport();
        switch (workerEvent.Type)
        {
            case "system-detected":
                UpdateSystemHeader(workerEvent.Data);
                break;
            case "package-detected" when workerEvent.PackageId is { } detectedId && _states.TryGetValue(detectedId, out var detectedState):
                detectedState.DetectedVersion = PowerShellWorkerClient.ReadString(workerEvent.Data, "detectedVersion");
                detectedState.Detection = workerEvent.Status == "error" ? PackageDetectionState.Failed :
                    !string.IsNullOrWhiteSpace(detectedState.DetectedVersion) ? PackageDetectionState.Installed : PackageDetectionState.Missing;
                detectedState.Status = detectedState.IsInstalled ? "Bereits installiert" :
                    detectedState.Detection == PackageDetectionState.Failed ? "Erkennung fehlgeschlagen" :
                    _packageById[detectedId].WindowsMode == "detection-only" ? "Nicht unterstützt" :
                    _packageById[detectedId].WindowsMode is "manual" or "web-fallback" ? "Manuelle Aktion erforderlich" :
                    _packageById[detectedId].Elevated && !_isAdministrator ? "Administratorrechte erforderlich" : "Nicht installiert";
                detectedState.Details = workerEvent.Data.TryGetProperty("details", out var details) && details.ValueKind == JsonValueKind.Object
                    ? details.ToString() : PowerShellWorkerClient.ReadString(workerEvent.Data, "details");
                detectedState.Error = workerEvent.Status == "error" ?
                    PowerShellWorkerException.SafeText(workerEvent.Message) : null;
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
                    finishedState.Error = PowerShellWorkerException.SafeText(PowerShellWorkerClient.ReadString(workerEvent.Data, "Notes"));
                }
                if (workerEvent.Status is "Installed" or "Already installed") finishedState.Detection = PackageDetectionState.Installed;
                var errorCode = PowerShellWorkerClient.ReadString(workerEvent.Data, "ErrorCode");
                finishedState.Status = errorCode switch
                {
                    "administrator-required" => "Administratorrechte erforderlich",
                    "verification-refused" => "Integritätsprüfung verweigert",
                    _ => TranslateStatus(workerEvent.Status)
                };
                finishedState.CurrentPhase = PowerShellWorkerClient.ReadString(workerEvent.Data, "Phase");
                UpdatePackageRow(finishedId);
                if (workerEvent.Status == "Failed" || errorCode == "verification-refused")
                    ShowFailure(WorkerDiagnostic.Describe(PackageName(finishedId), errorCode, finishedState.CurrentPhase,
                        finishedState.Error, installerExitCode: workerEvent.Data.ValueKind == JsonValueKind.Object &&
                            workerEvent.Data.TryGetProperty("InstallerExitCode", out var installerExit) &&
                            installerExit.ValueKind == JsonValueKind.Number && installerExit.TryGetInt32(out var code)
                                ? code : null));
                AppendLog($"{PackageName(finishedId)}: {finishedState.Status}{(string.IsNullOrWhiteSpace(finishedState.Error) ? "" : $" — {finishedState.Error}")}",
                    error: workerEvent.Status == "Failed");
                break;
            case "report-written":
                // Per-operation worker reports have unique paths; export the aggregate GUI run.
                SaveRunReport();
                AppendLog("Paketbericht wurde geschrieben; Gesamtlauf wird separat protokolliert.");
                break;
            case "log":
                AppendLog(workerEvent.Message ?? "PowerShell-Engine", error: workerEvent.Status == "error");
                break;
            case "worker-error":
                ShowFailure(WorkerDiagnostic.Describe(PackageName(workerEvent.PackageId), "worker-error", null, workerEvent.Message));
                AppendLog(PowerShellWorkerException.SafeText(workerEvent.Message) ?? "Workerfehler", error: true);
                break;
        }
    }

    private void SetCurrentPackageStatus(WorkerEvent workerEvent, string status)
    {
        if (workerEvent.PackageId is { } packageId && _states.TryGetValue(packageId, out var state))
        {
            state.Status = status;
            state.CurrentPhase = workerEvent.Type;
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
        _isAdministrator = administrator;
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
            var failure = exception as PowerShellWorkerException;
            var detail = WorkerDiagnostic.Describe(PackageName(id), failure?.ErrorCode ?? "worker-error",
                failure?.Phase ?? _states[id].CurrentPhase,
                failure?.StructuredMessage ?? exception.Message, failure?.ExitCode);
            _states[id].Status = failure?.ErrorCode == "verification-refused"
                ? "Integritätsprüfung verweigert" : "Fehlgeschlagen";
            _states[id].Error = detail;
            if (failure is not null) _runReport?.RecordWorkerFailure(id, PackageName(id), failure);
            else _runReport?.RecordFailureIfPending(id, PackageName(id), detail);
            SaveRunReport();
            UpdatePackageRow(id);
            ShowFailure(detail);
            AppendLog(detail, error: true);
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
            _runReport?.Record(id, PackageName(id), "Skipped by user", "Removed from the installation queue.");
            UpdatePackageRow(id);
        }
        SaveRunReport();
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

    internal void SelectMissing()
    {
        foreach (var (id, checkBox) in _selection)
        {
            checkBox.Checked = _states[id].Detection == PackageDetectionState.Missing &&
                _packageById[id].WindowsMode == "automatic";
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
            "Fehlgeschlagen" or "Erkennung fehlgeschlagen" or "Integritätsprüfung verweigert" => Color.FromArgb(255, 138, 138),
            "Nicht unterstützt" or "Administratorrechte erforderlich" => Color.FromArgb(255, 190, 96),
            "Erfolgreich installiert" or "Bereits installiert" => Color.FromArgb(130, 220, 160),
            "Manuelle Aktion erforderlich" => Color.FromArgb(255, 190, 96),
            _ => MutedColor
        };
        var package = _packageById[id];
        _toolTip.SetToolTip(_statusLabels[id], state.Error ?? _statusLabels[id].Text);
        var busy = _operationInProgress || _installQueue.IsBusy;
        _packageButtons[id].Enabled = !busy;
        _selection[id].Enabled = !busy;
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
            $"{modeNote}\n\n{_states[package.Id].Details}\n\nQuelle: {package.Website}\n\nDie GUI führt keinen ungeprüften Installer aus. Möchtest du die offizielle Website öffnen?",
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
        _currentActionLabel.Text = !busy && _lastFailureText is not null ?
            _lastFailureText[..Math.Min(_lastFailureText.Length, 180)] : message;
        _currentActionLabel.ForeColor = !busy && _lastFailureText is not null
            ? Color.FromArgb(255, 138, 138) : MutedColor;
        _progressBar.Visible = busy && marquee;
        if (_progressBar.Visible)
        {
            _progressBar.Style = ProgressBarStyle.Marquee;
        }
        var exclusive = _operationInProgress || _installQueue.IsBusy;
        foreach (var button in _exclusiveButtons) button.Enabled = !exclusive;
        foreach (var id in _states.Keys) UpdatePackageRow(id);
        _cancelButton.Enabled = _downloadCancellation is not null || _installQueue.IsBusy;
    }

    private void SaveRunReport(bool completed = false)
    {
        try { _runReport?.Write(completed); }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            AppendLog($"Gesamtbericht konnte nicht geschrieben werden: {exception.Message}", error: true);
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

    private void ShowFailure(string detail)
    {
        _lastFailureText = detail;
        _currentActionLabel.Text = detail[..Math.Min(detail.Length, 180)];
        _currentActionLabel.ForeColor = Color.FromArgb(255, 138, 138);
        _toolTip.SetToolTip(_currentActionLabel, detail);
    }

    private string PackageName(string? id) =>
        id is not null && _packageById.TryGetValue(id, out var package) ? package.Name : id ?? "System";

    private static string TranslateStatus(string? status) => status switch
    {
        "installed" or "Already installed" => "Bereits installiert",
        "already-installed" => "Bereits installiert",
        "missing" => "Nicht installiert",
        "ready" => "Bereit zur Installation",
        "Installed" => "Erfolgreich installiert",
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

    private static HashSet<string> LoadDeveloperProfile(string profilePath, IReadOnlyDictionary<string, PackageDefinition> packages)
    {
        using var document = JsonDocument.Parse(File.ReadAllText(profilePath));
        var ids = document.RootElement.GetProperty("packages")
            .EnumerateArray()
            .Select(item => item.GetString()!)
            .ToArray();
        return InstallPlanResolver.Resolve(ids, packages).ToHashSet(StringComparer.Ordinal);
    }
}
