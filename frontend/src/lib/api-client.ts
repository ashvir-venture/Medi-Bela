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
  ) {
    super(message);
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const token = getAccessToken();
  const isFormData = options.body instanceof FormData;

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers: {
      ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });

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
    let message = `Request failed (${response.status})`;
    try {
      const body = await response.json();
      message = Array.isArray(body.message) ? body.message.join(', ') : body.message ?? message;
    } catch {
      // ignore parse failure, use default message
    }
    throw new ApiError(message, response.status);
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
  phone: string;
  address: string | null;
}

export type PrescriptionStatus = 'PENDING' | 'REJECTED' | 'AWAITING_CONFIRMATION' | 'ACTIVE' | 'ENDED';

export interface PrescriptionListItem {
  id: string;
  status: PrescriptionStatus;
  imageUrl: string;
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

// --- AI health suggestions (admin) ---
// Separate from suggestion rules above: these are open-ended, per-user,
// AI-generated (see the LLM system prompt) rather than admin-authored
// deterministic rules. One row = one generation run for one user,
// created automatically right after their prescription is completed
// into a routine. Never shown to the user until published.

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

// --- Routines panel (admin) ---

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

export function listRoutines(params: { active?: boolean } = {}) {
  const qs = params.active === undefined ? '' : `?active=${params.active}`;
  return request<RoutineListItem[]>(`/admin/routines${qs}`);
}

export function getRoutine(id: string) {
  return request<RoutineDetail>(`/admin/routines/${id}`);
}

/** Explicit admin action: one AI call for this routine; returns the DRAFT. Never publishes. */
export function requestRoutineSuggestion(id: string) {
  return request<HealthSuggestion>(`/admin/routines/${id}/suggestion`, { method: 'POST' });
}

export function listHealthSuggestions() {
  return request<HealthSuggestion[]>('/admin/health-suggestions');
}

export function getHealthSuggestion(id: string) {
  return request<HealthSuggestion>(`/admin/health-suggestions/${id}`);
}

export function updateHealthSuggestion(
  id: string,
  input: { itemsEn: SuggestionItem[]; itemsBn: SuggestionItem[] },
) {
  return request<HealthSuggestion>(`/admin/health-suggestions/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  });
}

export function publishHealthSuggestion(id: string) {
  return request<HealthSuggestion>(`/admin/health-suggestions/${id}/publish`, { method: 'POST' });
}

export function unpublishHealthSuggestion(id: string) {
  return request<HealthSuggestion>(`/admin/health-suggestions/${id}/unpublish`, {
    method: 'POST',
  });
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
