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
