import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { LinuxBundleBuilder } from "@/components/linux-bundle-builder";
import { isLocalBundleEnabled } from "@/lib/linux-bundle";

export const dynamic = "force-dynamic";
export default async function LinuxPage() {
  if (!isLocalBundleEnabled((await headers()).get("host"))) notFound();
  return <main className="landing public-landing"><LinuxBundleBuilder /></main>;
}
