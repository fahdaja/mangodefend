"use client";

import { useState, Fragment, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { usersApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import { Users, Monitor, Search, ChevronDown, Loader2 } from "lucide-react";
import { format } from "date-fns";
import type { User, Device } from "@/lib/types";

export default function UsersPage() {
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [page, setPage] = useState(1);
  const [expandedUser, setExpandedUser] = useState<number | null>(null);

  // LOGIKA DEBOUNCE: Tunggu user berhenti mengetik 500ms sebelum fetch ke server
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedSearch(search);
      setPage(1); // Reset ke halaman 1 saat pencarian berubah
    }, 500);
    return () => clearTimeout(handler);
  }, [search]);

  // 1. Ambil data statistik untuk summary cards (Seluruh Database)
  const { data: stats } = useQuery({
    queryKey: ["users-stats"],
    queryFn: () => usersApi.getStats().then((r) => r.data),
  });

  // 2. Ambil data tabel (Hanya data per halaman & hasil search)
  const { data: response, isLoading } = useQuery({
    queryKey: ["users", debouncedSearch, page],
    queryFn: () => usersApi.getAll(debouncedSearch, page).then((r) => r.data),
  });

  const users: User[] = response?.data || [];
  const meta = response?.meta || { total: 0 };

  return (
    <>
      <Topbar title="Users" subtitle={`${meta.total} registered accounts`} />
      <div className="page-content">
        {/* STAT CARDS: Menggunakan data dari endpoint /stats agar selalu akurat */}
        <div style={{ display: "flex", gap: 16, marginBottom: 24 }}>
          <StatCard
            icon={<Users size={18} />}
            value={stats?.total}
            label="Total Users"
            color="blue"
          />
          <StatCard
            icon={<Users size={18} />}
            value={stats?.admins}
            label="Admins"
            color="orange"
          />
          <StatCard
            icon={<Users size={18} />}
            value={stats?.clients}
            label="Clients"
            color="green"
          />
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <p className="card-title">All Users</p>
              <p className="card-subtitle">Server-side searching enabled</p>
            </div>
            <div className="search-bar" style={{ width: 240 }}>
              <Search size={14} color="var(--text-muted)" />
              <input
                placeholder="Search email or role..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
          </div>

          <div className="table-wrapper">
            <table
              style={{
                opacity: isLoading ? 0.6 : 1,
                transition: "opacity 0.2s",
              }}
            >
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Devices</th>
                  <th>Subscriptions</th>
                  <th>Joined</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {users.length === 0 && !isLoading ? (
                  <tr>
                    <td
                      colSpan={7}
                      style={{ textAlign: "center", padding: 40 }}
                    >
                      No users found
                    </td>
                  </tr>
                ) : (
                  users.map((user) => (
                    <Fragment key={user.id}>
                      <tr
                        style={{ cursor: "pointer" }}
                        onClick={() =>
                          setExpandedUser(
                            expandedUser === user.id ? null : user.id,
                          )
                        }
                      >
                        <td>
                          <span style={{ fontFamily: "monospace" }}>
                            #{user.id}
                          </span>
                        </td>
                        <td>
                          <div
                            style={{
                              display: "flex",
                              alignItems: "center",
                              gap: 10,
                            }}
                          >
                            <div className="avatar">
                              {user.email[0].toUpperCase()}
                            </div>
                            <span>{user.email}</span>
                          </div>
                        </td>
                        <td>
                          <span
                            className={`badge ${user.role === "admin" ? "badge-orange" : "badge-info"}`}
                          >
                            {user.role}
                          </span>
                        </td>
                        {/* Data jumlah devices dihitung langsung oleh database */}
                        <td>
                          <span style={{ fontWeight: 600 }}>
                            {user.devices?.length ?? 0}
                          </span>
                        </td>
                        <td>
                          <span style={{ fontWeight: 600 }}>
                            {user.subscriptions?.length ?? 0}
                          </span>
                        </td>
                        <td>
                          {user.createdAt
                            ? format(new Date(user.createdAt), "dd MMM yyyy")
                            : "-"}
                        </td>
                        <td>
                          <ChevronDown
                            size={16}
                            style={{
                              transform:
                                expandedUser === user.id
                                  ? "rotate(180deg)"
                                  : "none",
                              transition: "0.2s",
                            }}
                          />
                        </td>
                      </tr>
                      {/* LAZY LOADING: Hanya memuat data device saat baris diklik */}
                      {expandedUser === user.id && (
                        <tr>
                          <td colSpan={7} style={{ padding: 0 }}>
                            <UserDeviceLoader userId={user.id} />
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </>
  );
}

// Komponen Pembantu untuk Stat Card
function StatCard({ icon, value, label, color }: any) {
  return (
    <div className="stat-card" style={{ flex: 1, padding: 16 }}>
      <div className={`stat-icon ${color}`}>{icon}</div>
      <div>
        <div className="stat-value">{value ?? 0}</div>
        <div className="stat-label">{label}</div>
      </div>
    </div>
  );
}

// Komponen untuk memuat daftar device secara terpisah (Lazy Loading)
function UserDeviceLoader({ userId }: { userId: number }) {
  const { data: response, isLoading } = useQuery({
    queryKey: ["user-devices", userId],
    queryFn: () => usersApi.getDevices(userId).then((r) => r.data),
  });

  if (isLoading) {
    return (
      <div
        style={{
          padding: 20,
          display: "flex",
          gap: 10,
          alignItems: "center",
          color: "var(--text-muted)",
        }}
      >
        <Loader2 size={16} className="spinner" />
        <span style={{ fontSize: 13 }}>Fetching devices...</span>
      </div>
    );
  }

  return <DeviceList devices={response?.data || []} />;
}

// Komponen Daftar Device (Tetap Sama)
function DeviceList({ devices }: { devices: Device[] }) {
  if (devices.length === 0)
    return (
      <div
        style={{
          padding: 20,
          fontSize: 13,
          color: "var(--text-muted)",
          background: "var(--bg-surface)",
        }}
      >
        No devices registered
      </div>
    );
  return (
    <div
      style={{
        background: "var(--bg-surface)",
        padding: "16px 24px",
        borderTop: "1px solid var(--bg-border)",
      }}
    >
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))",
          gap: 10,
        }}
      >
        {devices.map((d) => (
          <div
            key={d.id}
            style={{
              background: "var(--bg-card)",
              border: "1px solid var(--bg-border)",
              borderRadius: 10,
              padding: "12px 14px",
              display: "flex",
              gap: 10,
            }}
          >
            <div className="stat-icon blue" style={{ width: 32, height: 32 }}>
              <Monitor size={16} />
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 600 }}>{d.hostname}</p>
              <p style={{ fontSize: 11, color: "var(--text-muted)" }}>
                {d.os_type} · {d.app_type}
              </p>
              <span
                className={`badge ${d.is_active ? "badge-success" : "badge-muted"}`}
                style={{ fontSize: 10, marginTop: 4 }}
              >
                {d.is_active ? "Active" : "Inactive"}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
