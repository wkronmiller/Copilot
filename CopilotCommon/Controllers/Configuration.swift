//
//  Configuration.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/11/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

struct RootSettingKeys {
    static let username = "user_username"
    static let password = "user_password"
    static let weatherAlertsEnabled = "preference_weather_alerts"
    static let uploadLocationsCloud = "preference_upload_locations_cloud"
    static let enableMeshNetworking = "preference_enable_mesh"
}

public class Configuration: NSObject {
    let apiGatewayCore = "https://0kkgejw01g.execute-api.us-east-1.amazonaws.com/dev"
    //let apiGatewayCore = "http://192.168.11.218:3000" // Local testing
    
    //let baseMapTileUrl = "http://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
    let baseMapTileUrl = "http://statichosting.kronmiller.net:32771/dark_all/{z}/{x}/{y}.png"

    let radarTileUrl = "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/{z}/{x}/{y}.png"
    
    let defaultZoomMeters: CLLocationDistance = CLLocationDistance(8000)
    
    let defaultLocationDelegateUpdateFrequencyMs: Double = 5 * 1000 // 5 seconds
    let updateAnnotationFrequencyMs: Double = 1 * 1000 // 1 seconds
    
    let alertBadWeatherTimer: TimeInterval = 60 * 60 // 1 hour
    let alertBadWeatherFrequency: TimeInterval = 60 * 20 // 20 Minutes
    
    var audioAlertsEnabled: Bool = true
    
    private override init() {
        super.init()
    }
    
    func setAccount(username: String, password: String) {
        UserDefaults.standard.set(username, forKey: RootSettingKeys.username)
        UserDefaults.standard.set(password, forKey: RootSettingKeys.password)
    }
    
    func getAccount() -> Account? {
        if let username = UserDefaults.standard.string(forKey: RootSettingKeys.username) {
            NSLog("Got username \(username)")
            
            if let password = UserDefaults.standard.string(forKey: RootSettingKeys.password) {
                NSLog("Got password")
                return Account(username: username, password: password)
            }
        }
        return nil
    }
    
    func getWeatherAlertsEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: RootSettingKeys.weatherAlertsEnabled)
    }
    
    func getUploadLocationsToCloud() -> Bool {
        return UserDefaults.standard.bool(forKey: RootSettingKeys.uploadLocationsCloud)
    }
    
    func getEnableMeshNetworking() -> Bool {
        return UserDefaults.standard.bool(forKey: RootSettingKeys.enableMeshNetworking)
    }
    
    static let shared = Configuration()
}
