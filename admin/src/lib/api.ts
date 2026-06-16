import axios from "axios";

const BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000";

export const api = axios.create({
  baseURL: BASE_URL,
  headers: { "Content-Type": "application/json" },
});

api.interceptors.request.use((config) => {
  const token =
    typeof window !== "undefined" ? localStorage.getItem("access_token") : null;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (
      err.response?.status === 401 &&
      typeof window !== "undefined" &&
      window.location.pathname !== "/login" &&
      !err.config?.url?.includes("/auth/")
    ) {
      localStorage.removeItem("access_token");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  },
);

// ─── Auth ────────────────────────────────────────────────────────────────────
export const authApi = {
  login: (email: string, password: string, device: DeviceInfo) =>
    api.post("/auth/admin/login", { email, password, device }),

  clientLogin: (email: string, password: string, device: DeviceInfo) =>
    api.post("/auth/login", { email, password, device }),

  logout: (hardware_id: string, user_id: number) =>
    api.post("/auth/logout", { hardware_id, user_id }),
};

// ─── Users ───────────────────────────────────────────────────────────────────
export const usersApi = {
  /**
   * Mengambil data tabel dengan dukungan server-side search & pagination.
   */
  getAll: (search?: string, page: number = 1, limit: number = 10) =>
    api.get("/users", { params: { search, page, limit } }),

  /**
   * Mengambil angka total, admin, dan client untuk summary cards.
   */
  getStats: () => api.get("/stats"),

  getById: (id: number) => api.get(`/users/${id}`),

  /**
   * Fungsi Lazy Loading untuk melihat device milik user tertentu.
   * Dipanggil hanya saat baris tabel di-expand.
   */
  getDevices: (id: number) => api.get(`/${id}/devices`),
};

// ─── Subscriptions ───────────────────────────────────────────────────────────
export const subscriptionsApi = {
  getAllWithUsers: () => api.get("/subscriptions/all"),
  getPlans: () => api.get("/subscriptions/plan"),
  createPlan: (data: CreatePlanPayload) =>
    api.post("/subscriptions/plan", data),
  updatePlan: (id: number, data: Partial<CreatePlanPayload>) =>
    api.patch(`/subscriptions/plan/${id}`, data),
  deletePlan: (id: number) => api.delete(`/subscriptions/plan/${id}`),
};

export const transactionsApi = {
  getAll: () => api.get("/transactions"),
  checkout: (planId: number, method: "virtual_account" | "qris") =>
    api.post("/transactions/checkout", { plan_id: planId, method }),
  simulateSuccess: (id: number) =>
    api.post(`/transactions/webhook/success/${id}`),
  simulateWebhook: (id: number, status: "settlement" | "expire" | "failure") =>
    api.post("/transactions/webhook", { order_id: id, transaction_status: status }),
};

const ML_BASE_URL = process.env.NEXT_PUBLIC_ML_API_URL || "http://localhost:8000";
const mlServerApi = axios.create({
  baseURL: ML_BASE_URL,
  headers: { "Content-Type": "application/json" },
});

// ─── ML Models ───────────────────────────────────────────────────────────────
export const mlApi = {
  getAll: () => api.get("/models"),
  create: (data: CreateMlPayload) => api.post("/models", data),
  setActive: (id: number) =>
    api.patch(`/models/${id}/status`, { is_active: true }),
  setInactive: (id: number) =>
    api.patch(`/models/${id}/status`, { is_active: false }),
  delete: (id: number) => api.delete(`/models/${id}`),
  getServerHealth: () => mlServerApi.get("/health"),
  getServerStats: (days: number = 7) => mlServerApi.get("/api/v1/scans/stats", { params: { days } }),
  getServerLogs: (
    page: number = 1,
    limit: number = 20,
    search?: string,
    label?: string,
  ) =>
    mlServerApi.get("/api/v1/scans/logs", { params: { page, limit, search, label } }),
  getSystemLogs: (lines: number = 100) =>
    mlServerApi.get("/api/v1/scans/system-logs", { params: { lines } }),
  getAppsHealth: () => api.get("/models"),
  getAppsLogs: (lines: number = 100) =>
    api.get("/models/system-logs", { params: { lines } }),
};


// ─── Dataset ─────────────────────────────────────────────────────────────────
export const datasetApi = {
  getStats: (range: string = "30d") =>
    api.get("/dataset/stats", { params: { range } }),
  getRecent: (label?: string, page: number = 1, limit: number = 20) =>
    api.get("/dataset/recent", { params: { label, page, limit } }),
  getMalware: () => api.get("/dataset/malware"),
  getBenign: () => api.get("/dataset/benign"),
  getUnimportedMalware: (page: number = 1, limit: number = 20) =>
    api.get("/dataset/unimported-malware", { params: { page, limit } }),
  importToInventory: (file_hash: string, label: string = "malware") =>
    api.post("/dataset/import", { file_hash, label }),
};

// ─── Types ────────────────────────────────────────────────────────────────────
export interface CreatePlanPayload {
  plan_name: string;
  description: string;
  price: number;
  durationDays: number;
  model_id?: number | null;
  upload_file_limit?: number;
  full_scan_limit?: number;
}

export interface CreateMlPayload {
  version: string;
  file_path: string;
  checksum: string;
}

export interface DeviceInfo {
  hardware_id: string;
  hostname: string;
  os_type: string;
  app_type: string;
}
