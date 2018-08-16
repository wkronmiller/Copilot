//
//  Vehicle.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 8/15/18.
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
