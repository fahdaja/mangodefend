'use client'

import { useState } from 'react'
import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Activity, Server, RefreshCw, Layers, CheckCircle2, AlertTriangle, Zap, Play } from 'lucide-react'

interface WorkerStatus {
  name: string;
  queue: string;
  status: 'ONLINE' | 'BUSY' | 'OFFLINE';
  activeJobs: number;
  completedJobs: number;
  failedJobs: number;
  lastRun?: string;
}

const mockWorkers: WorkerStatus[] = [
  {
    name: 'ScanWorker',
    queue: 'scan_jobs',
    status: 'ONLINE',
    activeJobs: 0,
    completedJobs: 1420,
    failedJobs: 2,
    lastRun: 'Just now'
  },
  {
    name: 'SampleWorker',
    queue: 'sample_jobs',
    status: 'ONLINE',
    activeJobs: 1,
    completedJobs: 389,
    failedJobs: 0,
    lastRun: '1 min ago'
  },
  {
    name: 'PaymentWorker',
    queue: 'payment_events',
    status: 'ONLINE',
    activeJobs: 0,
    completedJobs: 254,
    failedJobs: 1,
    lastRun: '5 mins ago'
  },
  {
    name: 'NotificationWorker',
    queue: 'notification_jobs',
    status: 'ONLINE',
    activeJobs: 0,
    completedJobs: 1890,
    failedJobs: 0,
    lastRun: 'Just now'
  }
];

export default function WorkersPage() {
  const [workers, setWorkers] = useState<WorkerStatus[]>(mockWorkers);
  const [loading, setLoading] = useState(false);

  const handleRefresh = () => {
    setLoading(true);
    setTimeout(() => {
      setWorkers(workers.map(w => ({
        ...w,
        completedJobs: w.completedJobs + Math.floor(Math.random() * 3)
      })));
      setLoading(false);
    }, 600);
  };

  const totalActiveJobs = workers.reduce((sum, w) => sum + w.activeJobs, 0);
  const totalCompletedJobs = workers.reduce((sum, w) => sum + w.completedJobs, 0);
  const totalFailedJobs = workers.reduce((sum, w) => sum + w.failedJobs, 0);

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">RabbitMQ Workers & Queue Health</h1>
            <p className="text-muted-foreground mt-2">
              Asynchronous event-driven background processing engine monitoring
            </p>
          </div>
          <Button onClick={handleRefresh} variant="outline" className="gap-2" disabled={loading}>
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh Queue Status
          </Button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card className="border-emerald-500/30 bg-emerald-950/10">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-emerald-400">Workers Status</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-emerald-400">4 / 4 ONLINE</div>
              <CheckCircle2 className="w-5 h-5 text-emerald-500" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Active Processing Jobs</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-amber-400">{totalActiveJobs}</div>
              <Zap className="w-5 h-5 text-amber-500" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Total Jobs Completed</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold">{totalCompletedJobs.toLocaleString()}</div>
              <Layers className="w-5 h-5 text-muted-foreground" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Failed Jobs (Dead Letter)</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-rose-400">{totalFailedJobs}</div>
              <AlertTriangle className="w-5 h-5 text-rose-500" />
            </CardContent>
          </Card>
        </div>

        {/* Workers List */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {workers.map((worker) => (
            <Card key={worker.name} className="overflow-hidden border border-border">
              <CardHeader className="bg-muted/40 pb-4 border-b border-border flex flex-row items-center justify-between">
                <div>
                  <CardTitle className="text-lg font-bold flex items-center gap-2">
                    <Server className="w-5 h-5 text-primary" /> {worker.name}
                  </CardTitle>
                  <p className="text-xs text-muted-foreground font-mono mt-1">Queue: amqp://{worker.queue}</p>
                </div>
                <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" /> ONLINE
                </span>
              </CardHeader>
              <CardContent className="p-6 space-y-4">
                <div className="grid grid-cols-3 gap-2 text-center text-xs">
                  <div className="bg-muted/30 p-3 rounded-lg border border-border">
                    <span className="text-muted-foreground block mb-1">Active</span>
                    <span className="font-bold text-base text-amber-400">{worker.activeJobs}</span>
                  </div>
                  <div className="bg-muted/30 p-3 rounded-lg border border-border">
                    <span className="text-muted-foreground block mb-1">Completed</span>
                    <span className="font-bold text-base text-emerald-400">{worker.completedJobs}</span>
                  </div>
                  <div className="bg-muted/30 p-3 rounded-lg border border-border">
                    <span className="text-muted-foreground block mb-1">Failed</span>
                    <span className="font-bold text-base text-rose-400">{worker.failedJobs}</span>
                  </div>
                </div>

                <div className="pt-2 text-xs flex justify-between text-muted-foreground">
                  <span>Heartbeat / Last Activity:</span>
                  <span className="font-mono text-foreground">{worker.lastRun}</span>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </DashboardLayout>
  )
}
