export enum application_type {
    UNKNOWN = "Unknown",
    WEB = "Web",
    DESKTOP = "Desktop",
    MOBILE = "Mobile"
}

export enum os_type {
    UNKNOWN = "Unknown",
    WINDOWS = "Windows",
    MACOS = "macOS",
    LINUX = "Linux"
}

export function normalizeOsType(val: any): os_type {
    if (!val) return os_type.UNKNOWN;
    const str = String(val).toUpperCase();
    if (str.includes('WIN')) return os_type.WINDOWS;
    if (str.includes('MAC') || str.includes('DARWIN')) return os_type.MACOS;
    if (str.includes('LINUX')) return os_type.LINUX;
    return os_type.UNKNOWN;
}

export function normalizeAppType(val: any): application_type {
    if (!val) return application_type.UNKNOWN;
    const str = String(val).toUpperCase();
    if (str.includes('WEB')) return application_type.WEB;
    if (str.includes('DESK')) return application_type.DESKTOP;
    if (str.includes('MOB') || str.includes('ANDROID') || str.includes('IOS')) return application_type.MOBILE;
    return application_type.UNKNOWN;
}