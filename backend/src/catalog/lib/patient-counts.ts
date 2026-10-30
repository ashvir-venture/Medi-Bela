import { Prisma } from '@prisma/client';

type Db = { $queryRaw: <T = unknown>(query: Prisma.Sql) => Promise<T> };

/**
 * "Patients" of a doctor or medicine = distinct patients (role USER, deleted
 * accounts included: their prescriptions are kept) on confirmed
 * prescriptions (ACTIVE or ENDED). Medicines count the
 * lines of the prescription's current revision only; self-added routines are
 * not counted (they store no catalog medicine id).
 */
const COUNTED = Prisma.sql`p.status IN ('ACTIVE', 'ENDED') AND u.role = 'USER'`;

export interface RankedRow {
  id: string;
  patients: number;
}

export async function doctorPatientCount(db: Db, doctorId: string): Promise<number> {
  const [row] = await db.$queryRaw<{ n: number }[]>(Prisma.sql`
    SELECT COUNT(DISTINCT p."userId")::int AS n
    FROM prescriptions p JOIN users u ON u.id = p."userId"
    WHERE p."doctorId" = ${doctorId}::uuid AND ${COUNTED}`);
  return row?.n ?? 0;
}

export async function medicinePatientCount(db: Db, medicineId: string): Promise<number> {
  const [row] = await db.$queryRaw<{ n: number }[]>(Prisma.sql`
    SELECT COUNT(DISTINCT p."userId")::int AS n
    FROM prescription_medicines pm
    JOIN prescriptions p ON p.id = pm."prescriptionId" AND pm.revision = p."currentRevision"
    JOIN users u ON u.id = p."userId"
    WHERE pm."medicineId" = ${medicineId}::uuid AND ${COUNTED}`);
  return row?.n ?? 0;
}

/** Doctors by patient count, most first (ties by id); only doctors with patients. */
export function rankDoctors(db: Db, limit: number, offset: number): Promise<RankedRow[]> {
  return db.$queryRaw<RankedRow[]>(Prisma.sql`
    SELECT p."doctorId" AS id, COUNT(DISTINCT p."userId")::int AS patients
    FROM prescriptions p JOIN users u ON u.id = p."userId"
    WHERE p."doctorId" IS NOT NULL AND ${COUNTED}
    GROUP BY p."doctorId"
    ORDER BY patients DESC, id
    LIMIT ${limit} OFFSET ${offset}`);
}

/** Catalog medicines by patient count, most first (ties by id). */
export function rankMedicines(db: Db, limit: number, offset: number): Promise<RankedRow[]> {
  return db.$queryRaw<RankedRow[]>(Prisma.sql`
    SELECT pm."medicineId" AS id, COUNT(DISTINCT p."userId")::int AS patients
    FROM prescription_medicines pm
    JOIN prescriptions p ON p.id = pm."prescriptionId" AND pm.revision = p."currentRevision"
    JOIN users u ON u.id = p."userId"
    WHERE pm."medicineId" IS NOT NULL AND ${COUNTED}
    GROUP BY pm."medicineId"
    ORDER BY patients DESC, id
    LIMIT ${limit} OFFSET ${offset}`);
}
