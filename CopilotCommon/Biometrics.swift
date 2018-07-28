//
//  Biometrics.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/20/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

public struct HeartRateMeasurement: Codable {
    let start: Date
    let end: Date
    let value: Double
}

public struct BiometricSummary: Codable {
    let heartRateMeasurements: [HeartRateMeasurement]
}
