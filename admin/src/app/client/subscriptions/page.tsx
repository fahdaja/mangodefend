"use client";

import { useState } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { subscriptionsApi, transactionsApi } from "@/lib/api";
import { useAuthStore } from "@/lib/store";
import { useRouter } from "next/navigation";
import {
  Check,
  CreditCard,
  Lock,
  Shield,
  Loader2,
  AlertCircle,
  QrCode,
  ArrowRight,
  ShieldCheck,
  X,
  Sparkles,
} from "lucide-react";
import type { Plan } from "@/lib/types";

export default function ClientSubscriptionsPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const [selectedPlan, setSelectedPlan] = useState<Plan | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<"qris" | "virtual_account" | null>(null);
  const [showCheckoutModal, setShowCheckoutModal] = useState(false);
  const [activeTransaction, setActiveTransaction] = useState<any>(null);
  const [paymentSuccessData, setPaymentSuccessData] = useState<any>(null);
  const [submittingCheckout, setSubmittingCheckout] = useState(false);
  const [simulatingPayment, setSimulatingPayment] = useState(false);
  const [errorMsg, setErrorMsg] = useState("");

  // Fetch plans
  const { data: plansRaw, isLoading: plansLoading } = useQuery({
    queryKey: ["client-plans"],
    queryFn: () => subscriptionsApi.getPlans().then((r) => r.data?.data ?? r.data),
  });

  const plans: Plan[] = (Array.isArray(plansRaw) ? plansRaw : []).filter(
    (p) => p.plan_name?.toLowerCase() !== "free"
  );

  const formatCurrency = (val: number) =>
    new Intl.NumberFormat("id-ID", {
      style: "currency",
      currency: "IDR",
      maximumFractionDigits: 0,
    }).format(val);

  // Handle plan selection click
  const handleSelectPlan = (plan: Plan) => {
    setErrorMsg("");
    if (!token || !user) {
      // Not logged in -> Redirect to login page
      router.push(`/login?redirect=/client/subscriptions`);
      return;
    }
    setSelectedPlan(plan);
    setPaymentMethod(null);
    setActiveTransaction(null);
    setPaymentSuccessData(null);
    setShowCheckoutModal(true);
  };

  // Handle transaction checkout creation
  const handleCreateTransaction = async () => {
    if (!selectedPlan || !paymentMethod) return;
    setSubmittingCheckout(true);
    setErrorMsg("");
    try {
      const res = await transactionsApi.checkout(selectedPlan.id, paymentMethod);
      if (res.data?.data) {
        setActiveTransaction(res.data.data);
      } else {
        setActiveTransaction(res.data);
      }
    } catch (err: any) {
      setErrorMsg(
        err.response?.data?.message || "Failed to initiate transaction. Please try again."
      );
    } finally {
      setSubmittingCheckout(false);
    }
  };

  // Simulate payment webhook success callback
  const handleSimulatePaymentSuccess = async () => {
    const txId = activeTransaction?.id;
    if (!txId) return;
    setSimulatingPayment(true);
    setErrorMsg("");
    try {
      const res = await transactionsApi.simulateSuccess(txId);
      setPaymentSuccessData(res.data);
    } catch (err: any) {
      setErrorMsg(
        err.response?.data?.message || "Failed to simulate payment callback."
      );
    } finally {
      setSimulatingPayment(false);
    }
  };

  // Feature list based on plan type
  const getPlanFeatures = (planName: string) => {
    const defaultFeatures = [
      "AI-Powered Real-time Scan Engine",
      "Manual and Automatic File Scanning",
      "Quarantine and Threat Mitigation",
    ];

    if (planName.toLowerCase() === "free") {
      return [...defaultFeatures, "Scanning limits: 5 scans / day", "Community support"];
    } else if (planName.toLowerCase() === "pro") {
      return [
        ...defaultFeatures,
        "Unlimited scans on registered devices",
        "High-performance cloud sandboxing",
        "Advanced malware definition updates",
        "Priority 24/7 client support",
      ];
    } else {
      // Business/Enterprise
      return [
        ...defaultFeatures,
        "Unlimited scanning for up to 10 devices",
        "Custom private ML models execution",
        "Automated administrative audits",
        "Dedicated account technical manager",
        "Enterprise API access integration",
      ];
    }
  };

  return (
    <div className="login-page" style={{ overflowY: "auto", padding: "40px 20px" }}>
      <div className="login-bg-glow" style={{ opacity: 0.15 }} />

      {/* Grid Pattern */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "linear-gradient(rgba(249,115,22,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(249,115,22,0.02) 1px, transparent 1px)",
          backgroundSize: "64px 64px",
          pointerEvents: "none",
        }}
      />

      <div style={{ maxWidth: 1200, margin: "0 auto", width: "100%", position: "relative", zIndex: 2 }}>
        {/* Header */}
        <div style={{ textAlign: "center", marginBottom: 50 }}>
          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              background: "rgba(249,115,22,0.08)",
              border: "1px solid rgba(249,115,22,0.2)",
              padding: "6px 14px",
              borderRadius: 20,
              color: "var(--brand-primary)",
              fontSize: 12,
              fontWeight: 600,
              marginBottom: 16,
            }}
          >
            <Shield size={14} />
            MangoDefend Security Portal
          </div>
          <h1
            style={{
              fontSize: 36,
              fontWeight: 800,
              color: "var(--text-primary)",
              letterSpacing: "-0.5px",
              marginBottom: 12,
            }}
          >
            Select Your Protection Plan
          </h1>
          <p style={{ color: "var(--text-secondary)", fontSize: 15, maxWidth: 600, margin: "0 auto", lineHeight: 1.6 }}>
            Empower your devices with our state-of-the-art AI scanner and protect your infrastructure from
            modern malware threats.
          </p>

          {user && (
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 8,
                background: "rgba(255,255,255,0.03)",
                border: "1px solid var(--bg-border)",
                padding: "6px 12px",
                borderRadius: 8,
                marginTop: 20,
                fontSize: 13,
                color: "var(--text-secondary)",
              }}
            >
              <span>Logged in as:</span>
              <strong style={{ color: "var(--text-primary)" }}>{user.email}</strong>
              <span className="badge badge-purple" style={{ fontSize: 10, textTransform: "uppercase" }}>
                {user.role}
              </span>
            </div>
          )}
        </div>

        {/* Loading */}
        {plansLoading ? (
          <div style={{ display: "flex", justifyContent: "center", padding: "80px 0" }}>
            <div className="spinner spinner-dark" />
          </div>
        ) : (
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
              gap: 24,
              alignItems: "stretch",
            }}
          >
            {plans.map((plan) => {
              const features = getPlanFeatures(plan.plan_name);
              const isPro = plan.plan_name.toLowerCase() === "pro";
              const isBusiness = plan.plan_name.toLowerCase() === "bussiness";

              return (
                <div
                  key={plan.id}
                  className="card"
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "space-between",
                    padding: 32,
                    position: "relative",
                    overflow: "hidden",
                    border: isPro
                      ? "1px solid rgba(249,115,22,0.4)"
                      : isBusiness
                      ? "1px solid rgba(168,85,247,0.4)"
                      : "1px solid var(--bg-border)",
                    background: isPro
                      ? "radial-gradient(circle at top right, rgba(249,115,22,0.05) 0%, var(--bg-card) 60%)"
                      : isBusiness
                      ? "radial-gradient(circle at top right, rgba(168,85,247,0.05) 0%, var(--bg-card) 60%)"
                      : "var(--bg-card)",
                    boxShadow: isPro
                      ? "0 10px 30px -15px rgba(249,115,22,0.25)"
                      : isBusiness
                      ? "0 10px 30px -15px rgba(168,85,247,0.25)"
                      : "none",
                  }}
                >
                  {isPro && (
                    <div
                      style={{
                        position: "absolute",
                        top: 16,
                        right: 16,
                        background: "var(--brand-primary)",
                        color: "white",
                        fontSize: 10,
                        fontWeight: 700,
                        textTransform: "uppercase",
                        padding: "3px 10px",
                        borderRadius: 12,
                        display: "flex",
                        alignItems: "center",
                        gap: 4,
                      }}
                    >
                      <Sparkles size={10} />
                      Most Popular
                    </div>
                  )}

                  <div>
                    {/* Header */}
                    <span
                      style={{
                        fontSize: 11,
                        fontWeight: 700,
                        textTransform: "uppercase",
                        color: isPro ? "var(--brand-primary)" : isBusiness ? "#a855f7" : "var(--text-muted)",
                        letterSpacing: "1px",
                      }}
                    >
                      {plan.plan_name} Plan
                    </span>
                    <div style={{ display: "flex", alignItems: "baseline", marginTop: 8, marginBottom: 12 }}>
                      <span style={{ fontSize: 32, fontWeight: 800, color: "var(--text-primary)" }}>
                        {formatCurrency(Number(plan.price))}
                      </span>
                      <span style={{ fontSize: 13, color: "var(--text-secondary)", marginLeft: 6 }}>
                        / {plan.durationDays} days
                      </span>
                    </div>

                    <p style={{ fontSize: 14, color: "var(--text-secondary)", lineHeight: 1.5, marginBottom: 28 }}>
                      {plan.description}
                    </p>

                    <div style={{ borderTop: "1px solid var(--bg-border)", paddingTop: 20 }}>
                      <p style={{ fontSize: 12, fontWeight: 600, color: "var(--text-primary)", marginBottom: 12 }}>
                        INCLUDES FEATURES:
                      </p>
                      <ul style={{ listStyle: "none", display: "flex", flexDirection: "column", gap: 10 }}>
                        {features.map((f, i) => (
                          <li key={i} style={{ display: "flex", gap: 10, fontSize: 13, color: "var(--text-secondary)" }}>
                            <Check
                              size={15}
                              style={{
                                color: isPro ? "var(--brand-primary)" : isBusiness ? "#a855f7" : "var(--color-success)",
                                flexShrink: 0,
                                marginTop: 2,
                              }}
                            />
                            <span>{f}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  </div>

                  <button
                    onClick={() => handleSelectPlan(plan)}
                    className="btn w-full"
                    style={{
                      marginTop: 32,
                      width: "100%",
                      justifyContent: "center",
                      background: isPro
                        ? "var(--brand-primary)"
                        : isBusiness
                        ? "#a855f7"
                        : "rgba(255,255,255,0.05)",
                      color: isPro || isBusiness ? "white" : "var(--text-primary)",
                      border: isPro || isBusiness ? "none" : "1px solid var(--bg-border)",
                      padding: "12px",
                      fontWeight: 600,
                    }}
                  >
                    {!token ? (
                      <>
                        Sign In to Choose
                        <ArrowRight size={14} style={{ marginLeft: 6 }} />
                      </>
                    ) : (
                      "Choose Plan"
                    )}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Checkout & Payment Sandbox Modal */}
      {showCheckoutModal && selectedPlan && (
        <div className="modal-overlay" style={{ zIndex: 100 }}>
          <div className="modal" style={{ maxWidth: 460, padding: 28, position: "relative" }}>
            <button
              className="btn btn-outline btn-icon btn-sm"
              onClick={() => setShowCheckoutModal(false)}
              style={{ position: "absolute", top: 16, right: 16 }}
            >
              <X size={14} />
            </button>

            {/* Step 1: Choose Payment Method */}
            {!activeTransaction && (
              <div>
                <h3 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4, color: "var(--text-primary)" }}>
                  Select Payment Method
                </h3>
                <p style={{ fontSize: 12, color: "var(--text-secondary)", marginBottom: 20 }}>
                  Select how you would like to pay for <strong>{selectedPlan.plan_name} Plan</strong>.
                </p>

                {errorMsg && (
                  <div
                    style={{
                      background: "rgba(239,68,68,0.1)",
                      border: "1px solid rgba(239,68,68,0.2)",
                      padding: 12,
                      borderRadius: 8,
                      color: "var(--color-danger)",
                      fontSize: 13,
                      display: "flex",
                      gap: 8,
                      marginBottom: 16,
                    }}
                  >
                    <AlertCircle size={16} style={{ flexShrink: 0, marginTop: 1 }} />
                    <span>{errorMsg}</span>
                  </div>
                )}

                <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 24 }}>
                  <button
                    onClick={() => setPaymentMethod("qris")}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: 16,
                      borderRadius: 10,
                      border: paymentMethod === "qris" ? "2px solid var(--brand-primary)" : "1px solid var(--bg-border)",
                      background: paymentMethod === "qris" ? "rgba(249,115,22,0.03)" : "rgba(255,255,255,0.01)",
                      color: "var(--text-primary)",
                      cursor: "pointer",
                      textAlign: "left",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                      <QrCode size={20} color={paymentMethod === "qris" ? "var(--brand-primary)" : "var(--text-muted)"} />
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 14 }}>QRIS</div>
                        <div style={{ fontSize: 11, color: "var(--text-secondary)" }}>Pay with GoPay, OVO, ShopeePay, or Banks</div>
                      </div>
                    </div>
                    {paymentMethod === "qris" && <div style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--brand-primary)" }} />}
                  </button>

                  <button
                    onClick={() => setPaymentMethod("virtual_account")}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: 16,
                      borderRadius: 10,
                      border: paymentMethod === "virtual_account" ? "2px solid var(--brand-primary)" : "1px solid var(--bg-border)",
                      background: paymentMethod === "virtual_account" ? "rgba(249,115,22,0.03)" : "rgba(255,255,255,0.01)",
                      color: "var(--text-primary)",
                      cursor: "pointer",
                      textAlign: "left",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                      <CreditCard size={20} color={paymentMethod === "virtual_account" ? "var(--brand-primary)" : "var(--text-muted)"} />
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 14 }}>Virtual Account (Bank Transfer)</div>
                        <div style={{ fontSize: 11, color: "var(--text-secondary)" }}>Virtual Account transfer via major banks</div>
                      </div>
                    </div>
                    {paymentMethod === "virtual_account" && <div style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--brand-primary)" }} />}
                  </button>
                </div>

                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    borderTop: "1px solid var(--bg-border)",
                    paddingTop: 16,
                  }}
                >
                  <div>
                    <span style={{ fontSize: 11, color: "var(--text-secondary)" }}>Total Amount</span>
                    <div style={{ fontWeight: 800, fontSize: 16, color: "var(--text-primary)" }}>
                      {formatCurrency(Number(selectedPlan.price))}
                    </div>
                  </div>
                  <button
                    onClick={handleCreateTransaction}
                    disabled={!paymentMethod || submittingCheckout}
                    className="btn btn-primary"
                    style={{ padding: "10px 20px" }}
                  >
                    {submittingCheckout ? (
                      <>
                        <Loader2 size={14} className="spinner" style={{ marginRight: 6 }} />
                        Initiating...
                      </>
                    ) : (
                      <>
                        Proceed to Pay
                        <ArrowRight size={14} style={{ marginLeft: 6 }} />
                      </>
                    )}
                  </button>
                </div>
              </div>
            )}

            {/* Step 2: Payment Simulator Screen */}
            {activeTransaction && !paymentSuccessData && (
              <div style={{ textAlign: "center" }}>
                <h3 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4, color: "var(--text-primary)" }}>
                  Complete Payment
                </h3>
                <p style={{ fontSize: 12, color: "var(--text-secondary)", marginBottom: 20 }}>
                  Transaction ID: <span style={{ fontFamily: "monospace", color: "var(--brand-primary)" }}>#{activeTransaction.id}</span>
                </p>

                {errorMsg && (
                  <div
                    style={{
                      background: "rgba(239,68,68,0.1)",
                      border: "1px solid rgba(239,68,68,0.2)",
                      padding: 12,
                      borderRadius: 8,
                      color: "var(--color-danger)",
                      fontSize: 13,
                      display: "flex",
                      gap: 8,
                      marginBottom: 16,
                      textAlign: "left",
                    }}
                  >
                    <AlertCircle size={16} style={{ flexShrink: 0, marginTop: 1 }} />
                    <span>{errorMsg}</span>
                  </div>
                )}

                {/* QRIS Output */}
                {activeTransaction.method === "qris" ? (
                  <div style={{ margin: "24px 0" }}>
                    <div
                      style={{
                        width: 180,
                        height: 180,
                        background: "white",
                        padding: 12,
                        borderRadius: 12,
                        margin: "0 auto",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        position: "relative",
                        border: "3px solid var(--brand-primary)",
                      }}
                    >
                      {/* SVG representation of a QR Code */}
                      <svg width="100%" height="100%" viewBox="0 0 100 100" style={{ shapeRendering: "crispEdges" }}>
                        <path
                          d="M0 0h30v30H0zM70 0h30v30H70zM0 70h30v30H0zM40 40h20v20H40z"
                          fill="black"
                        />
                        <path
                          d="M5 5h20v20H5zM75 5h20v20H75zM5 75h20v20H5z"
                          fill="white"
                        />
                        <path
                          d="M10 10h10v10H10zM80 10h10v10H80zM10 80h10v10H10z"
                          fill="black"
                        />
                        {/* Randomized pattern */}
                        <path
                          d="M35 5h5v5h-5zM45 15h5v5h-5zM55 5h5v10h-5zM35 20h10v5h-10zM50 25h10v5H50zM65 35h5v10h-5zM75 45h10v5H75zM85 55h5v10h-5zM40 70h10v5H40zM55 80h15v5H55zM35 90h10v5h-10zM80 75h10v5H80z"
                          fill="black"
                        />
                      </svg>
                      <div
                        style={{
                          position: "absolute",
                          inset: 0,
                          border: "1px solid rgba(249,115,22,0.3)",
                          borderRadius: 8,
                          animation: "pulse 2s infinite",
                        }}
                      />
                    </div>
                    <p style={{ fontSize: 13, fontWeight: 600, color: "var(--text-primary)" }}>
                      Scan QRIS Code with your payment app
                    </p>
                    <p style={{ fontSize: 11, color: "var(--text-secondary)", marginTop: 4 }}>
                      Pay exact amount: <strong>{formatCurrency(activeTransaction.amount)}</strong>
                    </p>
                  </div>
                ) : (
                  /* Virtual Account Output */
                  <div style={{ margin: "24px 0", background: "rgba(255,255,255,0.02)", border: "1px solid var(--bg-border)", borderRadius: 12, padding: 20 }}>
                    <div style={{ textAlign: "left", marginBottom: 12 }}>
                      <span style={{ fontSize: 10, color: "var(--text-muted)", textTransform: "uppercase" }}>Virtual Account Number</span>
                      <div
                        style={{
                          fontSize: 20,
                          fontWeight: 700,
                          fontFamily: "monospace",
                          color: "var(--brand-primary)",
                          letterSpacing: "1px",
                          marginTop: 2,
                          display: "flex",
                          justifyContent: "space-between",
                          alignItems: "center",
                        }}
                      >
                        <span>82910088910023</span>
                        <span style={{ fontSize: 10, background: "rgba(249,115,22,0.1)", padding: "2px 6px", borderRadius: 4 }}>BCA VA</span>
                      </div>
                    </div>
                    <div style={{ textAlign: "left", borderTop: "1px solid var(--bg-border)", paddingTop: 12 }}>
                      <span style={{ fontSize: 10, color: "var(--text-muted)", textTransform: "uppercase" }}>Transfer Amount</span>
                      <div style={{ fontSize: 16, fontWeight: 700, color: "var(--text-primary)" }}>
                        {formatCurrency(activeTransaction.amount)}
                      </div>
                    </div>
                  </div>
                )}

                {/* Admin Sandbox Simulator Alert */}
                <div
                  style={{
                    background: "rgba(59,130,246,0.08)",
                    border: "1px solid rgba(59,130,246,0.2)",
                    borderRadius: 10,
                    padding: 16,
                    marginBottom: 24,
                    textAlign: "left",
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 8, color: "var(--color-info)", fontWeight: 600, fontSize: 13, marginBottom: 4 }}>
                    <Lock size={14} />
                    Sandbox Simulation Mode
                  </div>
                  <p style={{ fontSize: 12, color: "var(--text-secondary)", lineHeight: 1.5 }}>
                    You are in sandbox testing. Click the button below to simulate the Payment Gateway sending a successful payment notification webhook to MangoDefend's server.
                  </p>
                </div>

                <button
                  onClick={handleSimulatePaymentSuccess}
                  disabled={simulatingPayment}
                  className="btn w-full"
                  style={{
                    width: "100%",
                    background: "var(--color-success)",
                    color: "white",
                    padding: 12,
                    fontWeight: 600,
                    justifyContent: "center",
                    boxShadow: "0 4px 14px rgba(34,197,94,0.3)",
                    border: "none",
                  }}
                >
                  {simulatingPayment ? (
                    <>
                      <Loader2 size={16} className="spinner" style={{ marginRight: 6 }} />
                      Simulating Webhook Callback...
                    </>
                  ) : (
                    <>
                      <ShieldCheck size={16} style={{ marginRight: 6 }} />
                      Simulate Payment Success
                    </>
                  )}
                </button>
              </div>
            )}

            {/* Step 3: Success Screen */}
            {paymentSuccessData && (
              <div style={{ textAlign: "center", padding: "16px 0" }}>
                <div
                  style={{
                    width: 64,
                    height: 64,
                    borderRadius: "50%",
                    background: "rgba(34,197,94,0.1)",
                    border: "2px solid var(--color-success)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    margin: "0 auto 20px",
                  }}
                >
                  <Check size={32} color="var(--color-success)" style={{ strokeWidth: 3 }} />
                </div>

                <h3 style={{ fontSize: 20, fontWeight: 800, color: "var(--text-primary)", marginBottom: 8 }}>
                  Payment Completed!
                </h3>
                <p style={{ fontSize: 13, color: "var(--text-secondary)", lineHeight: 1.5, marginBottom: 24 }}>
                  Your payment was successfully verified. Your subscription plan <strong>{selectedPlan.plan_name}</strong> is now fully active!
                </p>

                <div
                  style={{
                    background: "rgba(255,255,255,0.02)",
                    border: "1px solid var(--bg-border)",
                    borderRadius: 10,
                    padding: 16,
                    textAlign: "left",
                    fontSize: 13,
                    marginBottom: 28,
                  }}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
                    <span style={{ color: "var(--text-muted)" }}>Plan:</span>
                    <strong style={{ color: "var(--text-primary)", textTransform: "capitalize" }}>{selectedPlan.plan_name}</strong>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
                    <span style={{ color: "var(--text-muted)" }}>Amount Paid:</span>
                    <strong style={{ color: "var(--text-primary)" }}>{formatCurrency(Number(selectedPlan.price))}</strong>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between" }}>
                    <span style={{ color: "var(--text-muted)" }}>Duration:</span>
                    <strong style={{ color: "var(--text-primary)" }}>{selectedPlan.durationDays} Days</strong>
                  </div>
                </div>

                <button
                  onClick={() => setShowCheckoutModal(false)}
                  className="btn btn-outline w-full"
                  style={{ width: "100%", justifyContent: "center" }}
                >
                  Close & Return
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
