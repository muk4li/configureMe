import packageCatalog from "../../bootstrap/windows-server-2022-developer/config/catalog.json";

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
  windowsMode: string;
};

export const catalog: PackageDefinition[] = packageCatalog.packages;

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
