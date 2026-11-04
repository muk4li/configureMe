import { describe, expect, it } from "vitest";
import { spawnSync } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { createWindowsBootstrapScript } from "../src/lib/bootstrap";
import { catalog } from "../src/lib/catalog";
import { expandDependencies, listProfiles, LocalConfigurationProvider, planSchema, profileSchema } from "../src/lib/profiles";

describe("profile configuration", () => {
  it("loads every bundled profile through the validator", async () => {
    const profiles = await listProfiles();
    expect(profiles).toHaveLength(6);
    expect(profiles.map((profile) => profile.id)).toContain("developer");
    expect(profiles.map((profile) => profile.id)).toContain("windows-server-2022-developer");
  });

  it("rejects duplicate and unknown package identifiers", () => {
    const base = {
      schemaVersion: 1,
      id: "test-profile",
      name: "Test profile",
      description: "",
      platform: "windows",
      options: {},
    };
    expect(profileSchema.safeParse({ ...base, packages: ["git", "git"] }).success).toBe(false);
    expect(profileSchema.safeParse({ ...base, packages: ["unknown-package"] }).success).toBe(false);
  });

  it("rejects commands or installer settings in profile data", () => {
    const result = profileSchema.safeParse({
      schemaVersion: 1,
      id: "test-profile",
      name: "Test profile",
      description: "",
      platform: "windows",
      packages: ["git"],
      command: "Invoke-Expression",
      options: {},
    });
    expect(result.success).toBe(false);
  });

  it("expands trusted package dependencies without duplicates", () => {
    expect(expandDependencies(["github-cli", "git"], "windows")).toEqual(["git", "github-cli"]);
  });

  it("defines fixed WinGet IDs for legacy WinGet strategies", () => {
    expect(
      catalog
        .filter((item) => item.windowsPackageId)
        .every((item) => typeof item.windowsPackageId === "string" && item.windowsPackageId.length > 0),
    ).toBe(true);
  });

  it("includes the standalone Windows Server profile and its required package IDs", async () => {
    const profile = await new LocalConfigurationProvider().getProfile("windows-server-2022-developer");
    expect(profile?.packages).toEqual(expect.arrayContaining([
      "git", "github-cli", "vscode", "nodejs-lts", "python", "dotnet-10-sdk",
      "powershell-7", "seven-zip", "firefox", "openssh-client",
      "github-copilot-desktop", "teams", "docker-desktop", "github-copilot-cli",
    ]));
  });

  it("generates a fixed, locally confirmed Windows bootstrap from the catalog", () => {
    const script = createWindowsBootstrapScript();
    expect(script).toContain('"git" = "Git.Git"');
    expect(script).toContain('"github-cli" = "GitHub.cli"');
    expect(script).toContain("--source winget");
    expect(script).toContain("if ($DryRun)");
    expect(script).toContain('Read-Host "Continue with this installation? Type YES"');
    expect(script).not.toContain("__PACKAGE_ALLOWLIST__");
    expect(script).not.toMatch(/Invoke-Expression|DownloadString|Start-Process/i);
    expect(script.indexOf("if ($DryRun)")).toBeLessThan(script.indexOf("$confirmation = Read-Host"));
    expect(script.indexOf("if ($DryRun)")).toBeLessThan(script.indexOf("Get-Command winget"));
  });

  it("parses the generated bootstrap with Windows PowerShell without running it", () => {
    if (process.platform !== "win32") return;
    const parser = "$source = [Console]::In.ReadToEnd(); $tokens = $null; $errors = $null; [void][System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors); if ($errors.Count -gt 0) { $errors | ForEach-Object { [Console]::Error.WriteLine($_.Message) }; exit 1 }";
    const result = spawnSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", parser], {
      input: createWindowsBootstrapScript(),
      encoding: "utf8",
    });
    expect(result.error).toBeUndefined();
    expect(result.status, result.stderr).toBe(0);
  });

  it("reads and safely saves validated JSON profiles through the local provider", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "configureme-test-"));
    try {
      const provider = new LocalConfigurationProvider(directory);
      const profile = profileSchema.parse({
        schemaVersion: 1,
        id: "local-test",
        name: "Local test",
        description: "",
        platform: "windows",
        packages: ["git"],
      });
      await provider.saveProfile(profile);
      expect(await provider.getProfile("local-test")).toEqual(profile);
      expect(await provider.getProfile("../local-test")).toBeUndefined();
      expect(await provider.listProfiles()).toEqual([profile]);
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });

  it("rejects unsupported operating systems and packages in install plans", () => {
    expect(
      planSchema.safeParse({
        schemaVersion: 1,
        catalogVersion: "1",
        profileId: "developer",
        platform: "linux",
        architecture: "x64",
        packages: ["git"],
      }).success,
    ).toBe(false);
    expect(
      planSchema.safeParse({
        schemaVersion: 1,
        catalogVersion: "1",
        profileId: "developer",
        platform: "windows",
        architecture: "x64",
        packages: ["github-copilot"],
      }).success,
    ).toBe(false);
  });
});
