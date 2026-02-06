//
//  widget.swift
//  widget
//
//  Created by Yudhistira Wibowo on 01.08.25.
//

import Foundation
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), config: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let config = AppConfigStore.load()
        print("Getting snapshot with config: \(String(describing: config))")
        completion(SimpleEntry(date: Date(), config: config))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let config = AppConfigStore.load()
        let refreshMinutes = config?.refreshInterval ?? 30
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: currentDate) ?? currentDate.addingTimeInterval(1800)

        let entry = SimpleEntry(date: currentDate, config: config)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let config: WidgetConfig?
}

struct StopObserverWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.config?.stopName ?? "No stop selected")
                .font(.headline)
            if let routes = entry.config?.routeIds, !routes.isEmpty {
                Text("Routes: \(routes.joined(separator: ", "))")
                    .font(.subheadline)
            } else {
                Text("Configure routes in the app")
                    .font(.subheadline)
            }
            Text(entry.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct StopObserverWidget: Widget {
    let kind: String = AppConfigStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StopObserverWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
