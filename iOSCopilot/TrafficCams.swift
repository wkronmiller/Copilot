//
//  TrafficCams.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/20/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

public struct TrafficCam {
    var name: String
    var address: URL
    var location: CLLocation
    var distance: CLLocationDistance
}

class TrafficCams: NSObject {
    private var nearbyCams: [TrafficCam] = []
    
    private func loadCam(rawCam: [String: Any]) -> TrafficCam {
        let name = rawCam["name"] as! String
        let address = URL(string: rawCam["address"] as! String)!
        let latitude = rawCam["latitude"] as! Double
        let longitude = rawCam["longitude"] as! Double
        let distance = CLLocationDistance(rawCam["distance"] as! Double)
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        return TrafficCam(name: name, address: address, location: location, distance: distance)
    }
    
    func getNearbyCameras() -> [TrafficCam] {
        NSLog("Getting nearby cameras")
        return self.nearbyCams
    }
    
    func refreshNearby(location: CLLocation, completionHandler: @escaping (Error?) -> Void) {
        let url = URL(string: "\(Configuration.shared.apiGatewayCore)/cameras/\(location.coordinate.latitude)/\(location.coordinate.longitude)")!
        
        NSLog("Fetching URL \(url)")
        WebUplink.shared.get(url: url, completionHandler: {(data, error) in
            if(nil != error) {
                NSLog("Error fetching cameras: \(error!)")
                return completionHandler(error)
            }
            if let rawCameras = data!["cameras"] as? [[String: Any]] {
                self.nearbyCams = rawCameras.map(self.loadCam)
                NSLog("Nearby cameras \(self.nearbyCams)")
            }
            return completionHandler(nil)
        })
    }
}
