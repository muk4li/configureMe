using System.Windows.Forms;

namespace ConfigureMe.Setup;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
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
            MessageBox.Show(
                $"configureMe Setup konnte nicht gestartet werden.\n\n{exception.Message}",
                "configureMe Setup",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}
