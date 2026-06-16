"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { datasetApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import {
  Database,
  Bug,
  ShieldCheck,
  Activity,
  Clock,
  Hash,
  ChevronLeft,
  ChevronRight,
  Filter,
} from "lucide-react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
} from "recharts";
import { format, subDays, subMonths, parseISO } from "date-fns";

// ─── Types ──────────────────────────────────────────────────────────────────
interface DatasetStats {
  total: number;
  by_label: { label: string; count: number }[];
  by_source: { source: string; count: number }[];
  breakdown: { label: string; source: string; count: number }[];
  timeline: { date: string; label: string; count: number }[];
}

interface DatasetSample {
  id: number;
  file_hash: string;
  label: "malware" | "benign";
  source: "seeder" | "scan";
  uploaded_at: string;
}

interface UnimportedSample {
  id: number;
  file_name: string;
  file_hash: string;
  is_malware: boolean;
  detected_at: string;
}

const PIE_COLORS = ["#ef4444", "#22c55e"];

export default function SamplesPage() {
  const [activeTab, setActiveTab] = useState<"all" | "malware" | "benign" | "unimported">("all");
  const [page, setPage] = useState(1);
  const [importingHash, setImportingHash] = useState<string | null>(null);
  const [timeRange, setTimeRange] = useState<"7d" | "30d" | "12m">("30d");

  // ─── Data fetching ────────────────────────────────────────────────────────
  const { data: statsRaw, refetch: refetchStats } = useQuery({
    queryKey: ["dataset-stats", timeRange],
    queryFn: () => datasetApi.getStats(timeRange).then((r) => r.data),
  });

  const filterLabel = activeTab === "all" ? undefined : activeTab;
  const isUnimportedTab = activeTab === "unimported";

  // Official dataset query
  const { data: recentRaw, isFetching: isFetchingRecent, refetch: refetchRecent } = useQuery({
    queryKey: ["dataset-recent", filterLabel, page],
    queryFn: () => datasetApi.getRecent(filterLabel, page, 15).then((r) => r.data),
    enabled: !isUnimportedTab,
  });

  // Unimported malware scans query
  const { data: unimportedRaw, isFetching: isFetchingUnimported, refetch: refetchUnimported } = useQuery({
    queryKey: ["dataset-unimported", page],
    queryFn: () => datasetApi.getUnimportedMalware(page, 15).then((r) => r.data),
    enabled: isUnimportedTab,
  });

  // Get total count of unimported malware for the tab badge
  const { data: unimportedStatsRaw, refetch: refetchUnimportedStats } = useQuery({
    queryKey: ["dataset-unimported-stats"],
    queryFn: () => datasetApi.getUnimportedMalware(1, 1).then((r) => r.data),
  });

  const stats: DatasetStats = statsRaw ?? {
    total: 0,
    by_label: [],
    by_source: [],
    breakdown: [],
    timeline: [],
  };

  const samples: any[] = isUnimportedTab
    ? (Array.isArray(unimportedRaw?.data) ? unimportedRaw.data : [])
    : (Array.isArray(recentRaw?.data) ? recentRaw.data : []);

  const meta = isUnimportedTab
    ? (unimportedRaw?.meta ?? { total: 0, page: 1, limit: 15, lastPage: 1 })
    : (recentRaw?.meta ?? { total: 0, page: 1, limit: 15, lastPage: 1 });

  const isFetching = isUnimportedTab ? isFetchingUnimported : isFetchingRecent;
  const unimportedCount = unimportedStatsRaw?.meta?.total ?? 0;

  // ─── Derived data ─────────────────────────────────────────────────────────
  const malwareCount = stats.by_label.find((l) => l.label === "malware")?.count ?? 0;
  const benignCount = stats.by_label.find((l) => l.label === "benign")?.count ?? 0;

  const pieData = [
    { name: "Malware", value: malwareCount },
    { name: "Benign", value: benignCount },
  ].filter((d) => d.value > 0);

  // Build bar chart breakdown data
  const breakdownData = (() => {
    const map: Record<string, { source: string; malware: number; benign: number }> = {};
    for (const b of stats.breakdown) {
      if (!map[b.source]) map[b.source] = { source: b.source === "seeder" ? "Seeder" : "Scan", malware: 0, benign: 0 };
      map[b.source][b.label as "malware" | "benign"] = b.count;
    }
    return Object.values(map);
  })();

  // Build timeline chart data (dynamic range)
  const timelineData = (() => {
    const dayMap: Record<string, { date: string; malware: number; benign: number }> = {};
    
    if (timeRange === "12m") {
      // Initialize last 12 months
      for (let i = 11; i >= 0; i--) {
        const d = format(subMonths(new Date(), i), "yyyy-MM");
        dayMap[d] = { date: format(parseISO(d + "-01"), "MMM yyyy"), malware: 0, benign: 0 };
      }
    } else {
      // Initialize last N days
      const daysCount = timeRange === "7d" ? 7 : 30;
      for (let i = daysCount - 1; i >= 0; i--) {
        const d = format(subDays(new Date(), i), "yyyy-MM-dd");
        dayMap[d] = { date: format(parseISO(d), "MMM d"), malware: 0, benign: 0 };
      }
    }

    for (const t of stats.timeline) {
      if (dayMap[t.date]) {
        dayMap[t.date][t.label as "malware" | "benign"] = t.count;
      }
    }
    return Object.values(dayMap);
  })();

  const malwareRatio = stats.total > 0 ? ((malwareCount / stats.total) * 100).toFixed(1) : "0";

  const tabs = [
    { key: "all" as const, label: "All Samples", count: stats.total },
    { key: "malware" as const, label: "Malware", count: malwareCount },
    { key: "benign" as const, label: "Benign", count: benignCount },
    { key: "unimported" as const, label: "Detected (Unimported)", count: unimportedCount },
  ];

  // ─── Actions ──────────────────────────────────────────────────────────────
  const handleImport = async (fileHash: string) => {
    try {
      setImportingHash(fileHash);
      await datasetApi.importToInventory(fileHash, "malware");
      refetchStats();
      refetchUnimportedStats();
      if (isUnimportedTab) {
        refetchUnimported();
      } else {
        refetchRecent();
      }
      alert("Malware successfully imported into dataset inventory!");
    } catch (err: any) {
      alert("Failed to import malware: " + (err.response?.data?.message || err.message));
    } finally {
      setImportingHash(null);
    }
  };

  return (
    <>
      <Topbar
        title="Dataset Samples"
        subtitle="Malware & benign sample inventory overview"
      />
      <div className="page-content">
        {/* ─── Stats Cards ────────────────────────────────────────────────── */}
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-icon purple"><Database size={20} /></div>
            <div>
              <div className="stat-value">{stats.total.toLocaleString()}</div>
              <div className="stat-label">Total Samples</div>
            </div>
          </div>
          <div className="stat-card">
            <div className="stat-icon red"><Bug size={20} /></div>
            <div>
              <div className="stat-value">{malwareCount.toLocaleString()}</div>
              <div className="stat-label">Malware Samples</div>
              <div className="stat-change negative" style={{ color: "var(--color-danger)" }}>
                {malwareRatio}% of dataset
              </div>
            </div>
          </div>
          <div className="stat-card">
            <div className="stat-icon green"><ShieldCheck size={20} /></div>
            <div>
              <div className="stat-value">{benignCount.toLocaleString()}</div>
              <div className="stat-label">Benign Samples</div>
              <div className="stat-change positive">
                {stats.total > 0 ? ((benignCount / stats.total) * 100).toFixed(1) : "0"}% of dataset
              </div>
            </div>
          </div>
          <div className="stat-card">
            <div className="stat-icon orange"><Activity size={20} /></div>
            <div>
              <div className="stat-value">{stats.by_source.find((s) => s.source === "scan")?.count ?? 0}</div>
              <div className="stat-label">From Scans</div>
              <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 4 }}>
                {stats.by_source.find((s) => s.source === "seeder")?.count ?? 0} from seeder
              </div>
            </div>
          </div>
        </div>

        {/* ─── Charts Row ─────────────────────────────────────────────────── */}
        <div className="grid-2 mb-6">
          {/* Timeline Area Chart */}
          <div className="card">
            <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <div>
                <p className="card-title">Sample Collection Timeline</p>
                <p className="card-subtitle">
                  Samples collected over the{" "}
                  {timeRange === "7d"
                    ? "last 7 days"
                    : timeRange === "30d"
                    ? "last 30 days"
                    : "last 12 months"}
                </p>
              </div>
              <div style={{ display: "flex", gap: "6px" }}>
                <button
                  onClick={() => setTimeRange("7d")}
                  className={`btn btn-sm ${timeRange === "7d" ? "btn-primary" : "btn-outline"}`}
                  style={{ padding: "4px 10px", fontSize: "11px", borderRadius: "6px" }}
                >
                  7 Days
                </button>
                <button
                  onClick={() => setTimeRange("30d")}
                  className={`btn btn-sm ${timeRange === "30d" ? "btn-primary" : "btn-outline"}`}
                  style={{ padding: "4px 10px", fontSize: "11px", borderRadius: "6px" }}
                >
                  30 Days
                </button>
                <button
                  onClick={() => setTimeRange("12m")}
                  className={`btn btn-sm ${timeRange === "12m" ? "btn-primary" : "btn-outline"}`}
                  style={{ padding: "4px 10px", fontSize: "11px", borderRadius: "6px" }}
                >
                  12 Months
                </button>
              </div>
            </div>
            <div className="chart-container" style={{ minHeight: 280 }}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={timelineData}>
                  <defs>
                    <linearGradient id="malwareGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="benignGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(37,37,53,0.8)" />
                  <XAxis
                    dataKey="date"
                    tick={{ fill: "var(--text-muted)", fontSize: 10 }}
                    axisLine={false}
                    tickLine={false}
                  />
                  <YAxis
                    tick={{ fill: "var(--text-muted)", fontSize: 11 }}
                    axisLine={false}
                    tickLine={false}
                    allowDecimals={false}
                  />
                  <Tooltip
                    contentStyle={{
                      background: "var(--bg-card)",
                      border: "1px solid var(--bg-border)",
                      borderRadius: 8,
                      fontSize: 12,
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="malware"
                    stroke="#ef4444"
                    strokeWidth={2}
                    fill="url(#malwareGrad)"
                    name="Malware"
                  />
                  <Area
                    type="monotone"
                    dataKey="benign"
                    stroke="#22c55e"
                    strokeWidth={2}
                    fill="url(#benignGrad)"
                    name="Benign"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Distribution Charts */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Dataset Distribution</p>
                <p className="card-subtitle">By label & source breakdown</p>
              </div>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
              {/* Donut Chart */}
              <div style={{ width: 170, height: 170, flexShrink: 0 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={pieData.length ? pieData : [{ name: "No data", value: 1 }]}
                      cx="50%"
                      cy="50%"
                      innerRadius={48}
                      outerRadius={76}
                      dataKey="value"
                      strokeWidth={0}
                    >
                      {(pieData.length ? pieData : [{ name: "No data", value: 1 }]).map(
                        (_, index) => (
                          <Cell
                            key={`cell-${index}`}
                            fill={pieData.length ? PIE_COLORS[index] : "var(--bg-border)"}
                          />
                        )
                      )}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        background: "var(--bg-card)",
                        border: "1px solid var(--bg-border)",
                        borderRadius: 8,
                        fontSize: 12,
                      }}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              {/* Legend + Bar breakdown */}
              <div style={{ flex: 1 }}>
                {pieData.map((item, idx) => (
                  <div key={item.name} style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
                    <div style={{ width: 10, height: 10, borderRadius: 3, background: PIE_COLORS[idx], flexShrink: 0 }} />
                    <div style={{ flex: 1 }}>
                      <p style={{ fontSize: 13, color: "var(--text-primary)", fontWeight: 600 }}>{item.name}</p>
                      <p style={{ fontSize: 11, color: "var(--text-muted)" }}>
                        {item.value} samples · {stats.total > 0 ? ((item.value / stats.total) * 100).toFixed(1) : 0}%
                      </p>
                    </div>
                  </div>
                ))}
                {!pieData.length && (
                  <p style={{ fontSize: 13, color: "var(--text-muted)" }}>No dataset samples</p>
                )}
                <div style={{ marginTop: 8, height: 100, minWidth: 0 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={breakdownData} layout="vertical">
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(37,37,53,0.5)" horizontal={false} />
                      <XAxis
                        type="number"
                        tick={{ fill: "var(--text-muted)", fontSize: 10 }}
                        axisLine={false}
                        tickLine={false}
                        allowDecimals={false}
                      />
                      <YAxis
                        type="category"
                        dataKey="source"
                        tick={{ fill: "var(--text-muted)", fontSize: 11 }}
                        axisLine={false}
                        tickLine={false}
                        width={55}
                      />
                      <Tooltip
                        contentStyle={{
                          background: "var(--bg-card)",
                          border: "1px solid var(--bg-border)",
                          borderRadius: 8,
                          fontSize: 12,
                        }}
                      />
                      <Bar dataKey="malware" stackId="a" fill="#ef4444" name="Malware" radius={[0, 0, 0, 0]} />
                      <Bar dataKey="benign" stackId="a" fill="#22c55e" name="Benign" radius={[0, 4, 4, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ─── Tabs + Table ────────────────────────────────────────────────── */}
        <div className="card">
          <div className="card-header">
            <div>
              <p className="card-title">Sample Inventory</p>
              <p className="card-subtitle">Browse all dataset entries with hash details</p>
            </div>
          </div>

          {/* Tab bar */}
          <div className="samples-tabs">
            {tabs.map((tab) => (
              <button
                key={tab.key}
                id={`tab-${tab.key}`}
                className={`samples-tab ${activeTab === tab.key ? "active" : ""}`}
                onClick={() => { setActiveTab(tab.key); setPage(1); }}
              >
                {tab.key === "malware" && <Bug size={13} />}
                {tab.key === "benign" && <ShieldCheck size={13} />}
                {tab.key === "unimported" && <Activity size={13} />}
                {tab.key === "all" && <Filter size={13} />}
                {tab.label}
                <span className="samples-tab-count">{tab.count}</span>
              </button>
            ))}
          </div>

          {/* Table */}
          {samples.length === 0 && !isFetching ? (
            <div className="empty-state">
              <div className="empty-state-icon">
                <Database size={20} color="var(--text-muted)" />
              </div>
              <p>No samples found</p>
            </div>
          ) : (
            <>
              <div className="table-wrapper" style={{ marginTop: 16 }}>
                <table>
                  <thead>
                    <tr>
                      <th>ID</th>
                      {isUnimportedTab && <th>File Name</th>}
                      <th>File Hash (SHA-256)</th>
                      <th>Label</th>
                      {!isUnimportedTab && <th>Source</th>}
                      <th>{isUnimportedTab ? "Detected At" : "Uploaded"}</th>
                      {isUnimportedTab && <th style={{ width: 100 }}>Action</th>}
                    </tr>
                  </thead>
                  <tbody>
                    {samples.map((sample) => (
                      <tr key={sample.id}>
                        <td>
                          <span style={{ fontFamily: "monospace", color: "var(--text-primary)", fontSize: 12 }}>
                            #{sample.id}
                          </span>
                        </td>
                        {isUnimportedTab && (
                          <td style={{ color: "var(--text-primary)", fontWeight: 500 }}>
                            {sample.file_name}
                          </td>
                        )}
                        <td>
                          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                            <Hash size={12} color="var(--text-muted)" />
                            <span className="hash-text" title={sample.file_hash}>
                              {sample.file_hash.slice(0, 16)}…{sample.file_hash.slice(-8)}
                            </span>
                          </div>
                        </td>
                        <td>
                          <span
                            className={`badge ${
                              isUnimportedTab || sample.label === "malware" ? "badge-danger" : "badge-success"
                            }`}
                          >
                            {isUnimportedTab || sample.label === "malware" ? (
                              <><Bug size={10} /> Malware</>
                            ) : (
                              <><ShieldCheck size={10} /> Benign</>
                            )}
                          </span>
                        </td>
                        {!isUnimportedTab && (
                          <td>
                            <span className={`badge ${sample.source === "scan" ? "badge-orange" : "badge-info"}`}>
                              {sample.source}
                            </span>
                          </td>
                        )}
                        <td style={{ fontSize: 12, color: "var(--text-muted)" }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                            <Clock size={12} />
                            {format(
                              new Date(isUnimportedTab ? sample.detected_at : sample.uploaded_at),
                              "dd MMM yyyy, HH:mm"
                            )}
                          </div>
                        </td>
                        {isUnimportedTab && (
                          <td>
                            <button
                              className="btn btn-primary btn-sm"
                              disabled={importingHash === sample.file_hash}
                              onClick={() => handleImport(sample.file_hash)}
                            >
                              {importingHash === sample.file_hash ? "Importing..." : "Import"}
                            </button>
                          </td>
                        )}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Pagination */}
              <div className="samples-pagination">
                <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
                  Showing {((meta.page - 1) * meta.limit) + 1}–
                  {Math.min(meta.page * meta.limit, meta.total)} of{" "}
                  {meta.total} samples
                </span>
                <div style={{ display: "flex", gap: 8 }}>
                  <button
                    className="btn btn-outline btn-sm"
                    disabled={page <= 1}
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                  >
                    <ChevronLeft size={14} /> Prev
                  </button>
                  <button
                    className="btn btn-outline btn-sm"
                    disabled={page >= meta.lastPage}
                    onClick={() => setPage((p) => p + 1)}
                  >
                    Next <ChevronRight size={14} />
                  </button>
                </div>
              </div>
            </>
          )}

          {isFetching && (
            <div className="loading-overlay">
              <div className="spinner spinner-dark" />
              Loading samples...
            </div>
          )}
        </div>
      </div>
    </>
  );
}
