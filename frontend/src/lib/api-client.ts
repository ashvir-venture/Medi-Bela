// Talks to the same NestJS backend as the Flutter app (`/api/v1` prefix).
// Deliberately minimal: no admin app existed to extend in this project,
// so this mirrors the mobile app's own conventions (Bearer token, same
// response shapes) rather than inventing a separate contract.

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
}

export interface PrescriptionUser {
  id: string;
  name: string;
  phone: string;
  address: string | null;
}

export interface PrescriptionListItem {
  id: string;
  status: 'PENDING' | 'COMPLETED' | 'REJECTED';
  imageUrl: string;
  createdAt: string;
  user: PrescriptionUser;
}

export interface PrescriptionDetail extends PrescriptionListItem {
  rejectionReason: string | null;
  processingNote: string | null;
  medicines: PrescriptionMedicine[];
  reviewedBy: { id: string; name: string } | null;
}

export function listPendingPrescriptions() {
  return request<PrescriptionListItem[]>('/prescriptions/admin/pending');
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
  status: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
  expiresAt: string | null;
  publishedAt: string | null;
  createdAt: string;
  createdBy: { id: string; name: string } | null;
}

export interface NoticeInput {
  title: string;
  content: string;
  audience?: 'ALL' | 'USER' | 'ADMIN';
  /** ISO date to set an expiry; on update, `null` removes it. */
  expiresAt?: string | null;
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

export function publishNotice(id: string) {
  return request<Notice>(`/admin/notices/${id}/publish`, { method: 'POST' });
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
    status: 'PENDING' | 'COMPLETED' | 'REJECTED';
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
