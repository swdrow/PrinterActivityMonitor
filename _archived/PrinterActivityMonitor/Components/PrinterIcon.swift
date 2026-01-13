import SwiftUI

// MARK: - Product Image Assets
// These use actual product photos for a professional look

/// General printer status icon (H2S with AMS on top)
struct PrinterStatusImage: View {
    var size: CGFloat = 40

    var body: some View {
        Image("h2s-with-ams")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

/// H2S printer image
struct H2SPrinterImage: View {
    var size: CGFloat = 40

    var body: some View {
        Image("h2s")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

/// AMS 2 Pro image
struct AMS2ProImage: View {
    var size: CGFloat = 40

    var body: some View {
        Image("ams-2-pro")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

/// Printer model types used for icon display
enum PrinterModelType: String, CaseIterable {
    case x1c = "X1C"
    case x1e = "X1E"
    case p1s = "P1S"
    case p1p = "P1P"
    case a1 = "A1"
    case a1mini = "A1 Mini"
    case h2s = "H2S"
    case h2d = "H2D"
    case unknown = "Unknown"

    /// Detect printer model from entity prefix or model string
    static func detect(from input: String?) -> PrinterModelType {
        guard let input = input else { return .unknown }
        let lowered = input.lowercased()

        if lowered.contains("x1c") || lowered.contains("x1_c") || lowered.contains("x1 carbon") || lowered.contains("x1carbon") {
            return .x1c
        } else if lowered.contains("x1e") || lowered.contains("x1_e") {
            return .x1e
        } else if lowered.contains("p1s") || lowered.contains("p1_s") {
            return .p1s
        } else if lowered.contains("p1p") || lowered.contains("p1_p") {
            return .p1p
        } else if lowered.contains("a1mini") || lowered.contains("a1_mini") || lowered.contains("a1 mini") {
            return .a1mini
        } else if lowered.contains("a1") && !lowered.contains("ams") {
            return .a1
        } else if lowered.contains("h2s") {
            return .h2s
        } else if lowered.contains("h2d") {
            return .h2d
        }

        return .unknown
    }

    var displayName: String {
        switch self {
        case .x1c: return "X1 Carbon"
        case .x1e: return "X1E"
        case .p1s: return "P1S"
        case .p1p: return "P1P"
        case .a1: return "A1"
        case .a1mini: return "A1 Mini"
        case .h2s: return "H2S"
        case .h2d: return "H2D"
        case .unknown: return "Printer"
        }
    }

    var isEnclosed: Bool {
        switch self {
        case .x1c, .x1e, .p1s, .h2s, .h2d: return true
        default: return false
        }
    }

    var accentColor: Color {
        switch self {
        case .x1c: return .orange
        case .x1e: return .purple
        case .p1s: return .cyan
        case .p1p: return .blue
        case .a1: return .green
        case .a1mini: return .mint
        case .h2s: return .teal
        case .h2d: return .indigo
        case .unknown: return .gray
        }
    }
}

/// Icon sizes
enum PrinterIconSize {
    case small   // 24pt - for lists
    case medium  // 40pt - for cards
    case large   // 60pt - for detail views

    var dimension: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 40
        case .large: return 60
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .small: return 1.5
        case .medium: return 2
        case .large: return 2.5
        }
    }
}

/// Printer icon view with model-specific design
/// Uses product images for H2S/H2D, programmatic icons for other models
struct PrinterIcon: View {
    let modelType: PrinterModelType
    var size: PrinterIconSize = .medium
    var accentColor: Color? = nil
    var showGlow: Bool = true
    var useProductImage: Bool = true  // Use actual product photos when available

    /// Initialize with a model string (from DeviceConfiguration)
    init(model: String?, size: PrinterIconSize = .medium, accentColor: Color? = nil, showGlow: Bool = true, useProductImage: Bool = true) {
        self.modelType = PrinterModelType.detect(from: model)
        self.size = size
        self.accentColor = accentColor
        self.showGlow = showGlow
        self.useProductImage = useProductImage
    }

    /// Initialize with a specific model type
    init(modelType: PrinterModelType, size: PrinterIconSize = .medium, accentColor: Color? = nil, showGlow: Bool = true, useProductImage: Bool = true) {
        self.modelType = modelType
        self.size = size
        self.accentColor = accentColor
        self.showGlow = showGlow
        self.useProductImage = useProductImage
    }

    private var effectiveAccentColor: Color {
        accentColor ?? modelType.accentColor
    }

    var body: some View {
        // Use product image for H2S/H2D if available
        if useProductImage && (modelType == .h2s || modelType == .h2d) {
            H2SPrinterImage(size: size.dimension)
                .shadow(color: showGlow ? effectiveAccentColor.opacity(0.3) : .clear, radius: size.dimension / 4)
        } else {
            programmaticIcon
        }
    }

    @ViewBuilder
    private var programmaticIcon: some View {
        ZStack {
            // Glow effect
            if showGlow {
                iconShape
                    .fill(effectiveAccentColor.opacity(0.3))
                    .blur(radius: size.dimension / 4)
            }

            // Main icon
            iconShape
                .stroke(
                    LinearGradient(
                        colors: [effectiveAccentColor, effectiveAccentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size.strokeWidth
                )

            // Fill
            iconShape
                .fill(effectiveAccentColor.opacity(0.1))

            // Model-specific details
            modelDetails
        }
        .frame(width: size.dimension, height: size.dimension)
    }

    private var iconShape: RoundedRectangle {
        let radius: CGFloat
        switch modelType {
        case .x1c, .x1e, .p1s, .h2s, .h2d:
            radius = size.dimension / 6
        case .p1p, .a1:
            radius = size.dimension / 8
        case .a1mini:
            radius = size.dimension / 4
        case .unknown:
            radius = size.dimension / 8
        }
        return RoundedRectangle(cornerRadius: radius)
    }

    @ViewBuilder
    private var modelDetails: some View {
        let detailSize = size.dimension * 0.3

        switch modelType {
        case .x1c, .x1e:
            // Lidar indicator (top)
            Circle()
                .fill(effectiveAccentColor)
                .frame(width: detailSize / 2, height: detailSize / 2)
                .offset(y: -size.dimension * 0.25)

            // Build plate lines
            buildPlateLines

        case .p1s:
            // Glass door indicator
            RoundedRectangle(cornerRadius: 2)
                .stroke(effectiveAccentColor.opacity(0.5), lineWidth: 1)
                .frame(width: size.dimension * 0.7, height: size.dimension * 0.5)

            buildPlateLines

        case .h2s, .h2d:
            // H2S/H2D - enclosed with ventilation
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(effectiveAccentColor.opacity(0.5))
                        .frame(width: 2, height: size.dimension * 0.3)
                }
            }
            .offset(y: -size.dimension * 0.2)

            buildPlateLines

        case .p1p, .a1:
            // Open frame details - vertical rails
            HStack(spacing: size.dimension * 0.5) {
                Rectangle()
                    .fill(effectiveAccentColor.opacity(0.5))
                    .frame(width: 1.5, height: size.dimension * 0.6)
                Rectangle()
                    .fill(effectiveAccentColor.opacity(0.5))
                    .frame(width: 1.5, height: size.dimension * 0.6)
            }

            buildPlateLines

        case .a1mini:
            // Compact indicator
            buildPlateLines

        case .unknown:
            // Generic printer icon
            Image(systemName: "printer.fill")
                .font(.system(size: size.dimension * 0.4))
                .foregroundStyle(effectiveAccentColor)
        }
    }

    private var buildPlateLines: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                    .fill(effectiveAccentColor.opacity(0.3))
                    .frame(width: size.dimension * 0.5, height: 1)
            }
        }
        .offset(y: size.dimension * 0.15)
    }
}

/// Open frame printer shape
struct OpenFrameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let inset: CGFloat = rect.width * 0.1

        // Left vertical rail
        path.move(to: CGPoint(x: inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: inset, y: rect.maxY - inset))

        // Right vertical rail
        path.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))

        // Top crossbar
        path.move(to: CGPoint(x: inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))

        // Bottom plate
        path.move(to: CGPoint(x: inset * 0.5, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset * 0.5, y: rect.maxY - inset))

        return path
    }
}

/// Alternative: Stylized 3D printer icon using SF Symbols composition
struct PrinterIconStylized: View {
    let modelType: PrinterModelType
    var size: PrinterIconSize = .medium
    var accentColor: Color? = nil

    init(model: String?, size: PrinterIconSize = .medium, accentColor: Color? = nil) {
        self.modelType = PrinterModelType.detect(from: model)
        self.size = size
        self.accentColor = accentColor
    }

    init(modelType: PrinterModelType, size: PrinterIconSize = .medium, accentColor: Color? = nil) {
        self.modelType = modelType
        self.size = size
        self.accentColor = accentColor
    }

    private var effectiveAccentColor: Color {
        accentColor ?? modelType.accentColor
    }

    var body: some View {
        ZStack {
            // Glow
            Image(systemName: symbolName)
                .font(.system(size: size.dimension * 0.8))
                .foregroundStyle(effectiveAccentColor)
                .blur(radius: 8)
                .opacity(0.4)

            // Main icon
            Image(systemName: symbolName)
                .font(.system(size: size.dimension * 0.8))
                .foregroundStyle(
                    LinearGradient(
                        colors: [effectiveAccentColor, effectiveAccentColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Model badge
            if modelType != .unknown {
                Text(modelType.rawValue)
                    .font(.system(size: size.dimension * 0.2, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(effectiveAccentColor.opacity(0.8))
                    .clipShape(Capsule())
                    .offset(y: size.dimension * 0.4)
            }
        }
        .frame(width: size.dimension, height: size.dimension * 1.2)
    }

    private var symbolName: String {
        switch modelType {
        case .x1c, .x1e: return "cube.box.fill"       // Enclosed premium
        case .p1s: return "cube.transparent"           // Enclosed glass
        case .h2s, .h2d: return "cube.box.fill"       // Enclosed ventilated
        case .p1p, .a1: return "square.3.layers.3d"   // Open frame
        case .a1mini: return "cube.fill"               // Compact
        case .unknown: return "printer.fill"           // Generic
        }
    }
}

// MARK: - AMS Icon

/// AMS icon view - uses AMS 2 Pro product image or programmatic fallback
struct AMSIcon: View {
    var size: PrinterIconSize = .medium
    var accentColor: Color = .orange
    var showGlow: Bool = true
    var useProductImage: Bool = true

    var body: some View {
        if useProductImage {
            AMS2ProImage(size: size.dimension)
                .shadow(color: showGlow ? accentColor.opacity(0.3) : .clear, radius: size.dimension / 4)
        } else {
            programmaticIcon
        }
    }

    @ViewBuilder
    private var programmaticIcon: some View {
        ZStack {
            // Glow effect
            if showGlow {
                RoundedRectangle(cornerRadius: size.dimension / 6)
                    .fill(accentColor.opacity(0.3))
                    .blur(radius: size.dimension / 4)
            }

            // Main shape
            RoundedRectangle(cornerRadius: size.dimension / 6)
                .stroke(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size.strokeWidth
                )

            // Fill
            RoundedRectangle(cornerRadius: size.dimension / 6)
                .fill(accentColor.opacity(0.1))

            // AMS tray indicators (4 slots)
            VStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(slotColor(index))
                        .frame(width: size.dimension * 0.6, height: size.dimension * 0.12)
                }
            }
        }
        .frame(width: size.dimension, height: size.dimension)
    }

    private func slotColor(_ index: Int) -> Color {
        let colors: [Color] = [.red, .yellow, .blue, .green]
        return colors[index].opacity(0.7)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.1)
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 30) {
                // Product Images
                Text("Product Images").font(.headline).foregroundStyle(.white)

                HStack(spacing: 30) {
                    VStack {
                        PrinterStatusImage(size: 60)
                        Text("H2S + AMS")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        H2SPrinterImage(size: 60)
                        Text("H2S")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        AMS2ProImage(size: 60)
                        Text("AMS 2 Pro")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }

                // All models - medium size
                Text("Printer Models").font(.headline).foregroundStyle(.white)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(PrinterModelType.allCases, id: \.self) { model in
                        VStack {
                            PrinterIcon(modelType: model, size: .medium)
                            Text(model.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                }

                // AMS Icon
                Text("AMS Icon").font(.headline).foregroundStyle(.white)

                HStack(spacing: 20) {
                    VStack {
                        AMSIcon(size: .small)
                        Text("Product")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        AMSIcon(size: .medium, useProductImage: false)
                        Text("Programmatic")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }

                // H2S comparison
                Text("H2S: Product vs Programmatic").font(.headline).foregroundStyle(.white)

                HStack(spacing: 30) {
                    VStack {
                        PrinterIcon(modelType: .h2s, size: .large, useProductImage: true)
                        Text("Product")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        PrinterIcon(modelType: .h2s, size: .large, useProductImage: false)
                        Text("Programmatic")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }

                // Sizes comparison
                Text("Sizes (X1C)").font(.headline).foregroundStyle(.white)

                HStack(spacing: 30) {
                    VStack {
                        PrinterIcon(modelType: .x1c, size: .small)
                        Text("Small").font(.caption2).foregroundStyle(.gray)
                    }
                    VStack {
                        PrinterIcon(modelType: .x1c, size: .medium)
                        Text("Medium").font(.caption2).foregroundStyle(.gray)
                    }
                    VStack {
                        PrinterIcon(modelType: .x1c, size: .large)
                        Text("Large").font(.caption2).foregroundStyle(.gray)
                    }
                }
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
