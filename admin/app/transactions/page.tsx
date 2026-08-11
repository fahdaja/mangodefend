'use client'

import { useState, useEffect } from 'react'
import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { StatusBadge } from '@/components/data-table'
import { Search, RefreshCw, Receipt, CheckCircle, Clock, XCircle, AlertCircle, Eye, ExternalLink } from 'lucide-react'
import { api } from '@/lib/api'

interface Transaction {
  id: number;
  order_id: string;
  gross_amount: number;
  payment_type: string;
  transaction_status: 'SUCCESS' | 'PENDING' | 'FAILED' | 'EXPIRED';
  transaction_time: string;
  settlement_time?: string;
  redirect_url?: string;
  user?: { id: number; email: string };
  plan?: { id: number; name: string };
}

const mockTransactions: Transaction[] = [
  {
    id: 1,
    order_id: 'TRX-20260811-001',
    gross_amount: 150000,
    payment_type: 'gopay',
    transaction_status: 'SUCCESS',
    transaction_time: '2026-08-11 14:20:00',
    settlement_time: '2026-08-11 14:21:15',
    user: { id: 1, email: 'user@mangodefend.com' },
    plan: { id: 2, name: 'Pro Plan' }
  },
  {
    id: 2,
    order_id: 'TRX-20260811-002',
    gross_amount: 500000,
    payment_type: 'bank_transfer',
    transaction_status: 'PENDING',
    transaction_time: '2026-08-11 15:10:00',
    user: { id: 2, email: 'enterprise@company.com' },
    plan: { id: 3, name: 'Enterprise Plan' }
  },
  {
    id: 3,
    order_id: 'TRX-20260810-009',
    gross_amount: 150000,
    payment_type: 'qris',
    transaction_status: 'EXPIRED',
    transaction_time: '2026-08-10 10:00:00',
    user: { id: 3, email: 'client3@test.com' },
    plan: { id: 2, name: 'Pro Plan' }
  }
];

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState<Transaction[]>(mockTransactions);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [selectedTx, setSelectedTx] = useState<Transaction | null>(null);
  const [loading, setLoading] = useState(false);

  const fetchTransactions = async () => {
    setLoading(true);
    try {
      const res = await api.get('/transactions');
      if (res.data && Array.isArray(res.data)) {
        setTransactions(res.data);
      }
    } catch {
      // Keep mock data if backend call fails during dev
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTransactions();
  }, []);

  const filteredTransactions = transactions.filter((tx) => {
    const matchesSearch =
      tx.order_id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      tx.user?.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      tx.payment_type?.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesStatus =
      statusFilter === 'ALL' || tx.transaction_status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  const totalSuccess = transactions.filter(t => t.transaction_status === 'SUCCESS').length;
  const totalPending = transactions.filter(t => t.transaction_status === 'PENDING').length;
  const totalRevenue = transactions
    .filter(t => t.transaction_status === 'SUCCESS')
    .reduce((sum, t) => sum + Number(t.gross_amount), 0);

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Transactions Management</h1>
            <p className="text-muted-foreground mt-2">
              Monitor Midtrans payment transactions, subscriptions, and receipts
            </p>
          </div>
          <Button onClick={fetchTransactions} variant="outline" className="gap-2" disabled={loading}>
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh Data
          </Button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Total Revenue</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-emerald-500">
                Rp {totalRevenue.toLocaleString('id-ID')}
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Successful Payments</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-emerald-400">{totalSuccess}</div>
              <CheckCircle className="w-5 h-5 text-emerald-500" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Pending Payments</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold text-amber-400">{totalPending}</div>
              <Clock className="w-5 h-5 text-amber-500" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Total Transactions</CardTitle>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <div className="text-2xl font-bold">{transactions.length}</div>
              <Receipt className="w-5 h-5 text-muted-foreground" />
            </CardContent>
          </Card>
        </div>

        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-4 justify-between items-center bg-card p-4 rounded-xl border border-border">
          <div className="relative w-full sm:w-80">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search Order ID, Email, Payment Method..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>
          <div className="flex gap-2 w-full sm:w-auto overflow-x-auto">
            {['ALL', 'SUCCESS', 'PENDING', 'EXPIRED', 'FAILED'].map((status) => (
              <Button
                key={status}
                size="sm"
                variant={statusFilter === status ? 'default' : 'outline'}
                onClick={() => setStatusFilter(status)}
                className="text-xs"
              >
                {status}
              </Button>
            ))}
          </div>
        </div>

        {/* Table */}
        <div className="bg-card border border-border rounded-xl overflow-hidden shadow-sm">
          <table className="w-full text-left text-sm">
            <thead className="bg-muted/50 border-b border-border text-muted-foreground uppercase text-[11px] tracking-wider font-semibold">
              <tr>
                <th className="px-6 py-4">Order ID</th>
                <th className="px-6 py-4">User</th>
                <th className="px-6 py-4">Plan</th>
                <th className="px-6 py-4">Amount</th>
                <th className="px-6 py-4">Method</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4">Date</th>
                <th className="px-6 py-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filteredTransactions.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-6 py-8 text-center text-muted-foreground">
                    No transactions found.
                  </td>
                </tr>
              ) : (
                filteredTransactions.map((tx) => (
                  <tr key={tx.id} className="hover:bg-muted/30 transition-colors">
                    <td className="px-6 py-4 font-mono font-medium">{tx.order_id}</td>
                    <td className="px-6 py-4">{tx.user?.email || 'N/A'}</td>
                    <td className="px-6 py-4 font-medium">{tx.plan?.name || 'N/A'}</td>
                    <td className="px-6 py-4 font-semibold text-emerald-400">
                      Rp {Number(tx.gross_amount).toLocaleString('id-ID')}
                    </td>
                    <td className="px-6 py-4 uppercase text-xs font-mono">{tx.payment_type || 'MIDTRANS'}</td>
                    <td className="px-6 py-4">
                      <StatusBadge
                        status={
                          tx.transaction_status === 'SUCCESS'
                            ? 'active'
                            : tx.transaction_status === 'PENDING'
                            ? 'pending'
                            : 'inactive'
                        }
                      />
                    </td>
                    <td className="px-6 py-4 text-xs text-muted-foreground">{tx.transaction_time}</td>
                    <td className="px-6 py-4 text-right">
                      <Button size="sm" variant="ghost" onClick={() => setSelectedTx(tx)} className="h-8 px-2">
                        <Eye className="w-4 h-4 mr-1" /> Details
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Modal Details */}
        {selectedTx && (
          <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
            <div className="bg-card border border-border rounded-xl max-w-lg w-full p-6 shadow-2xl space-y-6 animate-in fade-in zoom-in-95">
              <div className="flex justify-between items-center border-b border-border pb-4">
                <h3 className="text-xl font-bold flex items-center gap-2">
                  <Receipt className="w-5 h-5 text-primary" /> Transaction Details
                </h3>
                <Button size="sm" variant="ghost" onClick={() => setSelectedTx(null)}>✕</Button>
              </div>

              <div className="space-y-4 text-sm">
                <div className="grid grid-cols-2 gap-4 bg-muted/40 p-4 rounded-lg font-mono text-xs">
                  <div>
                    <span className="text-muted-foreground block mb-1">Order ID</span>
                    <span className="font-bold text-foreground">{selectedTx.order_id}</span>
                  </div>
                  <div>
                    <span className="text-muted-foreground block mb-1">Status</span>
                    <StatusBadge
                      status={
                        selectedTx.transaction_status === 'SUCCESS'
                          ? 'active'
                          : selectedTx.transaction_status === 'PENDING'
                          ? 'pending'
                          : 'inactive'
                      }
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">User Email:</span>
                    <span className="font-medium">{selectedTx.user?.email || 'N/A'}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Plan:</span>
                    <span className="font-medium">{selectedTx.plan?.name || 'N/A'}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Gross Amount:</span>
                    <span className="font-bold text-emerald-400">Rp {Number(selectedTx.gross_amount).toLocaleString('id-ID')}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Payment Type:</span>
                    <span className="font-mono uppercase">{selectedTx.payment_type || 'Midtrans'}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Transaction Time:</span>
                    <span>{selectedTx.transaction_time}</span>
                  </div>
                </div>

                {selectedTx.redirect_url && (
                  <div className="pt-2">
                    <a
                      href={selectedTx.redirect_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 text-xs text-primary hover:underline"
                    >
                      Open Midtrans Payment Page <ExternalLink className="w-3 h-3" />
                    </a>
                  </div>
                )}
              </div>

              <div className="pt-4 border-t border-border text-right">
                <Button variant="outline" onClick={() => setSelectedTx(null)}>Close</Button>
              </div>
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  )
}
