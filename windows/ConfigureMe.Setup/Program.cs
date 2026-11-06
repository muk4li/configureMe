using System.Windows.Forms;

namespace ConfigureMe.Setup;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Length == 1 && args[0] == "--layout-self-test")
        {
            try
            {
                Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f })
                {
                    using var form = new SetupForm(runStartupDetection: false);
                    form.Show();
                    form.Scale(new System.Drawing.SizeF(scale, scale));
                    form.Font = new System.Drawing.Font("Segoe UI", 9F * scale);
                    foreach (var size in new[] { new System.Drawing.Size(1180, 900), new System.Drawing.Size(900, 700), new System.Drawing.Size(1024, 768) })
                    {
                        form.MinimumSize = System.Drawing.Size.Empty;
                        form.Size = size;
                        Application.DoEvents();
                        form.AssertPackageLayout();
                        form.AssertButtonLayout();
                    }
                }
                Environment.ExitCode = 0;
            }
            catch (Exception exception)
            {
                Console.Error.WriteLine(exception);
                Environment.ExitCode = 1;
            }
            return;
        }

        if (args.Length == 1 && args[0] == "--self-test")
        {
            try
            {
                var engine = EngineBundle.ExtractVerified();
                var worker = new PowerShellWorkerClient(engine);
                var result = worker.RunAsync("list", null, false).GetAwaiter().GetResult();
                Environment.ExitCode = result.ExitCode == 0 && result.Events.Any(item => item.Type == "catalog") ? 0 : 1;
            }
            catch
            {
                Environment.ExitCode = 1;
            }
            return;
        }

        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        try
        {
            Application.Run(new SetupForm());
        }
        catch (Exception exception)
        {
            Environment.ExitCode = 1;
            MessageBox.Show(
                $"configureMe Setup konnte nicht gestartet werden.\n\n{exception.Message}",
                "configureMe Setup",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}
