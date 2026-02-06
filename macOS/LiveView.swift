//
//  LiveView.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 05.02.26.
//

import SwiftUI
import AppKit

struct LiveView : View {
    @State private var hostingWindow: NSWindow?
    @State private var isAlwaysOnTop = false
    @State private var widgetConfig: WidgetConfig?
    @State private var departures: [TransitDeparture] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastRefresh: Date?
    @State private var refreshTask: Task<Void, Never>?
    @State private var autoRefreshTask: Task<Void, Never>?
    @State private var appNapActivity: NSObjectProtocol?

    var body: some View {
        VStack(spacing: 16) {
            if let config = widgetConfig {
                configuredContent(config: config)
            } else {
                defaultContent
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .padding()
        .background(WindowAccessor { window in
            hostingWindow = window
            updateWindowLevel()
        })
        .onAppear {
            startKeepingAppActive()
            loadConfiguration()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            loadConfiguration()
        }
        .onDisappear {
            refreshTask?.cancel()
            autoRefreshTask?.cancel()
            stopKeepingAppActive()
        }
    }

    private var defaultContent: some View {
        VStack(spacing: 12) {
            Text("Ikuyo")
                .font(.title)
                .fontWeight(.semibold)

            Text("Open Settings in the app menu to configure your widget.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func configuredContent(config: WidgetConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(config.stopName)")
                .font(.headline)
            
            if departures.isEmpty {
                Text("No departures found for the selected routes.")
                    .foregroundStyle(.secondary)
            } else {
                List(sortedDepartures(), id: \.self) { departure in
                    scheduleRow(departure: departure)
                }
                .listStyle(.plain)
            }
            
            VStack (alignment: .leading ) {
                HStack {
                    if let lastRefresh {
                        Text("Last refresh: \(timeFormatter.string(from: lastRefresh))")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    
                    if isLoading {
                        Spacer()
                        SmallSpinner()
                        Text("Loading schedule…")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                
                Text(providerName(for: config))
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        }
    }

    private func updateWindowLevel() {
        guard let hostingWindow else { return }
        disableFullScreen(for: hostingWindow)
        hostingWindow.level = isAlwaysOnTop ? .floating : .normal
    }

    private func disableFullScreen(for window: NSWindow) {
        // Keep the utility window from entering macOS full screen.
        window.collectionBehavior.subtract([.fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling])

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.isEnabled = false
            zoomButton.isHidden = true
        }
    }

    private func loadConfiguration() {
        let config = AppConfigStore.load()
        widgetConfig = config
        isAlwaysOnTop = config?.alwaysOnTop ?? false
        updateWindowLevel()

        refreshTask?.cancel()
        refreshTask = Task { await refreshDepartures(for: config) }
        startAutoRefresh(for: config)
    }

    private func startAutoRefresh(for config: WidgetConfig?) {
        autoRefreshTask?.cancel()

        guard let config else { return }

        autoRefreshTask = Task {
            while !Task.isCancelled {
                let base = lastRefresh ?? Date()
                let nextRefresh = base.addingTimeInterval(TimeInterval(config.refreshInterval * 60))
                let delay = max(0, nextRefresh.timeIntervalSinceNow)

                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                if Task.isCancelled { break }
                await refreshDepartures(for: config)
            }
        }
    }

    private func refreshDepartures(for config: WidgetConfig?) async {
        guard let config, let provider = provider(for: config.providerId) else {
            await MainActor.run {
                departures = []
                lastRefresh = nil
                errorMessage = nil
                isLoading = false
            }
            return
        }

        await MainActor.run {
            errorMessage = nil
            isLoading = true
        }

        do {
            let availableRoutes = try await provider.findRoutes(stopId: config.stopId)
            let selectedRoutes = availableRoutes.filter { config.routeIds.contains($0.id) }
            let routesSet = Set(selectedRoutes)

            let fetched = try await provider.findDepartures(
                stopId: config.stopId,
                routes: routesSet,
                time: Date(),
                count: 10
            )

            let sorted = sortDepartures(fetched)

            await MainActor.run {
                departures = sorted
                lastRefresh = Date()
                isLoading = false
            }
        } catch let formatError as TimeFormatError {
            await MainActor.run {
                errorMessage = formatError.localizedDescription
                isLoading = false
            }
        } catch {
            print("Failed to load departures: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load departures. \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func sortedDepartures() -> [TransitDeparture] {
        sortDepartures(departures)
    }

    private func sortDepartures(_ list: [TransitDeparture]) -> [TransitDeparture] {
        let now = Date() // capture once to avoid jitter while sorting
        return list.sorted { lhs, rhs in
            let lhsTime = lhs.actualTime ?? lhs.plannedTime
            let rhsTime = rhs.actualTime ?? rhs.plannedTime

            let lhsDelta = abs(lhsTime.timeIntervalSince(now))
            let rhsDelta = abs(rhsTime.timeIntervalSince(now))

            if lhsDelta == rhsDelta {
                return lhsTime < rhsTime
            }

            return lhsDelta < rhsDelta
        }
    }

    private func scheduleRow(departure: TransitDeparture) -> some View {
        HStack(spacing: 12) {
            routeIcon(for: departure.route)

            Text(departure.route.shortName)
                .font(.headline)

            if let longName = departure.route.longName, !longName.isEmpty {
                Text(longName)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text("\(timeFormatter.string(from: departure.actualTime ?? departure.plannedTime))")
                .monospacedDigit()
        }
    }

    private func routeIcon(for route: TransitRoute) -> some View {
        Image(systemName: routeSymbolName(for: route.type))
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    private func routeSymbolName(for type: TransitRouteType) -> String {
        switch type {
        case .tram, .cableTram:
            "tram.fill"
        case .subway:
            "lightrail.fill"
        case .metro:
            "tram.fill.tunnel"
        case .rail:
            "train.side.front.car"
        case .bus, .trolleyBus:
            "bus.fill"
        case .ferry:
            "ferry.fill"
        case .aerialLift:
            "cablecar"
        case .funicular:
            "cablecar.fill"
        case .monorail:
            "tram.fill"
        }
    }

    private func formattedActualTime(for departure: TransitDeparture) -> String {
        let actual = departure.actualTime ?? departure.plannedTime
        let diffMinutes = Int((actual.timeIntervalSince(departure.plannedTime) / 60).rounded())
        return "\(timeFormatter.string(from: actual))"
    }

    private func providerName(for config: WidgetConfig) -> String {
        if let provider = provider(for: config.providerId) {
            return provider.longName
        }
        return config.providerId
    }

    private func provider(for id: String) -> (any DataProvider)? {
        allDataProviders.first { $0.id == id }
    }

    private func startKeepingAppActive() {
        guard appNapActivity == nil else { return }

        // Prevent App Nap so refresh tasks continue while the window is unfocused.
        let options: ProcessInfo.ActivityOptions = [.userInitiatedAllowingIdleSystemSleep, .latencyCritical]
        appNapActivity = ProcessInfo.processInfo.beginActivity(options: options, reason: "Keep schedule refresh active")
    }

    private func stopKeepingAppActive() {
        guard let activity = appNapActivity else { return }

        ProcessInfo.processInfo.endActivity(activity)
        appNapActivity = nil
    }

    private var timeFormatter: DateFormatter {
        Self.sharedTimeFormatter
    }

    private static let sharedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView.window) }
    }
}
