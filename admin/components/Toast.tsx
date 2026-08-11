"use client";

import React, { useEffect } from "react";
import { CheckCircle2, XCircle, X } from "lucide-react";

interface ToastProps {
  message: string;
  type?: "success" | "error";
  onClose?: () => void;
  duration?: number;
}

export default function Toast({ message, type = "success", onClose, duration = 3000 }: ToastProps) {
  useEffect(() => {
    if (duration && onClose) {
      const timer = setTimeout(onClose, duration);
      return () => clearTimeout(timer);
    }
  }, [duration, onClose]);

  return (
    <div
      className={`fixed bottom-5 right-5 z-50 flex items-center gap-3 px-4 py-3 rounded-lg shadow-lg border text-sm font-medium transition-all ${
        type === "success"
          ? "bg-emerald-950/90 border-emerald-500/50 text-emerald-200"
          : "bg-rose-950/90 border-rose-500/50 text-rose-200"
      }`}
    >
      {type === "success" ? (
        <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
      ) : (
        <XCircle className="w-5 h-5 text-rose-400 shrink-0" />
      )}
      <span>{message}</span>
      {onClose && (
        <button onClick={onClose} className="ml-2 hover:opacity-75">
          <X className="w-4 h-4" />
        </button>
      )}
    </div>
  );
}
