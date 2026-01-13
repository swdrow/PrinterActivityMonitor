import WidgetKit
import SwiftUI

@main
struct PrinterMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity will be added in Phase 5
        PrinterMonitorWidgetPlaceholder()
    }
}

// Placeholder widget until Live Activity is implemented
struct PrinterMonitorWidgetPlaceholder: Widget {
    let kind: String = "PrinterMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            Text("Printer Monitor")
        }
        .configurationDisplayName("Printer Monitor")
        .description("Monitor your 3D printer status")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        let entry = PlaceholderEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}
