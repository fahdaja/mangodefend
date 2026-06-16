"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Shield, Eye, EyeOff, Loader2, AlertCircle } from "lucide-react";
import { authApi } from "@/lib/api";
import { useAuthStore } from "@/lib/store";
import { getDeviceData } from "@/utils/device";
import Toast from "@/components/Toast";

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirect") || "/dashboard";
  
  const { setAuth } = useAuthStore();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [shake, setShake] = useState(false);
  const [showToast, setShowToast] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    setShowToast(false);

    try {
      const deviceData = getDeviceData();
      const isClientLogin = redirectTo.startsWith("/client");
      const res = isClientLogin
        ? await authApi.clientLogin(email, password, deviceData)
        : await authApi.login(email, password, deviceData);
      const { data } = res.data;
      const token = data?.access_token ?? res.data?.access_token;
      const user = data?.user ?? { id: 0, email, role: "admin" };

      if (!token) throw new Error("No access token returned");

      localStorage.setItem("access_token", token);
      setAuth(token, user);
      router.push(redirectTo);
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string } }; message?: string };
      const msg = axiosErr?.response?.data?.message ??
          axiosErr?.message ??
          "Login failed. Please check your credentials.";
      setError(msg);
      setShake(true);
      setShowToast(true);
      setTimeout(() => setShake(false), 500);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-bg-glow" />
      {showToast && (
        <Toast
          message={error || "Login failed"}
          type="error"
          onClose={() => setShowToast(false)}
          duration={8000}
        />
      )}

      {/* Decorative grid */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "linear-gradient(rgba(249,115,22,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(249,115,22,0.03) 1px, transparent 1px)",
          backgroundSize: "48px 48px",
          pointerEvents: "none",
        }}
      />

      <div className={`login-card ${shake ? "shake" : ""}`} style={{ animation: "slideUp 0.3s ease" }}>
        {/* Logo */}
        <div className="login-logo">
          <div className="login-logo-icon">
            <Shield size={24} color="white" />
          </div>
          <div>
            <div className="login-title">MangoDefend</div>
            <div className="login-subtitle">Admin Dashboard</div>
          </div>
        </div>

        <h2 style={{ fontSize: 20, fontWeight: 700, color: "var(--text-primary)", marginBottom: 8 }}>
          Welcome back
        </h2>
        <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 28 }}>
          Sign in to your admin account to continue
        </p>

        {error && (
          <div className="login-error" style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
            <AlertCircle size={16} style={{ flexShrink: 0, marginTop: 2, color: "var(--color-danger)" }} />
            <div>
              <div style={{ fontWeight: 600, fontSize: 13, color: "var(--color-danger)" }}>Access Denied</div>
              <div style={{ fontSize: 12, color: "var(--text-secondary)", marginTop: 2 }}>{error}</div>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label" htmlFor="login-email">Email Address</label>
            <input
              id="login-email"
              className="form-input"
              type="email"
              placeholder="admin@mangodefend.id"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoFocus
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="login-password">Password</label>
            <div style={{ position: "relative" }}>
              <input
                id="login-password"
                className="form-input"
                type={showPassword ? "text" : "password"}
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{ paddingRight: 44 }}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={{
                  position: "absolute",
                  right: 12,
                  top: "50%",
                  transform: "translateY(-50%)",
                  background: "none",
                  border: "none",
                  cursor: "pointer",
                  color: "var(--text-muted)",
                  padding: "2px",
                }}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          <button
            id="login-submit"
            type="submit"
            className="btn btn-primary w-full"
            disabled={loading}
            style={{ marginTop: 8, justifyContent: "center", width: "100%", padding: "11px 16px" }}
          >
            {loading ? (
              <>
                <Loader2 size={16} style={{ animation: "spin 0.6s linear infinite" }} />
                Signing in...
              </>
            ) : (
              "Sign In"
            )}
          </button>
        </form>

        <p style={{ fontSize: 11, color: "var(--text-muted)", textAlign: "center", marginTop: 24 }}>
          Admin access only — unauthorized attempts are logged
        </p>
      </div>
    </div>
  );
}
