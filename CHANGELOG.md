# Changelog

All notable changes to Printer Activity Monitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Mock Live Activity Testing** - Test Live Activities from Debug menu without an actual print job
  - Adjustable progress, layers, time remaining, and temperatures
  - Status picker for different print states
  - Preset buttons for quick testing scenarios

- **AI-Style Glow Effects** - New visual effects for premium dark mode aesthetic
  - `AIAuraModifier` - Subtle animated ambient glow behind content
  - `RainbowAuraModifier` - Animated rainbow gradient aura
  - `GradientShimmerModifier` - Sweep shimmer animation for loading states
  - `GlowingButtonStyle` - Button style with press glow feedback

- **New Accent Colors** - 4 additional accent color options
  - Teal (#00C9A7)
  - Indigo (#6366F1)
  - Amber (#F59E0B)
  - Mint (#34D399)

- **Live Activity Overhaul** - Complete visual redesign
  - Glass morphism styling with dark blur backgrounds
  - Accent-colored ambient glow behind progress ring
  - New glass-styled stat badges
  - Icon glow effects for visual hierarchy
  - Improved Dynamic Island expanded view

### Changed
- **Unified Dark Backgrounds** - Applied `DarkModeBackground` consistently across all views
  - AMSView now uses ambient-style dark background
  - PrintHistoryView uses topGlow-style background
  - Sheet presentations use radialGlow-style background

- **Glass Component Consistency** - Converted remaining system backgrounds to glass treatment
  - StatBox in PrintHistoryView now uses `GlassCardCompact`
  - FilamentSlotCard in AMSView uses glass with filament color glow
  - TemperatureQuickView uses glass card styling

### Fixed
- Build errors related to PrinterState parameter requirements
- PrintStatus enum scope issues in DebugView

## [1.0.0] - Initial Release

### Added
- **Core Features**
  - Live Activities for Lock Screen and Dynamic Island
  - Home Assistant REST API integration
  - Real-time printer status polling
  - Multi-printer support with entity prefix system

- **Views**
  - PrinterDashboardView - Main status display
  - SettingsView - App configuration
  - NotificationSettingsView - Notification preferences
  - PrintHistoryView - Print history with statistics
  - AMSView - AMS filament slot display
  - DeviceSetupView - Auto-discovery onboarding
  - DebugView - Debug utilities
  - PrintControlView - Printer control actions

- **Services**
  - HAAPIService - Home Assistant API client
  - ActivityManager - Live Activity lifecycle
  - NotificationManager - Local notification handling
  - PrintHistoryService - Print history persistence
  - EntityDiscoveryService - Auto-discovery for printers and AMS

- **UI Components**
  - GlassCard - Frosted glass card components
  - RainbowShimmer - Animated gradient effects
  - ProgressBar - Beautiful progress indicators
  - DarkModeBackground - Unified dark backgrounds
  - PrinterIcon - Printer model icons

- **Design System**
  - Liquid glass aesthetic with blur effects
  - 7 accent color options
  - Rainbow shimmer mode
  - Dark mode optimized design

- **Notifications**
  - Print complete notifications
  - Print failed notifications
  - Print paused notifications
  - Configurable notification settings

- **AMS Integration**
  - Filament slot display
  - Color and material tracking
  - Multi-AMS support

### Technical
- iOS 17.0+ deployment target
- ActivityKit for Live Activities
- SwiftUI throughout
- UserDefaults for settings persistence
- JSON file storage for print history
