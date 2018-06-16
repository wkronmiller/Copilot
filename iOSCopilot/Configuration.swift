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
    let homeLocation = CLLocation(latitude: 39.1595230, longitude: -77.2219680)
    
    let apiGatewayCore = "https://bqwa05ybua.execute-api.us-east-1.amazonaws.com/dev"
    
    let mapTileUrl = "http://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
    
    let defaultZoomMeters: CLLocationDistance = CLLocationDistance(8000)
    
    let defaultLocationDelegateUpdateFrequencyMs: Double = 5 * 1000 // 5 seconds
    let updateAnnotationFrequencyMs: Double = 1 * 1000 // 1 seconds
    
    let alertBadWeatherTimer: TimeInterval = 60 * 60 // 1 hour
    let alertBadWeatherFrequency: TimeInterval = 60 * 20 // 20 Minutes
    
    var audioAlertsEnabled: Bool = true
    
    private override init() {
        super.init()
    }
    
    static let shared = Configuration()
}
