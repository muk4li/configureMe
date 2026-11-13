using System.Drawing;
using System.Text.Json;
using System.Windows.Forms;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class SetupFormLayoutTests
{
    [Fact]
    public Task ImportIsAtomicShowsDependenciesAndPreservesManualMode() => RunOnStaAsync(root =>
    {
        using var form = new SetupForm(runStartupDetection: false, applicationDataRoot: root);
        form.Show(); Application.DoEvents();
        var bytes = File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "PlanFixtures", "valid-server.json"));
        var plan = form.ImportPlanSnapshot(bytes, new("windows-server-2022", "x64"));
        var git = (CheckBox)form.Controls.Find("PackageSelection:git", true).Single();
        var cli = (CheckBox)form.Controls.Find("PackageSelection:github-cli", true).Single();
        Assert.True(git.Checked); Assert.True(cli.Checked); Assert.False(git.Enabled);
        Assert.Contains("GitHub CLI", git.AccessibleDescription);
        Assert.Contains("Abhängigkeit", form.Controls.Find("PackageName:git", true).Single().Text);
        Assert.Equal(new[] { "git", "github-cli" }, plan.PackageIds);
        Assert.ThrowsAny<Exception>(() => form.ImportPlanSnapshot("{}"u8.ToArray(), new("windows-server-2022", "x64")));
        Assert.True(cli.Checked); // Failed import cannot replace a previously valid selection.
        form.ApplyWorkerEvent(new WorkerEvent("package-detected", "git", "installed", null,
            JsonSerializer.SerializeToElement(new { detectedVersion = "2.50.0" })));
        Assert.False(git.Enabled); // Detection/busy updates cannot unlock imported intent.
        form.AssertButtonLayout(); form.AssertMainLayout();
        form.ClearImportedPlan();
        Assert.True(git.Enabled);
        Assert.DoesNotContain("Abhängigkeit", form.Controls.Find("PackageName:git", true).Single().Text);
    });

    [Theory]
    [InlineData(1159, 709)]
    [InlineData(900, 700)]
    [InlineData(1280, 720)]
    [InlineData(1920, 1080)]
    public Task InitialMessageLoopAndWorkerUpdatesKeepMainRegionsUsable(int width, int height) => RunOnStaAsync(root =>
    {
        using var form = new SetupForm(runStartupDetection: false, applicationDataRoot: root) { Size = new Size(width, height) };
        using var timer = new System.Windows.Forms.Timer { Interval = 100 };
        var stage = 0;
        Exception? failure = null;
        timer.Tick += (_, _) =>
        {
            try
            {
                // No Scale(), font replacement or assertion-driven PerformLayout():
                // observe the same initial message loop as a normal Explorer launch.
                form.AssertMainLayout();
                form.AssertPackageLayout();
                form.AssertButtonLayout();
                switch (stage++)
                {
                    case 0:
                        form.ApplyWorkerEvent(new WorkerEvent("system-detected", null, null, null,
                            JsonSerializer.SerializeToElement(new { operatingSystem = new { Caption = "Microsoft Windows Server 2022 Datacenter Evaluation", Architecture = "x64", IsSupported = true }, isAdministrator = true })));
                        form.ApplyWorkerEvent(new WorkerEvent("package-detected", "vscode", "installed", null,
                            JsonSerializer.SerializeToElement(new { detectedVersion = "1.100.0" })));
                        break;
                    case 1: form.WindowState = FormWindowState.Maximized; break;
                    case 2: form.WindowState = FormWindowState.Normal; break;
                    case 3: form.Size = new Size(900, 700); break;
                    default:
                        var list = form.Controls.Find("PackageList", true).Single();
                        list.Dock = DockStyle.None;
                        list.Height = 0;
                        Assert.Throws<InvalidOperationException>(form.AssertMainLayout);
                        timer.Stop();
                        form.Close();
                        break;
                }
            }
            catch (Exception exception)
            {
                timer.Stop();
                form.Close();
                failure = exception;
            }
        };
        form.Shown += (_, _) => timer.Start();
        Application.Run(form);
        if (failure is not null) System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(failure).Throw();
    });

    [Fact]
    public Task ShowsEveryCategoryAndPackageAcrossResizeAndScale() => RunOnStaAsync(root =>
    {
        foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f })
        {
            using var scaled = new SetupForm(runStartupDetection: false, applicationDataRoot: root);
            scaled.Show();
            Application.DoEvents();
            scaled.AssertMainLayout();
            scaled.AssertPackageLayout();
            scaled.AssertButtonLayout();
            scaled.Scale(new SizeF(scale, scale));
            scaled.Font = new Font("Segoe UI", 9F * scale);
            foreach (var size in new[] { new Size(1180, 900), new Size(900, 700), new Size(1024, 768) })
            {
                // Fixed physical viewport exercises wrapping/scrolling even at 200%.
                scaled.MinimumSize = Size.Empty;
                scaled.Size = size;
                Application.DoEvents();
                scaled.AssertMainLayout();
                scaled.AssertPackageLayout();
                scaled.AssertButtonLayout();
            }
            var action = scaled.Controls.Find("ActionPanel", true).Single();
            var primary = action.Controls.OfType<FlowLayoutPanel>().SelectMany(panel => panel.Controls.OfType<Button>())
                .Single(button => button.Text == "Ausgewählte installieren");
            primary.Text = "Install selected applications";
            Application.DoEvents();
            scaled.AssertButtonLayout();
        }
        using var form = new SetupForm(runStartupDetection: false, applicationDataRoot: root);
        form.Show();
        Application.DoEvents();
        var list = Assert.IsType<FlowLayoutPanel>(Assert.Single(form.Controls.Find("PackageList", true)));
        Assert.True(list.Controls.Count > 1);
        foreach (var size in new[] { new Size(1180, 900), new Size(900, 700) })
        {
            form.Size = size;
            Application.DoEvents();
            form.AssertPackageLayout();
            form.AssertButtonLayout();
        }
        form.Scale(new SizeF(1.5f, 1.5f));
        Application.DoEvents();
        form.AssertPackageLayout();

        var installed = new Dictionary<string, string>
        {
            ["git"] = "2.56.0.windows.4", ["github-copilot-desktop"] = "1.1.34",
            ["firefox"] = "159.0", ["docker-desktop"] = "4.97.0",
            ["vscode"] = "1.144.0", ["nodejs-lts"] = "26.13.0",
            ["libreoffice"] = "26.8.2.2"
        };
        foreach (var (id, version) in installed)
        {
            form.ApplyWorkerEvent(new WorkerEvent("package-detected", id, "installed", null,
                JsonSerializer.SerializeToElement(new { detectedVersion = version })));
            var status = Assert.IsType<Label>(Assert.Single(form.Controls.Find($"PackageStatus:{id}", true)));
            Assert.Contains(version, status.Text);
            Assert.Contains("Bereits installiert", status.Text);
        }
        form.SelectMissing();
        foreach (var id in installed.Keys)
        {
            var selection = Assert.IsType<CheckBox>(Assert.Single(form.Controls.Find($"PackageSelection:{id}", true)));
            Assert.False(selection.Checked);
        }
    });

    private static async Task RunOnStaAsync(Action<string> test)
    {
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() =>
        {
            try
            {
                // Dispose forms and remove the private cache before reporting completion.
                using (var directory = new TestApplicationData()) test(directory.Root);
                completion.TrySetResult();
            }
            catch (Exception exception) { completion.TrySetException(exception); }
        }) { IsBackground = true };
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        await completion.Task.WaitAsync(TimeSpan.FromSeconds(20));
        Assert.True(thread.Join(TimeSpan.FromSeconds(5)), "The UI test thread must exit.");
    }
}
