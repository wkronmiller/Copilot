//
//  RideStatistics.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/28/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

struct Vehicle: Codable { //TODO: vehicle database
    let vin: String? = nil
    let plate: String? = nil
    let make = "BMW"
    let model = "S1000RR"
    let year = 2016
}

struct User: Codable { //TODO
    let nickname = "Rory"
}

struct RideStatistics: Codable {
    let user = User() //TODO
    let vehicle = Vehicle() //TODO
    let start: Date
    let end: Date
    let biometrics: BiometricSummary
    let locationTrace: LocationTrace
    let accelerationData: [Acceleration]
}
