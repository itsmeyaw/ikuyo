import Foundation

let allDataProviders = [
    MvvDataProvider.instance
]

protocol DataProvider {
    var id: String { get }
    var shortName: String { get }
    var longName: String { get }
    
    /// Finds stops for a provider based on a search query.
    ///
    /// - Parameter searchQuery: The text used to search for matching stops results (can be ID or the name of the stop).
    /// - Returns: A dictionary mapping stop identifiers to their name for results that match the query.
    func findStops(searchQuery: String) async throws -> [TransitStop]
    
    /// Find routes for a particular stopId.
    ///
    /// - Parameter stopId: The stop id to find the routes.
    /// - Returns: A dictionary mapping route identifiers to their name.
    func findRoutes(stopId: String) async throws -> [TransitRoute]
    
    /// Find departures for a stop and set of chosen routes
    ///
    /// - Parameter stopId: The stop id
    /// - Parameter routes: Set of route that want to be searched
    /// - Parameter time: The start time for the departure
    /// - Parameter count: The number of departures that want to be searched
    /// - Return: A dictionary of route id and time of actual departure
    func findDepartures(stopId: String, routes: Set<TransitRoute>, time: Date, count: Int) async throws -> [TransitDeparture]
}

extension DataProvider {
    /// Look up a provider singleton by its identifier.
    /// - Returns: The matching provider or nil if the id is unknown.
    static func getFromId(_ id: String) -> (any DataProvider)? {
        allDataProviders.first { $0.id == id }
    }
}

