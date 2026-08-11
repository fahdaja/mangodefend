'use client'

import { useState, useEffect } from 'react'
import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Database, Search, ShieldAlert, ShieldCheck, Plus, RefreshCw, FileCode, Upload } from 'lucide-react'
import { api } from '@/lib/api'

interface DatasetItem {
  id: number;
  file_hash: string;
  label: 'MALWARE' | 'BENIGN';
  file_name?: string;
  file_size?: number;
  file_type?: string;
  source?: string;
  created_at?: string;
}

const mockDataset: DatasetItem[] = [
  {
    id: 1,
    file_hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    label: 'MALWARE',
    file_name: 'trojan_downloader_v2.exe',
    file_type: 'PE32 Executable',
    source: 'SampleWorker Upload',
    created_at: '2026-08-11 12:00:00'
  },
  {
    id: 2,
    file_hash: '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
    label: 'BENIGN',
    file_name: 'explorer_helper.dll',
    file_type: 'DLL Library',
    source: 'System Whitelist',
    created_at: '2026-08-10 16:45:00'
  },
  {
    id: 3,
    file_hash: '8743b52063cd84097a65d1633f5c74f5',
    label: 'MALWARE',
    file_name: 'ransomware_payload_enc.bin',
    file_type: 'Binary Stream',
    source: 'RabbitMQ Worker',
    created_at: '2026-08-09 08:30:00'
  }
];

export default function DatasetPage() {
  const [dataset, setDataset] = useState<DatasetItem[]>(mockDataset);
  const [searchHash, setSearchHash] = useState('');
  const [labelFilter, setLabelFilter] = useState<'ALL' | 'MALWARE' | 'BENIGN'>('ALL');
  const [loading, setLoading] = useState(false);
  const [showImportModal, setShowImportModal] = useState(false);

  // Form State
  const [inputHash, setInputHash] = useState('');
  const [inputLabel, setInputLabel] = useState<'MALWARE' | 'BENIGN'>('MALWARE');
  const [inputFileName, setInputFileName] = useState('');

  const fetchDataset = async () => {
    setLoading(true);
    try {
      const [malwareRes, benignRes] = await Promise.all([
        api.get('/dataset/malware').catch(() => ({ data: [] })),
        api.get('/dataset/benign').catch(() => ({ data: [] }))
      ]);

      const combined: DatasetItem[] = [
        ...(Array.isArray(malwareRes.data) ? malwareRes.data.map((item: any) => ({ ...item, label: 'MALWARE' as const })) : []),
        ...(Array.isArray(benignRes.data) ? benignRes.data.map((item: any) => ({ ...item, label: 'BENIGN' as const })) : [])
      ];

      if (combined.length > 0) {
        setDataset(combined);
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDataset();
  }, []);

  const filteredItems = dataset.filter(item => {
    const matchesSearch =
      item.file_hash.toLowerCase().includes(searchHash.toLowerCase()) ||
      (item.file_name && item.file_name.toLowerCase().includes(searchHash.toLowerCase()));

    const matchesLabel = labelFilter === 'ALL' || item.label === labelFilter;

    return matchesSearch && matchesLabel;
  });

  const totalMalware = dataset.filter(d => d.label === 'MALWARE').length;
  const totalBenign = dataset.filter(d => d.label === 'BENIGN').length;

  const handleImportHash = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputHash.trim()) return;

    const newItem: DatasetItem = {
      id: Date.now(),
      file_hash: inputHash.trim(),
      label: inputLabel,
      file_name: inputFileName.trim() || 'imported_sample.bin',
      file_type: 'SHA-256 Fingerprint',
      source: 'Admin Manual Import',
      created_at: new Date().toISOString().replace('T', ' ').slice(0, 19)
    };

    setDataset([newItem, ...dataset]);
    setShowImportModal(false);
    setInputHash('');
    setInputFileName('');
  };

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Dataset Inventory Management</h1>
            <p className="text-muted-foreground mt-2">
              Malware & Benign fingerprint hashes database for cloud-assisted virus engine
            </p>
          </div>
          <div className="flex gap-2">
            <Button onClick={fetchDataset} variant="outline" className="gap-2" disabled={loading}>
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </Button>
            <Button onClick={() => setShowImportModal(true)} className="gap-2">
              <Upload className="w-4 h-4" /> Import Hash
            </Button>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Total Samples Registered</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold">{dataset.length}</div>
              <Database className="w-5 h-5 text-muted-foreground" />
            </CardContent>
          </Card>
          <Card className="border-rose-500/30 bg-rose-950/10">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-rose-400">Malware Fingerprints</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-rose-400">{totalMalware}</div>
              <ShieldAlert className="w-5 h-5 text-rose-500" />
            </CardContent>
          </Card>
          <Card className="border-emerald-500/30 bg-emerald-950/10">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-emerald-400">Benign Whitelist Samples</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-emerald-400">{totalBenign}</div>
              <ShieldCheck className="w-5 h-5 text-emerald-500" />
            </CardContent>
          </Card>
        </div>

        {/* Search & Filter */}
        <div className="flex flex-col sm:flex-row gap-4 justify-between items-center bg-card p-4 rounded-xl border border-border">
          <div className="relative w-full sm:w-96">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search SHA-256 Hash or File Name..."
              value={searchHash}
              onChange={(e) => setSearchHash(e.target.value)}
              className="pl-9 font-mono text-xs"
            />
          </div>
          <div className="flex gap-2 w-full sm:w-auto">
            <Button
              size="sm"
              variant={labelFilter === 'ALL' ? 'default' : 'outline'}
              onClick={() => setLabelFilter('ALL')}
            >
              All Labels
            </Button>
            <Button
              size="sm"
              variant={labelFilter === 'MALWARE' ? 'destructive' : 'outline'}
              onClick={() => setLabelFilter('MALWARE')}
            >
              Malware Only
            </Button>
            <Button
              size="sm"
              variant={labelFilter === 'BENIGN' ? 'default' : 'outline'}
              onClick={() => setLabelFilter('BENIGN')}
              className={labelFilter === 'BENIGN' ? 'bg-emerald-600 hover:bg-emerald-700' : ''}
            >
              Benign Only
            </Button>
          </div>
        </div>

        {/* Dataset Table */}
        <div className="bg-card border border-border rounded-xl overflow-hidden shadow-sm">
          <table className="w-full text-left text-sm">
            <thead className="bg-muted/50 border-b border-border text-muted-foreground uppercase text-[11px] tracking-wider font-semibold">
              <tr>
                <th className="px-6 py-4">SHA-256 Hash</th>
                <th className="px-6 py-4">Label</th>
                <th className="px-6 py-4">Sample Name</th>
                <th className="px-6 py-4">Source</th>
                <th className="px-6 py-4">Added Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border font-mono text-xs">
              {filteredItems.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-muted-foreground font-sans">
                    No dataset entries match your search.
                  </td>
                </tr>
              ) : (
                filteredItems.map((item) => (
                  <tr key={item.id} className="hover:bg-muted/30 transition-colors">
                    <td className="px-6 py-4 text-xs font-mono font-medium text-foreground truncate max-w-xs" title={item.file_hash}>
                      {item.file_hash}
                    </td>
                    <td className="px-6 py-4">
                      {item.label === 'MALWARE' ? (
                        <span className="px-2 py-1 rounded text-[10px] font-bold bg-rose-500/20 text-rose-300 border border-rose-500/30">
                          MALWARE
                        </span>
                      ) : (
                        <span className="px-2 py-1 rounded text-[10px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                          BENIGN
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 font-sans font-medium text-foreground">{item.file_name || 'Unspecified'}</td>
                    <td className="px-6 py-4 font-sans text-muted-foreground">{item.source || 'Upload'}</td>
                    <td className="px-6 py-4 font-sans text-muted-foreground">{item.created_at || 'Recently'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Modal Import Hash */}
        {showImportModal && (
          <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
            <form onSubmit={handleImportHash} className="bg-card border border-border rounded-xl max-w-md w-full p-6 shadow-2xl space-y-4 animate-in fade-in zoom-in-95">
              <div className="flex justify-between items-center border-b border-border pb-3">
                <h3 className="text-lg font-bold flex items-center gap-2">
                  <Database className="w-5 h-5 text-primary" /> Import Hash Fingerprint
                </h3>
                <Button size="sm" type="button" variant="ghost" onClick={() => setShowImportModal(false)}>✕</Button>
              </div>

              <div className="space-y-3 text-sm">
                <div>
                  <label className="text-xs text-muted-foreground block mb-1 font-medium">SHA-256 Hash</label>
                  <Input
                    required
                    placeholder="64-character SHA-256 hex string..."
                    className="font-mono text-xs"
                    value={inputHash}
                    onChange={(e) => setInputHash(e.target.value)}
                  />
                </div>
                <div>
                  <label className="text-xs text-muted-foreground block mb-1 font-medium">Classification Label</label>
                  <select
                    className="w-full bg-background border border-input rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                    value={inputLabel}
                    onChange={(e) => setInputLabel(e.target.value as any)}
                  >
                    <option value="MALWARE">MALWARE (Threat)</option>
                    <option value="BENIGN">BENIGN (Safe Whitelist)</option>
                  </select>
                </div>
                <div>
                  <label className="text-xs text-muted-foreground block mb-1 font-medium">File Name / Alias (Optional)</label>
                  <Input
                    placeholder="e.g. ransomware_variant_x.exe"
                    value={inputFileName}
                    onChange={(e) => setInputFileName(e.target.value)}
                  />
                </div>
              </div>

              <div className="pt-4 border-t border-border flex justify-end gap-2">
                <Button type="button" variant="outline" onClick={() => setShowImportModal(false)}>Cancel</Button>
                <Button type="submit">Import to Dataset</Button>
              </div>
            </form>
          </div>
        )}
      </div>
    </DashboardLayout>
  )
}
