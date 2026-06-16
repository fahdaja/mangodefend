export type Role = "admin" | "client";
export type OsType = "Windows" | "Linux" | "macOS";
export type AppType = "Desktop" | "Web" | "Mobile";
export type TransactionStatus = "PENDING" | "SUCCESS" | "FAILED" | "EXPIRED";
export type TransactionMethod = "virtual_account" | "qris";
export type PlanType = "free" | "pro" | "bussiness";

export interface User {
  id: number;
  email: string;
  role: Role;
  createdAt: string;
  devices?: Device[];
  subscriptions?: Subscription[];
}

export interface Device {
  id: number;
  user_id: number;
  hardware_id: string;
  hostname: string;
  os_type: OsType;
  app_type: AppType;
  last_active: string | null;
  last_login: string | null;
  is_active: boolean;
}

export interface MlModel {
  id: number;
  version: string;
  file_path: string;
  checksum: string;
  is_active: boolean;
  created_at: string;
}

export interface Plan {
  id: number;
  plan_name: PlanType;
  description: string;
  price: number;
  durationDays: number;
  model_id: number | null;
  model?: MlModel;
  upload_file_limit: number;
  full_scan_limit: number;
}

export interface Subscription {
  id: number;
  user_id: number;
  plan_id: number;
  start_date: string;
  end_date: string;
  is_active: boolean;
  update_at: string;
  user?: User;
  plan?: Plan;
  status?: 'active' | 'expired' | 'replaced' | 'cancelled';
}

export interface Transaction {
  id: number;
  user_id: number;
  plan_id: number;
  external_id?: string;
  amount: number;
  status: TransactionStatus;
  method: TransactionMethod;
  created_at: string;
  update_at: string;
  user?: User;
  plan?: Plan;
}

export interface StatsCard {
  title: string;
  value: string | number;
  change?: number;
  icon: string;
}
