export const platforms = ["windows", "linux", "macos"] as const;
export type Platform = (typeof platforms)[number];

export type InstallStrategy = {
  id: string;
  supported: boolean;
  label: string;
};

export type PackageDefinition = {
  id: string;
  name: string;
  description: string;
  category: string;
  website: string;
  platforms: Partial<Record<Platform, InstallStrategy>>;
  elevated: boolean;
  windowsPackageId?: string;
  dependencies?: string[];
};

export const catalog: PackageDefinition[] = [
  {
    id: "git",
    name: "Git",
    description: "Distributed version control for source code.",
    category: "Developer tools",
    website: "https://git-scm.com/",
    platforms: { windows: { id: "Git.Git", supported: true, label: "WinGet" } },
    elevated: false,
    windowsPackageId: "Git.Git",
  },
  {
    id: "github-cli",
    name: "GitHub CLI",
    description: "Work with GitHub from your terminal.",
    category: "Developer tools",
    website: "https://cli.github.com/",
    platforms: { windows: { id: "GitHub.cli", supported: true, label: "WinGet" } },
    elevated: false,
    windowsPackageId: "GitHub.cli",
    dependencies: ["git"],
  },
  {
    id: "vscode",
    name: "Visual Studio Code",
    description: "A lightweight, extensible code editor.",
    category: "Developer tools",
    website: "https://code.visualstudio.com/",
    platforms: { windows: { id: "Microsoft.VisualStudioCode", supported: true, label: "WinGet" } },
    elevated: false,
    windowsPackageId: "Microsoft.VisualStudioCode",
  },
  {
    id: "nodejs-lts",
    name: "Node.js LTS",
    description: "JavaScript runtime for local development.",
    category: "Languages",
    website: "https://nodejs.org/",
    platforms: { windows: { id: "OpenJS.NodeJS.LTS", supported: true, label: "WinGet" } },
    elevated: false,
    windowsPackageId: "OpenJS.NodeJS.LTS",
  },
  {
    id: "python",
    name: "Python",
    description: "Python programming language and runtime.",
    category: "Languages",
    website: "https://www.python.org/",
    platforms: { windows: { id: "Python.Python.3.12", supported: true, label: "WinGet" } },
    elevated: false,
    windowsPackageId: "Python.Python.3.12",
  },
  {
    id: "powershell",
    name: "PowerShell 7",
    description: "Modern, cross-platform automation shell.",
    category: "Developer tools",
    website: "https://github.com/PowerShell/PowerShell",
    platforms: { windows: { id: "Microsoft.PowerShell", supported: true, label: "WinGet" } },
    elevated: false,
    windowsPackageId: "Microsoft.PowerShell",
  },
  {
    id: "7zip",
    name: "7-Zip",
    description: "File archiver with a high compression ratio.",
    category: "Utilities",
    website: "https://www.7-zip.org/",
    platforms: { windows: { id: "7zip.7zip", supported: true, label: "WinGet" } },
    elevated: false,
    windowsPackageId: "7zip.7zip",
  },
  {
    id: "github-copilot",
    name: "GitHub Copilot",
    description: "AI coding assistance for supported development tools.",
    category: "AI development",
    website: "https://github.com/features/copilot",
    platforms: {},
    elevated: false,
  },
  {
    id: "dotnet-10-sdk",
    name: ".NET 10 SDK",
    description: "Microsoft .NET 10 SDK for Windows x64.",
    category: "Languages",
    website: "https://dotnet.microsoft.com/download/dotnet/10.0",
    platforms: { windows: { id: "quicksetup-dotnet-sdk", supported: true, label: "Official signed installer" } },
    elevated: true,
  },
  {
    id: "powershell-7",
    name: "PowerShell 7",
    description: "Current stable PowerShell 7 release; runs beside Windows PowerShell 5.1.",
    category: "Developer tools",
    website: "https://learn.microsoft.com/powershell/",
    platforms: { windows: { id: "quicksetup-powershell", supported: true, label: "Official signed MSI" } },
    elevated: true,
  },
  {
    id: "seven-zip",
    name: "7-Zip",
    description: "File archiver with an official x64 installer and documented silent mode.",
    category: "Utilities",
    website: "https://www.7-zip.org/",
    platforms: { windows: { id: "quicksetup-seven-zip", supported: true, label: "Official signed installer" } },
    elevated: true,
  },
  {
    id: "firefox",
    name: "Mozilla Firefox",
    description: "Stable Mozilla Firefox x64 enterprise MSI.",
    category: "Browsers",
    website: "https://www.mozilla.org/firefox/enterprise/",
    platforms: { windows: { id: "quicksetup-firefox", supported: true, label: "Official signed MSI" } },
    elevated: true,
  },
  {
    id: "openssh-client",
    name: "OpenSSH Client",
    description: "Windows-serviced OpenSSH Client capability for Windows Server.",
    category: "Developer tools",
    website: "https://learn.microsoft.com/windows-server/administration/openssh/openssh_install_firstuse",
    platforms: { windows: { id: "quicksetup-openssh-client", supported: true, label: "Windows optional capability" } },
    elevated: true,
  },
  {
    id: "github-copilot-desktop",
    name: "GitHub Copilot Desktop",
    description: "Separate desktop app; detection and manual guidance only on Windows Server.",
    category: "AI development",
    website: "https://github.com/github/app",
    platforms: { windows: { id: "quicksetup-copilot-desktop", supported: true, label: "Manual / support warning" } },
    elevated: false,
  },
  {
    id: "teams",
    name: "Microsoft Teams",
    description: "Windows Server desktop support is not asserted; web app fallback is provided.",
    category: "Communication",
    website: "https://teams.microsoft.com/v2",
    platforms: { windows: { id: "quicksetup-teams", supported: true, label: "Web fallback" } },
    elevated: false,
  },
  {
    id: "docker-desktop",
    name: "Docker Desktop",
    description: "Existing install diagnostics only; not officially supported on Windows Server.",
    category: "Developer tools",
    website: "https://docs.docker.com/desktop/setup/install/windows-install/",
    platforms: { windows: { id: "quicksetup-docker-desktop", supported: true, label: "Detection only / unsupported" } },
    elevated: false,
  },
  {
    id: "github-copilot-cli",
    name: "GitHub Copilot CLI",
    description: "Optional CLI; manual installation and interactive authentication only.",
    category: "AI development",
    website: "https://docs.github.com/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli",
    platforms: { windows: { id: "quicksetup-copilot-cli", supported: true, label: "Optional / manual" } },
    elevated: false,
  },
];

export function getPackage(id: string): PackageDefinition | undefined {
  return catalog.find((item) => item.id === id);
}

export function supportedPackageIds(platform: Platform): Set<string> {
  return new Set(
    catalog
      .filter((item) => item.platforms[platform]?.supported === true)
      .map((item) => item.id),
  );
}
