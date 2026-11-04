using System.Drawing;
using System.Text.Json;
using System.Windows.Forms;
using ConfigureMe.Setup;

namespace ConfigureMe.Setup.Tests;

public sealed class SetupFormLayoutTests
{
    [Fact]
    public async Task ShowsEveryCategoryAndPackageAcrossResizeAndScale()
    {
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() =>
        {
            try
            {
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
