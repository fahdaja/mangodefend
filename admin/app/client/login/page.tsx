"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Shield, Eye, EyeOff, Loader2, AlertCircle, ArrowRight, User } from "lucide-react";
import { authApi } from "@/lib/api";
import { useAuthStore } from "@/lib/store";
import { getDeviceData } from "@/utils/device";
import Toast from "@/components/Toast";

function ClientLoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirect") || "/client/subscriptions";
  
  const { setAuth } = useAuthStore();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [shake, setShake] = useState(false);
  const [showToast, setShowToast] = useState(false);

  const handleSubmit = async (e?: React.FormEvent, customEmail?: string, customPass?: string) => {
    if (e) e.preventDefault();
    setError("");
    setLoading(true);
    setShowToast(false);

    const loginEmail = customEmail || email;
    const loginPassword = customPass || password;

    try {
      const deviceData = getDeviceData();
      const res = await authApi.clientLogin(loginEmail, loginPassword, deviceData);
      const { data } = res.data;
      const token = data?.access_token ?? res.data?.access_token;
      const user = data?.user ?? { id: 0, email: loginEmail, role: "client" };

      if (!token) throw new Error("No access token returned");

      localStorage.setItem("access_token", token);
      setAuth(token, user);
      router.push(redirectTo);
    } catch (err: any) {
      const msg = err.response?.data?.message ??
          err.message ??
          "Login failed. Please check your credentials.";
      setError(msg);
      setShake(true);
      setShowToast(true);
      setTimeout(() => setShake(false), 500);
    } finally {
      setLoading(false);
    }
  };

  const handleQuickLogin = (emailPreset: string) => {
    setEmail(emailPreset);
    setPassword("client123");
    handleSubmit(undefined, emailPreset, "client123");
  };

  return (
    <div className="login-page" style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100vh", padding: "20px" }}>
      <div className="login-bg-glow" style={{ background: "radial-gradient(circle, rgba(249,115,22,0.15) 0%, transparent 70%)" }} />
      {showToast && (
        <Toast
          message={error || "Login failed"}
          type="error"
          onClose={() => setShowToast(false)}
          duration={5000}
        />
      )}

      {/* Decorative Grid */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "linear-gradient(rgba(249,115,22,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(249,115,22,0.02) 1px, transparent 1px)",
          backgroundSize: "56px 56px",
          pointerEvents: "none",
        }}
      />

      <div className={`login-card ${shake ? "shake" : ""}`} style={{ animation: "slideUp 0.3s ease", maxWidth: 440, width: "100%", padding: 32 }}>
        {/* Logo */}
        <div className="login-logo" style={{ marginBottom: 24 }}>
          <div className="login-logo-icon" style={{ background: "linear-gradient(135deg, var(--brand-primary) 0%, #ea580c 100%)" }}>
            <Shield size={22} color="white" />
          </div>
          <div>
            <div className="login-title" style={{ fontSize: 20 }}>MangoDefend</div>
            <div className="login-subtitle" style={{ color: "var(--brand-primary)", fontWeight: 600 }}>Client Portal</div>
          </div>
        </div>

        <h2 style={{ fontSize: 20, fontWeight: 800, color: "var(--text-primary)", marginBottom: 6 }}>
          Client Access
        </h2>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", marginBottom: 24, lineHeight: 1.5 }}>
          Sign in to subscribe, manage your devices, and monitor malware scans.
        </p>

        {error && (
          <div className="login-error" style={{ display: "flex", alignItems: "flex-start", gap: 10, background: "rgba(239,68,68,0.06)", border: "1px solid rgba(239,68,68,0.15)", borderRadius: 8, padding: 12, marginBottom: 20 }}>
            <AlertCircle size={16} style={{ flexShrink: 0, marginTop: 2, color: "var(--color-danger)" }} />
            <div>
              <div style={{ fontWeight: 600, fontSize: 13, color: "var(--color-danger)" }}>Authentication Error</div>
              <div style={{ fontSize: 12, color: "var(--text-secondary)", marginTop: 2 }}>{error}</div>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="form-group" style={{ marginBottom: 16 }}>
            <label className="form-label" htmlFor="login-email" style={{ fontSize: 12, fontWeight: 600 }}>Email Address</label>
            <input
              id="login-email"
              className="form-input"
              type="email"
              placeholder="name@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoFocus
              style={{ fontSize: 14 }}
            />
          </div>

          <div className="form-group" style={{ marginBottom: 24 }}>
            <label className="form-label" htmlFor="login-password" style={{ fontSize: 12, fontWeight: 600 }}>Password</label>
            <div style={{ position: "relative" }}>
              <input
                id="login-password"
                className="form-input"
                type={showPassword ? "text" : "password"}
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{ paddingRight: 44, fontSize: 14 }}
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
            style={{ justifyContent: "center", width: "100%", padding: "12px 16px", fontWeight: 600, display: "flex", gap: 8, alignItems: "center" }}
          >
            {loading ? (
              <>
                <Loader2 size={16} className="spinner" />
                Signing in...
              </>
            ) : (
              <>
                Sign In
                <ArrowRight size={16} />
              </>
            )}
          </button>
        </form>

        {/* Quick Login Presets for testing */}
        <div style={{ borderTop: "1px solid var(--bg-border)", marginTop: 28, paddingTop: 20 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.5px" }}>
            Quick Login Presets (Sandbox)
          </span>
          <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 12 }}>
            <button
              onClick={() => handleQuickLogin("budi@example.com")}
              disabled={loading}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                padding: "10px 14px",
                borderRadius: 8,
                border: "1px solid var(--bg-border)",
                background: "rgba(255, 255, 255, 0.02)",
                color: "var(--text-primary)",
                fontSize: 13,
                cursor: "pointer",
                textAlign: "left",
                transition: "all 0.2s"
              }}
              className="quick-login-btn"
            >
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <User size={14} color="var(--brand-primary)" />
                <div>
                  <strong>Budi Santoso</strong>
                  <span style={{ display: "block", fontSize: 11, color: "var(--text-muted)" }}>budi@example.com</span>
                </div>
              </div>
              <span style={{ fontSize: 11, background: "rgba(249,115,22,0.1)", color: "var(--brand-primary)", padding: "2px 6px", borderRadius: 4 }}>client123</span>
            </button>

            <button
              onClick={() => handleQuickLogin("siti@example.com")}
              disabled={loading}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                padding: "10px 14px",
                borderRadius: 8,
                border: "1px solid var(--bg-border)",
                background: "rgba(255, 255, 255, 0.02)",
                color: "var(--text-primary)",
                fontSize: 13,
                cursor: "pointer",
                textAlign: "left",
                transition: "all 0.2s"
              }}
              className="quick-login-btn"
            >
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <User size={14} color="var(--brand-primary)" />
                <div>
                  <strong>Siti Rahma</strong>
                  <span style={{ display: "block", fontSize: 11, color: "var(--text-muted)" }}>siti@example.com</span>
                </div>
              </div>
              <span style={{ fontSize: 11, background: "rgba(249,115,22,0.1)", color: "var(--brand-primary)", padding: "2px 6px", borderRadius: 4 }}>client123</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function ClientLoginPage() {
  return (
    <Suspense fallback={<div className="login-page" />}>
      <ClientLoginForm />
    </Suspense>
  );
}
