//
//  LocationModels.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/10/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

public struct LocationSegment: Codable {
    var altitude: Double
    var course: Double
    var latitude: Double
    var longitude: Double
    var speed: Double
    var epochMs: Double
    var privacyEnabled: Bool
}

public struct LocationTrace: Codable {
    var locations: [LocationSegment]
}

//TODO: voice alerts
public class LocationStats: NSObject {
    private let queue = DispatchQueue(label: "Location Stats Queue")
    private let homeLocation = CLLocation(latitude: 39.1595230, longitude: -77.2219680)
    private var lastLocation: CLLocation? = nil
    // TODO: keep inside TrafficStatus instance
    private var lastConditions: TrafficConditions? = nil
    // TODO: keep inside weatherStatus
    private var lastForecasts: [ForecastPeriod] = []
    
    private let weatherStatus = WeatherStatus()
    
    func getDistanceFromHome() -> CLLocationDistance {
        return lastLocation!.distance(from: homeLocation)
    }
    
    func hasData() -> Bool {
        return self.lastLocation != nil
    }
    
    func getLastLocation() -> CLLocation {
        return lastLocation!
    }
    
    func getTrafficConditions() -> TrafficConditions? {
        return lastConditions
    }
    
    func getForecasts() -> [ForecastPeriod] {
        return self.lastForecasts
    }
    
    func getWeatherStatus() -> WeatherStatus {
        return self.weatherStatus
    }
    
    func update(location: CLLocation, completionHandler: @escaping () -> Void) {
        lastLocation = location
        var completed = 0
        
        func addCompleted() {
            completed += 1
            if completed == 2 {
                completionHandler()
            }
        }
        
        //TODO: move away from singleton
        TrafficStatus.shared.fetch(location: location, completionHandler: {trafficConditions in
            self.queue.async {
                self.lastConditions = trafficConditions
                addCompleted()
            }
        })
        
        self.weatherStatus.getHourlyForecast(location: location, completionHandler: {(forecasts, error) in
            self.queue.async {
                if error == nil && forecasts != nil {
                    self.lastForecasts = forecasts!
                }
                return addCompleted()
            }
        })
    }
}
