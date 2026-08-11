'use client'

import { DashboardLayout } from './dashboard-layout'
import { StatsCard } from '@/components/stats-card'
import { DataTable } from '@/components/data-table'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import { Users, CreditCard, TrendingUp, AlertCircle } from 'lucide-react'
import {
  mockDashboardStats,
  mockAnalyticsData,
  mockUsers,
  mockSubscriptions,
  mockTransactions,
} from '@/lib/mock-data'
import { StatusBadge } from '@/components/data-table'

export default function DashboardHome() {
  const recentTransactions = mockTransactions.slice(0, 5)

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Page Header */}
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
          <p className="text-muted-foreground mt-2">
            Welcome back! Here&apos;s your business overview.
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatsCard
            title="Total Users"
            value={mockDashboardStats.totalUsers.toLocaleString('id-ID')}
            description="Registered accounts"
            icon={<Users className="w-5 h-5" />}
            trend={{ value: 8.5, direction: 'up' }}
          />
          <StatsCard
            title="Paid Subscriptions"
            value={mockDashboardStats.activeSubscriptions.toLocaleString('id-ID')}
            description="Pro & Enterprise tier"
            icon={<CreditCard className="w-5 h-5" />}
            trend={{ value: 12.5, direction: 'up' }}
          />
          <StatsCard
            title="Total Revenue"
            value={`IDR ${(mockDashboardStats.totalRevenue / 1000000).toFixed(1)}M`}
            description="This month"
            icon={<TrendingUp className="w-5 h-5" />}
            trend={{ value: 15.3, direction: 'up' }}
          />
          <StatsCard
            title="Churn Rate"
            value={`${mockDashboardStats.churnRate}%`}
            description="Monthly churn"
            icon={<AlertCircle className="w-5 h-5" />}
            trend={{ value: 2.1, direction: 'down' }}
          />
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Revenue Chart */}
          <Card>
            <CardHeader>
              <CardTitle>Revenue Trend</CardTitle>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={mockAnalyticsData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Line
                    type="monotone"
                    dataKey="revenue"
                    name="Revenue (IDR)"
                    stroke="hsl(var(--primary))"
                    strokeWidth={2}
                  />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>

          {/* Free Tier vs Paid Subscriptions Chart */}
          <Card>
            <CardHeader>
              <CardTitle>Free Tier vs Paid Subscriptions Growth</CardTitle>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={mockAnalyticsData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="freeUsers" name="Free Tier Users" fill="hsl(215 16% 47%)" />
                  <Bar dataKey="paidSubscriptions" name="Paid Subscribers (Pro/Enterprise)" fill="hsl(var(--primary))" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </div>


        {/* Recent Activity */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Recent Transactions */}
          <Card>
            <CardHeader>
              <CardTitle>Recent Transactions</CardTitle>
            </CardHeader>
            <CardContent>
              <DataTable
                columns={[
                  {
                    key: 'id',
                    label: 'ID',
                    render: (value) => <span className="text-sm">{value}</span>,
                  },
                  {
                    key: 'type',
                    label: 'Type',
                    render: (value) => (
                      <span className="capitalize text-sm font-medium">{value}</span>
                    ),
                  },
                  {
                    key: 'amount',
                    label: 'Amount',
                    render: (value) => (
                      <span className="font-semibold">
                        IDR {(value / 1000000).toFixed(1)}M
                      </span>
                    ),
                  },
                  {
                    key: 'status',
                    label: 'Status',
                    render: (value) => <StatusBadge status={value} />,
                  },
                ]}
                data={recentTransactions}
              />
            </CardContent>
          </Card>

          {/* Recent Users */}
          <Card>
            <CardHeader>
              <CardTitle>Recent Users</CardTitle>
            </CardHeader>
            <CardContent>
              <DataTable
                columns={[
                  { key: 'name', label: 'Name' },
                  {
                    key: 'status',
                    label: 'Status',
                    render: (value) => <StatusBadge status={value} />,
                  },
                  {
                    key: 'joinDate',
                    label: 'Joined',
                    render: (value) => <span className="text-sm">{value}</span>,
                  },
                ]}
                data={mockUsers.slice(0, 4)}
              />
            </CardContent>
          </Card>
        </div>
      </div>
    </DashboardLayout>
  )
}
