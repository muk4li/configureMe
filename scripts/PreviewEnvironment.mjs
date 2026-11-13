const removedNames = new Set(["AUTH_SECRET", "GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET", "INITIAL_ADMIN_GITHUB_USER", "ALLOWED_GITHUB_USERS", "APP_URL", "NEXT_TELEMETRY_DISABLED"]);
export function hasPreviewEnvFiles(names) {
  return names.some(name => {
    const normalized = name.toLowerCase();
    return (normalized === ".env" || normalized.startsWith(".env.")) && normalized !== ".env.example";
  });
}
export function previewPort(value = "3000") {
  if (!/^\d{4,5}$/.test(value) || Number(value) < 1024 || Number(value) > 65535)
    throw new Error("Choose a preview port between 1024 and 65535.");
  return value;
}
export function previewEnvironment(inherited, port) {
  const environment = { ...inherited };
  // Windows environment names are case-insensitive; a copied JS object is not.
  for (const name of Object.keys(environment)) if (removedNames.has(name.toUpperCase())) delete environment[name];
  return { ...environment, NEXT_TELEMETRY_DISABLED: "1", APP_URL: `http://127.0.0.1:${port}` };
}
