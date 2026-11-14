import Link from "next/link";
import { LinuxConfigurator } from "@/components/linux-configurator";
import { linuxRevision } from "@/lib/linux-bundle";
export const dynamic = "force-dynamic";
export default async function LinuxPage() {
  return <main className="landing public-landing">
    <header className="public-header"><Link className="brand" href="/">configureMe</Link><Link className="button button-quiet" href="/">Windows setup</Link></header>
    <LinuxConfigurator revision={await linuxRevision()} downloadEnabled={process.env.CONFIGUREME_LOCAL_LINUX_DOWNLOADS === "1"} />
  </main>;
}
