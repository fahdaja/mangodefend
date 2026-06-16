"use client";

import { Bell, Search } from "lucide-react";

interface TopbarProps {
  title: string;
  subtitle?: string;
}

export default function Topbar({ title, subtitle }: TopbarProps) {
  return (
    <header className="topbar">
      <div>
        <h1 className="topbar-title">{title}</h1>
        {subtitle && <p className="topbar-subtitle">{subtitle}</p>}
      </div>
      <div className="topbar-actions">
        <div className="search-bar">
          <Search size={14} color="var(--text-muted)" />
          <input placeholder="Search..." />
        </div>
        <button
          className="btn btn-outline btn-icon"
          style={{ position: "relative" }}
          title="Notifications"
        >
          <Bell size={16} />
          <span
            style={{
              position: "absolute",
              top: 6,
              right: 6,
              width: 7,
              height: 7,
              borderRadius: "50%",
              background: "var(--brand-primary)",
              border: "1.5px solid var(--bg-card)",
            }}
          />
        </button>
      </div>
    </header>
  );
}
