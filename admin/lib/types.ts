// User Management Types
export interface User {
  id: string
  email: string
  name: string
  phone: string
  status: 'active' | 'inactive' | 'suspended'
  subscriptionStatus: 'active' | 'pending' | 'expired'
  joinDate: string
  lastLogin: string
}

// Subscription Types
export interface Subscription {
  id: string
  userId: string
  planId: string
  planName: string
  status: 'active' | 'pending' | 'expired' | 'cancelled'
  startDate: string
  endDate: string
  autoRenew: boolean
  price: number
}

// Financial Wallet Types
export interface Transaction {
  id: string
  userId: string
  type: 'payment' | 'refund'
  amount: number
  status: 'completed' | 'pending' | 'failed'
  description: string
  timestamp: string
}

// Plan Types
export interface Plan {
  id: string
  name: string
  description: string
  price: number
  durationDays?: number
  deviceLimit?: number
  uploadFileLimit?: number
  fullScanLimit?: number
  modelName?: string
  modelVersion?: string
  currency?: string
  features?: string[]
  duration?: string
  status: 'active' | 'inactive'
  createdDate?: string
  totalSubscribers: number
}


// Analytics Types
export interface DashboardStats {
  totalUsers: number
  activeSubscriptions: number
  totalRevenue: number
  monthlyGrowth: number
  topPlan: string
  churnRate: number
}

export interface AnalyticsData {
  date: string
  revenue: number
  users: number
  freeUsers?: number
  paidSubscriptions?: number
  subscriptions: number
}

