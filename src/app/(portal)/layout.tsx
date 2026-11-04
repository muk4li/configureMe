import { redirect } from "next/navigation";
import { getSession } from "@/lib/auth";
import { PortalShell } from "@/components/portal-shell";

export const dynamic = "force-dynamic";

export default async function PortalLayout({ children }: LayoutProps<"/">) {
  const session = await getSession();
  if (!session) redirect("/");
  return <PortalShell session={session}>{children}</PortalShell>;
}
