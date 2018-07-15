//
//  Waze.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/11/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

struct TrafficJam {
    var line: [CLLocation]
    var severity: Int
    var speed: Double
}

struct TrafficAlert {
    let type: String
    let uuid: String
    let location: CLLocation
    let waypoint: Waypoint
}

struct TrafficConditions {
    var jams: [TrafficJam]
    var alerts: [TrafficAlert]
    
    func getPoliceLocations() -> [TrafficAlert] {
        return alerts.filter { alert in
            return (alert.type == "POLICE")
        }
    }
}

class TrafficStatus: NSObject {
    private let receiverConfig: LocationReceiverConfig
    private let webUplink: WebUplink
    private var lastFetched: Date? = nil
    private var lastStatus: TrafficConditions? = nil
    private var lastWaypoint: Waypoint? = nil
    
    override init() {
        self.receiverConfig = LocationReceiverConfig()
        self.receiverConfig.maxUpdateFrequencyMs = 20 * 1000 // 20 seconds
        self.webUplink = CopilotAPI.shared
        super.init()
    }
    
    private func mkUrl(location: CLLocation) -> URL {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        return URL(string: "\(Configuration.shared.apiGatewayCore)/waze/\(latitude)/\(longitude)")!
    }
    
    private func extractLine(data: [String: Any]) -> [CLLocation] {
        let rawLine = data["line"] as! [[String: Double]]
        return rawLine.map{coordDict in
            return CLLocation(latitude: coordDict["y"]!, longitude: coordDict["x"]!)
        }
    }
    
    private func extractJams(data: [String : Any]) -> [TrafficJam] {
        if let rawJams = data["jams"] as? [[String: Any]] {
            
            let jams = rawJams.map{jam -> TrafficJam in
                let line = self.extractLine(data: jam)
                let speed = jam["speed"] as! Double
                let severity = jam["severity"] as! Int
                return TrafficJam(line: line, severity: severity, speed: speed)
            }
            
            return jams
        }
        
        return []
    }
    
    private func extractAlerts(data: [String: Any]) -> [TrafficAlert] {
        let rawAlerts = data["alerts"] as? [[String: Any]]
        
        if(rawAlerts == nil) {
            NSLog("Error unpacking traffic alerts from \(data)")
            return []
        }
        
        return rawAlerts!.map{alert in
            let rawLocation = alert["location"] as! [String: Double]
            let latitude = rawLocation["y"]!
            let longitude = rawLocation["x"]!
            let location = CLLocation(latitude: latitude, longitude: longitude)
            
            let type = alert["type"] as! String
            let uuid = alert["uuid"] as! String
            
            let waypoint = getWaypoint(data: alert)!
            
            return TrafficAlert(type: type, uuid: uuid, location: location, waypoint: waypoint)
        }
    }
    
    private func getWaypoint(data: [String: Any]) -> Waypoint? {
        let rawWaypoint = data["waypoint"] as? [String: Any]
        if(rawWaypoint == nil) {
            return nil
        }
        let latitude = rawWaypoint!["latitude"] as! Double
        let longitude = rawWaypoint!["longitude"] as! Double
        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return Waypoint(location: coordinates, name: rawWaypoint!["name"] as? String)
    }
    
    func getLastStatus() -> TrafficConditions? {
        return self.lastStatus
    }
    
    func getLastFetched() -> Date? {
        return self.lastFetched
    }
    
    func getWaypoint() -> Waypoint? {
        return self.lastWaypoint
    }
    
    func fetch(location: CLLocation, completionHandler: @escaping (TrafficConditions?) -> Void) {
        let url = mkUrl(location: location)
        
        if self.receiverConfig.shouldUpdate() {
            NSLog("Updating traffic status")
            self.receiverConfig.setUpdating()
            CopilotAPI.shared.get(url: url, completionHandler: {(data, error) in
                if error != nil {
                    NSLog("Error loading traffic \(error!)")
                    self.receiverConfig.didUpdate()
                    return
                }
                self.lastFetched = Date()
                let jams = self.extractJams(data: data!)
                let alerts = self.extractAlerts(data: data!)
                self.lastWaypoint = self.getWaypoint(data: data!)
                self.lastStatus = TrafficConditions(jams: jams, alerts: alerts)
                self.receiverConfig.didUpdate()
                completionHandler(self.lastStatus)
            })
        } else {
            NSLog("Skipping traffic stats update")
            completionHandler(self.lastStatus)
        }
    }
}
