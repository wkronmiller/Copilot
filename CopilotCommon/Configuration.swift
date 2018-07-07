//
//  Configuration.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/11/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

public class Configuration: NSObject {
    
    let apiGatewayCore = "https://bqwa05ybua.execute-api.us-east-1.amazonaws.com/dev"
    //let apiGatewayCore = "http://192.168.11.218:3000"
    
    let baseMapTileUrl = "http://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
    //http://mesonet.agron.iastate.edu/ogc/
    let radarTileUrl = "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/{z}/{x}/{y}.png"
    
    let nominatimUrl = "http://statichosting.kronmiller.net:9000"
    
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
