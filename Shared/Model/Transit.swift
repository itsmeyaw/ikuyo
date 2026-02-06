//
//  Transit.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 23.01.26.
//

import Foundation

public struct TransitStop: Codable, Hashable {
    public let id: String
    public let code: String?
    public let name: String // Required for showing the information
    public let desc: String?
    public let lat: Double
    public let lon: Double
    public let url: URL?
    public let locationType: TransitLocationType

    public init(
        id: String,
        code: String?,
        name: String,
        desc: String?,
        lat: Double,
        lon: Double,
        url: URL?,
        locationType: TransitLocationType
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.desc = desc
        self.lat = lat
        self.lon = lon
        self.url = url
        self.locationType = locationType
    }
}

public enum TransitLocationType: String, Codable, Hashable {
    case stop, station, entraceExit, generic, boardingArea
}

public struct TransitRoute: Codable, Hashable {
    public let id: String
    public let shortName: String // Required for showing the information
    public let longName: String?
    public let desc: String?
    public let type: TransitRouteType
    public let url: URL?
    public let color: String?
    public let textColor: String?
    public let sortOrder: Int?

    public init(
        id: String,
        shortName: String,
        longName: String?,
        desc: String?,
        type: TransitRouteType,
        url: URL?,
        color: String?,
        textColor: String?,
        sortOrder: Int?
    ) {
        self.id = id
        self.shortName = shortName
        self.longName = longName
        self.desc = desc
        self.type = type
        self.url = url
        self.color = color
        self.textColor = textColor
        self.sortOrder = sortOrder
    }
}

public enum TransitRouteType: String, Codable, Hashable {
    case tram, subway, rail, bus, ferry, cableTram, aerialLift, funicular, trolleyBus, monorail, metro
}

public struct TransitDeparture: Codable, Hashable {
    public let route: TransitRoute
    public let plannedTime: Date
    public let actualTime: Date?

    public init(route: TransitRoute, plannedTime: Date, actualTime: Date?) {
        self.route = route
        self.plannedTime = plannedTime
        self.actualTime = actualTime
    }
}
