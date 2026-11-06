using System.Drawing;
using System.Text.Json;
using System.Windows.Forms;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class SetupFormLayoutTests
{
    [Theory]
    [InlineData(1159, 709)]
    [InlineData(900, 700)]
    [InlineData(1280, 720)]
    [InlineData(1920, 1080)]
    public async Task InitialMessageLoopAndWorkerUpdatesKeepMainRegionsUsable(int width, int height)
    {
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() =>
        {
            using var form = new SetupForm(runStartupDetection: false) { Size = new Size(width, height) };
            using var timer = new System.Windows.Forms.Timer { Interval = 100 };
            var stage = 0;
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
                            completion.TrySetResult();
                            break;
                    }
                }
                catch (Exception exception)
                {
                    timer.Stop();
                    form.Close();
                    completion.TrySetException(exception);
                }
            };
            form.Shown += (_, _) => timer.Start();
            Application.Run(form);
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        await completion.Task.WaitAsync(TimeSpan.FromSeconds(20));
    }

    [Fact]
    public async Task ShowsEveryCategoryAndPackageAcrossResizeAndScale()
    {
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() =>
        {
            try
            {
                foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f })
                {
                    using var scaled = new SetupForm(runStartupDetection: false);
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
                using var form = new SetupForm(runStartupDetection: false);
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
                completion.TrySetResult();
            }
            catch (Exception exception) { completion.TrySetException(exception); }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        await completion.Task.WaitAsync(TimeSpan.FromSeconds(20));
    }
}
