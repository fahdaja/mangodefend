'use client'

import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { mockAnalyticsData, mockDashboardStats } from '@/lib/mock-data'
import { Download } from 'lucide-react'
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  AreaChart,
  Area,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'

import { useState } from 'react'

export default function AnalyticsPage() {
  const [dateRange, setDateRange] = useState<string>('monthly')

  // Data for pie chart (Plan Distribution including Free vs Paid)
  const planDistribution = [
    { name: 'Free Starter Plan', value: 120 },
    { name: 'Pro Security Plan', value: 45 },
    { name: 'Enterprise Protection', value: 28 },
  ]

  const COLORS = [
    'hsl(215 16% 47%)',
    'hsl(var(--primary))',
    'hsl(262 83% 58%)',
  ]

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Analytics</h1>
            <p className="text-muted-foreground mt-2">
              Business insights, conversion funnel, and tier distribution
            </p>
          </div>
          <Button className="gap-2">
            <Download className="w-4 h-4" />
            Export Report
          </Button>
        </div>

        {/* Date Range Filter */}
        <Card>
          <CardContent className="pt-6">
            <div className="flex gap-2">
              {['weekly', 'monthly', 'yearly'].map((range) => (
                <Button
                  key={range}
                  variant={dateRange === range ? 'default' : 'outline'}
                  onClick={() => setDateRange(range)}
                  className="capitalize"
                >
                  {range}
                </Button>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Key Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Total Registered Users</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {mockDashboardStats.totalUsers.toLocaleString('id-ID')}
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                {mockDashboardStats.monthlyGrowth}% growth
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Paid Subscriptions</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {mockDashboardStats.activeSubscriptions.toLocaleString('id-ID')}
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                {((mockDashboardStats.activeSubscriptions / mockDashboardStats.totalUsers) * 100).toFixed(1)}% paid conversion
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Total Revenue</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                IDR {(mockDashboardStats.totalRevenue / 1000000).toFixed(1)}M
              </div>
              <p className="text-xs text-muted-foreground mt-1">This month</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Top Paid Plan</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{mockDashboardStats.topPlan}</div>
              <p className="text-xs text-muted-foreground mt-1">Most popular paid tier</p>
            </CardContent>
          </Card>
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Revenue Trend - Area Chart */}
          <Card>
            <CardHeader>
              <CardTitle>Revenue Trend (Last 10 Days)</CardTitle>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <AreaChart data={mockAnalyticsData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Area
                    type="monotone"
                    dataKey="revenue"
                    name="Revenue (IDR)"
                    fill="hsl(var(--primary))"
                    stroke="hsl(var(--primary))"
                    fillOpacity={0.2}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>

          {/* Free Tier vs Paid Subscriptions Bar Chart */}
          <Card>
            <CardHeader>
              <CardTitle>Free Tier vs Paid Subscriptions Conversion</CardTitle>
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

          {/* Plan Distribution */}
          <Card>
            <CardHeader>
              <CardTitle>Subscription Distribution by Plan Tier</CardTitle>
            </CardHeader>
            <CardContent className="flex justify-center">
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={planDistribution}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, value }) => `${name}: ${value}`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {planDistribution.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>

          {/* Daily Metrics Comparison */}
          <Card>
            <CardHeader>
              <CardTitle>Revenue vs Registered Users Growth</CardTitle>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={mockAnalyticsData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis yAxisId="left" />
                  <YAxis yAxisId="right" orientation="right" />
                  <Tooltip />
                  <Legend />
                  <Line
                    yAxisId="left"
                    type="monotone"
                    dataKey="revenue"
                    name="Revenue (IDR)"
                    stroke="hsl(var(--primary))"
                    strokeWidth={2}
                  />
                  <Line
                    yAxisId="right"
                    type="monotone"
                    dataKey="users"
                    name="Total Users"
                    stroke="hsl(215 16% 47%)"
                    strokeWidth={2}
                  />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </div>

        {/* Detailed Metrics Table */}
        <Card>
          <CardHeader>
            <CardTitle>Daily Conversion & Revenue Breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="border-b border-border">
                  <tr>
                    <th className="text-left py-3 px-4 font-semibold">Date</th>
                    <th className="text-right py-3 px-4 font-semibold">Revenue</th>
                    <th className="text-right py-3 px-4 font-semibold">Registered Users</th>
                    <th className="text-right py-3 px-4 font-semibold">Free Tier</th>
                    <th className="text-right py-3 px-4 font-semibold">Paid Subscriptions</th>
                    <th className="text-right py-3 px-4 font-semibold">Paid Conversion</th>
                  </tr>
                </thead>
                <tbody>
                  {mockAnalyticsData.map((data, idx) => {
                    const paid = data.paidSubscriptions || 0
                    const free = data.freeUsers || (data.users - paid)
                    const conversion = ((paid / data.users) * 100).toFixed(1)
                    return (
                      <tr key={idx} className="border-b border-border hover:bg-muted">
                        <td className="py-3 px-4">{data.date}</td>
                        <td className="text-right py-3 px-4 font-semibold">
                          IDR {(data.revenue / 1000000).toFixed(1)}M
                        </td>
                        <td className="text-right py-3 px-4">{data.users}</td>
                        <td className="text-right py-3 px-4 text-muted-foreground">{free}</td>
                        <td className="text-right py-3 px-4 font-semibold text-primary">{paid}</td>
                        <td className="text-right py-3 px-4 font-bold">{conversion}%</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}

