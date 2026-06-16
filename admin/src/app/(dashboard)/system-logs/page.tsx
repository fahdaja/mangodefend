"use client";

import { useState, useRef, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { mlApi } from "@/lib/api";
import Topbar from "@/components/Topbar";
import { Terminal, RefreshCw } from "lucide-react";
import { format } from "date-fns";

export default function SystemLogsPage() {
  const [activeLogTab, setActiveLogTab] = useState<"ml" | "apps">("ml");
  const consoleRef = useRef<HTMLDivElement>(null);
  const appsConsoleRef = useRef<HTMLDivElement>(null);

  // 1. ML Server Logs (Auto-refreshes every 5 seconds)
  const {
    data: systemLogsData,
    refetch: refetchSystemLogs,
    isRefetching: isRefetchingSystemLogs,
  } = useQuery({
    queryKey: ["ml-system-logs"],
    queryFn: () =>
      mlApi
        .getSystemLogs(150)
        .then((r) => r.data)
        .catch(() => null),
    refetchInterval: 5000,
  });

  // 2. Apps Server Logs (Auto-refreshes every 5 seconds)
  const {
    data: appsLogsData,
    refetch: refetchAppsLogs,
    isRefetching: isRefetchingAppsLogs,
  } = useQuery({
    queryKey: ["apps-system-logs"],
    queryFn: () =>
      mlApi
        .getAppsLogs(150)
        .then((r) => r.data)
        .catch(() => null),
    refetchInterval: 5000,
  });

  const isAnyRefetching = isRefetchingSystemLogs || isRefetchingAppsLogs;
  const systemLogs = systemLogsData?.logs ?? [];
  const appsLogs = appsLogsData?.logs ?? [];

  // Scroll ML terminal logs to bottom on update
  useEffect(() => {
    if (consoleRef.current) {
      consoleRef.current.scrollTop = consoleRef.current.scrollHeight;
    }
  }, [systemLogs, activeLogTab]);

  // Scroll Apps terminal logs to bottom on update
  useEffect(() => {
    if (appsConsoleRef.current) {
      appsConsoleRef.current.scrollTop = appsConsoleRef.current.scrollHeight;
    }
  }, [appsLogs, activeLogTab]);

  return (
    <>
      <Topbar
        title="System Logs"
        subtitle={`System operational & engine execution output · ${format(new Date(), "EEEE, d MMMM yyyy")}`}
      />
      <div className="page-content">
        <div className="card">
          <div
            className="card-header"
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              flexWrap: "wrap",
              gap: 12,
              borderBottom: "1px solid rgba(255, 255, 255, 0.05)",
              paddingBottom: 12,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <Terminal size={18} color="var(--color-success)" />
              <div>
                <p className="card-title">Live System Logs Console</p>
                <p className="card-subtitle">
                  Real-time process output and console stream of backend servers
                </p>
              </div>
            </div>
            <div>
              <button
                className="btn btn-outline btn-sm"
                onClick={() => {
                  if (activeLogTab === "ml") refetchSystemLogs();
                  else refetchAppsLogs();
                }}
                style={{ fontSize: 11, display: "flex", alignItems: "center", gap: 6 }}
              >
                <RefreshCw size={12} className={isAnyRefetching ? "spinner" : ""} />
                Fetch Logs
              </button>
            </div>
          </div>

          {/* Log Tabs Selection */}
          <div
            style={{
              display: "flex",
              borderBottom: "1px solid rgba(255, 255, 255, 0.05)",
              padding: "8px 16px 0",
              gap: 16,
              background: "rgba(0,0,0,0.15)",
            }}
          >
            <button
              onClick={() => setActiveLogTab("ml")}
              style={{
                background: "transparent",
                border: "none",
                color: activeLogTab === "ml" ? "#38bdf8" : "var(--text-muted)",
                borderBottom: activeLogTab === "ml" ? "2px solid #38bdf8" : "2px solid transparent",
                padding: "8px 12px 12px 12px",
                cursor: "pointer",
                fontWeight: 600,
                fontSize: 13,
                transition: "all 0.15s",
              }}
            >
              ML Inference Server (FastAPI)
            </button>
            <button
              onClick={() => setActiveLogTab("apps")}
              style={{
                background: "transparent",
                border: "none",
                color: activeLogTab === "apps" ? "#38bdf8" : "var(--text-muted)",
                borderBottom: activeLogTab === "apps" ? "2px solid #38bdf8" : "2px solid transparent",
                padding: "8px 12px 12px 12px",
                cursor: "pointer",
                fontWeight: 600,
                fontSize: 13,
                transition: "all 0.15s",
              }}
            >
              Apps API Server (NestJS)
            </button>
          </div>

          {/* Console Window */}
          {activeLogTab === "ml" ? (
            <div
              ref={consoleRef}
              style={{
                background: "#0c0d12",
                borderRadius: "0 0 8px 8px",
                padding: 16,
                fontFamily: "monospace, Courier New, Courier",
                fontSize: 12,
                color: "#e2e8f0",
                height: 480,
                overflowY: "auto",
                borderTop: "none",
              }}
            >
              {systemLogs.length === 0 ? (
                <div style={{ color: "var(--text-muted)", fontStyle: "italic", textAlign: "center", paddingTop: 180 }}>
                  No system logs available (Server offline or log empty)
                </div>
              ) : (
                systemLogs.map((logLine: string, index: number) => {
                  let color = "#cbd5e1"; // default text
                  if (logLine.includes("INFO")) color = "#34d399"; // green for info
                  if (logLine.includes("ERROR") || logLine.includes("FAIL")) color = "#f87171"; // red for errors
                  if (logLine.includes("WARNING")) color = "#fbbf24"; // orange for warnings
                  if (logLine.includes("Detail Waktu Proses Internal") || logLine.trim().startsWith("- ")) {
                    color = "#c084fc"; // purple for internal timing execution stats
                  }
                  
                  return (
                    <div
                      key={index}
                      style={{
                        color,
                        whiteSpace: "pre-wrap",
                        marginBottom: 4,
                        lineHeight: "1.4",
                        borderLeft: logLine.includes("Detail Waktu Proses Internal") ? "3px solid #c084fc" : "none",
                        paddingLeft: logLine.includes("Detail Waktu Proses Internal") ? 8 : 0,
                      }}
                    >
                      {logLine}
                    </div>
                  );
                })
              )}
            </div>
          ) : (
            <div
              ref={appsConsoleRef}
              style={{
                background: "#0c0d12",
                borderRadius: "0 0 8px 8px",
                padding: 16,
                fontFamily: "monospace, Courier New, Courier",
                fontSize: 12,
                color: "#e2e8f0",
                height: 480,
                overflowY: "auto",
                borderTop: "none",
              }}
            >
              {appsLogs.length === 0 ? (
                <div style={{ color: "var(--text-muted)", fontStyle: "italic", textAlign: "center", paddingTop: 180 }}>
                  No apps logs available (Server offline or log empty)
                </div>
              ) : (
                appsLogs.map((logLine: string, index: number) => {
                  let color = "#cbd5e1"; // default text
                  if (logLine.includes("[INFO]") || logLine.includes("INFO")) color = "#34d399";
                  if (logLine.includes("[ERROR]") || logLine.includes("ERROR")) color = "#f87171";
                  if (logLine.includes("[WARNING]") || logLine.includes("WARNING")) color = "#fbbf24";
                  if (logLine.includes("[NestFactory]") || logLine.includes("[InstanceLoader]") || logLine.includes("[RoutesResolver]") || logLine.includes("[RouterExplorer]")) {
                    color = "#60a5fa"; // light blue for NestJS setup/mapping logs
                  }
                  
                  return (
                    <div
                      key={index}
                      style={{
                        color,
                        whiteSpace: "pre-wrap",
                        marginBottom: 4,
                        lineHeight: "1.4",
                      }}
                    >
                      {logLine}
                    </div>
                  );
                })
              )}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
