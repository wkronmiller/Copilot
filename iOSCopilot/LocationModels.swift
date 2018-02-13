//
//  LocationModels.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/10/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

public struct LocationSegment: Codable {
    var altitude: Double
    var course: Double
    var latitude: Double
    var longitude: Double
    var speed: Double
    var epochMs: Double
}

public struct LocationTrace: Codable {
    var locations: [LocationSegment]
}
