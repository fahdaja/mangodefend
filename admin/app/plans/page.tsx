'use client'

import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { DataTable, StatusBadge } from '@/components/data-table'
import { mockPlans } from '@/lib/mock-data'
import type { Plan } from '@/lib/types'
import { Edit2, Trash2, Plus, Cpu, Package, Check } from 'lucide-react'
import { useState, useEffect } from 'react'
import { api } from '@/lib/api'

interface MlModelOption {
  id: number;
  model_name: string;
  version: string;
}

export default function PlansPage() {
  const [plans, setPlans] = useState<Plan[]>(mockPlans)
  const [viewMode, setViewMode] = useState<'grid' | 'table'>('grid')
  const [showAddModal, setShowAddModal] = useState(false)
  const [availableModels, setAvailableModels] = useState<MlModelOption[]>([
    { id: 1, model_name: 'MangoDefend Random Forest', version: 'v1.2.0-rf' },
    { id: 2, model_name: 'MangoDefend XGBoost Classifier', version: 'v1.1.0-xgb' },
    { id: 3, model_name: 'MangoDefend Lightweight NN', version: 'v1.0.0-nn' },
  ])

  // Form State
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [price, setPrice] = useState('150000')
  const [durationDays, setDurationDays] = useState('30')
  const [deviceLimit, setDeviceLimit] = useState('5')
  const [uploadFileLimit, setUploadFileLimit] = useState('50')
  const [fullScanLimit, setFullScanLimit] = useState('10')
  const [selectedModelId, setSelectedModelId] = useState<string>('1')

  useEffect(() => {
    // Fetch available ML models from backend
    api.get('/models').then((res) => {
      if (res.data?.data && Array.isArray(res.data.data)) {
        setAvailableModels(res.data.data)
      }
    }).catch(() => {})
  }, [])

  const totalRevenue = plans.reduce(
    (sum, plan) => sum + plan.price * plan.totalSubscribers,
    0
  )

  const handleDelete = (id: string) => {
    setPlans(plans.filter((p) => p.id !== id))
  }

  const handleCreatePlan = async (e: React.FormEvent) => {
    e.preventDefault()

    const selectedModel = availableModels.find(m => String(m.id) === selectedModelId)
    const modelTag = selectedModel ? `AI Model: ${selectedModel.version}` : 'Standard AI Model'

    const newPlanObj = {
      plan_name: name || 'PRO',
      description: description || 'High-performance malware protection plan',
      price: parseFloat(price) || 150000,
      durationDays: parseInt(durationDays, 10) || 30,
      device_limit: parseInt(deviceLimit, 10) || 5,
      upload_file_limit: parseInt(uploadFileLimit, 10) || 50,
      full_scan_limit: parseInt(fullScanLimit, 10) || 10,
      model_id: selectedModelId ? parseInt(selectedModelId, 10) : null
    }

    try {
      await api.post('/subscriptions/plan', newPlanObj)
    } catch {}

    const newPlanUI: Plan = {
      id: String(Date.now()),
      name: name || 'Pro Security Plan',
      description: description || 'High-performance malware protection plan',
      price: parseFloat(price) || 150000,
      duration: `${durationDays} Days`,
      features: [
        `Up to ${deviceLimit} Devices`,
        `Daily Upload Scan Limit: ${uploadFileLimit}`,
        `Full Scan Limit: ${fullScanLimit}`,
        modelTag
      ],
      status: 'active',
      totalSubscribers: 0
    }

    setPlans([newPlanUI, ...plans])
    setShowAddModal(false)
    setName('')
    setDescription('')
  }

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Plans Management</h1>
            <p className="text-muted-foreground mt-2">
              Create, configure device limits, and attach ML models to subscription plans
            </p>
          </div>
          <Button onClick={() => setShowAddModal(true)} className="gap-2">
            <Plus className="w-4 h-4" />
            New Plan
          </Button>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Total Plans</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{plans.length}</div>
              <p className="text-xs text-muted-foreground mt-1">
                {plans.filter((p) => p.status === 'active').length} active
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Total Subscribers</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {plans.reduce((sum, p) => sum + p.totalSubscribers, 0)}
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                Across all plans
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium">Monthly Revenue</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                IDR {(totalRevenue / 1000000).toFixed(1)}M
              </div>
              <p className="text-xs text-muted-foreground mt-1">From plans</p>
            </CardContent>
          </Card>
        </div>

        {/* View Mode Toggle */}
        <div className="flex gap-2">
          <Button
            variant={viewMode === 'grid' ? 'default' : 'outline'}
            onClick={() => setViewMode('grid')}
          >
            Grid View
          </Button>
          <Button
            variant={viewMode === 'table' ? 'default' : 'outline'}
            onClick={() => setViewMode('table')}
          >
            Table View
          </Button>
        </div>

        {/* Plans Grid View */}
        {viewMode === 'grid' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {plans.map((plan) => (
            <Card key={plan.id} className="flex flex-col">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div>
                    <CardTitle className="text-lg">{plan.name}</CardTitle>
                    <p className="text-sm text-muted-foreground mt-1">
                      {plan.description}
                    </p>
                  </div>
                  <StatusBadge status={plan.status} />
                </div>
              </CardHeader>
              <CardContent className="flex-1 space-y-4">
                <div className="border-t border-border pt-4 flex justify-between items-baseline">
                  <div>
                    <div className="text-2xl font-bold text-primary">
                      {plan.price === 0 ? 'FREE' : `Rp ${plan.price.toLocaleString('id-ID')}`}
                    </div>
                    <p className="text-xs text-muted-foreground">
                      per {plan.durationDays || 30} Days
                    </p>
                  </div>
                  <span className="text-xs font-mono font-bold px-2 py-1 bg-primary/10 text-primary border border-primary/20 rounded">
                    {plan.totalSubscribers} Subscribers
                  </span>
                </div>

                {/* Quota Limits Grid */}
                <div className="space-y-2 border-t border-border pt-3">
                  <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider">
                    Plan Limits & Quotas
                  </p>
                  <div className="grid grid-cols-3 gap-2 text-center text-xs font-mono">
                    <div className="bg-muted/40 p-2 rounded border border-border">
                      <span className="text-[10px] text-muted-foreground block">Device Limit</span>
                      <span className="font-bold text-foreground">{plan.deviceLimit ?? 2} Devices</span>
                    </div>
                    <div className="bg-muted/40 p-2 rounded border border-border">
                      <span className="text-[10px] text-muted-foreground block">Upload Scans</span>
                      <span className="font-bold text-foreground">{plan.uploadFileLimit ?? 5}/day</span>
                    </div>
                    <div className="bg-muted/40 p-2 rounded border border-border">
                      <span className="text-[10px] text-muted-foreground block">Full Scans</span>
                      <span className="font-bold text-foreground">{plan.fullScanLimit ?? 1}/day</span>
                    </div>
                  </div>
                </div>

                {/* Attached ML Model Info */}
                <div className="p-3 bg-muted/30 rounded-lg border border-border space-y-1 text-xs">
                  <span className="font-semibold text-muted-foreground flex items-center gap-1.5 text-[11px]">
                    <Cpu className="w-3.5 h-3.5 text-primary" /> ATTACHED ML MODEL
                  </span>
                  <p className="font-mono font-bold text-foreground">
                    {plan.modelName || 'MangoDefend Random Forest'}{' '}
                    <span className="text-primary">({plan.modelVersion || 'v1.2.0-rf'})</span>
                  </p>
                </div>

                <div className="flex gap-2 pt-2 border-t border-border">
                  <Button variant="outline" size="sm" className="flex-1 gap-2">
                    <Edit2 className="w-4 h-4" />
                    Edit
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="flex-1 gap-2 text-destructive"
                    onClick={() => handleDelete(plan.id)}
                  >
                    <Trash2 className="w-4 h-4" />
                    Delete
                  </Button>
                </div>
              </CardContent>

            </Card>
          ))}
        </div>
        )}

        {/* Plans Table View */}
        {viewMode === 'table' && (
        <Card>
          <CardHeader>
            <CardTitle>Plans List</CardTitle>
          </CardHeader>
          <CardContent>
            <DataTable<Plan>
              columns={[
                { key: 'name', label: 'Plan Name' },
                { key: 'description', label: 'Description' },
                {
                  key: 'price',
                  label: 'Price',
                  render: (value) => `IDR ${(value / 1000000).toFixed(1)}M`,
                },
                { key: 'duration', label: 'Duration' },
                {
                  key: 'totalSubscribers',
                  label: 'Subscribers',
                },
                {
                  key: 'status',
                  label: 'Status',
                  render: (value) => <StatusBadge status={value} />,
                },
              ]}
              data={plans}
              emptyMessage="No plans found"
            />
          </CardContent>
        </Card>
        )}

        {/* Modal Form New Plan */}
        {showAddModal && (
          <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
            <form onSubmit={handleCreatePlan} className="bg-card border border-border rounded-xl max-w-lg w-full p-6 shadow-2xl space-y-4 animate-in fade-in zoom-in-95 max-h-[90vh] overflow-y-auto">
              <div className="flex justify-between items-center border-b border-border pb-3">
                <h3 className="text-lg font-bold flex items-center gap-2">
                  <Package className="w-5 h-5 text-primary" /> Create New Subscription Plan
                </h3>
                <Button size="sm" type="button" variant="ghost" onClick={() => setShowAddModal(false)}>✕</Button>
              </div>

              <div className="space-y-3 text-sm">
                <div>
                  <label className="text-xs text-muted-foreground block mb-1 font-medium">Plan Name</label>
                  <Input
                    required
                    placeholder="e.g. Pro Security Plan"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                </div>

                <div>
                  <label className="text-xs text-muted-foreground block mb-1 font-medium">Description</label>
                  <Input
                    required
                    placeholder="Brief summary of plan benefits..."
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs text-muted-foreground block mb-1 font-medium">Price (IDR)</label>
                    <Input
                      type="number"
                      required
                      placeholder="150000"
                      value={price}
                      onChange={(e) => setPrice(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="text-xs text-muted-foreground block mb-1 font-medium">Duration (Days)</label>
                    <Input
                      type="number"
                      required
                      placeholder="30"
                      value={durationDays}
                      onChange={(e) => setDurationDays(e.target.value)}
                    />
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className="text-xs text-muted-foreground block mb-1 font-medium">Device Limit</label>
                    <Input
                      type="number"
                      required
                      placeholder="5"
                      value={deviceLimit}
                      onChange={(e) => setDeviceLimit(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="text-xs text-muted-foreground block mb-1 font-medium">Upload Scan Limit</label>
                    <Input
                      type="number"
                      required
                      placeholder="50"
                      value={uploadFileLimit}
                      onChange={(e) => setUploadFileLimit(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="text-xs text-muted-foreground block mb-1 font-medium">Full Scan Limit</label>
                    <Input
                      type="number"
                      required
                      placeholder="10"
                      value={fullScanLimit}
                      onChange={(e) => setFullScanLimit(e.target.value)}
                    />
                  </div>
                </div>

                {/* Dropdown Link ML Model to Plan */}
                <div className="p-3 bg-muted/40 rounded-lg border border-border space-y-2">
                  <label className="text-xs font-bold text-primary flex items-center gap-1.5">
                    <Cpu className="w-4 h-4 text-primary" /> Attach ML Model for this Plan
                  </label>
                  <select
                    className="w-full bg-background border border-input rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary font-mono text-xs"
                    value={selectedModelId}
                    onChange={(e) => setSelectedModelId(e.target.value)}
                  >
                    <option value="">-- No Specific Model (Default Global Model) --</option>
                    {availableModels.map((model) => (
                      <option key={model.id} value={model.id}>
                        {model.model_name} ({model.version})
                      </option>
                    ))}
                  </select>
                  <p className="text-[11px] text-muted-foreground">
                    Client devices subscribed to this plan will download and use the selected ML model version for local malware scanning.
                  </p>
                </div>
              </div>

              <div className="pt-4 border-t border-border flex justify-end gap-2">
                <Button type="button" variant="outline" onClick={() => setShowAddModal(false)}>Cancel</Button>
                <Button type="submit">Create & Save Plan</Button>
              </div>
            </form>
          </div>
        )}
      </div>
    </DashboardLayout>
  )
}

