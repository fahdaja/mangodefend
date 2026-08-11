import axios from "axios";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000";

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

api.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const token = localStorage.getItem("access_token");
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

export const authApi = {
  clientLogin: (email: string, pass: string, device?: any) =>
    api.post("/auth/login", { email, password: pass, device }),
  adminLogin: (email: string, pass: string) =>
    api.post("/auth/admin/login", { email, password: pass }),
  verifyRegistrationOtp: (email: string, code: string) =>
    api.post("/auth/verify-registration-otp", { email, code }),
  verifyLoginOtp: (email: string, otp: string, device?: any) =>
    api.post("/auth/verify-login-otp", { email, otp, device }),
  resendOtp: (email: string, type?: "registration" | "login") =>
    api.post("/auth/resend-otp", { email, type }),
  forgotPassword: (email: string) =>
    api.post("/auth/forgot-password", { email }),
  resetPassword: (email: string, token: string, newPass: string) =>
    api.post("/auth/reset-password", { email, token, newPassword: newPass }),
  logout: () => api.post("/auth/logout"),
};
