/**
 * A patient on staff screens: the name, and the phone when there is one.
 * A deleted account has no phone and the stored name "Deleted user".
 */
export function PatientName({ user }: { user: { name: string; phone: string | null } }) {
  return (
    <>
      {user.name}
      {user.phone && <span className="muted"> ({user.phone})</span>}
    </>
  );
}
