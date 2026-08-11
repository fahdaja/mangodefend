'use client'

import { useState, useEffect } from 'react'
import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { StatusBadge } from '@/components/data-table'
import { Cpu, Plus, CheckCircle, RefreshCw, Trash2, ToggleLeft, ToggleRight, Sparkles, Activity } from 'lucide-react'
import { api } from '@/lib/api'

interface MlModel {
  id: number;
  model_name: string;
  version: string;
  framework: string;
  accuracy: number;
  is_active: boolean;
  file_url?: string;
  created_at?: string;
}

const mockModels: MlModel[] = [
  {
    id: 1,
    model_name: 'MangoDefend Random Forest v1.2',
    version: 'v1.2.0-rf',
    framework: 'scikit-learn / ONNX',
    accuracy: 98.6,
    is_active: true,
    created_at: '2026-08-01 10:00:00'
  },
  {
    id: 2,
    model_name: 'MangoDefend XGBoost Deep Classifier',
    version: 'v1.1.0-xgb',
    framework: 'XGBoost',
    accuracy: 97.4,
    is_active: false,
    created_at: '2026-07-15 09:30:00'
  },
  {
    id: 3,
    model_name: 'MangoDefend Neural Net Lightweight',
    version: 'v1.0.0-nn',
    framework: 'TensorFlow Lite',
    accuracy: 95.8,
    is_active: false,
    created_at: '2026-06-10 14:20:00'
  }
];

export default function MlModelsPage() {
  const [models, setModels] = useState<MlModel[]>(mockModels);
  const [loading, setLoading] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  
  // Form State
  const [modelName, setModelName] = useState('');
  const [version, setVersion] = useState('');
  const [framework, setFramework] = useState('ONNX / Scikit-Learn');
  const [accuracy, setAccuracy] = useState('98.5');
  const [filePath, setFilePath] = useState('https://storage.supabase.co/models/v1.2.0-rf.onnx');
  const [checksum, setChecksum] = useState('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');


  const fetchModels = async () => {
    setLoading(true);
    try {
      const res = await api.get('/models');
      if (res.data && Array.isArray(res.data)) {
        setModels(res.data);
      }
    } catch {
      // Keep mock data if backend endpoint is offline in dev
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchModels();
  }, []);

  const handleToggleActive = async (id: number, currentStatus: boolean) => {
    try {
      await api.patch(`/models/${id}/status`, { is_active: !currentStatus });
    } catch {}

    setModels(models.map(m => {
      if (m.id === id) return { ...m, is_active: !currentStatus };
      // Exclusive active model logic
      if (!currentStatus) return { ...m, is_active: false };
      return m;
    }));
  };

  const handleDeleteModel = async (id: number) => {
    if (!confirm('Are you sure you want to delete this ML model version?')) return;
    try {
      await api.delete(`/models/${id}`);
    } catch {}
    setModels(models.filter(m => m.id !== id));
  };

  const handleAddModel = (e: React.FormEvent) => {
    e.preventDefault();
    const newModel: MlModel = {
      id: Date.now(),
      model_name: modelName || 'New MangoDefend Classifier',
      version: version || `v1.${models.length + 1}.0`,
      framework,
      accuracy: parseFloat(accuracy) || 98.0,
      is_active: false,
      created_at: new Date().toISOString().replace('T', ' ').slice(0, 19)
    };
    setModels([newModel, ...models]);
    setShowAddModal(false);
    setModelName('');
    setVersion('');
  };

  const activeModel = models.find(m => m.is_active) || models[0];

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Machine Learning Models</h1>
            <p className="text-muted-foreground mt-2">
              Manage malware detection AI model versions and active inference engine
            </p>
          </div>
          <div className="flex gap-2">
            <Button onClick={fetchModels} variant="outline" className="gap-2" disabled={loading}>
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Sync Models
            </Button>
            <Button onClick={() => setShowAddModal(true)} className="gap-2">
              <Plus className="w-4 h-4" /> Register New Model
            </Button>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="border-primary/50 bg-primary/5">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-primary flex items-center gap-2">
                <Sparkles className="w-4 h-4" /> Currently Active Model
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-xl font-bold">{activeModel?.model_name || 'None'}</div>
              <p className="text-xs text-muted-foreground mt-1 font-mono">
                Version: {activeModel?.version} • Accuracy: {activeModel?.accuracy}%
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Total Model Versions</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold">{models.length}</div>
              <Cpu className="w-5 h-5 text-muted-foreground" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Highest Accuracy Model</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-emerald-400">
                {Math.max(...models.map(m => m.accuracy), 0)}%
              </div>
              <Activity className="w-5 h-5 text-emerald-500" />
            </CardContent>
          </Card>
        </div>

        {/* Models List */}
        <div className="grid grid-cols-1 gap-4">
          {models.map((model) => (
            <Card key={model.id} className={`transition-all ${model.is_active ? 'border-emerald-500/50 bg-emerald-950/10' : ''}`}>
              <CardContent className="p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
                <div className="space-y-1">
                  <div className="flex items-center gap-3">
                    <h3 className="text-lg font-bold">{model.model_name}</h3>
                    <span className="px-2 py-0.5 rounded text-xs font-mono bg-muted font-medium">
                      {model.version}
                    </span>
                    {model.is_active && (
                      <span className="px-2 py-0.5 rounded text-xs font-semibold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 flex items-center gap-1">
                        <CheckCircle className="w-3 h-3" /> ACTIVE INFERENCE
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Framework: <span className="text-foreground font-mono">{model.framework}</span> • Accuracy: <span className="text-emerald-400 font-semibold">{model.accuracy}%</span>
                  </p>
                  <p className="text-xs text-muted-foreground">Registered: {model.created_at || 'Recently'}</p>
                </div>

                <div className="flex items-center gap-3 w-full md:w-auto justify-end">
                  <Button
                    size="sm"
                    variant={model.is_active ? 'default' : 'outline'}
                    onClick={() => handleToggleActive(model.id, model.is_active)}
                    className="gap-2"
                  >
                    {model.is_active ? (
                      <>
                        <ToggleRight className="w-5 h-5 text-emerald-400" /> Active Model
                      </>
                    ) : (
                      <>
                        <ToggleLeft className="w-5 h-5 text-muted-foreground" /> Set as Active
                      </>
                    )}
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => handleDeleteModel(model.id)}
                    className="text-rose-400 hover:text-rose-300 hover:bg-rose-950/30"
                  >
                    <Trash2 className="w-4 h-4" />
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Modal Register New Model */}
        {showAddModal && (
          <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
            <form onSubmit={handleAddModel} className="bg-card border border-border rounded-xl max-w-md w-full p-6 shadow-2xl space-y-4 animate-in fade-in zoom-in-95">
              <div className="flex justify-between items-center border-b border-border pb-3">
                <h3 className="text-lg font-bold flex items-center gap-2">
                  <Cpu className="w-5 h-5 text-primary" /> Register ML Model
                </h3>
                <Button size="sm" type="button" variant="ghost" onClick={() => setShowAddModal(false)}>✕</Button>
              </div>

              <div className="space-y-3 text-sm">
                <div>
                  <label className="text-xs text-muted-foreground block mb-1 font-medium">Model Name</label>
                  <Input
                    required
                    placeholder="e.g. MangoDefend XGBoost v2.0"
                    value={modelName}
                    onChange={(e) => setModelName(e.target.value)}
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs text-muted-foreground block mb-1 font-medium">Version Tag</label>
                    <Input
                      required
                      placeholder="e.g. v2.0.0-xgb"
                      value={version}
                      onChange={(e) => setVersion(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="text-xs text-muted-foreground block mb-1 font-medium">Validation Accuracy (%)</label>
                    <Input
                      type="number"
                      step="0.1"
                      required
                      placeholder="98.5"
                      value={accuracy}
                      onChange={(e) => setAccuracy(e.target.value)}
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs text-muted-foreground block mb-1 font-medium">Framework & Engine</label>
                  <Input
                    required
                    placeholder="ONNX / Scikit-Learn / TensorFlow"
                    value={framework}
                    onChange={(e) => setFramework(e.target.value)}
                  />
                </div>

                {/* Model File Tracking Fields */}
                <div>
                  <label className="text-xs font-semibold text-primary block mb-1">Model File Storage Path / URL (`file_path`)</label>
                  <Input
                    required
                    placeholder="e.g. https://storage.supabase.co/models/v2.0.0-xgb.onnx"
                    value={filePath}
                    onChange={(e) => setFilePath(e.target.value)}
                    className="font-mono text-xs"
                  />
                  <p className="text-[10px] text-muted-foreground mt-0.5">Location where client devices download the ONNX binary.</p>
                </div>

                <div>
                  <label className="text-xs font-semibold text-primary block mb-1">SHA-256 Checksum Integrity (`checksum`)</label>
                  <Input
                    required
                    placeholder="e.g. e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
                    value={checksum}
                    onChange={(e) => setChecksum(e.target.value)}
                    className="font-mono text-xs"
                  />
                  <p className="text-[10px] text-muted-foreground mt-0.5">Integrity hash to verify downloaded model file is untampered.</p>
                </div>
              </div>


              <div className="pt-4 border-t border-border flex justify-end gap-2">
                <Button type="button" variant="outline" onClick={() => setShowAddModal(false)}>Cancel</Button>
                <Button type="submit">Save & Register</Button>
              </div>
            </form>
          </div>
        )}
      </div>
    </DashboardLayout>
  )
}
