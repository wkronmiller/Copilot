//
//  LocationSegment.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/17/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

public struct LocationSegment: Codable {
    var epochMs: Double
    var altitude: Double
    var course: Double
    var latitude: Double
    var longitude: Double
    var speed: Double
}

public struct LocationTrace: Codable {
    var locations: [LocationSegment]
    
    func getFastTimesSeconds(minMetersPerSecond: Double) -> Set<Double> {
        return Set(locations
            .filter { $0.speed >= minMetersPerSecond }
            .map{ round($0.epochMs / 1000) })
    }
}

public struct Waypoint {
    let location: CLLocationCoordinate2D
    let name: String?
}
