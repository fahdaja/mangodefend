// src/utils/device.ts

import { DeviceInfo } from "@/lib/api";

export const getDeviceData = (): DeviceInfo => {
  const userAgent = typeof window !== "undefined" ? window.navigator.userAgent : "unknown";

  let hardwareId = typeof window !== "undefined" ? localStorage.getItem("device_id") : null;
  if (!hardwareId) {
    hardwareId = `HW-${Math.random().toString(36).substr(2, 9).toUpperCase()}`;
    if (typeof window !== "undefined") localStorage.setItem("device_id", hardwareId);
  }

  return {
    hardware_id: hardwareId || "unknown",
    hostname: typeof window !== "undefined" ? window.location.hostname : "localhost",
    os_type: userAgent.includes("Windows") ? "Windows" : userAgent.includes("Mac") ? "MacOS" : "Linux",
    app_type: "Web",
  };
};