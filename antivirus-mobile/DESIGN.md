---
name: Aegis Sentinel Global Design System
description: A premium, high-fidelity design system for a modern mobile antivirus
  application. Built on deep navy surfaces with vibrant emerald accents, focusing
  on trust, security, and precision.
colors:
  surface: '#051424'
  surface-dim: '#010f1f'
  surface-bright: '#2c3a4c'
  surface-container-lowest: '#010f1f'
  surface-container-low: '#0d1c2d'
  surface-container: '#111e2f'
  surface-container-high: '#1a293b'
  surface-container-highest: '#243447'
  primary: '#10b981'
  on-primary: '#ffffff'
  primary-container: rgba(16, 185, 129, 0.15)
  secondary: '#10b981'
  on-secondary: '#ffffff'
  error: '#ef4444'
  on-error: '#ffffff'
  warning: '#f59e0b'
  on-warning: '#ffffff'
  info: '#3b82f6'
  on-surface: '#ffffff'
  on-surface-variant: '#94a3b8'
  outline: '#334155'
  outline-variant: rgba(51, 65, 85, 0.5)
  inverse-surface: '#dde4dd'
  inverse-on-surface: '#2b322d'
  surface-tint: '#4edea3'
  on-primary-container: '#00422b'
  inverse-primary: '#006c49'
  secondary-container: '#00a572'
  on-secondary-container: '#00311f'
  tertiary: '#ffb3af'
  on-tertiary: '#650911'
  tertiary-container: '#fc7c78'
  on-tertiary-container: '#711419'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#6ffbbe'
  primary-fixed-dim: '#4edea3'
  on-primary-fixed: '#002113'
  on-primary-fixed-variant: '#005236'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffdad7'
  tertiary-fixed-dim: '#ffb3af'
  on-tertiary-fixed: '#410005'
  on-tertiary-fixed-variant: '#842225'
  background: '#0e1511'
  on-background: '#dde4dd'
  surface-variant: '#2f3632'
typography:
  font-family: Inter, sans-serif
  display:
    large: 700 32px/1.2 'Inter'
  headline:
    large: 700 24px/1.3 'Inter'
    medium: 600 20px/1.3 'Inter'
    small: 600 18px/1.3 'Inter'
  title:
    large: 600 16px/1.4 'Inter'
    medium: 500 16px/1.4 'Inter'
    small: 500 14px/1.4 'Inter'
  body:
    large: 400 16px/1.5 'Inter'
    medium: 400 14px/1.5 'Inter'
    small: 400 12px/1.5 'Inter'
  label:
    large: 500 14px/1.2 'Inter'
    medium: 500 12px/1.2 'Inter'
    small: 500 10px/1.2 'Inter'
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '1.3'
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '1.3'
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: '1.3'
  title-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: '1.4'
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: '1.4'
  title-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.5'
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: '1.5'
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.2'
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.2'
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '500'
    lineHeight: '1.2'
spacing:
  margin-xs: 8px
  margin-sm: 12px
  margin-md: 16px
  margin-lg: 24px
  stack-gap-xs: 4px
  stack-gap-sm: 8px
  stack-gap-md: 16px
  stack-gap-lg: 24px
  container-padding: 16px
shapes:
  roundness-none: 0px
  roundness-xs: 4px
  roundness-sm: 8px
  roundness-md: 12px
  roundness-lg: 16px
  roundness-xl: 24px
  roundness-full: 9999px
components:
  Cards:
    background: var(--surface-container)
    border-radius: var(--roundness-lg)
    padding: var(--spacing-margin-md)
    border: 1px solid var(--outline-variant)
  PrimaryButton:
    background: var(--primary)
    text: var(--on-primary)
    border-radius: var(--roundness-md)
    font: var(--typography-label-large)
    height: 48px
  TopAppBar:
    background: rgba(5, 20, 36, 0.8)
    blur: 12px
    height: 64px
    text: var(--on-surface)
  BottomNavBar:
    background: var(--surface-container)
    height: 80px
    active-item: var(--primary)
    inactive-item: var(--on-surface-variant)
elevation:
  low: 0 2px 4px rgba(0,0,0,0.1)
  medium: 0 4px 8px rgba(0,0,0,0.2)
  high: 0 8px 16px rgba(0,0,0,0.3)
  glow-primary: 0 0 20px rgba(16, 185, 129, 0.3)
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
---
