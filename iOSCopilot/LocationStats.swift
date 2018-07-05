//
//  LocationStats.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/17/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

//TODO: voice alerts
public class LocationStats: NSObject {
    private let queue = DispatchQueue(label: "Location Stats Queue")
    
    private var lastLocation: CLLocation? = nil
    private var lastWaypoint: Waypoint? = nil
    
    private let geocoder = Geocoder()
    private let trafficStatus = TrafficStatus()
    private let weatherStatus = WeatherStatus()
    private let cameras = TrafficCams()
    
    func hasData() -> Bool {
        return self.lastLocation != nil
    }
    
    func getLastLocation() -> CLLocation {
        return lastLocation!
    }
    
    func getTrafficStatus() -> TrafficStatus {
        return self.trafficStatus
    }
    
    func getWeatherStatus() -> WeatherStatus {
        return self.weatherStatus
    }
    
    func getCameras() -> TrafficCams {
        return self.cameras
    }
    
    func getGeoData() -> GeoLocation? {
        return self.geocoder.lastLocation
    }
    
    func update(waypoint: Waypoint) {
        self.lastWaypoint = waypoint
    }
    
    func update(location: CLLocation, completionHandler: @escaping () -> Void) {
        lastLocation = location
        var completed = 0
        
        func addCompleted() {
            self.queue.async {
                completed += 1
                if completed == 3 {
                    completionHandler()
                }
            }
        }
        
        //self.geocoder.geocode(location: location, completionHandler: addCompleted)
        
        self.trafficStatus.fetch(location: location, completionHandler: {trafficConditions in
            addCompleted()
        })
        
        self.weatherStatus.getHourlyForecast(location: location, completionHandler: {(forecasts, error) in
            return addCompleted()
        })
        
        self.cameras.refreshNearby(location: location, completionHandler: {error in
            return addCompleted()
        })
    }
}
