"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  CreditCard,
  ArrowLeftRight,
  Cpu,
  LogOut,
  Shield,
  Database,
  Activity,
  Terminal,
} from "lucide-react";
import { useAuthStore } from "@/lib/store";

const navItems = [
  {
    section: "Overview",
    items: [
      { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
      { label: "System Logs", href: "/system-logs", icon: Terminal },
    ],
  },
  {
    section: "Business Operations",
    items: [
      { label: "Users", href: "/users", icon: Users },
      { label: "Subscriptions", href: "/subscriptions", icon: CreditCard },
      { label: "Transactions", href: "/transactions", icon: ArrowLeftRight },
    ],
  },
  {
    section: "ML Engine & Security",
    items: [
      { label: "ML Monitoring", href: "/ml-monitoring", icon: Activity },
      { label: "ML Models", href: "/ml-models", icon: Cpu },
      { label: "Malware Samples", href: "/samples", icon: Database },
    ],
  },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { user, logout } = useAuthStore();

  const initial = user?.email?.[0]?.toUpperCase() ?? "A";

  return (
    <aside className="sidebar">
      {/* Logo */}
      <div className="sidebar-logo">
        <div className="sidebar-logo-icon">
          <Shield size={20} color="white" />
        </div>
        <div>
          <div className="sidebar-logo-text">MangoDefend</div>
          <div className="sidebar-logo-sub">Admin Panel</div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="sidebar-nav">
        {navItems.map((section) => (
          <div key={section.section}>
            <div className="nav-section-label">{section.section}</div>
            {section.items.map((item) => {
              const Icon = item.icon;
              const isActive =
                pathname === item.href || pathname.startsWith(item.href + "/");
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`nav-item ${isActive ? "active" : ""}`}
                >
                  <Icon size={16} className="nav-item-icon" />
                  {item.label}
                </Link>
              );
            })}
          </div>
        ))}
      </nav>

      {/* Footer */}
      <div className="sidebar-footer">
        <div className="sidebar-user">
          <div className="sidebar-user-avatar">{initial}</div>
          <div className="sidebar-user-info">
            <div className="sidebar-user-email">
              {user?.email ?? "admin@mangodefend.id"}
            </div>
            <div className="sidebar-user-role">Administrator</div>
          </div>
          <button
            onClick={logout}
            title="Logout"
            style={{
              background: "transparent",
              border: "none",
              cursor: "pointer",
              color: "var(--text-muted)",
              padding: "4px",
              borderRadius: "6px",
              transition: "color 0.15s",
            }}
            onMouseEnter={(e) =>
              ((e.currentTarget as HTMLButtonElement).style.color =
                "var(--color-danger)")
            }
            onMouseLeave={(e) =>
              ((e.currentTarget as HTMLButtonElement).style.color =
                "var(--text-muted)")
            }
          >
            <LogOut size={16} />
          </button>
        </div>
      </div>
    </aside>
  );
}
