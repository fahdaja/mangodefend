"use client";

import { useState, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { transactionsApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import Toast from "@/components/Toast";
import { ArrowLeftRight, CheckCircle, Clock, XCircle, Search, PlayCircle } from "lucide-react";
import { format } from "date-fns";
import type { Transaction } from "@/lib/types";

type ToastType = "success" | "error" | "info";
type ToastState = { message: string; type: ToastType } | null;

export default function TransactionsPage() {
  const qc = useQueryClient();
  const [toast, setToast] = useState<ToastState>(null);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");

  const showToast = useCallback((message: string, type: ToastType = "success") => {
    setToast({ message, type });
  }, []);

  const { data: rawData, isLoading } = useQuery({
    queryKey: ["transactions"],
    queryFn: () => transactionsApi.getAll().then((r) => r.data?.data ?? r.data),
  });

  const transactions: Transaction[] = Array.isArray(rawData) ? rawData : [];

  const simulateWebhookMutation = useMutation({
    mutationFn: ({ id, status }: { id: number; status: "settlement" | "expire" | "failure" }) =>
      transactionsApi.simulateWebhook(id, status),
    onSuccess: (_, variables) => {
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["subscriptions-all"] });
      
      const msgMap = {
        settlement: "Payment simulated successfully — subscription activated & email receipt sent!",
        failure: "Transaction marked as FAILED.",
        expire: "Transaction marked as EXPIRED.",
      };
      showToast(msgMap[variables.status], "success");
    },
    onError: () => showToast("Failed to simulate webhook status update", "error"),
  });

  const filtered = transactions.filter((t) => {
    const matchStatus = statusFilter === "all" || t.status.toLowerCase() === statusFilter.toLowerCase();
    const matchSearch =
      !search ||
      t.id.toString().includes(search) ||
      t.user_id.toString().includes(search) ||
      t.user?.email?.toLowerCase().includes(search.toLowerCase()) ||
      t.plan?.plan_name?.toLowerCase().includes(search.toLowerCase()) ||
      t.external_id?.toLowerCase().includes(search.toLowerCase());
    return matchStatus && matchSearch;
  });

  const totalRevenue = transactions
    .filter((t) => t.status === "SUCCESS")
    .reduce((acc, t) => acc + Number(t.amount), 0);

  const formatCurrency = (val: number) =>
    new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(val);

  const statusCounts = {
    all: transactions.length,
    pending: transactions.filter((t) => t.status === "PENDING").length,
    success: transactions.filter((t) => t.status === "SUCCESS").length,
    failed: transactions.filter((t) => t.status === "FAILED").length,
    expired: transactions.filter((t) => t.status === "EXPIRED").length,
  };

  const statusBadge = (status: string) => {
    const cfg: Record<string, { cls: string; icon: React.ReactNode }> = {
      success: { cls: "badge-success", icon: <CheckCircle size={10} /> },
      pending: { cls: "badge-warning", icon: <Clock size={10} /> },
      failed: { cls: "badge-danger", icon: <XCircle size={10} /> },
      expired: { cls: "badge-muted", icon: <Clock size={10} /> },
    };
    const c = cfg[status.toLowerCase()] ?? { cls: "badge-muted", icon: null };
    return (
      <span className={`badge ${c.cls}`}>
        {c.icon} {status}
      </span>
    );
  };

  return (
    <>
      <Topbar title="Transactions" subtitle="Payment records and webhook simulation" />
      <div className="page-content">
        {/* Stats */}
        <div style={{ display: "flex", gap: 16, marginBottom: 24 }}>
          <div className="stat-card" style={{ flex: 1.5, padding: 16 }}>
            <div className="stat-icon green"><ArrowLeftRight size={18} /></div>
            <div>
              <div className="stat-value">{formatCurrency(totalRevenue)}</div>
              <div className="stat-label">Total Revenue (Success)</div>
            </div>
          </div>
          {[
            { label: "Pending", count: statusCounts.pending, cls: "orange", icon: <Clock size={18} /> },
            { label: "Success", count: statusCounts.success, cls: "green", icon: <CheckCircle size={18} /> },
            { label: "Failed", count: statusCounts.failed, cls: "red", icon: <XCircle size={18} /> },
            { label: "Expired", count: statusCounts.expired, cls: "gray", icon: <Clock size={18} /> },
          ].map((s) => (
            <div key={s.label} className="stat-card" style={{ flex: 1, padding: 16 }}>
              <div className={`stat-icon ${s.cls}`}>{s.icon}</div>
              <div>
                <div className="stat-value">{s.count}</div>
                <div className="stat-label">{s.label}</div>
              </div>
            </div>
          ))}
        </div>

        {/* Table */}
        <div className="card">
          <div className="card-header" style={{ flexWrap: "wrap", gap: 12 }}>
            <div>
              <p className="card-title">All Transactions</p>
              <p className="card-subtitle">{filtered.length} records</p>
            </div>
            <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
              {/* Status filter */}
              <div style={{ display: "flex", gap: 4, background: "var(--bg-surface)", padding: 3, borderRadius: 8, border: "1px solid var(--bg-border)" }}>
                {(["all", "pending", "success", "failed", "expired"] as const).map((s) => (
                  <button
                    key={s}
                    onClick={() => setStatusFilter(s)}
                    style={{
                      padding: "5px 12px",
                      borderRadius: 6,
                      border: "none",
                      cursor: "pointer",
                      fontSize: 12,
                      fontWeight: 600,
                      fontFamily: "Inter, sans-serif",
                      background: statusFilter === s ? "var(--bg-card)" : "transparent",
                      color: statusFilter === s ? "var(--text-primary)" : "var(--text-muted)",
                      transition: "all 0.15s",
                    }}
                  >
                    {s.charAt(0).toUpperCase() + s.slice(1)} ({statusCounts[s]})
                  </button>
                ))}
              </div>
              <div className="search-bar" style={{ width: 220 }}>
                <Search size={14} color="var(--text-muted)" />
                <input
                  placeholder="Search by ID or user..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </div>
            </div>
          </div>

          {isLoading ? (
            <div className="loading-overlay"><div className="spinner spinner-dark" /> Loading...</div>
          ) : (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>User</th>
                    <th>Plan</th>
                    <th>External ID</th>
                    <th>Amount</th>
                    <th>Method</th>
                    <th>Status</th>
                    <th>Date</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.length === 0 ? (
                    <tr>
                      <td colSpan={9} style={{ textAlign: "center", padding: 40 }}>
                        <p style={{ color: "var(--text-muted)", fontSize: 13 }}>No transactions found</p>
                      </td>
                    </tr>
                  ) : (
                    filtered.map((tx) => (
                      <tr key={tx.id}>
                        <td style={{ fontFamily: "monospace", fontSize: 12, color: "var(--text-primary)" }}>
                          #{tx.id}
                        </td>
                        <td>
                          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                            <div className="avatar" style={{ width: 26, height: 26, fontSize: 10 }}>
                              {tx.user?.email?.[0]?.toUpperCase() ?? "?"}
                            </div>
                            <span style={{ fontSize: 12, color: "var(--text-primary)", maxWidth: 140, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                              {tx.user?.email ?? `User #${tx.user_id}`}
                            </span>
                          </div>
                        </td>
                        <td>
                          <span className={`badge ${
                            tx.plan?.plan_name === "bussiness" ? "badge-purple" :
                            tx.plan?.plan_name === "pro" ? "badge-orange" : "badge-muted"
                          }`}>
                            {tx.plan?.plan_name ?? `Plan #${tx.plan_id}`}
                          </span>
                        </td>
                        <td style={{ fontSize: 11, fontFamily: "monospace", color: "var(--text-muted)", maxWidth: 140, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                          {tx.external_id ?? "—"}
                        </td>
                        <td style={{ color: "var(--text-primary)", fontWeight: 600, fontSize: 13 }}>
                          {formatCurrency(Number(tx.amount))}
                        </td>
                        <td>
                          {tx.method ? (
                            <span className="badge badge-info">{tx.method.replace("_", " ")}</span>
                          ) : (
                            <span style={{ color: "var(--text-muted)", fontSize: 12 }}>—</span>
                          )}
                        </td>
                        <td>{statusBadge(tx.status)}</td>
                        <td style={{ fontSize: 12 }}>
                          {format(new Date(tx.created_at), "dd MMM yyyy, HH:mm")}
                        </td>
                        <td>
                          {tx.status === "PENDING" && (
                            <div style={{ display: "flex", gap: 6 }}>
                              <button
                                className="btn btn-success btn-sm"
                                onClick={() => simulateWebhookMutation.mutate({ id: tx.id, status: "settlement" })}
                                disabled={simulateWebhookMutation.isPending}
                                title="Simulate payment success"
                                style={{ padding: "4px 8px", fontSize: 11 }}
                              >
                                <PlayCircle size={12} />
                                Pay
                              </button>
                              <button
                                className="btn btn-danger btn-sm"
                                onClick={() => simulateWebhookMutation.mutate({ id: tx.id, status: "failure" })}
                                disabled={simulateWebhookMutation.isPending}
                                title="Simulate payment failure"
                                style={{ padding: "4px 8px", fontSize: 11 }}
                              >
                                <XCircle size={12} />
                                Fail
                              </button>
                              <button
                                className="btn btn-muted btn-sm"
                                onClick={() => simulateWebhookMutation.mutate({ id: tx.id, status: "expire" })}
                                disabled={simulateWebhookMutation.isPending}
                                title="Simulate payment expiry"
                                style={{ padding: "4px 8px", fontSize: 11, background: "var(--bg-border)", color: "var(--text-muted)" }}
                              >
                                <Clock size={12} />
                                Expire
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Info box */}
        <div
          style={{
            marginTop: 16,
            background: "rgba(59,130,246,0.06)",
            border: "1px solid rgba(59,130,246,0.15)",
            borderRadius: 10,
            padding: "12px 16px",
            fontSize: 12,
            color: "var(--color-info)",
            display: "flex",
            alignItems: "center",
            gap: 10,
          }}
        >
          <PlayCircle size={16} />
          <span>
            <strong>Simulate</strong> buttons trigger the unified webhook endpoint{" "}
            <code style={{ background: "rgba(59,130,246,0.1)", padding: "1px 6px", borderRadius: 4 }}>
              POST /transactions/webhook
            </code>{" "}
            sending custom statuses to mock the entire payment cycle (Pay, Fail, Expire).
          </span>
        </div>
      </div>

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </>
  );
}
