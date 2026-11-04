import { mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import path from "node:path";
import { z } from "zod";
import { catalog, platforms, supportedPackageIds, type Platform } from "./catalog";

export const profileSchema = z
  .object({
    schemaVersion: z.literal(1),
    id: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    name: z.string().min(1).max(80),
    description: z.string().max(240),
    platform: z.enum(platforms),
    packages: z.array(z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)).max(50),
    options: z
      .object({
        configureGit: z.boolean().optional(),
        interactiveAuthentication: z.boolean().optional(),
      })
      .strict()
      .default({}),
  })
  .strict()
  .superRefine((profile, context) => {
    if (new Set(profile.packages).size !== profile.packages.length) {
      context.addIssue({ code: "custom", path: ["packages"], message: "Duplicate package IDs are not allowed." });
    }

    const knownIds = new Set(catalog.map((item) => item.id));
    for (const [index, packageId] of profile.packages.entries()) {
      if (!knownIds.has(packageId)) {
        context.addIssue({ code: "custom", path: ["packages", index], message: `Unknown package: ${packageId}` });
      } else if (!supportedPackageIds(profile.platform).has(packageId)) {
        context.addIssue({
          code: "custom",
          path: ["packages", index],
          message: `${packageId} has no supported installer for ${profile.platform}.`,
        });
      }
    }
  });

export type Profile = z.infer<typeof profileSchema>;

export const planSchema = z
  .object({
    schemaVersion: z.literal(1),
    catalogVersion: z.literal("1"),
    profileId: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    platform: z.enum(platforms),
    architecture: z.literal("x64"),
    packages: z.array(z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)).min(1).max(50),
  })
  .strict()
  .superRefine((plan, context) => {
    if (new Set(plan.packages).size !== plan.packages.length) {
      context.addIssue({ code: "custom", path: ["packages"], message: "Duplicate package IDs are not allowed." });
    }
    const allowed = supportedPackageIds(plan.platform);
    for (const [index, packageId] of plan.packages.entries()) {
      if (!allowed.has(packageId)) {
        context.addIssue({
          code: "custom",
          path: ["packages", index],
          message: `${packageId} has no supported installer for ${plan.platform}.`,
        });
      }
    }
  });

export type InstallPlan = z.infer<typeof planSchema>;

export interface ConfigurationProvider {
  listProfiles(): Promise<Profile[]>;
  getProfile(id: string): Promise<Profile | undefined>;
  saveProfile(profile: Profile): Promise<void>;
}

export class LocalConfigurationProvider implements ConfigurationProvider {
  constructor(private readonly directory = path.join(process.cwd(), "profiles")) {}

  async listProfiles(): Promise<Profile[]> {
    const entries = await readdir(this.directory, { withFileTypes: true });
    const files = entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
      .map((entry) => entry.name)
      .sort();
    return Promise.all(
      files.map(async (file) => {
        const contents = await readFile(path.join(this.directory, file), "utf8");
        return profileSchema.parse(JSON.parse(contents));
      }),
    );
  }

  async getProfile(id: string): Promise<Profile | undefined> {
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id)) return undefined;
    try {
      const contents = await readFile(path.join(this.directory, `${id}.json`), "utf8");
      const profile = profileSchema.parse(JSON.parse(contents));
      return profile.id === id ? profile : undefined;
    } catch (error) {
      if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") return undefined;
      throw error;
    }
  }

  async saveProfile(input: Profile): Promise<void> {
    const profile = profileSchema.parse(input);
    await mkdir(this.directory, { recursive: true });
    const temporaryPath = path.join(this.directory, `.${profile.id}.${randomUUID()}.tmp`);
    const destinationPath = path.join(this.directory, `${profile.id}.json`);
    try {
      await writeFile(temporaryPath, `${JSON.stringify(profile, null, 2)}\n`, {
        encoding: "utf8",
        flag: "wx",
        mode: 0o600,
      });
      await rename(temporaryPath, destinationPath);
    } finally {
      await rm(temporaryPath, { force: true });
    }
  }
}

const localProvider = new LocalConfigurationProvider();

export function listProfiles(): Promise<Profile[]> {
  return localProvider.listProfiles();
}

export function getProfile(id: string): Promise<Profile | undefined> {
  return localProvider.getProfile(id);
}

export function expandDependencies(packageIds: string[], platform: Platform): string[] {
  const allowed = supportedPackageIds(platform);
  const result = new Set<string>();
  const visiting = new Set<string>();

  function add(id: string) {
    if (result.has(id)) return;
    if (visiting.has(id)) throw new Error(`Package dependency cycle includes ${id}.`);
    const definition = catalog.find((item) => item.id === id);
    if (!definition || !allowed.has(id)) {
      throw new Error(`Package ${id} is not installable on ${platform}.`);
    }
    visiting.add(id);
    for (const dependency of definition.dependencies ?? []) add(dependency);
    visiting.delete(id);
    result.add(id);
  }

  for (const packageId of packageIds) add(packageId);
  return [...result];
}
