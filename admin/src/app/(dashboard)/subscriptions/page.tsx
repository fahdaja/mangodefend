"use client";

import { useState, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { subscriptionsApi, mlApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import Toast from "@/components/Toast";
import { Plus, CreditCard, Edit2, Trash2, X, Loader2, Check } from "lucide-react";
import { format } from "date-fns";
import type { Subscription, Plan, MlModel } from "@/lib/types";

type ToastType = "success" | "error" | "info";
type ToastState = { message: string; type: ToastType } | null;

export default function SubscriptionsPage() {
  const qc = useQueryClient();
  const [toast, setToast] = useState<ToastState>(null);
  const [tab, setTab] = useState<"subscriptions" | "plans">("subscriptions");
  const [showCreatePlan, setShowCreatePlan] = useState(false);
  const [editPlan, setEditPlan] = useState<Plan | null>(null);

  const showToast = useCallback((message: string, type: ToastType = "success") => {
    setToast({ message, type });
  }, []);

  // ─── Queries ─────────────────────────────────────────────────────────────
  const { data: subsRaw, isLoading: subsLoading } = useQuery({
    queryKey: ["subscriptions-all"],
    queryFn: () => subscriptionsApi.getAllWithUsers().then((r) => r.data?.data ?? r.data),
  });

  const { data: plansRaw, isLoading: plansLoading } = useQuery({
    queryKey: ["plans"],
    queryFn: () => subscriptionsApi.getPlans().then((r) => r.data?.data ?? r.data),
  });

  const { data: mlRaw } = useQuery({
    queryKey: ["ml-models"],
    queryFn: () => mlApi.getAll().then((r) => r.data?.data ?? r.data),
  });

  const subscriptions: Subscription[] = Array.isArray(subsRaw) ? subsRaw : [];
  const plans: Plan[] = Array.isArray(plansRaw) ? plansRaw : [];
  const mlModels: MlModel[] = Array.isArray(mlRaw) ? mlRaw : [];

  // ─── Mutations ─────────────────────────────────────────────────────────────
  const deletePlanMutation = useMutation({
    mutationFn: (id: number) => subscriptionsApi.deletePlan(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["plans"] });
      showToast("Plan deleted successfully");
    },
    onError: () => showToast("Failed to delete plan", "error"),
  });

  const formatCurrency = (val: number) =>
    new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(val);

  const activeCount = subscriptions.filter((s) => s.is_active).length;
  const expiredCount = subscriptions.filter((s) => !s.is_active).length;

  return (
    <>
      <Topbar title="Subscriptions" subtitle="Manage plans and user subscriptions" />
      <div className="page-content">
        {/* Stats */}
        <div style={{ display: "flex", gap: 16, marginBottom: 24 }}>
          {[
            { label: "Total", value: subscriptions.length, cls: "blue" },
            { label: "Active", value: activeCount, cls: "green" },
            { label: "Expired", value: expiredCount, cls: "red" },
            { label: "Plans", value: plans.length, cls: "orange" },
          ].map((s) => (
            <div key={s.label} className="stat-card" style={{ flex: 1, padding: 16 }}>
              <div className={`stat-icon ${s.cls}`}><CreditCard size={18} /></div>
              <div>
                <div className="stat-value">{s.value}</div>
                <div className="stat-label">{s.label}</div>
              </div>
            </div>
          ))}
        </div>

        {/* Tabs */}
        <div style={{ display: "flex", gap: 4, marginBottom: 20, background: "var(--bg-surface)", borderRadius: 10, padding: 4, width: "fit-content", border: "1px solid var(--bg-border)" }}>
          {(["subscriptions", "plans"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              style={{
                padding: "7px 20px",
                borderRadius: 7,
                border: "none",
                cursor: "pointer",
                fontSize: 13,
                fontWeight: 600,
                fontFamily: "Inter, sans-serif",
                background: tab === t ? "var(--bg-card)" : "transparent",
                color: tab === t ? "var(--text-primary)" : "var(--text-muted)",
                transition: "all 0.15s",
              }}
            >
              {t === "subscriptions" ? "Subscriptions" : "Plans"}
            </button>
          ))}
        </div>

        {/* ─── Subscriptions Tab ─────────────────────────────────────────────── */}
        {tab === "subscriptions" && (
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">All Subscriptions</p>
                <p className="card-subtitle">User subscription records</p>
              </div>
            </div>
            {subsLoading ? (
              <div className="loading-overlay"><div className="spinner spinner-dark" /> Loading...</div>
            ) : (
              <div className="table-wrapper">
                <table>
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>User</th>
                      <th>Plan</th>
                      <th>ML Model</th>
                      <th>Start Date</th>
                      <th>End Date</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {subscriptions.length === 0 ? (
                      <tr>
                        <td colSpan={7} style={{ textAlign: "center", padding: 40 }}>
                          <p style={{ color: "var(--text-muted)", fontSize: 13 }}>No subscriptions found</p>
                        </td>
                      </tr>
                    ) : (
                      subscriptions.map((s) => (
                        <tr key={s.id}>
                          <td style={{ fontFamily: "monospace", fontSize: 12 }}>#{s.id}</td>
                          <td>
                            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                              <div className="avatar" style={{ width: 26, height: 26, fontSize: 10 }}>
                                {s.user?.email?.[0]?.toUpperCase() ?? "?"}
                              </div>
                              <span style={{ fontSize: 12, color: "var(--text-primary)", maxWidth: 140, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                                {s.user?.email ?? `User #${s.user_id}`}
                              </span>
                            </div>
                          </td>
                          <td>
                            <span className={`badge ${
                              s.plan?.plan_name === "bussiness" ? "badge-purple" :
                              s.plan?.plan_name === "pro" ? "badge-orange" : "badge-muted"
                            }`}>
                              {s.plan?.plan_name ?? `Plan #${s.plan_id}`}
                            </span>
                          </td>
                          <td style={{ fontSize: 12, color: "var(--text-muted)" }}>
                            {s.plan?.model?.version ?? "—"}
                          </td>
                          <td style={{ fontSize: 12 }}>{format(new Date(s.start_date), "dd MMM yyyy")}</td>
                          <td style={{ fontSize: 12 }}>
                            <span style={{ color: new Date(s.end_date) < new Date() ? "var(--color-danger)" : "var(--text-secondary)" }}>
                              {format(new Date(s.end_date), "dd MMM yyyy")}
                            </span>
                          </td>
                          <td>
                            <span className={`badge ${
                              s.status === "active" ? "badge-success" :
                              s.status === "replaced" ? "badge-info" :
                              s.status === "cancelled" ? "badge-danger" : "badge-muted"
                            }`}>
                              {s.status ? s.status.charAt(0).toUpperCase() + s.status.slice(1) : (s.is_active ? "Active" : "Expired")}
                            </span>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* ─── Plans Tab ──────────────────────────────────────────────────────── */}
        {tab === "plans" && (
          <div>
            <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: 16 }}>
              <button className="btn btn-primary" onClick={() => setShowCreatePlan(true)}>
                <Plus size={15} /> Create Plan
              </button>
            </div>
            {plansLoading ? (
              <div className="loading-overlay"><div className="spinner spinner-dark" /> Loading...</div>
            ) : (
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: 16 }}>
                {plans.map((plan) => (
                  <PlanCard
                    key={plan.id}
                    plan={plan}
                    formatCurrency={formatCurrency}
                    onEdit={() => setEditPlan(plan)}
                    onDelete={() => deletePlanMutation.mutate(plan.id)}
                  />
                ))}
                {plans.length === 0 && (
                  <div className="empty-state" style={{ gridColumn: "1/-1" }}>
                    <div className="empty-state-icon">
                      <CreditCard size={20} color="var(--text-muted)" />
                    </div>
                    <p>No plans created yet</p>
                    <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => setShowCreatePlan(true)}>
                      <Plus size={14} /> Create First Plan
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Modals */}
      {showCreatePlan && (
        <PlanModal
          mlModels={mlModels}
          onClose={() => setShowCreatePlan(false)}
          onSuccess={() => {
            setShowCreatePlan(false);
            qc.invalidateQueries({ queryKey: ["plans"] });
            showToast("Plan created successfully");
          }}
          onError={() => showToast("Failed to create plan", "error")}
        />
      )}

      {editPlan && (
        <PlanModal
          mlModels={mlModels}
          plan={editPlan}
          onClose={() => setEditPlan(null)}
          onSuccess={() => {
            setEditPlan(null);
            qc.invalidateQueries({ queryKey: ["plans"] });
            showToast("Plan updated successfully");
          }}
          onError={() => showToast("Failed to update plan", "error")}
        />
      )}

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </>
  );
}

// ─── Plan Card ────────────────────────────────────────────────────────────────
function PlanCard({
  plan,
  formatCurrency,
  onEdit,
  onDelete,
}: {
  plan: Plan;
  formatCurrency: (v: number) => string;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const colorMap: Record<string, string> = {
    free: "var(--text-muted)",
    pro: "var(--brand-primary)",
    bussiness: "#a855f7",
  };

  return (
    <div className="card" style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <span
          className="badge"
          style={{
            background: `${colorMap[plan.plan_name]}1a`,
            color: colorMap[plan.plan_name],
            border: `1px solid ${colorMap[plan.plan_name]}33`,
          }}
        >
          {plan.plan_name}
        </span>
        <div style={{ display: "flex", gap: 6 }}>
          <button className="btn btn-outline btn-sm btn-icon" onClick={onEdit} title="Edit plan">
            <Edit2 size={13} />
          </button>
          <button className="btn btn-danger btn-sm btn-icon" onClick={onDelete} title="Delete plan">
            <Trash2 size={13} />
          </button>
        </div>
      </div>
      <div>
        <p style={{ fontSize: 26, fontWeight: 800, color: "var(--text-primary)", letterSpacing: "-0.5px" }}>
          {formatCurrency(Number(plan.price))}
        </p>
        <p style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 2 }}>per {plan.durationDays} days</p>
      </div>
      <p style={{ fontSize: 13, color: "var(--text-secondary)", lineHeight: 1.5 }}>
        {plan.description}
      </p>

      <div style={{ display: "flex", flexDirection: "column", gap: 6, fontSize: 12, background: "var(--bg-surface)", borderRadius: 8, padding: "8px 12px" }}>
        <div>
          <span style={{ color: "var(--text-muted)" }}>Upload File Limit: </span>
          <span style={{ color: "var(--text-primary)", fontWeight: 500 }}>
            {plan.upload_file_limit === -1 ? "Unlimited" : `${plan.upload_file_limit} scans/day`}
          </span>
        </div>
        <div>
          <span style={{ color: "var(--text-muted)" }}>Full Scan Limit: </span>
          <span style={{ color: "var(--text-primary)", fontWeight: 500 }}>
            {plan.full_scan_limit === -1 ? "Unlimited" : `${plan.full_scan_limit} scans/day`}
          </span>
        </div>
        {plan.model && (
          <div>
            <span style={{ color: "var(--text-muted)" }}>ML Model: </span>
            <span style={{ color: "var(--color-info)", fontWeight: 500 }}>v{plan.model.version}</span>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Plan Modal ───────────────────────────────────────────────────────────────
function PlanModal({
  plan,
  mlModels,
  onClose,
  onSuccess,
  onError,
}: {
  plan?: Plan;
  mlModels: MlModel[];
  onClose: () => void;
  onSuccess: () => void;
  onError: () => void;
}) {
  const isEdit = !!plan;
  const [form, setForm] = useState({
    plan_name: plan?.plan_name ?? "free",
    description: plan?.description ?? "",
    price: plan?.price?.toString() ?? "",
    durationDays: plan?.durationDays?.toString() ?? "",
    model_id: plan?.model_id?.toString() ?? "",
    upload_file_limit: plan?.upload_file_limit?.toString() ?? "0",
    full_scan_limit: plan?.full_scan_limit?.toString() ?? "0",
  });
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const payload = {
        plan_name: form.plan_name,
        description: form.description,
        price: Number(form.price),
        durationDays: Number(form.durationDays),
        model_id: form.model_id ? Number(form.model_id) : null,
        upload_file_limit: Number(form.upload_file_limit),
        full_scan_limit: Number(form.full_scan_limit),
      };
      if (isEdit) {
        await subscriptionsApi.updatePlan(plan!.id, payload);
      } else {
        await subscriptionsApi.createPlan(payload);
      }
      onSuccess();
    } catch {
      onError();
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header">
          <h2 className="modal-title">{isEdit ? "Edit Plan" : "Create Plan"}</h2>
          <button className="btn btn-outline btn-icon btn-sm" onClick={onClose}><X size={14} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Plan Type</label>
            <select
              id="plan-name-select"
              className="form-select"
              value={form.plan_name}
              onChange={(e) => setForm({ ...form, plan_name: e.target.value as import("@/lib/types").PlanType })}
              required
            >
              <option value="free">FREE</option>
              <option value="pro">PRO</option>
              <option value="bussiness">BUSSINESS</option>
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Description</label>
            <textarea
              id="plan-description"
              className="form-input"
              placeholder="Plan description..."
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              required
            />
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div className="form-group">
              <label className="form-label">Price (IDR)</label>
              <input
                id="plan-price"
                type="number"
                className="form-input"
                placeholder="99000"
                value={form.price}
                onChange={(e) => setForm({ ...form, price: e.target.value })}
                required
              />
            </div>
            <div className="form-group">
              <label className="form-label">Duration (days)</label>
              <input
                id="plan-duration"
                type="number"
                className="form-input"
                placeholder="30"
                value={form.durationDays}
                onChange={(e) => setForm({ ...form, durationDays: e.target.value })}
                required
              />
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div className="form-group">
              <label className="form-label">Upload File Limit (Daily)</label>
              <input
                id="plan-upload-limit"
                type="number"
                className="form-input"
                placeholder="5"
                value={form.upload_file_limit}
                onChange={(e) => setForm({ ...form, upload_file_limit: e.target.value })}
                required
              />
              <span style={{ fontSize: 10, color: "var(--text-muted)", marginTop: 2 }}>Use -1 for unlimited</span>
            </div>
            <div className="form-group">
              <label className="form-label">Full Scan Limit (Daily)</label>
              <input
                id="plan-full-limit"
                type="number"
                className="form-input"
                placeholder="0"
                value={form.full_scan_limit}
                onChange={(e) => setForm({ ...form, full_scan_limit: e.target.value })}
                required
              />
              <span style={{ fontSize: 10, color: "var(--text-muted)", marginTop: 2 }}>Use -1 for unlimited</span>
            </div>
          </div>
          <div className="form-group">
            <label className="form-label">ML Model (optional)</label>
            <select
              id="plan-model-select"
              className="form-select"
              value={form.model_id}
              onChange={(e) => setForm({ ...form, model_id: e.target.value })}
            >
              <option value="">— No Model —</option>
              {mlModels.map((m) => (
                <option key={m.id} value={m.id}>
                  v{m.version} {m.is_active ? "(active)" : ""}
                </option>
              ))}
            </select>
          </div>
          <div className="modal-footer">
            <button type="button" className="btn btn-outline" onClick={onClose}>Cancel</button>
            <button id="plan-submit" type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? <Loader2 size={15} style={{ animation: "spin 0.6s linear infinite" }} /> : <Check size={15} />}
              {isEdit ? "Save Changes" : "Create Plan"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
