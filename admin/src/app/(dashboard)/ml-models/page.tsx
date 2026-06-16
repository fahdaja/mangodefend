"use client";

import { useState, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { mlApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import Toast from "@/components/Toast";
import {
  Cpu,
  Plus,
  CheckCircle,
  Trash2,
  X,
  Loader2,
  Check,
  Zap,
  Shield,
} from "lucide-react";
import { format } from "date-fns";
import type { MlModel } from "@/lib/types";

type ToastType = "success" | "error" | "info";
type ToastState = { message: string; type: ToastType } | null;

export default function MlModelsPage() {
  const qc = useQueryClient();
  const [toast, setToast] = useState<ToastState>(null);
  const [showCreate, setShowCreate] = useState(false);

  const showToast = useCallback(
    (message: string, type: ToastType = "success") => {
      setToast({ message, type });
    },
    [],
  );

  const { data: rawData, isLoading } = useQuery({
    queryKey: ["ml-models"],
    queryFn: () => mlApi.getAll().then((r) => r.data?.data ?? r.data),
  });

  // Memastikan data selalu menjadi array agar .map() tidak error
  const models: MlModel[] = rawData
    ? Array.isArray(rawData)
      ? rawData
      : Object.values(rawData)
    : [];

  const deleteMutation = useMutation({
    mutationFn: (id: number) => mlApi.delete(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ml-models"] });
      showToast("Model deleted successfully");
    },
    onError: () => showToast("Failed to delete model", "error"),
  });

  const activeModel = models.find((m) => m.is_active);

  return (
    <>
      <Topbar
        title="ML Models"
        subtitle="Manage machine learning model versions"
      />
      <div className="page-content">
        {/* Stats Section */}
        <div style={{ display: "flex", gap: 16, marginBottom: 24 }}>
          <div className="stat-card" style={{ flex: 1, padding: 16 }}>
            <div className="stat-icon purple">
              <Cpu size={18} />
            </div>
            <div>
              <div className="stat-value">{models.length}</div>
              <div className="stat-label">Total Models</div>
            </div>
          </div>
          <div className="stat-card" style={{ flex: 1, padding: 16 }}>
            <div className="stat-icon green">
              <Zap size={18} />
            </div>
            <div>
              <div className="stat-value">{activeModel?.version ?? "None"}</div>
              <div className="stat-label">Active Version</div>
            </div>
          </div>
          <div className="stat-card" style={{ flex: 1, padding: 16 }}>
            <div className="stat-icon blue">
              <Shield size={18} />
            </div>
            <div>
              <div className="stat-value">ONNX</div>
              <div className="stat-label">Model Format</div>
            </div>
          </div>
        </div>

        {/* Active Model Banner */}
        {activeModel && (
          <div
            className="card mb-6"
            style={{
              background:
                "linear-gradient(135deg, rgba(34,197,94,0.08) 0%, rgba(16,185,129,0.04) 100%)",
              borderColor: "rgba(34,197,94,0.2)",
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              flexWrap: "wrap",
              gap: 16,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
              <div
                style={{
                  width: 48,
                  height: 48,
                  borderRadius: 12,
                  background: "rgba(34,197,94,0.12)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <CheckCircle size={24} color="var(--color-success)" />
              </div>
              <div>
                <p
                  style={{
                    fontSize: 11,
                    color: "var(--color-success)",
                    fontWeight: 600,
                    textTransform: "uppercase",
                    letterSpacing: "0.8px",
                    marginBottom: 4,
                  }}
                >
                  Currently Active Model
                </p>
                <p
                  style={{
                    fontSize: 20,
                    fontWeight: 700,
                    color: "var(--text-primary)",
                  }}
                >
                  Version {activeModel.version}
                </p>
              </div>
            </div>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: "4px 24px",
              }}
            >
              <Detail label="Path" value={activeModel.file_path} mono />
              <Detail
                label="Deployed"
                value={format(new Date(activeModel.created_at), "dd MMM yyyy")}
              />
              <Detail
                label="Checksum (SHA256)"
                value={activeModel.checksum.slice(0, 20) + "…"}
                mono
              />
            </div>
          </div>
        )}

        {/* Models List Table */}
        <div className="card">
          <div className="card-header">
            <div>
              <p className="card-title">All Model Versions</p>
              <p className="card-subtitle">ONNX models for malware detection</p>
            </div>
            <button
              className="btn btn-primary"
              onClick={() => setShowCreate(true)}
            >
              <Plus size={15} /> Register Model
            </button>
          </div>

          {isLoading ? (
            <div className="loading-overlay">
              <div className="spinner spinner-dark" /> Loading...
            </div>
          ) : (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>Version</th>
                    <th>File Path</th>
                    <th>Checksum (SHA256)</th>
                    <th>Registered</th>
                    <th>Status</th>
                    <th style={{ textAlign: "center" }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {models.length === 0 ? (
                    <tr>
                      <td
                        colSpan={6}
                        style={{ textAlign: "center", padding: 40 }}
                      >
                        <div className="empty-state">
                          <div className="empty-state-icon">
                            <Cpu size={20} color="var(--text-muted)" />
                          </div>
                          <p>No models registered yet</p>
                          <button
                            className="btn btn-primary"
                            style={{ marginTop: 12 }}
                            onClick={() => setShowCreate(true)}
                          >
                            <Plus size={14} /> Register First Model
                          </button>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    models.map((model) => (
                      <tr key={model.id}>
                        <td>
                          <span
                            style={{
                              fontFamily: "monospace",
                              color: "var(--text-primary)",
                              fontWeight: 600,
                              fontSize: 13,
                            }}
                          >
                            v{model.version}
                          </span>
                        </td>
                        <td>
                          <span
                            style={{
                              fontFamily: "monospace",
                              fontSize: 11,
                              color: "var(--text-muted)",
                            }}
                          >
                            {model.file_path}
                          </span>
                        </td>
                        <td>
                          <span
                            title={model.checksum}
                            style={{
                              fontFamily: "monospace",
                              fontSize: 11,
                              color: "var(--text-secondary)",
                              cursor: "help",
                            }}
                          >
                            {model.checksum.slice(0, 16)}…
                          </span>
                        </td>
                        <td style={{ fontSize: 12 }}>
                          {format(new Date(model.created_at), "dd MMM yyyy")}
                        </td>
                        <td>
                          <span
                            className={`badge ${model.is_active ? "badge-success" : "badge-muted"}`}
                          >
                            {model.is_active ? "Active" : "Inactive"}
                          </span>
                        </td>
                        <td>
                          <div
                            style={{
                              display: "flex",
                              gap: 8,
                              justifyContent: "center",
                            }}
                          >
                            <button
                              className="btn btn-danger btn-sm btn-icon"
                              onClick={() => {
                                // Tetap beri konfirmasi jika model sedang aktif
                                const msg = model.is_active
                                  ? `PERINGATAN: Model v${model.version} sedang AKTIF. Jika dihapus, sistem deteksi mungkin terganggu. Lanjutkan?`
                                  : `Hapus model v${model.version}?`;
                                if (confirm(msg)) {
                                  deleteMutation.mutate(model.id);
                                }
                              }}
                              // SEKARANG HANYA DISABLED SAAT LOADING PROSES DELETE
                              disabled={deleteMutation.isPending}
                              title="Hapus data"
                              style={{ cursor: "pointer" }}
                            >
                              <Trash2 size={13} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Modal & Toast Components */}
      {showCreate && (
        <CreateModelModal
          onClose={() => setShowCreate(false)}
          onSuccess={() => {
            setShowCreate(false);
            qc.invalidateQueries({ queryKey: ["ml-models"] });
            showToast("Model registered successfully");
          }}
          onError={() => showToast("Failed to register model", "error")}
        />
      )}
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
    </>
  );
}

// --- Sub-components (Detail & Modal) ---

function Detail({
  label,
  value,
  mono,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div>
      <p
        style={{
          fontSize: 10,
          color: "var(--text-muted)",
          textTransform: "uppercase",
          letterSpacing: "0.6px",
        }}
      >
        {label}
      </p>
      <p
        style={{
          fontSize: 12,
          color: "var(--text-secondary)",
          fontFamily: mono ? "monospace" : "inherit",
        }}
      >
        {value}
      </p>
    </div>
  );
}

function CreateModelModal({
  onClose,
  onSuccess,
  onError,
}: {
  onClose: () => void;
  onSuccess: () => void;
  onError: () => void;
}) {
  const [form, setForm] = useState({
    version: "",
    file_path: "",
    checksum: "",
  });
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await mlApi.create(form);
      onSuccess();
    } catch {
      onError();
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      className="modal-overlay"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className="modal">
        <div className="modal-header">
          <h2 className="modal-title">Register ML Model</h2>
          <button className="btn btn-outline btn-icon btn-sm" onClick={onClose}>
            <X size={14} />
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Version</label>
            <input
              className="form-input"
              placeholder="e.g. 1.0.0"
              value={form.version}
              onChange={(e) => setForm({ ...form, version: e.target.value })}
              required
            />
          </div>
          <div className="form-group">
            <label className="form-label">File Path</label>
            <input
              className="form-input"
              placeholder="e.g. /models/mangodefend_v1.onnx"
              value={form.file_path}
              onChange={(e) => setForm({ ...form, file_path: e.target.value })}
              required
            />
          </div>
          <div className="form-group">
            <label className="form-label">Checksum (SHA256)</label>
            <input
              className="form-input"
              placeholder="SHA256 hash"
              value={form.checksum}
              onChange={(e) => setForm({ ...form, checksum: e.target.value })}
              required
              style={{ fontFamily: "monospace", fontSize: 12 }}
            />
          </div>
          <div className="modal-footer">
            <button type="button" className="btn btn-outline" onClick={onClose}>
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={loading}
            >
              {loading ? (
                <Loader2
                  size={15}
                  style={{ animation: "spin 0.6s linear infinite" }}
                />
              ) : (
                <Check size={15} />
              )}
              Register
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
