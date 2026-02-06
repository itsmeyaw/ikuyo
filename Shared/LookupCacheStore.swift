//
//  LookupCacheStore.swift
//  Ikuyo
//
//  Created by GitHub Copilot on 31.01.26.
//

import Foundation

public struct LookupCache: Codable, Equatable {
    public let providerId: String
    public let stopQuery: String
    public let stopResults: [TransitStop]
    public let selectedStop: TransitStop?
    public let availableRoutes: [TransitRoute]
}

public enum LookupCacheStore {
    private static let suite = "group.com.itsmeyaw.Ikuyo"
    private static let key = "lookup_cache_v1"

    private static var defaults: UserDefaults {
        guard let d = UserDefaults(suiteName: suite) else {
            fatalError("Missing App Group \(suite)")
        }
        return d
    }

    public static func load() -> LookupCache? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LookupCache.self, from: data)
    }

    public static func save(_ cache: LookupCache) throws {
        let data = try JSONEncoder().encode(cache)
        defaults.set(data, forKey: key)
    }

    public static func clear() {
        defaults.removeObject(forKey: key)
    }
}
