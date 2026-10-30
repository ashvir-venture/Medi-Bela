// Talks to the same NestJS backend as the Flutter app (`/api` prefix).
// Mirrors the mobile app's conventions (Bearer token, same response
// shapes). The backend's role guards are the real authorization; the
// panel only hides what a role can't use.

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3001/api';

const TOKEN_KEY = 'carebridge_admin_access_token';
const REFRESH_KEY = 'carebridge_admin_refresh_token';

export interface AdminUser {
  id: string;
  name: string;
  phone: string;
  role: 'ADMIN' | 'PHARMACIST' | 'USER';
}

export function saveTokens(accessToken: string) {
  localStorage.setItem(TOKEN_KEY, accessToken);
}

export function clearTokens() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  mePromise = null;
}

// --- Session ---
// The signed-in staff member, fetched once per page load from /users/me
// (never read from localStorage, so editing storage can't change a role).

let mePromise: Promise<AdminUser> | null = null;

export function getMe(): Promise<AdminUser> {
  if (!mePromise) {
    mePromise = request<AdminUser>('/users/me').catch((err) => {
      mePromise = null;
      throw err;
    });
  }
  return mePromise;
}

/** Seeds the cache right after login, so the first page skips a round trip. */
export function rememberMe(user: AdminUser) {
  mePromise = Promise.resolve(user);
}

export function getAccessToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    /** The backend's machine-readable code (NETWORK when the server wasn't reached). */
    public code?: string,
    /** Support reference of an unexpected server error, e.g. "7KQ2-M9". */
    public ref?: string,
  ) {
    super(message);
  }
}

/** Raised on window when the API answers 503: MaintenanceGate shows its screen. */
export const MAINTENANCE_EVENT = 'medibela:maintenance';

const GENERIC_ERROR = 'Something went wrong. Please try again.';

/**
 * The text shown for an error code. The panel is English only. Codes whose
 * server message is already specific (validation, conflicts, wrong sign-in)
 * keep it; the rest get a short, friendly line with a way out.
 */
export function errorText(code: string | undefined, serverMessage: string | undefined, ref?: string): string {
  switch (code) {
    case 'NETWORK':
      return "Couldn't reach the server. Check your connection and try again.";
    case 'PASSWORD_INCORRECT':
      return 'The password is not correct.';
    case 'RATE_LIMITED':
      return 'Too many requests. Wait a minute and try again.';
    case 'NOT_FOUND':
      return 'This item was not found. It may have been removed.';
    case 'FORBIDDEN':
      return "You don't have access to this.";
    case 'MAINTENANCE':
      return 'Medi-Bela is being updated. Please try again in a few minutes.';
    case 'SERVER_ERROR':
      return ref ? `Something went wrong. Ref: ${ref}` : GENERIC_ERROR;
    case 'VALIDATION_FAILED':
    case 'BAD_REQUEST':
    case 'CONFLICT':
    case 'INVALID_CREDENTIALS':
    case 'ACCOUNT_SUSPENDED':
    case 'ACCOUNT_NOT_ACTIVE':
    case 'PHONE_TAKEN':
    case 'RESET_CODE_INVALID':
    case 'PAYLOAD_TOO_LARGE':
      return serverMessage || GENERIC_ERROR;
    default:
      return GENERIC_ERROR;
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const token = getAccessToken();
  const isFormData = options.body instanceof FormData;

  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      ...options,
      headers: {
        ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...options.headers,
      },
    });
  } catch {
    // Offline, DNS, CORS or the server down: no HTTP answer at all.
    throw new ApiError(errorText('NETWORK', undefined), 0, 'NETWORK');
  }

  // A 401 from login means the credentials were rejected, not that an
  // existing session expired. Let the normal error handler read its message.
  const isLoginRequest = path === '/auth/login';

  if (response.status === 401 && !isLoginRequest) {
    // Protected endpoint: the access token is expired or invalid.
    clearTokens();
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
    throw new ApiError('Session expired', 401);
  }

  if (!response.ok) {
    let serverMessage: string | undefined;
    let code: string | undefined;
    let ref: string | undefined;
    try {
      const body = await response.json();
      serverMessage = Array.isArray(body.message) ? body.message.join(', ') : body.message;
      code = body.code;
      ref = body.ref;
    } catch {
      // ignore parse failure: the status decides below
    }
    if (response.status === 503) {
      code = 'MAINTENANCE';
      if (typeof window !== 'undefined') window.dispatchEvent(new Event(MAINTENANCE_EVENT));
    }
    code ??= response.status >= 500 ? 'SERVER_ERROR' : undefined;
    throw new ApiError(errorText(code, serverMessage, ref), response.status, code, ref);
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

// --- Auth ---

export async function login(
  phone: string,
  password: string,
): Promise<{ user: AdminUser; tokens: { accessToken: string } }> {
  return request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ phone, password }),
  });
}

// --- Prescriptions (admin) ---

export interface LookupRow {
  id: number;
  name: string;
}

export interface Lookups {
  genders: LookupRow[];
  divisions: LookupRow[];
  districts: (LookupRow & { divisionId: number })[];
  doctorSpecialties: LookupRow[];
  medicineForms: LookupRow[];
  medicineCategories: LookupRow[];
  mealTimings: LookupRow[];
  testCategories: LookupRow[];
}

let lookupsPromise: Promise<Lookups> | null = null;

/** Dropdown data from the lookup tables; cached for the page's lifetime. */
export function getLookups(): Promise<Lookups> {
  if (!lookupsPromise) {
    lookupsPromise = request<Lookups>('/lookups').catch((err) => {
      lookupsPromise = null;
      throw err;
    });
  }
  return lookupsPromise;
}

export interface CursorPage<T> {
  items: T[];
  nextCursor: string | null;
}

// --- Catalog: doctors, medicines, tests ---

/** Who made a catalog record (the last pharmacist to save it). Admin responses only. */
export interface CreatedBy {
  id: string;
  name: string;
  role: AdminUser['role'];
}

export interface Doctor {
  id: string;
  name: string;
  bmdcNumber: string | null;
  specialtyId: number | null;
  chamber: string | null;
  phone: string | null;
  districtId: number | null;
  createdAt: string;
  specialty: LookupRow | null;
  district: LookupRow | null;
  _count?: { prescriptions: number };
  /** Computed by the backend: still missing name, specialty, phone or address. */
  incomplete?: boolean;
  createdBy?: CreatedBy | null;
  /** Admin detail only: distinct patients on confirmed prescriptions. */
  patients?: number;
}

export interface DoctorInput {
  name: string;
  bmdcNumber?: string;
  specialtyId?: number;
  chamber?: string;
  phone?: string;
  districtId?: number;
}

export interface MedicineGeneric {
  id: number;
  name: string;
}

export interface CatalogMedicine {
  id: string;
  brandName: string;
  /** The linked generic's name (same as generic?.name). */
  genericName: string | null;
  genericId?: number | null;
  generic?: MedicineGeneric | null;
  formId: number | null;
  categoryId: number | null;
  manufacturer: string | null;
  createdAt: string;
  form: LookupRow | null;
  category?: LookupRow | null;
  _count?: { lines: number };
  /** Computed by the backend: still missing name, form, category or manufacturer. */
  incomplete?: boolean;
  createdBy?: CreatedBy | null;
  /** Admin detail only: distinct patients on confirmed prescriptions. */
  patients?: number;
}

export interface MedicineInput {
  brandName: string;
  /** Found ignoring case or created; an empty string removes the generic. */
  genericName?: string;
  genericId?: number;
  formId?: number;
  categoryId?: number;
  manufacturer?: string;
}

export interface DiagnosticTest {
  id: string;
  name: string;
  categoryId: number | null;
  category?: LookupRow | null;
}

export interface CatalogListParams {
  cursor?: string | null;
  q?: string;
  incomplete?: boolean;
}

function catalogQuery(params: CatalogListParams) {
  const qs = new URLSearchParams();
  if (params.cursor) qs.set('cursor', params.cursor);
  if (params.q) qs.set('q', params.q);
  if (params.incomplete) qs.set('incomplete', 'true');
  const s = qs.toString();
  return s ? `?${s}` : '';
}

export function searchDoctors(q: string) {
  return request<Doctor[]>(`/catalog/doctors/search?q=${encodeURIComponent(q)}`);
}

export function searchMedicines(q: string) {
  return request<CatalogMedicine[]>(`/catalog/medicines/search?q=${encodeURIComponent(q)}`);
}

export function searchGenerics(q: string) {
  return request<MedicineGeneric[]>(`/catalog/generics/search?q=${encodeURIComponent(q)}`);
}

export function searchTests(q: string) {
  return request<DiagnosticTest[]>(`/catalog/tests/search?q=${encodeURIComponent(q)}`);
}

export function listDoctors(params: CatalogListParams) {
  return request<CursorPage<Doctor>>(`/catalog/doctors${catalogQuery(params)}`);
}

export function getDoctor(id: string) {
  return request<Doctor>(`/catalog/doctors/${id}`);
}

export function updateDoctor(id: string, input: Partial<DoctorInput>) {
  return request<Doctor>(`/catalog/doctors/${id}`, { method: 'PATCH', body: JSON.stringify(input) });
}

export function listMedicines(params: CatalogListParams) {
  return request<CursorPage<CatalogMedicine>>(`/catalog/medicines${catalogQuery(params)}`);
}

export function getMedicine(id: string) {
  return request<CatalogMedicine>(`/catalog/medicines/${id}`);
}

export function createMedicine(input: MedicineInput) {
  return request<CatalogMedicine>('/catalog/medicines', { method: 'POST', body: JSON.stringify(input) });
}

export function updateMedicine(id: string, input: Partial<MedicineInput>) {
  return request<CatalogMedicine>(`/catalog/medicines/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  });
}

export function createTest(name: string) {
  return request<DiagnosticTest>('/catalog/tests', { method: 'POST', body: JSON.stringify({ name }) });
}

// --- Prescriptions ---

export interface PrescriptionMedicine {
  id: string;
  medicineName: string;
  dosage: string;
  frequency: string;
  duration: string;
  instructions: string | null;
  timesPerDay: number | null;
  scheduleTimes: string | null; // JSON-encoded string[]
  durationDays: number | null;
  startDate: string | null;
  verified: boolean;
  medicineId: string | null;
  strength: string | null;
  doseAmount: string | null;
  mealTimingId: number | null;
  continuous: boolean;
  medicine: CatalogMedicine | null;
  mealTiming: LookupRow | null;
}

export interface PrescriptionUser {
  id: string;
  name: string;
  /** null once the patient deleted their account (name is then "Deleted user"). */
  phone: string | null;
  address: string | null;
}

export type PrescriptionStatus = 'PENDING' | 'REJECTED' | 'AWAITING_CONFIRMATION' | 'ACTIVE' | 'ENDED';

export interface PrescriptionListItem {
  id: string;
  status: PrescriptionStatus;
  /** null once the patient deleted their account (the photo is erased). */
  imageUrl: string | null;
  createdAt: string;
  reviewedAt: string | null;
  previousPrescriptionId: string | null;
  user: PrescriptionUser;
  reviewedBy: { id: string; name: string } | null;
}

export interface PrescriptionDetail extends PrescriptionListItem {
  rejectionReason: string | null;
  processingNote: string | null;
  medicines: PrescriptionMedicine[];
  doctorId: string | null;
  doctor: Doctor | null;
  visitDate: string | null;
  diagnosis: string | null;
  nextVisitDate: string | null;
  tests: { test: DiagnosticTest }[];
  previous: {
    id: string;
    status: PrescriptionStatus;
    rejectionReason: string | null;
    createdAt: string;
  } | null;
}

export type QueueStatus = PrescriptionStatus | 'ALL';

export function listPrescriptionQueue(status: QueueStatus, cursor?: string | null) {
  const qs = new URLSearchParams({ status });
  if (cursor) qs.set('cursor', cursor);
  return request<CursorPage<PrescriptionListItem>>(`/prescriptions/admin/queue?${qs}`);
}

export interface PrescriptionDetailsInput {
  doctorId?: string;
  doctor?: DoctorInput;
  doctorNotApplicable?: boolean;
  visitDate?: string | null;
  diagnosis?: string | null;
  nextVisitDate?: string | null;
  testIds?: string[];
}

export function savePrescriptionDetails(prescriptionId: string, input: PrescriptionDetailsInput) {
  return request<PrescriptionDetail>(`/prescriptions/admin/${prescriptionId}/details`, {
    method: 'PUT',
    body: JSON.stringify(input),
  });
}

export function getPrescription(id: string) {
  return request<PrescriptionDetail>(`/prescriptions/admin/${id}`);
}

export interface MedicineEntryInput {
  id?: string;
  medicineName: string;
  dosage: string;
  frequency: string;
  duration: string;
  instructions?: string;
  timesPerDay?: number;
  scheduleTimes?: string[];
  durationDays?: number;
  startDate?: string;
  medicineId?: string;
  strength?: string;
  doseAmount?: string;
  mealTimingId?: number;
  continuous?: boolean;
}

export function saveMedicines(prescriptionId: string, medicines: MedicineEntryInput[]) {
  return request<PrescriptionDetail>(`/prescriptions/admin/${prescriptionId}/medicines`, {
    method: 'PUT',
    body: JSON.stringify({ medicines }),
  });
}

export function removeMedicine(prescriptionId: string, medicineId: string) {
  return request<PrescriptionDetail>(
    `/prescriptions/admin/${prescriptionId}/medicines/${medicineId}`,
    { method: 'DELETE' },
  );
}

export function completePrescription(prescriptionId: string) {
  return request<PrescriptionDetail>(`/prescriptions/admin/${prescriptionId}/complete`, {
    method: 'POST',
  });
}

export function rejectPrescription(prescriptionId: string, rejectionReason: string) {
  return request<PrescriptionDetail>(`/prescriptions/admin/${prescriptionId}/reject`, {
    method: 'POST',
    body: JSON.stringify({ rejectionReason }),
  });
}

// --- Health suggestion rules (admin) ---

export const CONDITION_TYPE_MEDICINE_NAME_CONTAINS = 'MEDICINE_NAME_CONTAINS';

export interface SuggestionRule {
  id: string;
  name: string;
  description: string | null;
  conditionType: string;
  conditionValue: string;
  suggestedAction: string;
  enabled: boolean; // true = published/live; false = draft
  createdAt: string;
}

export interface SuggestionRuleInput {
  name: string;
  description?: string;
  conditionType: string;
  conditionValue: string;
  suggestedAction: string;
}

export function listSuggestionRules() {
  return request<SuggestionRule[]>('/admin/suggestion-rules');
}

export function getSuggestionRule(id: string) {
  return request<SuggestionRule>(`/admin/suggestion-rules/${id}`);
}

export function createSuggestionRule(input: SuggestionRuleInput) {
  return request<SuggestionRule>('/admin/suggestion-rules', {
    method: 'POST',
    body: JSON.stringify(input),
  });
}

export function updateSuggestionRule(id: string, input: Partial<SuggestionRuleInput>) {
  return request<SuggestionRule>(`/admin/suggestion-rules/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  });
}

/** The "Publish" action: goes live immediately and backfills reminders
 * for every already-verified medicine that matches. */
export function publishSuggestionRule(id: string) {
  return request<{ rule: SuggestionRule; remindersCreated: number }>(
    `/admin/suggestion-rules/${id}/publish`,
    { method: 'POST' },
  );
}

export function unpublishSuggestionRule(id: string) {
  return request<SuggestionRule>(`/admin/suggestion-rules/${id}/unpublish`, { method: 'POST' });
}

// --- AI health suggestions (pharmacist) ---
// Separate from suggestion rules above: these are open-ended, per-user,
// AI-generated (see the LLM system prompt) rather than pharmacist-authored
// deterministic rules. One row = one generation run for one routine,
// requested by a pharmacist from the routine panel (never automatic).
// Never shown to the user until a pharmacist publishes it.

export interface SuggestionItem {
  category: string;
  text: string;
}

export interface HealthSuggestion {
  id: string;
  itemsEn: SuggestionItem[];
  itemsBn: SuggestionItem[];
  sourceMedicines: string;
  status: 'DRAFT' | 'PUBLISHED';
  publishedAt: string | null;
  createdAt: string;
  user: PrescriptionUser;
  publishedBy: { id: string; name: string } | null;
  /** Set for suggestions requested from the routine panel. */
  routine?: { id: string; medicineName: string; dosage: string } | null;
}

// --- Routines panel (pharmacist) ---

export type RoutineSuggestion = Omit<HealthSuggestion, 'user' | 'routine'>;

export interface RoutineListItem {
  id: string;
  medicineName: string;
  dosage: string;
  frequency: string;
  startDate: string;
  endDate: string | null;
  active: boolean;
  user: PrescriptionUser;
  /** Latest suggestion only (no items) -- enough for a status badge. */
  healthSuggestions: { id: string; status: 'DRAFT' | 'PUBLISHED'; createdAt: string }[];
}

export interface RoutineDetail extends Omit<RoutineListItem, 'healthSuggestions'> {
  prescriptionMedicine: { instructions: string | null; duration: string } | null;
  /** Newest first, with items. */
  healthSuggestions: RoutineSuggestion[];
}

function listQuery(params: Record<string, string | boolean | null | undefined>) {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v) qs.set(k, String(v));
  const s = qs.toString();
  return s ? `?${s}` : '';
}

/** 20 per page, newest first; q matches medicine, patient name or phone. */
export function listRoutines(params: { cursor?: string | null; q?: string; active?: boolean } = {}) {
  return request<CursorPage<RoutineListItem>>(`/pharmacist/routines${listQuery(params)}`);
}

export function getRoutine(id: string) {
  return request<RoutineDetail>(`/pharmacist/routines/${id}`);
}

/** Explicit pharmacist action: one AI call for this routine; returns the DRAFT. Never publishes. */
export function requestRoutineSuggestion(id: string) {
  return request<HealthSuggestion>(`/pharmacist/routines/${id}/suggestion`, { method: 'POST' });
}

/** 20 per page, newest first; q matches medicine, patient name or phone. */
export function listHealthSuggestions(
  params: { cursor?: string | null; q?: string; status?: HealthSuggestion['status'] } = {},
) {
  return request<CursorPage<HealthSuggestion>>(`/pharmacist/health-suggestions${listQuery(params)}`);
}

export function getHealthSuggestion(id: string) {
  return request<HealthSuggestion>(`/pharmacist/health-suggestions/${id}`);
}

export function updateHealthSuggestion(
  id: string,
  input: { itemsEn: SuggestionItem[]; itemsBn: SuggestionItem[] },
) {
  return request<HealthSuggestion>(`/pharmacist/health-suggestions/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  });
}

export function publishHealthSuggestion(id: string) {
  return request<HealthSuggestion>(`/pharmacist/health-suggestions/${id}/publish`, { method: 'POST' });
}

export function unpublishHealthSuggestion(id: string) {
  return request<HealthSuggestion>(`/pharmacist/health-suggestions/${id}/unpublish`, {
    method: 'POST',
  });
}

// --- Audit log (admin, read-only) ---

export interface AuditLogRow {
  id: string;
  createdAt: string;
  /** e.g. "prescription.reject" */
  action: string;
  entityType: string;
  entityId: string | null;
  actor: { id: string; name: string; role: AdminUser['role'] } | null;
  /** The patient the change was about, if any. */
  subjectUser: { id: string; name: string } | null;
}

export interface AuditLogDetail extends AuditLogRow {
  before: unknown;
  after: unknown;
}

export interface AuditLogParams {
  cursor?: string | null;
  action?: string;
  actorId?: string;
  actorRole?: AdminUser['role'];
  /** YYYY-MM-DD, inclusive */
  from?: string;
  to?: string;
}

export function listAuditLogs(params: AuditLogParams = {}) {
  return request<CursorPage<AuditLogRow>>(`/admin/audit-logs${listQuery({ ...params })}`);
}

export function getAuditLogFilters() {
  return request<{ actions: string[]; actors: { id: string; name: string; role: AdminUser['role'] }[] }>(
    '/admin/audit-logs/filters',
  );
}

export function getAuditLog(id: string) {
  return request<AuditLogDetail>(`/admin/audit-logs/${id}`);
}

// --- Govt notices (admin) ---

export interface Notice {
  id: string;
  title: string;
  content: string;
  audience: 'ALL' | 'USER' | 'ADMIN';
  status: 'DRAFT' | 'PENDING_APPROVAL' | 'PUBLISHED' | 'ARCHIVED';
  expiresAt: string | null;
  /** Null while a published notice waits for its start time (scheduled). */
  publishedAt: string | null;
  startsAt: string | null;
  source: string | null;
  sourceUrl: string | null;
  /** An admin's note when sending a pharmacist's notice back. */
  reviewNote: string | null;
  approvedAt: string | null;
  createdAt: string;
  createdBy: { id: string; name: string } | null;
  approvedBy: { id: string; name: string } | null;
  /** None = nationwide. */
  divisions: { divisionId: number; division: LookupRow }[];
}

export interface NoticeInput {
  title: string;
  content: string;
  audience?: 'ALL' | 'USER' | 'ADMIN';
  /** ISO dates; on update, `null` removes them. */
  expiresAt?: string | null;
  startsAt?: string | null;
  source?: string | null;
  sourceUrl?: string | null;
  /** [] = nationwide. */
  divisionIds?: number[];
}

export function listNotices() {
  return request<Notice[]>('/admin/notices');
}

export function getNotice(id: string) {
  return request<Notice>(`/admin/notices/${id}`);
}

export function createNotice(input: NoticeInput) {
  return request<Notice>('/admin/notices', { method: 'POST', body: JSON.stringify(input) });
}

export function updateNotice(id: string, input: Partial<NoticeInput>) {
  return request<Notice>(`/admin/notices/${id}`, { method: 'PATCH', body: JSON.stringify(input) });
}

/** Admin: publish (or approve a pending one); schedules it when startsAt is in the future. */
export function publishNotice(id: string) {
  return request<Notice>(`/admin/notices/${id}/publish`, { method: 'POST' });
}

/** Pharmacist: send a draft for an admin's approval. */
export function submitNotice(id: string) {
  return request<Notice>(`/admin/notices/${id}/submit`, { method: 'POST' });
}

/** Pharmacist: take a pending notice back to draft. */
export function withdrawNotice(id: string) {
  return request<Notice>(`/admin/notices/${id}/withdraw`, { method: 'POST' });
}

/** Admin: return a pending notice to draft with a note for the pharmacist. */
export function sendBackNotice(id: string, note: string) {
  return request<Notice>(`/admin/notices/${id}/send-back`, { method: 'POST', body: JSON.stringify({ note }) });
}

export function archiveNotice(id: string) {
  return request<Notice>(`/admin/notices/${id}/archive`, { method: 'POST' });
}

export function deleteNotice(id: string) {
  return request<void>(`/admin/notices/${id}`, { method: 'DELETE' });
}

// --- Dashboard (admin) ---
// All numbers are computed by the backend (GET /admin/dashboard); the admin
// app only renders them.

export interface DashboardData {
  generatedAt: string;
  totals: {
    users: number;
    families: number;
    prescriptions: { total: number; pending: number; completed: number; rejected: number };
  };
  recentPrescriptions: {
    id: string;
    status: PrescriptionStatus;
    createdAt: string;
    user: { id: string; name: string };
  }[];
  analytics: {
    prescriptionsPerDay: { date: string; count: number }[];
    newUsersPerDay: { date: string; count: number }[];
    doses7d: { taken: number; missed: number; adherencePercent: number | null };
    liveNotices: number;
    activeRules: number;
    aiSuggestionsAwaitingReview: number;
    noticesAwaitingApproval: number;
  };
}

export function getDashboard() {
  return request<DashboardData>('/admin/dashboard');
}

// --- Analytics (admin) ---
// GET /admin/analytics*: computed by the backend and cached there for
// `cacheSeconds`; generatedAt says when.

export interface CountBucket {
  id: number;
  name: string;
  count: number;
}

export interface TopDoctor {
  id: string;
  name: string;
  specialty: LookupRow | null;
  patients: number;
}

export interface TopMedicine {
  id: string;
  brandName: string;
  manufacturer: string | null;
  form: LookupRow | null;
  patients: number;
}

export interface AnalyticsData {
  generatedAt: string;
  cacheSeconds: number;
  users: {
    total: number;
    byStatus: { active: number; deactivated: number; suspended: number };
    byDivision: CountBucket[];
    divisionNotSet: number;
    byGender: CountBucket[];
    genderNotSet: number;
    byAge: { band: string; count: number }[];
    ageNotSet: number;
  };
  families: { total: number; members: number };
  catalog: { doctors: number; medicines: number; incompleteDoctors: number; incompleteMedicines: number };
  topDoctors: TopDoctor[];
  topMedicines: TopMedicine[];
}

export interface DivisionAnalytics {
  generatedAt: string;
  division: LookupRow;
  districts: CountBucket[];
  notSet: number;
}

export type Ranked<T> = T & { rank: number };

export function getAnalytics() {
  return request<AnalyticsData>('/admin/analytics');
}

export function getDivisionAnalytics(divisionId: number) {
  return request<DivisionAnalytics>(`/admin/analytics/divisions/${divisionId}`);
}

export function listTopDoctors(cursor: string | null) {
  return request<CursorPage<Ranked<TopDoctor>>>(
    `/admin/analytics/top-doctors${cursor ? `?cursor=${encodeURIComponent(cursor)}` : ''}`,
  );
}

export function listTopMedicines(cursor: string | null) {
  return request<CursorPage<Ranked<TopMedicine>>>(
    `/admin/analytics/top-medicines${cursor ? `?cursor=${encodeURIComponent(cursor)}` : ''}`,
  );
}

export interface PharmacistDashboardData {
  generatedAt: string;
  queue: { pending: number; reuploads: number; awaitingConfirmation: number };
  today: { prepared: number; rejected: number };
  catalog: { incompleteDoctors: number; incompleteMedicines: number };
  /** Unpublished AI suggestions (drafts). */
  aiSuggestions: { drafts: number };
  /** The pharmacist's own notices: sent back by an admin, and waiting for approval. */
  notices: { sentBack: number; pending: number };
  oldestPending: {
    id: string;
    createdAt: string;
    previousPrescriptionId: string | null;
    user: { id: string; name: string };
  }[];
}

export function getPharmacistDashboard() {
  return request<PharmacistDashboardData>('/pharmacist/dashboard');
}

// --- Users (admin) ---

export type AccountStatus = 'ACTIVE' | 'DEACTIVATED' | 'SUSPENDED' | 'DELETED';
export type AgeBand = '0-17' | '18-39' | '40-59' | '60+';

export interface AdminUserRow {
  id: string;
  name: string;
  phone: string | null;
  role: AdminUser['role'];
  accountStatus: AccountStatus;
  createdAt: string;
  division: LookupRow | null;
  /** False for admins (never banned) and deleted accounts. */
  canBan: boolean;
}

export interface AdminUsersParams {
  cursor?: string | null;
  phone?: string;
  divisionId?: number;
  ageBand?: AgeBand;
  role?: AdminUser['role'];
  status?: AccountStatus;
}

/** 20 per page, newest first. Deleted accounts only when status=DELETED. */
export function listAdminUsers(params: AdminUsersParams = {}) {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== '') qs.set(k, String(v));
  return request<CursorPage<AdminUserRow>>(`/admin/users${qs.size ? `?${qs}` : ''}`);
}

export function banUser(id: string) {
  return request<{ id: string; accountStatus: AccountStatus }>(`/admin/users/${id}/ban`, { method: 'POST' });
}

export function unbanUser(id: string) {
  return request<{ id: string; accountStatus: AccountStatus }>(`/admin/users/${id}/unban`, { method: 'POST' });
}
