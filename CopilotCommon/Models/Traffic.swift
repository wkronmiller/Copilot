//
//  Traffic.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 8/15/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

struct TrafficJam {
    var line: [CLLocation]
    var severity: Int
    var speed: Double
}

struct TrafficAlert {
    let type: String
    let uuid: String
    let location: CLLocation
    let waypoint: Waypoint
}

struct TrafficConditions {
    var jams: [TrafficJam]
    var alerts: [TrafficAlert]
    
    func getPoliceLocations() -> [TrafficAlert] {
        return alerts.filter { alert in
            return (alert.type == "POLICE")
        }
    }
    
    func getPoliceNearby(location: CLLocation, radius: CLLocationDistance) -> [TrafficAlert] {
        return self.getPoliceLocations().filter{ policeLocation in
            return location.distance(from: location) < radius
        }
    }
}
