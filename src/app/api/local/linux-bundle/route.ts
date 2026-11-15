import { NextResponse, type NextRequest } from "next/server";
import { BundleSelectionError, bundleSelectionSchema, buildBundle, isLocalBundleEnabled, loadCatalog } from "@/lib/linux-bundle";
import { PublicInputError, readPublicJson } from "@/lib/public-request";

export const runtime = "nodejs";
const headers = { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" };
const error = (message: string, status: number) => NextResponse.json({ error: message }, { status, headers });
const notFound = () => new NextResponse("Not Found", { status: 404, headers });

export async function GET(request: NextRequest) {
  if (!isLocalBundleEnabled(request.headers.get("host"))) return notFound();
  const catalog = loadCatalog();
  return NextResponse.json({
    catalogRevision: catalog.revision,
    steps: catalog.steps.map(({ id, title, dependsOn, packages }) => ({ id, title, dependsOn, packages: packages.map((p) => p.name) })),
  }, { headers });
}

export async function POST(request: NextRequest) {
  if (!isLocalBundleEnabled(request.headers.get("host"))) return notFound();
  // Same-origin only: the browser's Origin must equal the loopback Host it talks to.
  if (request.headers.get("sec-fetch-site") === "cross-site" || request.headers.get("origin") !== `http://${request.headers.get("host")}`)
    return error("Invalid request origin.", 403);
  try {
    const parsed = bundleSelectionSchema.safeParse(await readPublicJson(request));
    if (!parsed.success) return error("Ungültige Auswahl.", 400);
    const bundle = buildBundle(parsed.data);
    return new NextResponse(new Uint8Array(bundle.archive), { headers: {
      ...headers, "Content-Type": "application/gzip",
      "Content-Disposition": `attachment; filename="${bundle.archiveName}"`,
      "X-Bundle-Sha256": bundle.archiveSha256, "X-Bundle-Commit": bundle.commit, "X-Bundle-Name": bundle.archiveName,
    } });
  } catch (exception) {
    if (exception instanceof PublicInputError) return error(exception.message, exception.status);
    if (exception instanceof BundleSelectionError) return error(exception.message, 422);
    return error(exception instanceof Error ? exception.message : "Bundle konnte nicht erstellt werden.", 409);
  }
}
