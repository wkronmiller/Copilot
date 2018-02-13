//
//  Configuration.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/11/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

class Configuration: NSObject {
    
    let apiGatewayCore = "https://t5n5d0mfrd.execute-api.us-east-1.amazonaws.com/dev"
    
    let mapTileUrl = "http://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
    
    let defaultZoomMeters: CLLocationDistance = CLLocationDistance(8000)
    
    let defaultLocationDelegateUpdateFrequencyMs: Double = 5 * 1000 // 5 seconds
    let updateAnnotationFrequencyMs: Double = 10 * 1000 // 10 seconds
    
    private override init() {
        super.init()
    }
    
    static let shared = Configuration()
}
