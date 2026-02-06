//
//  MvvDataProvider.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 23.01.26.
//

import Foundation

// MARK: - MvvStopFinderResponse
struct MvvStopFinderResponse: Codable {
    let success: Bool
    let message: String
    let results: [MvvStopFinderResult]
}

// MARK: - MvvStopFinderResult
struct MvvStopFinderResult: Codable {
    let id: String
    let name: String
    let usage, type, stateless: String?
    let anyType, sort, quality, best: String?
    let object, mainLoc, modes: String?
    let ref: MvvStopFinderRef?
    let postcode, street: String?
}

extension MvvStopFinderResult {
    func toTransitStop() -> TransitStop {
        let coordString = ref?.coords
        let parts = coordString?.split(separator: ",")
        
        let (stopLat, stopLon): (Double, Double)
        if let partX = parts?.first,
           let partY = parts?.last,
           let doublePartX = Double(partX),
           let doublePartY = Double(partY) {
            (stopLat, stopLon) = webMercatorToLatLon(x: doublePartX, y: doublePartY)
        } else {
            (stopLat, stopLon) = (-1, -1)
        }
        
        let type: TransitLocationType = switch self.type {
        case "stop": .stop
        default: .generic
        }
        
        return TransitStop(
            id: id,
            code: nil,
            name: name,
            desc: nil,
            lat: stopLat,
            lon: stopLon,
            url: nil,
            locationType: type
        )
    }
}

// MARK: - MvvStopFinderRef
struct MvvStopFinderRef: Codable {
    let id, gid, omc, placeID: String?
    let place, coords: String?
}

// MARK: - MvvDepartureResult
struct MvvDepartureResult: Codable {
    let error: String?
    let departures: [MvvDeparture]?
    let notifications: [MvvNotification]?
}

// MARK: - MvvDeparture
struct MvvDeparture: Codable {
    let line: MvvLine
    let direction: String
    let station: MvvStation
    let track: String
    let departureDate, departurePlanned, departureLive: String?
    let inTime: Bool?
    let notifications: [MvvNotification]?
}

extension MvvDeparture {
    func toTransitDeparture() throws -> TransitDeparture {
        let routeType: TransitRouteType = self.line.name.toTransitRouteType()

        let route = TransitRoute(
            id: self.line.stateless,
            shortName: self.line.number,
            longName: self.line.direction,
            desc: nil,
            type: routeType,
            url: nil,
            color: nil,
            textColor: nil,
            sortOrder: nil
        )

        func parsedTime(dateString: String?, timeString: String?) throws -> Date? {
            guard let timeString else { return nil }
            if let dateString {
                return try dateAndTimeStringToDate(dateString: dateString, timeString: timeString)
            }
            return try timeStringToDate(timeString: timeString)
        }

        let plannedTime = (try? parsedTime(dateString: self.departureDate, timeString: self.departurePlanned)) ?? Date()
        let actualTime = (try? parsedTime(dateString: self.departureDate, timeString: self.departureLive)) ?? plannedTime

        return TransitDeparture(route: route, plannedTime: plannedTime, actualTime: actualTime)
    }
}

// MARK: - MvvLine
struct MvvLine: Codable {
    let number, symbol, direction, stateless: String
    let name: MvvLineName
}

enum MvvLineName: String, Codable {
    case bus = "Bus"
    case sBahn = "S-Bahn"
    case uBahn = "U-Bahn"
    case metroBus = "MetroBus"
    case nachtBus = "NachtBus"
    case regionalBus = "RegionalBus"
    case tram = "Tram"
}

extension MvvLineName {
    /// Map MVV line naming to GTFS-like TransitRouteType
    func toTransitRouteType() -> TransitRouteType {
        switch self {
        case .sBahn: return .subway
        case .uBahn: return .metro
        case .tram: return .tram
        case .bus, .metroBus, .nachtBus, .regionalBus: return .bus
        }
    }

    /// Create a line name from a raw API string, defaulting to bus if unknown.
    static func from(apiName: String?) -> MvvLineName {
        guard let apiName, let value = MvvLineName(rawValue: apiName) else {
            return .bus
        }
        return value
    }
}

// MARK: - MvvNotification
struct MvvNotification: Codable {
    let text: String?
    let link: String?
    let type: String?
}

// MARK: - Station
struct MvvStation: Codable {
    let id: String
    let name: String
}


// MARK: - MvvDataProvider
public class MvvDataProvider: DataProvider {
    private static let ENDPOINT = "https://www.mvv-muenchen.de"
    let id = "mvv"
    let shortName = "MVV"
    let longName = "Münchner VerhkehrsVerbund"
    static let instance = MvvDataProvider()
    
    private init() {}
    
    func findStops(searchQuery: String) async throws -> [TransitStop] {
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(Self.ENDPOINT)/?eID=stopFinder&query=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResonse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResonse.statusCode) else {
            if let bodyString = String(data: data, encoding: .utf8) {
                print("MVV departures HTTP \(httpResonse.statusCode): \(bodyString)")
            } else {
                print("MVV departures HTTP \(httpResonse.statusCode): <non-UTF8 body>")
            }
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(MvvStopFinderResponse.self, from: data)
        guard decodedResponse.success else {
            throw DataProviderError.responseError(decodedResponse.message)
        }
        
        return decodedResponse.results.map {$0.toTransitStop()}
    }
    
    func findRoutes(stopId: String) async throws -> [TransitRoute] {
        let encodedQuery = stopId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(Self.ENDPOINT)/?eID=departuresFinder&action=available_lines&stop_id=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResonse = response as? HTTPURLResponse, (200...299).contains(httpResonse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONSerialization.jsonObject(with: data)

        guard let root = decodedResponse as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        if let error = root["error"] as? String, error.count != 0 {
            throw URLError(.badServerResponse)
        }

        let apiResults = root["lines"] as? [[String: Any]] ?? []
        var returnResults: [TransitRoute] = []

        for apiResult in apiResults {
            let lineName = MvvLineName.from(apiName: apiResult["name"] as? String)
            let transitRouteType = lineName.toTransitRouteType()
            
            returnResults.append(
                TransitRoute(
                    id: apiResult["stateless"] as! String,
                    shortName: apiResult["number"] as! String,
                    longName: apiResult["direction"] as? String,
                    desc: nil,
                    type: transitRouteType,
                    url: nil,
                    color: nil,
                    textColor: nil,
                    sortOrder: nil
                )
            )
        }
        
        return returnResults
    }
    
    func findDepartures(stopId: String, routes: Set<TransitRoute>, time: Date, count: Int) async throws -> [TransitDeparture] {
        var allowedCharsets = CharacterSet.urlQueryAllowed
        allowedCharsets.remove(charactersIn: ":")
        let encodedStopId = stopId.addingPercentEncoding(withAllowedCharacters: allowedCharsets) ?? ""
        let linesRaw = routes.map { "&line=" + $0.id }.joined()
        let linesRawEncoded = linesRaw.addingPercentEncoding(withAllowedCharacters: allowedCharsets) ?? linesRaw
        let linesBase64 = Data(linesRawEncoded.utf8).base64EncodedString()
        let urlString = "\(Self.ENDPOINT)/?eID=departuresFinder&action=get_departures&stop_id=\(encodedStopId)&requested_timestamp=\(Int(time.timeIntervalSince1970))&lines=\(linesBase64)"

        if routes.isEmpty {
            print("MVV departures skipped: no routes provided")
            return []
        }

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let bodyString = String(data: data, encoding: .utf8) {
                print("MVV departures HTTP \(httpResponse.statusCode): \(bodyString)")
            } else {
                print("MVV departures HTTP \(httpResponse.statusCode): <non-UTF8 body>")
            }
            throw URLError(.badServerResponse)
        }

        let decodedResponse = try JSONDecoder().decode(MvvDepartureResult.self, from: data)

        if let error = decodedResponse.error, !error.isEmpty {
            print("MVV departures error field: \(error)")
            throw URLError(.badServerResponse)
        }
        
        let result: [TransitDeparture] = try {
            var parsed: [TransitDeparture] = []
            for departure in decodedResponse.departures ?? [] {
                do {
                    parsed.append(try departure.toTransitDeparture())
                } catch is TimeFormatError {
                    print("Skipping departure due to invalid time format: \(departure)")
                    continue
                }
            }
            return parsed
        }()

        if result.isEmpty {
            print("Warning: MVV transit departure is empty")
        }
        
        return result
    }
}
