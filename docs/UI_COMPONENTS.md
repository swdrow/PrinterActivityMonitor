# UI Components Documentation

## Navigation Structure

### Tab-Based Navigation (ContentView.swift)

| Tab | Icon | Order | Purpose |
|-----|------|-------|---------|
| Dashboard | `printer.fill` | 0 | Main status display |
| Controls | `slider.horizontal.3` | 1 | Print operations |
| AMS | `tray.2.fill` | 2 | Filament management |
| History | `clock.arrow.circlepath` | 3 | Print history |
| Settings | `gear` | 4 | Configuration |
| Debug | `ant.fill` | 5 | Testing (DEBUG only) |

---

## View Hierarchy

```
ContentView (TabView root)
├── PrinterDashboardView (Tab 0)
│   ├── NotConfiguredCard
│   ├── LoadingSkeletonView
│   ├── ConnectionErrorCard
│   ├── ConnectionStatusView
│   ├── PrinterStatusCard
│   │   └── TemperatureQuickView
│   ├── LiveActivityControlCard
│   └── StatsGridView
│
├── PrintControlView (Tab 1)
│   ├── PrintStatusHeader
│   ├── PrintControlsSection
│   ├── TemperatureControlSection
│   └── LightControlSection
│
├── AMSView (Tab 2)
│   ├── AMSDisconnectedCard
│   ├── HumidityCard
│   ├── FilamentSlotsGrid
│   │   └── FilamentSlotCard
│   ├── LowFilamentWarningCard
│   └── AMSQuickActionsCard
│
├── PrintHistoryView (Tab 3)
│   ├── StatisticsCard
│   └── HistoryEntryCard
│
├── SettingsView (Tab 4)
│   ├── Connection Section
│   ├── Display Fields Section
│   ├── Appearance Section
│   └── TokenInfoSheet
│
└── DebugView (Tab 5, DEBUG)
    ├── Connection Status
    ├── Quick Actions
    ├── Sensor Test Results
    └── Configuration Info
```

---

## Main Views

### PrinterDashboardView

**Purpose**: Real-time printer status display

**Key States**:
- Not Configured: Warning card
- Loading: Skeleton with shimmer
- Error: Retry card
- Normal: Full status

**Components**:
- ConnectionStatusView: Green/red indicator
- PrinterStatusCard: Model icon, file name, progress, temps
- LiveActivityControlCard: Start/Stop activity
- StatsGridView: Optional stat cards

### AMSView

**Purpose**: Filament management

**Components**:
- HumidityCard: Humidity bar, drying controls
- FilamentSlotsGrid: 2x2 grid of slots
- FilamentSlotCard: Color, material, remaining %
- LowFilamentWarningCard: Slots < 20%
- AMSQuickActionsCard: Refresh RFID, Retract

### SettingsView

**Sections**:
1. Home Assistant Connection (URL, token, prefix)
2. Display Fields (toggles)
3. Appearance (color picker, compact mode)
4. Updates (refresh interval)
5. Notifications
6. Reset

### DeviceSetupView

**Setup Steps**:
1. Welcome: Discovery intro
2. Discovering: Progress spinner
3. Select Devices: Toggle printers/AMS
4. Complete: Summary

---

## Reusable Components

### GlassCard

**Purpose**: Frosted glass container with depth

**Style**:
- Base: `.ultraThinMaterial`
- Gradient overlay: White opacity
- Shadow: Two-layer (black)
- Border radius: 24pt

**Variants**:
- GlassCard: Standard
- GlassCardWithShimmer: Rainbow border
- MiniGlass: Compact 12pt radius

### ProgressBar

**Purpose**: Animated progress display

**Parameters**:
```swift
progress: Double     // 0.0-1.0
accentColor: AccentColorOption
height: CGFloat      // Default: 12
```

**Features**:
- Animated fill with gradient
- Glow effect
- Rainbow: 7-color + shimmer

### RainbowShimmer

**Effects**:
- GeminiRainbowShimmer: Flowing gradient
- RainbowProgressBar: 7-color animated
- RainbowAccent: Rotating hue
- ShimmeringText: Gradient text

**Modifiers**:
```swift
.geminiShimmer(intensity:, cornerRadius:)
.rainbowShimmer(opacity:, cornerRadius:)
.rainbowBorder(lineWidth:, cornerRadius:)
```

---

## Live Activity Views

**File**: `PrinterLiveActivityView.swift`

### Lock Screen View

**Compact Layout**:
```
[Printer] 45% | [████████░░] | 2h15m [●]
```

**Full Layout**:
```
[Ring 45%] | Benchy.gcode [Printing]
           | ⏱ 2h15m ~3:45 PM
           | [🔥215°] [🛏️60°]
```

### Dynamic Island

- **Expanded**: Full width with stats
- **Compact Leading**: Icon + progress
- **Compact Trailing**: Time remaining
- **Minimal**: Printer icon only

---

## Theming

### AccentColorOption

```swift
case cyan, blue, purple, pink, orange, green, rainbow
```

**Application Points**:
- Tab bar tint
- Buttons
- Progress bars
- Borders
- Icons

### Color Mapping

| Option | Color |
|--------|-------|
| cyan | .cyan |
| blue | .blue |
| purple | .purple |
| pink | .pink |
| orange | .orange |
| green | .green |
| rainbow | AngularGradient |

---

## State Handling

### Loading States

**LoadingSkeletonView**:
- RoundedRectangle placeholders
- `.shimmer()` modifier (0.6→1.0 opacity)
- 1.2s animation

### Error States

**ConnectionErrorCard**:
- Red warning icon
- Error message
- Retry button

**AMSDisconnectedCard**:
- Orange warning
- "AMS Not Detected"

### Empty States

**NotConfiguredCard**:
- Question mark icon
- Configuration instructions

---

## Accessibility

### Current Status
- ✅ Status badges use icon + text + color
- ✅ Primary/secondary text contrast
- ✅ Buttons minimum 44pt height
- ✅ Haptic feedback on actions

### Improvements Needed
- Add `.accessibilityLabel()` to icons
- Add `.accessibilityLiveRegion()` for updates
- Check `accessibilityReduceMotion` for animations

---

## Component Reference

| Component | File | Purpose |
|-----------|------|---------|
| GlassCard | Components/ | Glass container |
| ProgressBar | Components/ | Progress display |
| CompactProgressRing | Components/ | Circular progress |
| RainbowShimmer | Components/ | Rainbow effects |
| FilamentSlotCard | AMSView | Filament slot |
| StatisticsCard | PrintHistoryView | Stats summary |
