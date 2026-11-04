import JSZip from "jszip";
import { createHash } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import { getSession } from "@/lib/auth";
import { createWindowsBootstrapScript } from "@/lib/bootstrap";
import { catalog } from "@/lib/catalog";
import { isRateLimited } from "@/lib/rate-limit";
import { isExpectedRequestOrigin } from "@/lib/oauth";
import { expandDependencies, getProfile, planSchema } from "@/lib/profiles";
import { createServer2022Bundle } from "@/lib/server-bundle";

const manualInstallLinks: Record<string, string> = {
  git: "https://git-scm.com/download/win",
  "github-cli": "https://cli.github.com/",
  vscode: "https://code.visualstudio.com/download",
  "nodejs-lts": "https://nodejs.org/",
  python: "https://www.python.org/downloads/windows/",
  powershell: "https://github.com/PowerShell/PowerShell/releases",
  "7zip": "https://www.7-zip.org/",
};

export async function POST(request: NextRequest) {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Authentication required." }, { status: 401 });
  if (!isExpectedRequestOrigin(request.headers.get("origin"), request.nextUrl.origin)) {
    return NextResponse.json({ error: "Invalid request origin." }, { status: 403 });
  }
  if (isRateLimited(`bootstrap:${session.username}`, 8)) {
    return NextResponse.json({ error: "Too many bundle requests. Try again later." }, { status: 429 });
  }
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > 16_384) return NextResponse.json({ error: "Request is too large." }, { status: 413 });
  const reader = request.body?.getReader();
  if (!reader) return NextResponse.json({ error: "Request body is required." }, { status: 400 });
  const chunks: Buffer[] = [];
  let totalBytes = 0;
  let input: unknown;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > 16_384) {
        await reader.cancel();
        return NextResponse.json({ error: "Request is too large." }, { status: 413 });
      }
      chunks.push(Buffer.from(value));
    }
    input = JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    return NextResponse.json({ error: "Request body must be valid JSON." }, { status: 400 });
  }
  const parsed = planSchema.safeParse(input);
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid installation plan.", details: parsed.error.issues }, { status: 400 });
  }
  const profile = await getProfile(parsed.data.profileId);
  if (!profile || profile.platform !== parsed.data.platform) {
    return NextResponse.json({ error: "Unknown profile or unsupported platform." }, { status: 400 });
  }

  let packages: string[];
  try {
    packages = expandDependencies(parsed.data.packages, parsed.data.platform);
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid packages." },
      { status: 400 },
    );
  }

  const plan = planSchema.parse({ ...parsed.data, packages });
  if (plan.profileId === "windows-server-2022-developer") {
    const profilePackages = new Set(profile.packages);
    if (packages.some((id) => !profilePackages.has(id))) {
      return NextResponse.json({ error: "The Server 2022 bundle can only include packages defined by its profile." }, { status: 400 });
    }

    const archive = await createServer2022Bundle(packages);
    return new NextResponse(new Uint8Array(archive), {
      headers: {
        "Content-Type": "application/zip",
        "Content-Disposition": 'attachment; filename="configureMe-WindowsServer2022-Developer-QuickSetup.zip"',
        "Cache-Control": "private, no-store",
      },
    });
  }
  const legacyUnsupportedPackages = packages.filter((id) => !catalog.find((item) => item.id === id)?.windowsPackageId);
  if (legacyUnsupportedPackages.length > 0) {
    return NextResponse.json({
      error: `These packages are available only in the standalone Windows Server 2022 profile: ${legacyUnsupportedPackages.join(", ")}.`,
    }, { status: 400 });
  }

  const zip = new JSZip();
  const planJson = `${JSON.stringify(plan, null, 2)}\n`;
  const sha256 = createHash("sha256").update(planJson).digest();
  const hash = sha256.toString("hex");
  zip.file("plan.json", planJson);
  zip.file("plan.sha256", `${hash}\n`);
  zip.file("install.ps1", createWindowsBootstrapScript());
  zip.file(
    "README.txt",
    [
      "configureMe Windows bootstrap",
      "",
      "This package is unsigned. The SHA-256 file detects accidental plan corruption but does not prove publisher identity.",
      "Only use bundles downloaded from an HTTPS configureMe portal you trust. Do not run if the source is uncertain.",
      "",
      "Requirements: Windows PowerShell 5.1, Windows 10/11 x64, and WinGet.",
      "Preview without system changes: .\\install.ps1 -DryRun",
      "Install after reviewing the plan: .\\install.ps1",
      "No administrator elevation is requested by this script. Some package installers may display their own prompts.",
      "If WinGet is unavailable, install packages manually from these official websites:",
      ...plan.packages.map((id) => `- ${id}: ${manualInstallLinks[id]}`),
      "",
      "A browser download cannot install software automatically. Review the files before running them.",
    ].join("\r\n"),
  );

  const archive = await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" });
  return new NextResponse(new Uint8Array(archive), {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="configureme-${plan.profileId}.zip"`,
      "Cache-Control": "private, no-store",
    },
  });
}
