//
//  Acceleration.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 8/15/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

public class Acceleration: Codable {
    let epochMs: Double
    let x: Double
    let y: Double
    let z: Double
    
    init(epochMs: Double, x: Double, y: Double, z: Double) {
        self.epochMs = epochMs
        self.x = x
        self.y = y
        self.z = z
    }
    
    lazy var magnitude: Double = { [unowned self] in
        return sqrt(self.squaredMagnitude)
        }()
    
    lazy var squaredMagnitude: Double = { [unowned self] in
        return pow(x, 2) + pow(y, 2) + pow(z, 2)
        }()
}
