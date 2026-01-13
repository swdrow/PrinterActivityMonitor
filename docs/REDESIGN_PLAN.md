# Printer Activity Monitor - Complete Redesign Plan

## Design Philosophy: "Liquid Aurora"

A refined iOS-native dark mode aesthetic inspired by iOS 18's liquid glass with soft aurora-style gradients. The design prioritizes **clarity**, **calm**, and **sophistication** over flashy effects.

---

## Part 1: Design System Specification

### 1.1 Color Palette

#### Primary Accent: Celestial Cyan
```swift
// Single primary accent - all UI elements use this
static let accent = Color(red: 0.35, green: 0.78, blue: 0.98)  // #59C7FA
static let accentLight = Color(red: 0.55, green: 0.85, blue: 1.0)
static let accentDark = Color(red: 0.2, green: 0.55, blue: 0.75)
```

#### Aurora Gradient (Soft, Not Rainbow)
```swift
// Subtle 3-color aurora for special elements only
static let auroraStart = Color(red: 0.35, green: 0.78, blue: 0.98)   // Cyan
static let auroraMid = Color(red: 0.55, green: 0.6, blue: 0.95)      // Soft violet
static let auroraEnd = Color(red: 0.45, green: 0.85, blue: 0.75)     // Mint
```

#### Semantic Colors
```swift
static let success = Color(red: 0.3, green: 0.75, blue: 0.55)   // Muted teal-green
static let warning = Color(red: 0.95, green: 0.7, blue: 0.35)   // Warm amber
static let error = Color(red: 0.9, green: 0.4, blue: 0.45)      // Soft coral
static let neutral = Color(red: 0.55, green: 0.55, blue: 0.6)   // Cool gray
```

#### Background System
```swift
// Deep space background - NOT pure black
static let backgroundPrimary = Color(red: 0.04, green: 0.04, blue: 0.06)    // Near black
static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.10)  // Card base
static let backgroundTertiary = Color(red: 0.12, green: 0.12, blue: 0.14)   // Elevated

// Surface colors for glass
static let surfaceGlass = Color.white.opacity(0.05)
static let surfaceGlassElevated = Color.white.opacity(0.08)
```

#### Text Colors
```swift
static let textPrimary = Color.white.opacity(0.95)
static let textSecondary = Color.white.opacity(0.6)
static let textTertiary = Color.white.opacity(0.4)
static let textDisabled = Color.white.opacity(0.25)
```

---

### 1.2 Typography Scale

```swift
// Using SF Pro with refined weights
struct Typography {
    // Display - Screen titles only
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)

    // Headlines
    static let headline = Font.system(size: 20, weight: .semibold)
    static let headlineSmall = Font.system(size: 17, weight: .semibold)

    // Body
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .medium)

    // Labels
    static let label = Font.system(size: 13, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)

    // Numeric (for stats/progress)
    static let numeric = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let numericSmall = Font.system(size: 17, weight: .semibold, design: .rounded)
}
```

---

### 1.3 Spacing System (8pt Grid)

```swift
struct Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

---

### 1.4 Corner Radii

```swift
struct Radius {
    static let small: CGFloat = 8      // Buttons, badges
    static let medium: CGFloat = 12    // Small cards, inputs
    static let large: CGFloat = 16     // Standard cards
    static let xl: CGFloat = 20        // Modal sheets
    static let full: CGFloat = 9999    // Pills, circular
}
```

---

### 1.5 Shadow System

```swift
struct Shadows {
    // Subtle elevation - NOT heavy black shadows
    static let subtle = (color: Color.black.opacity(0.15), radius: 8, y: 4)
    static let medium = (color: Color.black.opacity(0.2), radius: 16, y: 8)
    static let glow = (color: accent.opacity(0.25), radius: 20, y: 0)  // Accent glow
}
```

---

## Part 2: Component Redesign

### 2.1 Glass Card (Simplified)

**Current Issues:**
- Too many layered gradients
- Heavy borders create rigid feel
- Shadow too dark

**New Design:**
```swift
// Single clean glass effect
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var style: GlassStyle = .standard

    enum GlassStyle {
        case standard      // Default card
        case elevated      // More prominent
        case subtle        // Recessed/secondary
        case interactive   // Tappable items
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Single subtle top edge highlight
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}
```

---

### 2.2 Progress Ring (Live Activity)

**Current Issues:**
- Rainbow gradient is dated
- Ring too thick (competes with content)
- Percentage text inside ring is cramped

**New Design:**
```swift
// Elegant thin ring with aurora gradient
struct AuroraProgressRing: View {
    let progress: Double  // 0-100
    let size: CGFloat
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            // Progress with subtle aurora
            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(
                    AngularGradient(
                        colors: [
                            DesignSystem.accent,
                            DesignSystem.accentLight,
                            DesignSystem.accent
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Subtle glow at progress tip
            Circle()
                .trim(from: max(0, progress/100 - 0.02), to: progress/100)
                .stroke(DesignSystem.accent, lineWidth: lineWidth)
                .blur(radius: 4)
                .opacity(0.6)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
```

---

### 2.3 Tab Bar (Native iOS)

**Current Issues:**
- Floating pill highlight looks broken
- Custom styling fights iOS conventions

**New Design:**
```swift
// Use standard iOS tab bar with tint color only
TabView(selection: $selectedTab) {
    // tabs...
}
.tint(DesignSystem.accent)
// Remove all custom tab bar styling - let iOS handle it
```

---

### 2.4 Stat Badges

**Current Issues:**
- Too much visual weight
- Colors compete with each other

**New Design:**
```swift
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String?
    var style: BadgeStyle = .default

    enum BadgeStyle {
        case `default`     // Neutral background
        case accent        // Highlighted
        case temperature   // Warm tint for temps
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.08))
        }
    }

    var iconColor: Color {
        switch style {
        case .default: return .white.opacity(0.6)
        case .accent: return DesignSystem.accent
        case .temperature: return DesignSystem.warning.opacity(0.8)
        }
    }
}
```

---

### 2.5 Status Indicator

**Current Issues:**
- Bright green pill is jarring
- Multiple status colors compete

**New Design:**
```swift
struct StatusIndicator: View {
    let status: PrintStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(status.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical: 5)
        .background {
            Capsule()
                .fill(statusColor.opacity(0.12))
        }
    }

    var statusColor: Color {
        switch status {
        case .printing: return DesignSystem.accent
        case .paused: return DesignSystem.warning
        case .finished: return DesignSystem.success
        case .failed: return DesignSystem.error
        case .idle: return DesignSystem.neutral
        }
    }
}
```

---

## Part 3: Live Activity Redesign

### 3.1 Lock Screen Layout (Simplified)

**Information Hierarchy:**
1. **Primary**: Progress percentage + ring
2. **Secondary**: File name + time remaining
3. **Tertiary**: Status + key stats

```
┌─────────────────────────────────────────────────┐
│  ╭──────╮                                       │
│  │      │   benchy_test.3mf                     │
│  │  67% │   ○ Printing                          │
│  │      │                                       │
│  ╰──────╯   1h 24m remaining  ·  ETA 23:45     │
│                                                 │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                 │
│  ⬡ 142/280    🔥 220°    🛏️ 60°               │
└─────────────────────────────────────────────────┘
```

**Design Principles:**
- Progress ring: 60pt, 4pt stroke, aurora gradient
- No percentage text inside ring (too cramped) - show beside it
- File name: Truncate with ... (max 20 chars)
- Status: Subtle pill, not bright green
- Stats: Monochrome icons, neutral backgrounds
- Single accent color throughout

---

### 3.2 Dynamic Island Compact

**Current Issues:**
- Progress ring too small for image inside
- Too much info crammed in trailing

**New Design:**
```
Leading: [Progress arc + cube icon] (24pt)
Trailing: [67% · 1:24] (percentage + time only)
```

- Remove image from compact ring (too small)
- Use simple cube icon as printer symbol
- Trailing: Just percentage and time, no icons

---

### 3.3 Dynamic Island Expanded

**Simplified Layout:**
```
┌────────────────────────────────────────┐
│  🖨️ 67%        benchy.3mf      ⏱ 1:24  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  ⬡ 142/280        🔥 220°    🛏️ 60°   │
└────────────────────────────────────────┘
```

---

## Part 4: Screen-by-Screen Redesign

### 4.1 Dashboard (Idle State)

**Current Issues:**
- Too much empty space
- "No print" card feels incomplete
- Cards too heavy

**New Design:**
```
┌──────────────────────────────────────┐
│  Printer Monitor                     │
│  ● Connected                         │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  ◇  No active print            │  │
│  │     Ready for next job         │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Printer Status                │  │
│  │  ┌──────┐ ┌──────┐ ┌──────┐   │  │
│  │  │ 25°  │ │ 25°  │ │ 28°  │   │  │
│  │  │Nozzle│ │ Bed  │ │Chamber│  │  │
│  │  └──────┘ └──────┘ └──────┘   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Recent Prints                 │  │
│  │  benchy.3mf      2h ago   ✓   │  │
│  │  bracket.3mf     Yesterday ✓   │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

**Improvements:**
- Show temperature status even when idle
- Add "Recent Prints" preview
- Lighter cards, more breathing room
- Remove 3D cube icon (use simple diamond)

---

### 4.2 Dashboard (Printing State)

```
┌──────────────────────────────────────┐
│  Printer Monitor                     │
│  ● Printing                          │
│                                      │
│  ┌────────────────────────────────┐  │
│  │     ╭────────╮                 │  │
│  │     │   67%  │  benchy.3mf    │  │
│  │     │  ◯━━━━ │  ○ Printing    │  │
│  │     ╰────────╯                 │  │
│  │                                │  │
│  │  1h 24m remaining              │  │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━  │  │
│  │                                │  │
│  │  ⬡ 142/280  🔥 220°  🛏️ 60°  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌─────────────┐ ┌─────────────┐    │
│  │   ⏸ Pause   │ │   ⏹ Stop    │    │
│  └─────────────┘ └─────────────┘    │
│                                      │
└──────────────────────────────────────┘
```

---

### 4.3 AMS Screen

**Current Issues:**
- Environment card cluttered
- Slot cards too heavy
- Quick actions buttons clash

**New Design:**
```
┌──────────────────────────────────────┐
│  AMS                                 │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Environment                   │  │
│  │  ┌──────────┐ ┌──────────┐    │  │
│  │  │  🌡️ 24°  │ │  💧 32%  │    │  │
│  │  │   Temp   │ │ Humidity │    │  │
│  │  └──────────┘ └──────────┘    │  │
│  │                                │  │
│  │  [ Start Drying ]             │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Filament Slots                │  │
│  │  ┌────────┐ ┌────────┐        │  │
│  │  │ ● PETG │ │ ● PC   │        │  │
│  │  │ 220°C  │ │ 260°C  │        │  │
│  │  └────────┘ └────────┘        │  │
│  │  ┌────────┐ ┌────────┐        │  │
│  │  │ ◉ PLA  │ │ ● PLA  │        │  │
│  │  │ 200°C  │ │ 200°C  │        │  │
│  │  └────────┘ └────────┘        │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

**Improvements:**
- Split temp/humidity into two clean cards
- Remove humidity progress bar (not useful for low values)
- Simpler slot cards with color dot + material
- Remove "No RFID" text (just omit percentage)
- Muted quick actions (secondary buttons)

---

## Part 5: Implementation Plan

### Phase 1: Design System Foundation (Priority: Critical)
**Create: `DesignSystem.swift`**

1. [ ] Define color tokens (accent, semantic, backgrounds, text)
2. [ ] Define typography scale
3. [ ] Define spacing constants
4. [ ] Define corner radii
5. [ ] Define shadow system
6. [ ] Create color extensions for hex conversion

**Estimated: 1 file, ~150 lines**

---

### Phase 2: Core Components (Priority: Critical)
**Update: Components/**

1. [ ] Refactor `GlassCard.swift` → `LiquidGlassCard.swift`
   - Simplify to single clean implementation
   - Remove multiple variants (consolidate)
   - Use design tokens

2. [ ] Create `AuroraProgressRing.swift`
   - Thin elegant ring
   - Subtle aurora gradient (not rainbow)
   - Configurable size/stroke

3. [ ] Create `StatBadge.swift`
   - Neutral monochrome style
   - Optional accent highlight
   - Consistent sizing

4. [ ] Create `StatusIndicator.swift`
   - Subtle pill with dot
   - Status-aware colors

5. [ ] Simplify `DarkModeBackground.swift`
   - Remove complex animations
   - Single clean ambient style
   - Optional subtle aurora

6. [ ] Remove/deprecate `RainbowShimmer.swift`
   - Replace rainbow with aurora
   - Remove flashy effects

**Estimated: 6 files, ~400 lines**

---

### Phase 3: Live Activity (Priority: High)
**Update: `PrinterLiveActivityView.swift`**

1. [ ] Implement new Lock Screen layout
   - Larger progress ring (60pt)
   - Percentage outside ring
   - Simplified stats row
   - Subtle status pill

2. [ ] Implement new Dynamic Island compact
   - Simple progress arc + icon
   - Percentage + time trailing

3. [ ] Implement new Dynamic Island expanded
   - Cleaner layout
   - Fewer competing colors

4. [ ] Remove rainbow gradient option
   - Replace with aurora
   - Single accent color

5. [ ] Fix any color inconsistencies
   - Use DesignSystem colors
   - Consistent opacity levels

**Estimated: 1 file, ~350 lines rewrite**

---

### Phase 4: Main Views (Priority: Medium)
**Update: Views/**

1. [ ] `PrinterDashboardView.swift`
   - Implement idle state design
   - Implement printing state design
   - Add recent prints section
   - Use new components

2. [ ] `AMSView.swift`
   - Split environment into temp/humidity cards
   - Simplify slot cards
   - Remove heavy styling

3. [ ] `ContentView.swift`
   - Remove custom tab bar styling
   - Use native iOS tab bar

4. [ ] Other views (Settings, History, Controls)
   - Apply design tokens
   - Use new card components
   - Consistent styling

**Estimated: 4-6 files, ~800 lines updates**

---

### Phase 5: Cleanup (Priority: Low)
**Repository maintenance**

1. [ ] Remove duplicate files ("Print Monitor/", backup files)
2. [ ] Consolidate asset catalogs
3. [ ] Remove unused rainbow components
4. [ ] Update previews for all components
5. [ ] Test on device

**Estimated: File cleanup, testing**

---

## Part 6: Files to Create/Modify

### New Files
```
PrinterActivityMonitor/
├── DesignSystem/
│   └── DesignSystem.swift          # NEW: Central design tokens
├── Components/
│   ├── LiquidGlassCard.swift       # NEW: Replaces GlassCard
│   ├── AuroraProgressRing.swift    # NEW: Elegant progress ring
│   ├── StatBadge.swift             # NEW: Stat display component
│   └── StatusIndicator.swift       # NEW: Status pill
```

### Modified Files
```
Components/
├── DarkModeBackground.swift        # MODIFY: Simplify
├── ProgressBar.swift               # MODIFY: Use aurora
├── GlassCard.swift                 # DEPRECATE: Replace with Liquid
└── RainbowShimmer.swift            # DEPRECATE: Remove rainbow

Views/
├── PrinterDashboardView.swift      # MODIFY: New layouts
├── AMSView.swift                   # MODIFY: Simplified cards
└── ContentView.swift               # MODIFY: Native tab bar

Widget/
└── PrinterLiveActivityView.swift   # MODIFY: Complete redesign
```

### Delete Files
```
PrinterActivityMonitor/
├── ContentView 2.swift             # DELETE: Backup
├── PrinterActivityMonitorApp 2.swift # DELETE: Backup
└── Print Monitor/                  # DELETE: Duplicate directory
```

---

## Part 7: Success Criteria

### Visual Quality
- [ ] No competing accent colors
- [ ] Consistent spacing throughout
- [ ] Cards feel light, not heavy
- [ ] Progress indicators are elegant
- [ ] Status is clear but not jarring

### iOS Native Feel
- [ ] Tab bar looks native
- [ ] Follows iOS 18 aesthetic
- [ ] Smooth animations
- [ ] Accessible contrast ratios

### Live Activity Excellence
- [ ] Instantly readable progress
- [ ] Clear hierarchy
- [ ] Works on all backgrounds
- [ ] Compact modes are useful

---

## Ready to Implement

This plan provides a complete roadmap for transforming the app from its current state to a refined, Apple-native dark mode experience with the "Liquid Aurora" aesthetic.

**Recommended order:**
1. Phase 1 (Design System) - Foundation for everything
2. Phase 2 (Components) - Building blocks
3. Phase 3 (Live Activity) - Most visible to users
4. Phase 4 (Main Views) - Complete the experience
5. Phase 5 (Cleanup) - Polish

Shall I begin implementation?
