//
//  LocationStats.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/17/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

//TODO: voice alerts
public class LocationStats: NSObject {
    private let queue = DispatchQueue(label: "Location Stats Queue")
    
    private var lastUpdated: Date? = nil
    private var lastLocation: CLLocation? = nil
    private var lastWaypoint: Waypoint? = nil
    
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
    
    func update(waypoint: Waypoint) {
        self.lastWaypoint = waypoint
    }
    
    func update(location: CLLocation, completionHandler: @escaping () -> Void) {
        var significantChange = true
        if let last = self.lastLocation {
            let distanceKm = last.distance(from: location) / 1000
            if let timeElapsedSeconds = self.lastUpdated?.timeIntervalSinceNow {
                significantChange = (distanceKm > 5) || (abs(timeElapsedSeconds) > 90)
            }
        }
        
        lastLocation = location
        var completed = 0
        func addCompleted() {
            self.queue.async {
                completed += 1
                if completed == 3 {
                    self.lastUpdated = Date()
                    completionHandler()
                }
            }
        }
        
        let backgrounded = UIApplication.shared.applicationState == .background
        
        if(significantChange) {
            self.trafficStatus.fetch(location: location, completionHandler: {trafficConditions in
                addCompleted()
            })
            
            self.weatherStatus.getHourlyForecast(location: location, completionHandler: {(forecasts, error) in
                return addCompleted()
            })
            
            // Skip camera update on backgrounded
            if(!backgrounded) {
                self.cameras.refreshNearby(location: location, completionHandler: {error in
                    return addCompleted()
                })
            } else {
                addCompleted()
            }
        } else {
            completionHandler()
        }
    }
}
