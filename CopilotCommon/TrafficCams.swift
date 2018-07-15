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
}

class TrafficCams: NSObject {
    private var cameras: [TrafficCam] = []
    
    private func loadCam(rawCam: [String: Any]) -> TrafficCam {
        NSLog("Loading camera \(rawCam)")
        let name = rawCam["name"] as! String
        let address = URL(string: rawCam["address"] as! String)!
        NSLog("Camera address \(address)")
        let latitude = rawCam["latitude"] as! Double
        let longitude = rawCam["longitude"] as! Double
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        return TrafficCam(name: name, address: address, location: location)
    }
    
    func getCameras() -> [TrafficCam] {
        NSLog("Getting nearby cameras")
        return self.cameras
    }
    
    private func fetchCameras(url: URL, completionHandler: @escaping (Error?) -> Void) {
        NSLog("Fetching URL \(url)")
        CopilotAPI.shared.get(url: url, completionHandler: {(data, error) in
            if(nil != error) {
                NSLog("Error fetching cameras: \(error!)")
                return completionHandler(error)
            }
            NSLog("Raw camera data \(data)")
            if let rawCameras = data?["cameras"] as? [[String: Any]] {
                self.cameras = rawCameras.map(self.loadCam)
                NSLog("Nearby cameras \(self.cameras)")
            } else {
                NSLog("Failed to get cameras")
            }
            return completionHandler(nil)
        })
    }
    
    func refreshNearby(location: CLLocation, completionHandler: @escaping (Error?) -> Void) {
        let url = URL(string: "\(Configuration.shared.apiGatewayCore)/cameras/\(location.coordinate.latitude)/\(location.coordinate.longitude)")!
        fetchCameras(url: url, completionHandler: completionHandler)
    }
    
    func refresh(allCamerasLoaded: @escaping (Error?) -> Void) {
        let url = URL(string: "\(Configuration.shared.apiGatewayCore)/cameras")!
        fetchCameras(url: url, completionHandler: allCamerasLoaded)
    }
}
