"use client";

import { useState, useRef, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { mlApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import {
  Activity,
  CheckCircle2,
  XCircle,
  ShieldAlert,
  Database,
  Search,
  HardDrive,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Server,
  Cpu,
  Terminal,
} from "lucide-react";
import { format, parseISO } from "date-fns";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
} from "recharts";

export default function MlMonitoringPage() {
  const [search, setSearch] = useState("");
  const [labelFilter, setLabelFilter] = useState("");
  const [page, setPage] = useState(1);
  const limit = 10;

  const [daysRange, setDaysRange] = useState(7);

  // Terminal console ref for system logs
  const consoleRef = useRef<HTMLDivElement>(null);

  // 1. Apps API Server Health (Auto-refreshes every 5 seconds)
  const {
    data: appsHealthData,
    refetch: refetchAppsHealth,
    isRefetching: isRefetchingAppsHealth,
  } = useQuery({
    queryKey: ["apps-server-health"],
    queryFn: () =>
      mlApi
        .getAppsHealth()
        .then((r) => r.data)
        .catch(() => ({ status: "offline", service: "MangoDefend Apps API" })),
    refetchInterval: 5000,
  });

  // 2. ML Server Health (Auto-refreshes every 5 seconds)
  const {
    data: mlHealthData,
    refetch: refetchMlHealth,
    isRefetching: isRefetchingMlHealth,
  } = useQuery({
    queryKey: ["ml-server-health"],
    queryFn: () =>
      mlApi
        .getServerHealth()
        .then((r) => r.data)
        .catch(() => ({ status: "offline", service: "MangoDefend ML API" })),
    refetchInterval: 5000,
  });

  // 3. ML Stats Query (Auto-refreshes every 10 seconds)
  const { data: statsData, refetch: refetchStats } = useQuery({
    queryKey: ["ml-server-stats", daysRange],
    queryFn: () =>
      mlApi
        .getServerStats(daysRange)
        .then((r) => r.data)
        .catch(() => null),
    refetchInterval: 10000,
  });

  // 4. ML Logs Query (Depends on page, search, filter)
  const {
    data: logsData,
    isLoading: isLoadingLogs,
    refetch: refetchLogs,
  } = useQuery({
    queryKey: ["ml-server-logs", page, search, labelFilter],
    queryFn: () =>
      mlApi
        .getServerLogs(
          page,
          limit,
          search || undefined,
          labelFilter || undefined,
        )
        .then((r) => r.data)
        .catch(() => null),
  });

  // 5. System Logs Query (Auto-refreshes every 5 seconds)
  const {
    data: systemLogsData,
    refetch: refetchSystemLogs,
    isRefetching: isRefetchingSystemLogs,
  } = useQuery({
    queryKey: ["ml-system-logs"],
    queryFn: () =>
      mlApi
        .getSystemLogs(100)
        .then((r) => r.data)
        .catch(() => null),
    refetchInterval: 5000,
  });

  const isAppsOnline = appsHealthData?.status === "ok" || !!appsHealthData;
  const isMlOnline = mlHealthData?.status === "ok";
  const isAnyRefetching =
    isRefetchingAppsHealth || isRefetchingMlHealth || isRefetchingSystemLogs;

  const totalScans = statsData?.total_scans ?? 0;
  const malwareCount = statsData?.malware_count ?? 0;
  const benignCount = statsData?.benign_count ?? 0;
  const totalSizeBytes = statsData?.total_size_bytes ?? 0;
  const malwarePercentage = statsData?.malware_percentage ?? 0;
  const recentActivity = statsData?.recent_activity ?? [];

  const logs = logsData?.logs ?? [];
  const totalLogs = logsData?.total ?? 0;
  const totalPages = logsData?.pages ?? 1;
  const systemLogs = systemLogsData?.logs ?? [];

  // Scroll terminal logs to bottom on update
  useEffect(() => {
    if (consoleRef.current) {
      consoleRef.current.scrollTop = consoleRef.current.scrollHeight;
    }
  }, [systemLogs]);

  // Manual Refresh Handler
  const handleRefreshAll = () => {
    refetchAppsHealth();
    refetchMlHealth();
    refetchStats();
    refetchLogs();
    refetchSystemLogs();
  };

  // Format File Size
  const formatBytes = (bytes: number, decimals = 2) => {
    if (bytes === 0) return "0 Bytes";
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
  };

  return (
    <>
      <Topbar
        title="ML Monitoring"
        subtitle="Live connection state and statistics for both core API and ML detection servers"
      />
      <div className="page-content">
        {/* ─── Header Action Row ──────────────────────────────────────────── */}
        <div
          style={{
            display: "flex",
            justifyContent: "flex-end",
            marginBottom: 20,
          }}
        >
          <button
            onClick={handleRefreshAll}
            className="btn btn-outline btn-sm"
            disabled={isAnyRefetching}
            style={{ display: "flex", alignItems: "center", gap: 8 }}
          >
            <RefreshCw
              size={14}
              className={isAnyRefetching ? "spinner" : ""}
              style={{
                animation: isAnyRefetching ? "spin 1s linear infinite" : "none",
              }}
            />
            Refresh All Monitors
          </button>
        </div>

        {/* ─── Server Status Grid (Side-by-Side) ─────────────────────────── */}
        <div className="grid-2 mb-6">
          {/* Card 1: Apps API Server (NestJS) */}
          <div
            className="card"
            style={{
              background: isAppsOnline
                ? "linear-gradient(135deg, rgba(59,130,246,0.06) 0%, rgba(37,99,235,0.03) 100%)"
                : "linear-gradient(135deg, rgba(239,68,68,0.08) 0%, rgba(220,38,38,0.04) 100%)",
              borderColor: isAppsOnline
                ? "rgba(59,130,246,0.2)"
                : "rgba(239,68,68,0.2)",
              display: "flex",
              flexDirection: "column",
              gap: 16,
              justifyContent: "space-between",
            }}
          >
            <div
              style={{
                display: "flex",
                alignItems: "flex-start",
                justifyContent: "space-between",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
                <div
                  style={{
                    width: 44,
                    height: 44,
                    borderRadius: 10,
                    background: isAppsOnline
                      ? "rgba(59,130,246,0.12)"
                      : "rgba(239,68,68,0.12)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Server
                    size={22}
                    color={
                      isAppsOnline ? "var(--color-info)" : "var(--color-danger)"
                    }
                  />
                </div>
                <div>
                  <h3
                    style={{
                      fontSize: 16,
                      fontWeight: 700,
                      color: "var(--text-primary)",
                    }}
                  >
                    MangoDefend Apps API
                  </h3>
                  <p
                    style={{
                      fontSize: 11,
                      fontFamily: "monospace",
                      color: "var(--text-muted)",
                      marginTop: 2,
                    }}
                  >
                    NestJS Backend Server
                  </p>
                </div>
              </div>
              <span
                className={`badge ${isAppsOnline ? "badge-info" : "badge-danger"}`}
                style={{ textTransform: "uppercase", fontSize: 10 }}
              >
                {isAppsOnline ? "Online" : "Offline"}
              </span>
            </div>

            <div
              style={{
                borderTop: "1px solid var(--bg-border)",
                paddingTop: 12,
                display: "flex",
                justifyContent: "space-between",
                fontSize: 12,
              }}
            >
              <div>
                <p
                  style={{
                    color: "var(--text-muted)",
                    fontSize: 10,
                    textTransform: "uppercase",
                    marginBottom: 2,
                  }}
                >
                  Endpoint URL
                </p>
                <p
                  style={{
                    color: "var(--text-secondary)",
                    fontFamily: "monospace",
                  }}
                >
                  http://localhost:4000
                </p>
              </div>
              <div style={{ textAlign: "right" }}>
                <p
                  style={{
                    color: "var(--text-muted)",
                    fontSize: 10,
                    textTransform: "uppercase",
                    marginBottom: 2,
                  }}
                >
                  Database Status
                </p>
                <p
                  style={{
                    color: isAppsOnline
                      ? "var(--color-success)"
                      : "var(--color-danger)",
                    fontWeight: 500,
                  }}
                >
                  {isAppsOnline ? "Connected" : "Disconnected"}
                </p>
              </div>
            </div>
          </div>

          {/* Card 2: ML Detection Server (FastAPI) */}
          <div
            className="card"
            style={{
              background: isMlOnline
                ? "linear-gradient(135deg, rgba(34,197,94,0.06) 0%, rgba(16,185,129,0.03) 100%)"
                : "linear-gradient(135deg, rgba(239,68,68,0.08) 0%, rgba(220,38,38,0.04) 100%)",
              borderColor: isMlOnline
                ? "rgba(34,197,94,0.2)"
                : "rgba(239,68,68,0.2)",
              display: "flex",
              flexDirection: "column",
              gap: 16,
              justifyContent: "space-between",
            }}
          >
            <div
              style={{
                display: "flex",
                alignItems: "flex-start",
                justifyContent: "space-between",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
                <div
                  style={{
                    width: 44,
                    height: 44,
                    borderRadius: 10,
                    background: isMlOnline
                      ? "rgba(34,197,94,0.12)"
                      : "rgba(239,68,68,0.12)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Cpu
                    size={22}
                    color={
                      isMlOnline
                        ? "var(--color-success)"
                        : "var(--color-danger)"
                    }
                  />
                </div>
                <div>
                  <h3
                    style={{
                      fontSize: 16,
                      fontWeight: 700,
                      color: "var(--text-primary)",
                    }}
                  >
                    {mlHealthData?.service ?? "MangoDefend ML API"}
                  </h3>
                  <p
                    style={{
                      fontSize: 11,
                      fontFamily: "monospace",
                      color: "var(--text-muted)",
                      marginTop: 2,
                    }}
                  >
                    FastAPI AI/ONNX Model Server
                  </p>
                </div>
              </div>
              <span
                className={`badge ${isMlOnline ? "badge-success" : "badge-danger"}`}
                style={{ textTransform: "uppercase", fontSize: 10 }}
              >
                {isMlOnline ? "Online" : "Offline"}
              </span>
            </div>

            <div
              style={{
                borderTop: "1px solid var(--bg-border)",
                paddingTop: 12,
                display: "flex",
                justifyContent: "space-between",
                fontSize: 12,
              }}
            >
              <div>
                <p
                  style={{
                    color: "var(--text-muted)",
                    fontSize: 10,
                    textTransform: "uppercase",
                    marginBottom: 2,
                  }}
                >
                  Endpoint URL
                </p>
                <p
                  style={{
                    color: "var(--text-secondary)",
                    fontFamily: "monospace",
                  }}
                >
                  http://localhost:8000
                </p>
              </div>
              <div style={{ textAlign: "right" }}>
                <p
                  style={{
                    color: "var(--text-muted)",
                    fontSize: 10,
                    textTransform: "uppercase",
                    marginBottom: 2,
                  }}
                >
                  Core Engine
                </p>
                <p style={{ color: "var(--text-secondary)", fontWeight: 500 }}>
                  {isMlOnline ? "ONNX Runtime" : "-"}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* ─── Stats Grid ─────────────────────────────────────────────────── */}
        <div className="stats-grid mb-6">
          <div className="stat-card">
            <div className="stat-icon blue">
              <Activity size={20} />
            </div>
            <div>
              <div className="stat-value">{totalScans}</div>
              <div className="stat-label">Total Files Scanned</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon red">
              <ShieldAlert size={20} />
            </div>
            <div>
              <div
                className="stat-value"
                style={{ color: "var(--color-danger)" }}
              >
                {malwareCount}
              </div>
              <div className="stat-label">
                Malware Detected ({malwarePercentage}%)
              </div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon green">
              <CheckCircle2 size={20} />
            </div>
            <div>
              <div
                className="stat-value"
                style={{ color: "var(--color-success)" }}
              >
                {benignCount}
              </div>
              <div className="stat-label">
                Benign Files ({(100 - malwarePercentage).toFixed(1)}%)
              </div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon purple">
              <HardDrive size={20} />
            </div>
            <div>
              <div className="stat-value">{formatBytes(totalSizeBytes)}</div>
              <div className="stat-label">Total Data Processed</div>
            </div>
          </div>
        </div>

        {/* ─── Analytics Row (Charts) ─────────────────────────────────────── */}
        <div className="grid-2 mb-6">
          {/* Area Chart: Scanning Activity Trend */}
          <div className="card">
            <div
              className="card-header"
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}
            >
              <div>
                <p className="card-title">Scanning Activity Trend</p>
                <p className="card-subtitle">
                  Daily distribution of malware vs benign scan requests
                </p>
              </div>
              <div>
                <select
                  className="form-select"
                  style={{ width: 130, padding: "6px 12px", fontSize: 12 }}
                  value={daysRange}
                  onChange={(e) => setDaysRange(Number(e.target.value))}
                >
                  <option value={7}>Last 7 Days</option>
                  <option value={30}>Last 30 Days</option>
                  <option value={90}>Last 90 Days</option>
                </select>
              </div>
            </div>
            <div
              className="chart-container"
              style={{ height: 260, minWidth: 0 }}
            >
              {recentActivity.length === 0 ? (
                <div
                  style={{
                    display: "flex",
                    height: "100%",
                    alignItems: "center",
                    justifyContent: "center",
                    color: "var(--text-muted)",
                    fontSize: 13,
                  }}
                >
                  No activity data available (Server offline)
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={240}>
                  <AreaChart data={recentActivity}>
                    <defs>
                      <linearGradient
                        id="malwareGrad"
                        x1="0"
                        y1="0"
                        x2="0"
                        y2="1"
                      >
                        <stop
                          offset="5%"
                          stopColor="#ef4444"
                          stopOpacity={0.3}
                        />
                        <stop
                          offset="95%"
                          stopColor="#ef4444"
                          stopOpacity={0}
                        />
                      </linearGradient>
                      <linearGradient
                        id="benignGrad"
                        x1="0"
                        y1="0"
                        x2="0"
                        y2="1"
                      >
                        <stop
                          offset="5%"
                          stopColor="#22c55e"
                          stopOpacity={0.3}
                        />
                        <stop
                          offset="95%"
                          stopColor="#22c55e"
                          stopOpacity={0}
                        />
                      </linearGradient>
                    </defs>
                    <CartesianGrid
                      strokeDasharray="3 3"
                      stroke="rgba(37,37,53,0.8)"
                    />
                    <XAxis
                      dataKey="date"
                      tick={{ fill: "var(--text-muted)", fontSize: 11 }}
                      axisLine={false}
                      tickLine={false}
                      tickFormatter={(str) => {
                        try {
                          return format(parseISO(str), "MMM d");
                        } catch {
                          return str;
                        }
                      }}
                    />
                    <YAxis
                      tick={{ fill: "var(--text-muted)", fontSize: 11 }}
                      axisLine={false}
                      tickLine={false}
                    />
                    <Tooltip
                      contentStyle={{
                        background: "var(--bg-card)",
                        border: "1px solid var(--bg-border)",
                        borderRadius: 8,
                        fontSize: 12,
                      }}
                      labelFormatter={(label) => {
                        try {
                          return format(parseISO(label), "EEEE, d MMMM yyyy");
                        } catch {
                          return label;
                        }
                      }}
                    />
                    <Area
                      type="monotone"
                      dataKey="malware"
                      stroke="#ef4444"
                      strokeWidth={2}
                      fill="url(#malwareGrad)"
                      name="Malware Detected"
                    />
                    <Area
                      type="monotone"
                      dataKey="benign"
                      stroke="#22c55e"
                      strokeWidth={2}
                      fill="url(#benignGrad)"
                      name="Benign File"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>

          {/* Pie Chart: Scan Verdict Distribution */}
          <div
            className="card"
            style={{
              display: "flex",
              flexDirection: "column",
              justifyContent: "space-between",
              minWidth: 0,
            }}
          >
            <div className="card-header">
              <div>
                <p className="card-title">Verdict Distribution</p>
                <p className="card-subtitle">
                  Ratio of benign files vs detected malware
                </p>
              </div>
            </div>
            <div
              className="chart-container"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                height: 200,
                minWidth: 0,
              }}
            >
              {totalScans === 0 ? (
                <div style={{ color: "var(--text-muted)", fontSize: 13 }}>
                  No scans processed yet
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={180}>
                  <PieChart>
                    <Pie
                      data={[
                        { name: "Malware", value: malwareCount },
                        { name: "Benign", value: benignCount },
                      ]}
                      cx="50%"
                      cy="50%"
                      innerRadius={50}
                      outerRadius={70}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      <Cell fill="#ef4444" />
                      <Cell fill="#22c55e" />
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </div>
            {totalScans > 0 && (
              <div
                style={{
                  display: "flex",
                  justifyContent: "center",
                  gap: 24,
                  paddingBottom: 16,
                  fontSize: 12,
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  <div
                    style={{
                      width: 8,
                      height: 8,
                      borderRadius: "50%",
                      background: "#ef4444",
                    }}
                  />
                  <span style={{ color: "var(--text-secondary)" }}>
                    Malware: {malwareCount} ({malwarePercentage}%)
                  </span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  <div
                    style={{
                      width: 8,
                      height: 8,
                      borderRadius: "50%",
                      background: "#22c55e",
                    }}
                  />
                  <span style={{ color: "var(--text-secondary)" }}>
                    Benign: {benignCount} (
                    {(100 - malwarePercentage).toFixed(1)}%)
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* ─── Real-Time Scan Logs ────────────────────────────────────────── */}
        <div className="card">
          <div className="card-header" style={{ flexWrap: "wrap", gap: 16 }}>
            <div>
              <p className="card-title">ML Detection History</p>
              <p className="card-subtitle">
                Showing latest threat scan results from ML sandbox
              </p>
            </div>
            {/* Filters Row */}
            <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
              <div className="search-bar" style={{ width: 220 }}>
                <Search size={14} color="var(--text-muted)" />
                <input
                  type="text"
                  placeholder="Search file name..."
                  value={search}
                  onChange={(e) => {
                    setSearch(e.target.value);
                    setPage(1);
                  }}
                />
              </div>
              <select
                className="form-select"
                style={{ width: 140, padding: "7px 12px", fontSize: 13 }}
                value={labelFilter}
                onChange={(e) => {
                  setLabelFilter(e.target.value);
                  setPage(1);
                }}
              >
                <option value="">All Results</option>
                <option value="malware">Malware Only</option>
                <option value="benign">Benign Only</option>
              </select>
            </div>
          </div>

          {isLoadingLogs ? (
            <div className="loading-overlay">
              <div className="spinner spinner-dark" /> Loading Logs...
            </div>
          ) : (
            <>
              <div className="table-wrapper">
                <table>
                  <thead>
                    <tr>
                      <th>File Name</th>
                      <th>File Size</th>
                      <th>Platform</th>
                      <th>Scanned At</th>
                      <th>Verdict</th>
                    </tr>
                  </thead>
                  <tbody>
                    {logs.length === 0 ? (
                      <tr>
                        <td
                          colSpan={5}
                          style={{ textAlign: "center", padding: 32 }}
                        >
                          <div className="empty-state">
                            <div className="empty-state-icon">
                              <Database size={20} color="var(--text-muted)" />
                            </div>
                            <p>No threat scan logs found</p>
                          </div>
                        </td>
                      </tr>
                    ) : (
                      logs.map((log: any) => (
                        <tr key={log.id}>
                          <td>
                            <span
                              style={{
                                color: "var(--text-primary)",
                                fontWeight: 500,
                                fontSize: 13,
                              }}
                            >
                              {log.file_name}
                            </span>
                          </td>
                          <td>
                            <span
                              style={{
                                fontFamily: "monospace",
                                fontSize: 11,
                                color: "var(--text-secondary)",
                              }}
                            >
                              {formatBytes(log.file_size)}
                            </span>
                          </td>
                          <td>
                            <span
                              className={`badge ${
                                log.app_platform?.toLowerCase() === "desktop"
                                  ? "badge-orange"
                                  : log.app_platform?.toLowerCase() === "mobile"
                                    ? "badge-info"
                                    : "badge-muted"
                              }`}
                            >
                              {log.app_platform || "Unknown"}
                            </span>
                          </td>
                          <td style={{ fontSize: 12 }}>
                            {log.scanned_at
                              ? format(
                                  parseISO(log.scanned_at),
                                  "dd MMM yyyy, HH:mm",
                                )
                              : "-"}
                          </td>
                          <td>
                            <span
                              className={`badge ${
                                log.label === "malware"
                                  ? "badge-danger"
                                  : "badge-success"
                              }`}
                            >
                              {log.label === "malware" ? "Malware" : "Benign"}
                            </span>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>

              {/* Pagination controls */}
              {totalPages > 1 && (
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    marginTop: 16,
                  }}
                >
                  <p style={{ fontSize: 12, color: "var(--text-muted)" }}>
                    Showing {(page - 1) * limit + 1} to{" "}
                    {Math.min(page * limit, totalLogs)} of {totalLogs} logs
                  </p>
                  <div style={{ display: "flex", gap: 8 }}>
                    <button
                      className="btn btn-outline btn-sm btn-icon"
                      disabled={page === 1}
                      onClick={() => setPage((p) => Math.max(p - 1, 1))}
                    >
                      <ChevronLeft size={14} />
                    </button>
                    <button
                      className="btn btn-outline btn-sm btn-icon"
                      disabled={page === totalPages}
                      onClick={() =>
                        setPage((p) => Math.min(p + 1, totalPages))
                      }
                    >
                      <ChevronRight size={14} />
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </>
  );
}
