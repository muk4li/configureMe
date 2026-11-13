namespace ConfigureMe.Setup;

internal static class SetupPlanDryRun
{
    // This boundary deliberately has no download/install/confirmed path.
    public static async Task<WorkerRunResult> RunAsync(ValidatedSetupPlan plan,
        Func<string, IReadOnlyList<string>, bool, Task<WorkerRunResult>> run)
    {
        var detected = await run("detect", plan.PackageIds, false);
        if (detected.ExitCode != 0) throw new InvalidDataException("Die Dry-Run-Erkennung ist fehlgeschlagen.");
        var preview = await run("plan", plan.PackageIds, false);
        if (preview.ExitCode != 0) throw new InvalidDataException("Der Dry-Run-Plan ist fehlgeschlagen.");
        return new(0, detected.Events.Concat(preview.Events).ToArray(), detected.StandardError + preview.StandardError);
    }
}
