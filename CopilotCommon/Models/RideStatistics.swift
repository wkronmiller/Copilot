//
//  RideStatistics.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/28/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

struct RideStatistics: Codable {
    let user = User() //TODO
    let vehicle = Vehicle() //TODO
    let start: Date
    let end: Date
    let biometrics: BiometricSummary
    let locationTrace: LocationTrace
    let accelerationData: [Acceleration]
    
    func getRidingAcceleration(minMetersPerSecond: Double) -> [Acceleration] {
        let fastTimes = self.locationTrace
            .getFastTimesSeconds(minMetersPerSecond: minMetersPerSecond)
        return self.accelerationData.filter{ accel in
            return fastTimes.contains(round(accel.epochMs / 1000))
        }
    }
}

extension Double {
    var metersPerSecondToMPH: Double {
        get {
            return self * 2.23694
        }
    }
}
