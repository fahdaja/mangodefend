"use client";

import { useQuery } from "@tanstack/react-query";
import { usersApi, subscriptionsApi, transactionsApi, mlApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import {
  Users,
  CreditCard,
  ArrowLeftRight,
  Cpu,
  TrendingUp,
  TrendingDown,
  CheckCircle,
  XCircle,
  Clock,
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
} from "recharts";
import { format, subDays } from "date-fns";
import type { Transaction, Subscription, User } from "@/lib/types";

// ─── Mock recent activity data (for chart) ────────────────────────────────────
const last7Days = Array.from({ length: 7 }, (_, i) => ({
  date: format(subDays(new Date(), 6 - i), "MMM d"),
  transactions: Math.floor(Math.random() * 15) + 2,
  subscriptions: Math.floor(Math.random() * 8) + 1,
}));

const COLORS = ["#f97316", "#3b82f6", "#22c55e", "#a855f7"];

export default function DashboardPage() {
  const { data: usersData, isLoading: usersLoading } = useQuery({
    queryKey: ["users"],
    queryFn: () => usersApi.getAll().then((r) => r.data?.data ?? r.data),
  });

  const { data: subsData, isLoading: subsLoading } = useQuery({
    queryKey: ["subscriptions-all"],
    queryFn: () =>
      subscriptionsApi.getAllWithUsers().then((r) => r.data?.data ?? r.data),
  });

  const { data: txData, isLoading: txLoading } = useQuery({
    queryKey: ["transactions"],
    queryFn: () => transactionsApi.getAll().then((r) => r.data?.data ?? r.data),
  });

  const { data: mlData, isLoading: mlLoading } = useQuery({
    queryKey: ["ml-models"],
    queryFn: () => mlApi.getAll().then((r) => r.data?.data ?? r.data),
  });

  const users: User[] = Array.isArray(usersData) ? usersData : [];
  const subscriptions: Subscription[] = Array.isArray(subsData) ? subsData : [];
  const transactions: Transaction[] = Array.isArray(txData) ? txData : [];

  const dashboardLoading = usersLoading || subsLoading || txLoading || mlLoading;

  const activeSubscriptions = subscriptions.filter((s) => s.is_active).length;
  const pendingTx = transactions.filter((t) => t.status === "PENDING").length;
  const successTx = transactions.filter((t) => t.status === "SUCCESS").length;
  const totalRevenue = transactions
    .filter((t) => t.status === "SUCCESS")
    .reduce((acc, t) => acc + Number(t.amount), 0);

  const txStatusData = [
    { name: "Success", value: successTx },
    { name: "Pending", value: pendingTx },
    { name: "Failed", value: transactions.filter((t) => t.status === "FAILED").length },
  ].filter((d) => d.value > 0);

  const recentTransactions = [...transactions]
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    .slice(0, 5);

  const recentUsers = [...users]
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 5);

  const formatCurrency = (val: number) =>
    new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(val);

  const statusBadge = (status: string) => {
    const map: Record<string, string> = {
      success: "badge-success",
      pending: "badge-warning",
      failed: "badge-danger",
    };
    return <span className={`badge ${map[status] ?? "badge-muted"}`}>{status}</span>;
  };

  if (dashboardLoading) {
    return (
      <>
        <Topbar
          title="Dashboard"
          subtitle={`Welcome back · ${format(new Date(), "EEEE, d MMMM yyyy")}`}
        />
        <div className="page-content" style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "50vh" }}>
          <div className="spinner spinner-dark" />
          <span style={{ marginLeft: 10, color: "var(--text-muted)", fontSize: 14 }}>Loading dashboard overview...</span>
        </div>
      </>
    );
  }

  return (
    <>
      <Topbar
        title="Dashboard"
        subtitle={`Welcome back · ${format(new Date(), "EEEE, d MMMM yyyy")}`}
      />
      <div className="page-content">
        {/* ─── Stats ─────────────────────────────────────────────────────────── */}
        <div className="stats-grid">
          <StatCard
            icon={<Users size={20} />}
            iconClass="blue"
            value={users.length}
            label="Total Users"
            change={12}
          />
          <StatCard
            icon={<CreditCard size={20} />}
            iconClass="orange"
            value={activeSubscriptions}
            label="Active Subscriptions"
            change={8}
          />
          <StatCard
            icon={<ArrowLeftRight size={20} />}
            iconClass="green"
            value={transactions.length}
            label="Total Transactions"
            change={-3}
          />
          <StatCard
            icon={<Cpu size={20} />}
            iconClass="purple"
            value={Array.isArray(mlData) ? mlData.length : 0}
            label="ML Models"
          />
        </div>

        {/* ─── Revenue Banner ─────────────────────────────────────────────────── */}
        <div
          className="card mb-6"
          style={{
            background: "linear-gradient(135deg, rgba(249,115,22,0.12) 0%, rgba(220,38,38,0.08) 100%)",
            borderColor: "rgba(249,115,22,0.25)",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            flexWrap: "wrap",
            gap: 16,
          }}
        >
          <div>
            <p style={{ fontSize: 12, color: "var(--brand-primary)", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 6 }}>
              Total Revenue
            </p>
            <p style={{ fontSize: 36, fontWeight: 800, color: "var(--text-primary)", letterSpacing: "-1px" }}>
              {formatCurrency(totalRevenue)}
            </p>
            <p style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 4 }}>
              From {successTx} successful transactions · {pendingTx} pending
            </p>
          </div>
          <div style={{ display: "flex", gap: 24 }}>
            <div style={{ textAlign: "right" }}>
              <p style={{ fontSize: 11, color: "var(--text-muted)", marginBottom: 4 }}>Success Rate</p>
              <p style={{ fontSize: 22, fontWeight: 700, color: "var(--color-success)" }}>
                {transactions.length
                  ? Math.round((successTx / transactions.length) * 100)
                  : 0}%
              </p>
            </div>
            <div style={{ textAlign: "right" }}>
              <p style={{ fontSize: 11, color: "var(--text-muted)", marginBottom: 4 }}>Pending</p>
              <p style={{ fontSize: 22, fontWeight: 700, color: "var(--color-warning)" }}>
                {pendingTx}
              </p>
            </div>
          </div>
        </div>

        {/* ─── Charts Row ─────────────────────────────────────────────────────── */}
        <div className="grid-2 mb-6">
          {/* Area Chart */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Activity (7 days)</p>
                <p className="card-subtitle">Transactions & new subscriptions</p>
              </div>
            </div>
            <div className="chart-container">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={last7Days}>
                  <defs>
                    <linearGradient id="txGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f97316" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#f97316" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="subGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(37,37,53,0.8)" />
                  <XAxis
                    dataKey="date"
                    tick={{ fill: "var(--text-muted)", fontSize: 11 }}
                    axisLine={false}
                    tickLine={false}
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
                  />
                  <Area
                    type="monotone"
                    dataKey="transactions"
                    stroke="#f97316"
                    strokeWidth={2}
                    fill="url(#txGrad)"
                    name="Transactions"
                  />
                  <Area
                    type="monotone"
                    dataKey="subscriptions"
                    stroke="#3b82f6"
                    strokeWidth={2}
                    fill="url(#subGrad)"
                    name="Subscriptions"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Pie Chart */}
          <div className="card" style={{ display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
            <div className="card-header">
              <div>
                <p className="card-title">Transaction Status</p>
                <p className="card-subtitle">Distribution of all payment statuses</p>
              </div>
            </div>
            <div className="chart-container" style={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
              {txStatusData.length === 0 ? (
                <p style={{ color: "var(--text-muted)", fontSize: 13 }}>No transactions to display</p>
              ) : (
                <ResponsiveContainer width="100%" height={200}>
                  <PieChart>
                    <Pie
                      data={txStatusData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={80}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {txStatusData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </div>
            <div style={{ display: "flex", justifyContent: "center", gap: 20, flexWrap: "wrap", fontSize: 12 }}>
              {txStatusData.map((d, i) => (
                <div key={d.name} style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  <div style={{ width: 8, height: 8, borderRadius: "50%", background: COLORS[i % COLORS.length] }} />
                  <span style={{ color: "var(--text-secondary)" }}>
                    {d.name} ({d.value})
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* ─── Lists Row ─────────────────────────────────────────────────────── */}
        <div className="grid-2">
          {/* Recent Transactions */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Recent Transactions</p>
                <p className="card-subtitle">Latest payment records</p>
              </div>
            </div>
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Amount</th>
                    <th>Status</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {recentTransactions.map((tx) => (
                    <tr key={tx.id}>
                      <td style={{ fontFamily: "monospace", fontSize: 12 }}>#{tx.id.toString().slice(0, 8)}</td>
                      <td style={{ fontWeight: 600 }}>{formatCurrency(Number(tx.amount))}</td>
                      <td>{statusBadge(tx.status.toLowerCase())}</td>
                      <td style={{ fontSize: 11 }}>{format(new Date(tx.created_at), "dd MMM, HH:mm")}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Newest Users */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Newest Users</p>
                <p className="card-subtitle">Latest registered members</p>
              </div>
            </div>
            {users.length === 0 ? (
              <div className="loading-overlay">
                <div className="spinner spinner-dark" /> Loading Users...
              </div>
            ) : (
              <div className="table-wrapper">
                <table>
                  <thead>
                    <tr>
                      <th>User</th>
                      <th>Role</th>
                      <th>Joined</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentUsers.map((user) => (
                      <tr key={user.id}>
                        <td>
                          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                            <div className="avatar" style={{ width: 28, height: 28, fontSize: 11 }}>
                              {user.email[0].toUpperCase()}
                            </div>
                            <span
                              style={{
                                color: "var(--text-primary)",
                                fontSize: 12,
                                maxWidth: 140,
                                overflow: "hidden",
                                textOverflow: "ellipsis",
                                whiteSpace: "nowrap",
                              }}
                            >
                              {user.email}
                            </span>
                          </div>
                        </td>
                        <td>
                          <span className={`badge ${user.role === "admin" ? "badge-orange" : "badge-info"}`}>
                            {user.role}
                          </span>
                        </td>
                        <td style={{ fontSize: 11 }}>
                          {format(new Date(user.createdAt), "dd MMM")}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}

// ─── Stat Card Component ──────────────────────────────────────────────────────
function StatCard({
  icon,
  iconClass,
  value,
  label,
  change,
}: {
  icon: React.ReactNode;
  iconClass: string;
  value: number;
  label: string;
  change?: number;
}) {
  return (
    <div className="stat-card">
      <div className={`stat-icon ${iconClass}`}>{icon}</div>
      <div>
        <div className="stat-value">{value.toLocaleString()}</div>
        <div className="stat-label">{label}</div>
        {change !== undefined && (
          <div className={`stat-change ${change >= 0 ? "positive" : "negative"}`}>
            {change >= 0 ? <TrendingUp size={11} /> : <TrendingDown size={11} />}
            {Math.abs(change)}% this month
          </div>
        )}
      </div>
    </div>
  );
}
