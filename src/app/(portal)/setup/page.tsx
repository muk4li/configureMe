import { SetupWizard } from "@/components/setup-wizard";
import { listProfiles } from "@/lib/profiles";

export default async function SetupPage({
  searchParams,
}: {
  searchParams: Promise<{ profile?: string }>;
}) {
  const [{ profile }, profiles] = await Promise.all([searchParams, listProfiles()]);
  return (
    <>
      <div className="page-heading">
        <div><div className="eyebrow-small">LOCAL INSTALLATION PLANNER</div><h1>New computer setup</h1><p>Choose an installable profile, confirm what will change, and download a reviewable bundle.</p></div>
      </div>
      <SetupWizard profiles={profiles} initialProfileId={profile} />
    </>
  );
}
