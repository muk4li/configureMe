namespace ConfigureMe.Setup;

internal static class WorkerDiagnostic
{
    public static string Describe(string packageName, string? errorCode, string? phase,
        string? message, int? workerExitCode = null, int? installerExitCode = null)
    {
        var category = errorCode switch
        {
            "administrator-required" => "Administratorrechte erforderlich",
            "metadata-error" => "Installer-Metadaten konnten nicht geladen werden",
            "download-error" => "Download fehlgeschlagen",
            "verification-refused" => "Integritätsprüfung verweigert",
            "verification-error" => "Installer-Prüfung fehlgeschlagen",
            "installer-error" or "installer-exit" => "Installer fehlgeschlagen",
            "verification-failed" or "git-version-verification-failed" or "post-install-verification-error" =>
                "Installation konnte danach nicht verifiziert werden",
            "user-canceled" => "Vom Benutzer abgebrochen",
            _ => phase switch
            {
                "download-started" => "Download fehlgeschlagen",
                "verification-started" => "Installer-Prüfung fehlgeschlagen",
                "installation-started" => "Installer fehlgeschlagen",
                _ => "PowerShell-Worker-Fehler"
            }
        };
        var details = new List<string> { $"{packageName}: {category}" };
        if (!string.IsNullOrWhiteSpace(phase)) details.Add($"Phase: {TranslatePhase(phase)}");
        if (installerExitCode.HasValue) details.Add($"Installer-Code: {installerExitCode.Value}");
        if (workerExitCode.HasValue) details.Add($"Worker-Code: {workerExitCode.Value}");
        if (PowerShellWorkerException.SafeText(message) is { } safeMessage) details.Add(safeMessage);
        return string.Join(" · ", details);
    }

    private static string TranslatePhase(string phase) => phase switch
    {
        "detection" => "Erkennung",
        "metadata" => "Metadaten",
        "preflight" => "Vorprüfung",
        "download-started" or "download-completed" => "Download",
        "verification-started" or "verification-completed" => "Integritätsprüfung",
        "installation-started" or "installation-completed" or "installation" => "Installation",
        "post-install-verification" => "Nachprüfung",
        _ => phase
    };
}
