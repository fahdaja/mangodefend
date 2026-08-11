'use client'

import { useState, useEffect } from 'react'
import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { ShieldAlert, ShieldCheck, Search, RefreshCw, Eye, FileText, Cpu, Smartphone } from 'lucide-react'
import { api } from '@/lib/api'

interface ScanRecord {
  id: number;
  file_name?: string;
  sha256_hash: string;
  classification: 'MALWARE' | 'BENIGN';
  scan_type: 'UPLOAD_FILE' | 'FULL_SCAN';
  confidence_score?: number;
  model_version?: string;
  user_email?: string;
  device_name?: string;
  created_at: string;
}

const mockScans: ScanRecord[] = [
  {
    id: 101,
    file_name: 'suspicious_installer.exe',
    sha256_hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    classification: 'MALWARE',
    scan_type: 'UPLOAD_FILE',
    confidence_score: 99.4,
    model_version: 'v1.2.0-rf',
    user_email: 'user1@mangodefend.com',
    device_name: 'Windows 11 Workstation',
    created_at: '2026-08-11 15:30:12'
  },
  {
    id: 102,
    file_name: 'system32_update.dll',
    sha256_hash: '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
    classification: 'BENIGN',
    scan_type: 'FULL_SCAN',
    confidence_score: 98.1,
    model_version: 'v1.2.0-rf',
    user_email: 'finance@company.com',
    device_name: 'MacBook Pro M3',
    created_at: '2026-08-11 14:15:40'
  },
  {
    id: 103,
    file_name: 'unknown_keylogger.py',
    sha256_hash: '8743b52063cd84097a65d1633f5c74f5',
    classification: 'MALWARE',
    scan_type: 'UPLOAD_FILE',
    confidence_score: 96.8,
    model_version: 'v1.2.0-rf',
    user_email: 'client@test.com',
    device_name: 'Ubuntu Linux 24.04',
    created_at: '2026-08-10 11:20:05'
  }
];

export default function ScansPage() {
  const [scans, setScans] = useState<ScanRecord[]>(mockScans);
  const [searchQuery, setSearchQuery] = useState('');
  const [classFilter, setClassFilter] = useState<'ALL' | 'MALWARE' | 'BENIGN'>('ALL');
  const [selectedScan, setSelectedScan] = useState<ScanRecord | null>(null);
  const [loading, setLoading] = useState(false);

  const fetchScans = async () => {
    setLoading(true);
    try {
      const res = await api.get('/scans/history/1');
      if (res.data && Array.isArray(res.data)) {
        setScans(res.data);
      }
    } catch {
      // Keep mock data if backend call fails during dev
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchScans();
  }, []);

  const filteredScans = scans.filter((scan) => {
    const matchesSearch =
      scan.sha256_hash.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (scan.file_name && scan.file_name.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (scan.user_email && scan.user_email.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesClass =
      classFilter === 'ALL' || scan.classification === classFilter;

    return matchesSearch && matchesClass;
  });

  const malwareCount = scans.filter(s => s.classification === 'MALWARE').length;
  const benignCount = scans.filter(s => s.classification === 'BENIGN').length;

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Scans & Threat Monitoring</h1>
            <p className="text-muted-foreground mt-2">
              Real-time malware analysis logs, SHA-256 fingerprint detection, and AI confidence scores
            </p>
          </div>
          <Button onClick={fetchScans} variant="outline" className="gap-2" disabled={loading}>
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh Logs
          </Button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Total Scans Conducted</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold">{scans.length}</div>
              <FileText className="w-5 h-5 text-muted-foreground" />
            </CardContent>
          </Card>
          <Card className="border-rose-500/30 bg-rose-950/10">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-rose-400">Malware Threats Intercepted</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-rose-400">{malwareCount}</div>
              <ShieldAlert className="w-5 h-5 text-rose-500" />
            </CardContent>
          </Card>
          <Card className="border-emerald-500/30 bg-emerald-950/10">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-emerald-400">Clean Files Verified</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-emerald-400">{benignCount}</div>
              <ShieldCheck className="w-5 h-5 text-emerald-500" />
            </CardContent>
          </Card>
        </div>

        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-4 justify-between items-center bg-card p-4 rounded-xl border border-border">
          <div className="relative w-full sm:w-96">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search SHA-256 Hash, File Name, User Email..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 font-mono text-xs"
            />
          </div>
          <div className="flex gap-2 w-full sm:w-auto">
            <Button
              size="sm"
              variant={classFilter === 'ALL' ? 'default' : 'outline'}
              onClick={() => setClassFilter('ALL')}
            >
              All Scans
            </Button>
            <Button
              size="sm"
              variant={classFilter === 'MALWARE' ? 'destructive' : 'outline'}
              onClick={() => setClassFilter('MALWARE')}
            >
              Malware Only
            </Button>
            <Button
              size="sm"
              variant={classFilter === 'BENIGN' ? 'default' : 'outline'}
              onClick={() => setClassFilter('BENIGN')}
              className={classFilter === 'BENIGN' ? 'bg-emerald-600 hover:bg-emerald-700' : ''}
            >
              Benign Only
            </Button>
          </div>
        </div>

        {/* Table */}
        <div className="bg-card border border-border rounded-xl overflow-hidden shadow-sm">
          <table className="w-full text-left text-sm">
            <thead className="bg-muted/50 border-b border-border text-muted-foreground uppercase text-[11px] tracking-wider font-semibold">
              <tr>
                <th className="px-6 py-4">File Name</th>
                <th className="px-6 py-4">Classification</th>
                <th className="px-6 py-4">Confidence</th>
                <th className="px-6 py-4">Model</th>
                <th className="px-6 py-4">User / Device</th>
                <th className="px-6 py-4">Timestamp</th>
                <th className="px-6 py-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filteredScans.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-8 text-center text-muted-foreground">
                    No scan logs found.
                  </td>
                </tr>
              ) : (
                filteredScans.map((scan) => (
                  <tr key={scan.id} className="hover:bg-muted/30 transition-colors">
                    <td className="px-6 py-4 font-medium text-foreground">{scan.file_name || 'Uploaded File'}</td>
                    <td className="px-6 py-4">
                      {scan.classification === 'MALWARE' ? (
                        <span className="px-2.5 py-1 rounded text-[11px] font-bold bg-rose-500/20 text-rose-300 border border-rose-500/30 inline-flex items-center gap-1">
                          <ShieldAlert className="w-3 h-3 text-rose-400" /> THREAT DETECTED
                        </span>
                      ) : (
                        <span className="px-2.5 py-1 rounded text-[11px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 inline-flex items-center gap-1">
                          <ShieldCheck className="w-3 h-3 text-emerald-400" /> CLEAN / BENIGN
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 font-mono font-semibold text-emerald-400">
                      {scan.confidence_score ? `${scan.confidence_score}%` : '98.5%'}
                    </td>
                    <td className="px-6 py-4 font-mono text-xs text-muted-foreground">{scan.model_version || 'v1.2.0-rf'}</td>
                    <td className="px-6 py-4 text-xs">
                      <div>{scan.user_email || 'System User'}</div>
                      <div className="text-muted-foreground font-mono">{scan.device_name || 'Client Device'}</div>
                    </td>
                    <td className="px-6 py-4 text-xs text-muted-foreground">{scan.created_at}</td>
                    <td className="px-6 py-4 text-right">
                      <Button size="sm" variant="ghost" onClick={() => setSelectedScan(scan)} className="h-8 px-2">
                        <Eye className="w-4 h-4 mr-1" /> View Hash
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Modal Details */}
        {selectedScan && (
          <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
            <div className="bg-card border border-border rounded-xl max-w-lg w-full p-6 shadow-2xl space-y-6 animate-in fade-in zoom-in-95">
              <div className="flex justify-between items-center border-b border-border pb-4">
                <h3 className="text-xl font-bold flex items-center gap-2">
                  <ShieldAlert className="w-5 h-5 text-primary" /> Scan Inspection Breakdown
                </h3>
                <Button size="sm" variant="ghost" onClick={() => setSelectedScan(null)}>✕</Button>
              </div>

              <div className="space-y-4 text-sm">
                <div className="bg-muted/40 p-4 rounded-lg font-mono text-xs space-y-2">
                  <span className="text-muted-foreground block font-sans text-xs">SHA-256 Fingerprint:</span>
                  <span className="font-bold text-foreground break-all">{selectedScan.sha256_hash}</span>
                </div>

                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Sample Name:</span>
                    <span className="font-medium">{selectedScan.file_name || 'N/A'}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Classification Result:</span>
                    <span className={`font-bold ${selectedScan.classification === 'MALWARE' ? 'text-rose-400' : 'text-emerald-400'}`}>
                      {selectedScan.classification}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">AI Confidence:</span>
                    <span className="font-mono font-bold text-emerald-400">{selectedScan.confidence_score}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">AI Model Version:</span>
                    <span className="font-mono">{selectedScan.model_version || 'v1.2.0-rf'}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">User Email:</span>
                    <span>{selectedScan.user_email || 'N/A'}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Target Device:</span>
                    <span>{selectedScan.device_name || 'N/A'}</span>
                  </div>
                </div>
              </div>

              <div className="pt-4 border-t border-border text-right">
                <Button variant="outline" onClick={() => setSelectedScan(null)}>Close</Button>
              </div>
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  )
}
