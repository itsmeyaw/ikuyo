//
//  ConfigurationView.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 01.08.25.
//

import SwiftUI

struct ConfigurationView: View {
    @State private var selectedProviderId: String = allDataProviders.first?.id ?? ""
    @State private var stopQuery: String = ""
    @State private var stopResults: [TransitStop] = []
    @State private var selectedStop: TransitStop?
    @State private var isSearchingStops = false
    @State private var stopSearchTask: Task<Void, Never>?
    @State private var routeLoadTask: Task<Void, Never>?

    @State private var availableRoutes: [TransitRoute] = []
    @State private var selectedRouteIds: Set<String> = []
    @State private var isLoadingRoutes = false

    @State private var refreshIntervalMinutes: Int = 1
    @State private var alwaysOnTop: Bool = false

    @State private var statusMessage: String?

    static let minimumSize = CGSize(width: 520, height: 520)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Provider", selection: $selectedProviderId) {
                    ForEach(allDataProviders, id: \.id) { provider in
                        Text("\(provider.shortName) (\(provider.longName))")
                            .tag(provider.id)
                    }
                }
                .onChange(of: selectedProviderId) { _ in
                    resetStopAndRoutes()
                }
                
                TextField("Stop", text: $stopQuery)
                    .onChange(of: stopQuery, perform: scheduleStopSearch)
                    .textFieldStyle(.roundedBorder)

                if isSearchingStops {
                    HStack(spacing: 8) {
                        SmallSpinner()
                        Text("Searching...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !stopResults.isEmpty && (selectedStop == nil || selectedStop?.name != stopQuery) {
                    List(stopResults, id: \.id) { stop in
                        Button {
                            selectStop(stop)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stop.name)
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: 100, maxHeight: 220)
                }

                if let selectedStop {
                    Text("Selected: \(selectedStop.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Routes")
                    .font(.headline)
                    .padding(.top, 12)

                if isLoadingRoutes {
                    HStack(spacing: 8) {
                        SmallSpinner()
                        Text("Loading routes...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if availableRoutes.isEmpty {
                    Text("Choose a stop to load routes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableRoutes, id: \.id) { route in
                        Toggle(isOn: Binding(
                            get: { selectedRouteIds.contains(route.id) },
                            set: { isOn in
                                if isOn {
                                    selectedRouteIds.insert(route.id)
                                } else {
                                    selectedRouteIds.remove(route.id)
                                }
                            }
                        )) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(route.shortName)
                                    .font(.headline)
                                if let long = route.longName, !long.isEmpty {
                                    Text(long)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Toggle("Always On Top", isOn: $alwaysOnTop)
                    .padding(.top, 10)

                LabeledContent("Refresh Interval") {
                    Stepper("\(refreshIntervalMinutes) min", value: $refreshIntervalMinutes, in: 1...1440)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)

                Section {
                    Button("Save Configuration", action: saveConfiguration)
                        .disabled(!canSave)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 20)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .navigationTitle("Configuration")
        }
        .onAppear(perform: restorePersistedState)
        .padding(.all, 10)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var selectedProvider: (any DataProvider)? {
        allDataProviders.first { $0.id == selectedProviderId }
    }

    private var canSave: Bool {
        selectedProvider != nil && selectedStop != nil && !selectedRouteIds.isEmpty
    }

    private func resetStopAndRoutes() {
        stopQuery = ""
        stopResults = []
        selectedStop = nil
        availableRoutes = []
        selectedRouteIds = []
        clearLookupCache()
        routeLoadTask?.cancel()
        routeLoadTask = nil
    }

    private func scheduleStopSearch(_ query: String) {
        stopSearchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            stopResults = []
            clearLookupCache()
            return
        }

        isSearchingStops = true
        stopSearchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250)) // simple debounce to avoid flooding the API
            await searchStops(query: query)
        }
    }

    @MainActor
    private func searchStops(query: String) async {
        guard let provider = selectedProvider else {
            isSearchingStops = false
            return
        }

        do {
            let results = try await provider.findStops(searchQuery: query)
            stopResults = results
            statusMessage = nil
        } catch {
            stopResults = []
            statusMessage = "Failed to load stops: \(error.localizedDescription)"
        }

        isSearchingStops = false
    }

    private func selectStop(_ stop: TransitStop) {
        selectedStop = stop
        stopQuery = stop.name
        stopResults = []
        loadRoutes(for: stop, allowCached: false, resetSelection: true)
    }

    private func loadRoutes(for stop: TransitStop, allowCached: Bool = true, resetSelection: Bool = true) {
        routeLoadTask?.cancel()
        routeLoadTask = Task { @MainActor in
            if resetSelection {
                selectedRouteIds = []
            }

            availableRoutes = []
            isLoadingRoutes = true

            if allowCached,
               let cache = LookupCacheStore.load(),
               cache.providerId == selectedProviderId,
               cache.selectedStop?.id == stop.id,
               !cache.availableRoutes.isEmpty {
                availableRoutes = cache.availableRoutes
                if !resetSelection {
                    selectedRouteIds.formIntersection(cache.availableRoutes.map { $0.id })
                }
                isLoadingRoutes = false
                return
            }

            guard let provider = selectedProvider else {
                isLoadingRoutes = false
                return
            }

            do {
                let routes = try await provider.findRoutes(stopId: stop.id)
                availableRoutes = routes
                if resetSelection {
                    selectedRouteIds = []
                } else {
                    selectedRouteIds.formIntersection(routes.map { $0.id })
                }
                statusMessage = nil
            } catch {
                availableRoutes = []
                if resetSelection {
                    selectedRouteIds = []
                }
                statusMessage = "Failed to load routes: \(error.localizedDescription)"
            }

            isLoadingRoutes = false
        }
    }

    private func saveConfiguration() {
        guard let provider = selectedProvider, let stop = selectedStop else { return }

        let config = WidgetConfig(
            providerId: provider.id,
            stopId: stop.id,
            stopName: stop.name,
            routeIds: Array(selectedRouteIds),
            refreshInterval: refreshIntervalMinutes,
            alwaysOnTop: alwaysOnTop
        )

        do {
            try AppConfigStore.save(config)
            persistLookupCache()
            statusMessage = "Configuration saved"
        } catch {
            statusMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func restorePersistedState() {
        
        if let config = AppConfigStore.load() {
            selectedProviderId = config.providerId
            selectedRouteIds = Set(config.routeIds)
            selectedStop = TransitStop(
                id: config.stopId,
                code: nil,
                name: config.stopName,
                desc: nil,
                lat: 0,
                lon: 0,
                url: nil,
                locationType: .generic
            )
            stopQuery = config.stopName
            refreshIntervalMinutes = max(1, config.refreshInterval)
            alwaysOnTop = config.alwaysOnTop
        } else {
            selectedProviderId = allDataProviders.first?.id ?? ""
            refreshIntervalMinutes = 1
            alwaysOnTop = false
        }

        if let cache = LookupCacheStore.load(), cache.providerId == selectedProviderId {
            stopQuery = cache.stopQuery
            stopResults = cache.stopResults
            selectedStop = cache.selectedStop
            availableRoutes = cache.availableRoutes
        }

        if let stop = selectedStop, availableRoutes.isEmpty {
            loadRoutes(for: stop, allowCached: true, resetSelection: false)
        }

        isSearchingStops = false
    }

    private func persistLookupCache() {
        guard let provider = selectedProvider else { return }
        let cache = LookupCache(
            providerId: provider.id,
            stopQuery: selectedStop?.name ?? stopQuery,
            stopResults: stopResults,
            selectedStop: selectedStop,
            availableRoutes: availableRoutes
        )
        try? LookupCacheStore.save(cache)
    }

    private func clearLookupCache() {
        LookupCacheStore.clear()
    }
}

#Preview {
    ConfigurationView()
}
