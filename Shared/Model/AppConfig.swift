//
//  AppConfig.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 31.01.26.
//

public struct WidgetConfig: Codable, Equatable {
    public var providerId: String
    public var stopId: String
    public var stopName: String
    public var routeIds: [String]
    public var refreshInterval: Int
    public var alwaysOnTop: Bool

    public init(providerId: String, stopId: String, stopName: String, routeIds: [String], refreshInterval: Int, alwaysOnTop: Bool = false) {
        self.providerId = providerId
        self.stopId = stopId
        self.stopName = stopName
        self.routeIds = routeIds
        self.refreshInterval = refreshInterval
        self.alwaysOnTop = alwaysOnTop
    }

    private enum CodingKeys: String, CodingKey {
        case providerId
        case stopId
        case stopName
        case routeIds
        case refreshInterval
        case alwaysOnTop
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(String.self, forKey: .providerId)
        stopId = try container.decode(String.self, forKey: .stopId)
        stopName = try container.decode(String.self, forKey: .stopName)
        routeIds = try container.decode([String].self, forKey: .routeIds)
        refreshInterval = try container.decode(Int.self, forKey: .refreshInterval)
        alwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(stopId, forKey: .stopId)
        try container.encode(stopName, forKey: .stopName)
        try container.encode(routeIds, forKey: .routeIds)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        try container.encode(alwaysOnTop, forKey: .alwaysOnTop)
    }
}
