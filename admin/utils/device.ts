export interface DeviceData {
  device_name: string;
  os_type: string;
  os_version: string;
  app_type: string;
  app_version: string;
}

export function getDeviceData(): DeviceData {
  let device_name = "Web Browser";
  let os_type = "Linux";
  let os_version = "1.0.0";
  let app_type = "Web";
  let app_version = "1.0.0";

  if (typeof window !== "undefined" && window.navigator) {
    const ua = window.navigator.userAgent;
    if (ua.includes("Win")) os_type = "Windows";
    else if (ua.includes("Mac")) os_type = "MacOS";
    else if (ua.includes("Android")) os_type = "Android";
    else if (ua.includes("iPhone") || ua.includes("iPad")) os_type = "iOS";
    else if (ua.includes("Linux")) os_type = "Linux";

    device_name = `${os_type} Web Browser`;
  }

  return {
    device_name,
    os_type,
    os_version,
    app_type,
    app_version,
  };
}
