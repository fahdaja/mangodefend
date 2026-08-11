'use client'

import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { DataTable, StatusBadge } from '@/components/data-table'
import { useState } from 'react'
import { Search, Filter } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { mockSubscriptions } from '@/lib/mock-data'
import type { Subscription } from '@/lib/types'

export default function SubscriptionsPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [filterStatus, setFilterStatus] = useState<string>('all')
  const [sortBy, setSortBy] = useState<string>('date')

  const filteredSubscriptions = mockSubscriptions
    .filter((sub) => {
      const matchesSearch = 
        sub.planName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        sub.userId.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = filterStatus === 'all' || sub.status === filterStatus
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      if (sortBy === 'date') {
        return new Date(b.startDate).getTime() - new Date(a.startDate).getTime()
      } else if (sortBy === 'price') {
        return b.price - a.price
      }
      return 0
    })

  const stats = {
    total: mockSubscriptions.length,
    active: mockSubscriptions.filter((s) => s.status === 'active').length,
    pending: mockSubscriptions.filter((s) => s.status === 'pending').length,
    expired: mockSubscriptions.filter((s) => s.status === 'expired').length,
  }

  const activeRevenue = mockSubscriptions
    .filter((s) => s.status === 'active')
    .reduce((sum, s) => sum + s.price, 0)

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Subscriptions</h1>
            <p className="text-muted-foreground mt-2">
              Manage all user subscriptions and plans
            </p>
          </div>
          <Button>Create Subscription</Button>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Total Subscriptions</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.total}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Active</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-600">{stats.active}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Pending</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-yellow-600">{stats.pending}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Expired</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-600">{stats.expired}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Active Revenue</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                IDR {(activeRevenue / 1000000).toFixed(1)}M
              </div>
              <p className="text-xs text-muted-foreground mt-1">Monthly</p>
            </CardContent>
          </Card>
        </div>

        {/* Search and Filters */}
        <Card>
          <CardContent className="pt-6">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-3 w-4 h-4 text-muted-foreground" />
                <Input
                  placeholder="Search by plan or user..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-10"
                />
              </div>
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="px-4 py-2 border border-border rounded-lg bg-background text-foreground"
              >
                <option value="all">All Status</option>
                <option value="active">Active</option>
                <option value="pending">Pending</option>
                <option value="expired">Expired</option>
              </select>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="px-4 py-2 border border-border rounded-lg bg-background text-foreground"
              >
                <option value="date">Sort: Recent</option>
                <option value="price">Sort: Price</option>
              </select>
            </div>
          </CardContent>
        </Card>

        {/* Subscriptions Table */}
        <Card>
          <CardHeader>
            <CardTitle>Subscriptions ({filteredSubscriptions.length})</CardTitle>
          </CardHeader>
          <CardContent>
            <DataTable<Subscription>
              columns={[
                { key: 'id', label: 'Subscription ID' },
                { key: 'planName', label: 'Plan' },
                {
                  key: 'price',
                  label: 'Price',
                  render: (value) => `IDR ${(value / 1000000).toFixed(1)}M`,
                },
                { key: 'startDate', label: 'Start Date' },
                { key: 'endDate', label: 'End Date' },
                {
                  key: 'autoRenew',
                  label: 'Auto Renew',
                  render: (value) => (value ? 'Yes' : 'No'),
                },
                {
                  key: 'status',
                  label: 'Status',
                  render: (value) => <StatusBadge status={value} />,
                },
              ]}
              data={filteredSubscriptions}
              emptyMessage="No subscriptions found"
            />
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}
