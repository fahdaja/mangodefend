'use client'

import { DashboardLayout } from '../dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Bell, Lock, Users, Palette } from 'lucide-react'
import { useState } from 'react'

export default function SettingsPage() {
  const [accountForm, setAccountForm] = useState({
    fullName: 'Admin Dashboard',
    email: 'admin@mangodefend.com',
    phone: '+62 812 3456 7890',
  })

  const [passwordForm, setPasswordForm] = useState({
    current: '',
    new: '',
    confirm: '',
  })

  const [notifications, setNotifications] = useState({
    emailAlerts: true,
    smsAlerts: false,
    dailyReport: true,
    weeklyReport: false,
  })

  const [savedMessage, setSavedMessage] = useState('')

  const handleAccountChange = (field: string, value: string) => {
    setAccountForm((prev) => ({ ...prev, [field]: value }))
  }

  const handlePasswordChange = (field: string, value: string) => {
    setPasswordForm((prev) => ({ ...prev, [field]: value }))
  }

  const handleToggleNotification = (field: string) => {
    setNotifications((prev) => ({ ...prev, [field]: !prev[field] }))
  }

  const handleSaveAccount = () => {
    setSavedMessage('Account settings saved successfully!')
    setTimeout(() => setSavedMessage(''), 3000)
  }

  const handleUpdatePassword = () => {
    if (passwordForm.new && passwordForm.new === passwordForm.confirm) {
      setSavedMessage('Password updated successfully!')
      setPasswordForm({ current: '', new: '', confirm: '' })
      setTimeout(() => setSavedMessage(''), 3000)
    }
  }
  return (
    <DashboardLayout>
      <div className="space-y-8 max-w-2xl">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
          <p className="text-muted-foreground mt-2">
            Manage your admin dashboard settings
          </p>
        </div>

        {/* Success Message */}
        {savedMessage && (
          <Card className="bg-green-50 border-green-200">
            <CardContent className="pt-6">
              <p className="text-green-700 font-medium">{savedMessage}</p>
            </CardContent>
          </Card>
        )}

        {/* Account Settings */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="w-5 h-5" />
              Account Settings
            </CardTitle>
            <CardDescription>Manage your account information</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium">Full Name</label>
                <Input
                  value={accountForm.fullName}
                  onChange={(e) => handleAccountChange('fullName', e.target.value)}
                  className="mt-2"
                />
              </div>
              <div>
                <label className="text-sm font-medium">Email</label>
                <Input
                  value={accountForm.email}
                  onChange={(e) => handleAccountChange('email', e.target.value)}
                  type="email"
                  className="mt-2"
                />
              </div>
            </div>
            <div>
              <label className="text-sm font-medium">Phone Number</label>
              <Input
                value={accountForm.phone}
                onChange={(e) => handleAccountChange('phone', e.target.value)}
                className="mt-2"
              />
            </div>
            <Button onClick={handleSaveAccount}>Save Changes</Button>
          </CardContent>
        </Card>

        {/* Security Settings */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Lock className="w-5 h-5" />
              Security
            </CardTitle>
            <CardDescription>Manage your security settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div>
              <h4 className="font-medium mb-3">Change Password</h4>
              <div className="space-y-4">
                <div>
                  <label className="text-sm font-medium">Current Password</label>
                  <Input
                    type="password"
                    placeholder="••••••••"
                    value={passwordForm.current}
                    onChange={(e) => handlePasswordChange('current', e.target.value)}
                    className="mt-2"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium">New Password</label>
                  <Input
                    type="password"
                    placeholder="••••••••"
                    value={passwordForm.new}
                    onChange={(e) => handlePasswordChange('new', e.target.value)}
                    className="mt-2"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium">Confirm Password</label>
                  <Input
                    type="password"
                    placeholder="••••••••"
                    value={passwordForm.confirm}
                    onChange={(e) => handlePasswordChange('confirm', e.target.value)}
                    className="mt-2"
                  />
                </div>
              </div>
            </div>
            <Button onClick={handleUpdatePassword}>Update Password</Button>
          </CardContent>
        </Card>

        {/* Notification Settings */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Bell className="w-5 h-5" />
              Notifications
            </CardTitle>
            <CardDescription>Manage your notification preferences</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between p-3 border border-border rounded-lg">
              <div>
                <p className="font-medium">Email Alerts</p>
                <p className="text-sm text-muted-foreground">
                  Receive email updates on activities
                </p>
              </div>
              <input
                type="checkbox"
                checked={notifications.emailAlerts}
                onChange={() => handleToggleNotification('emailAlerts')}
                className="w-5 h-5"
              />
            </div>
            <div className="flex items-center justify-between p-3 border border-border rounded-lg">
              <div>
                <p className="font-medium">SMS Alerts</p>
                <p className="text-sm text-muted-foreground">
                  Get SMS notifications
                </p>
              </div>
              <input
                type="checkbox"
                checked={notifications.smsAlerts}
                onChange={() => handleToggleNotification('smsAlerts')}
                className="w-5 h-5"
              />
            </div>
            <div className="flex items-center justify-between p-3 border border-border rounded-lg">
              <div>
                <p className="font-medium">Daily Report</p>
                <p className="text-sm text-muted-foreground">
                  Receive daily summary reports
                </p>
              </div>
              <input
                type="checkbox"
                checked={notifications.dailyReport}
                onChange={() => handleToggleNotification('dailyReport')}
                className="w-5 h-5"
              />
            </div>
            <div className="flex items-center justify-between p-3 border border-border rounded-lg">
              <div>
                <p className="font-medium">Weekly Report</p>
                <p className="text-sm text-muted-foreground">
                  Receive weekly analytics reports
                </p>
              </div>
              <input
                type="checkbox"
                checked={notifications.weeklyReport}
                onChange={() => handleToggleNotification('weeklyReport')}
                className="w-5 h-5"
              />
            </div>
            <Button onClick={() => setSavedMessage('Notification preferences saved!')}>
              Save Preferences
            </Button>
          </CardContent>
        </Card>

        {/* API Settings */}
        <Card>
          <CardHeader>
            <CardTitle>API Configuration</CardTitle>
            <CardDescription>Configure your API settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div>
              <label className="text-sm font-medium">Backend API URL</label>
              <Input
                placeholder="https://api.example.com"
                className="mt-2"
              />
              <p className="text-xs text-muted-foreground mt-2">
                Configure your NestJS backend URL for API integration
              </p>
            </div>
            <div>
              <label className="text-sm font-medium">API Key</label>
              <Input placeholder="your-api-key" type="password" className="mt-2" />
              <p className="text-xs text-muted-foreground mt-2">
                Your API key for authentication
              </p>
            </div>
            <Button>Test Connection</Button>
          </CardContent>
        </Card>

        {/* Theme Settings */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Palette className="w-5 h-5" />
              Theme
            </CardTitle>
            <CardDescription>Customize the dashboard appearance</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <p className="font-medium mb-3">Color Scheme</p>
              <div className="flex gap-3">
                <button className="p-4 border-2 border-primary rounded-lg bg-background">
                  <span className="text-sm font-medium">Light</span>
                </button>
                <button className="p-4 border-2 border-border rounded-lg bg-background hover:border-muted-foreground">
                  <span className="text-sm font-medium">Dark</span>
                </button>
                <button className="p-4 border-2 border-border rounded-lg bg-background hover:border-muted-foreground">
                  <span className="text-sm font-medium">System</span>
                </button>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Danger Zone */}
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="text-destructive">Danger Zone</CardTitle>
            <CardDescription>Irreversible actions</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="p-4 border border-destructive rounded-lg bg-destructive/5">
              <p className="font-medium mb-3">Delete Account</p>
              <p className="text-sm text-muted-foreground mb-4">
                Once you delete your account, there is no going back. Please be certain.
              </p>
              <Button variant="destructive">Delete My Account</Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}
