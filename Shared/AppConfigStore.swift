//
//  AppConfigStore.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 31.01.26.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum AppConfigStore {
    public static let widgetKind = "StopObserverWidget"
    private static let suite = "group.id.itsmeyaw.ikuyo"
    private static let key = "app_config_v1"

    private static var defaults: UserDefaults {
        guard let d = UserDefaults(suiteName: suite) else {
            fatalError("Missing App Group \(suite)")
        }
        return d
    }

    public static func load() -> WidgetConfig? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetConfig.self, from: data)
    }

    public static func save(_ config: WidgetConfig) throws {
        let data = try JSONEncoder().encode(config)
        defaults.set(data, forKey: key)
        reloadWidgetTimelines()
    }

    private static func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        #endif
    }
}
