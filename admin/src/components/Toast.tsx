"use client";

import { CheckCircle, XCircle, Info, X } from "lucide-react";
import { useEffect } from "react";

interface ToastProps {
  message: string;
  type: "success" | "error" | "info";
  onClose: () => void;
  duration?: number;
}

export default function Toast({ message, type, onClose, duration = 3500 }: ToastProps) {
  useEffect(() => {
    const timer = setTimeout(onClose, duration);
    return () => clearTimeout(timer);
  }, [onClose, duration]);

  const icons = {
    success: <CheckCircle size={16} color="var(--color-success)" />,
    error: <XCircle size={16} color="var(--color-danger)" />,
    info: <Info size={16} color="var(--color-info)" />,
  };

  return (
    <div className={`toast toast-${type}`}>
      {icons[type]}
      <span style={{ flex: 1 }}>{message}</span>
      <button
        onClick={onClose}
        style={{ background: "none", border: "none", cursor: "pointer", color: "var(--text-muted)", padding: "2px" }}
      >
        <X size={14} />
      </button>
    </div>
  );
}
