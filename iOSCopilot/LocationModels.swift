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

public struct Waypoint {
    let location: CLLocationCoordinate2D
    let name: String?
}
