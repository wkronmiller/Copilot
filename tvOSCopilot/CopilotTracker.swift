//
//  CopilotTracker.swift
//  tvOSCopilot
//
//  Created by William Rory Kronmiller on 7/7/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import MapKit

struct LocationTrace {
    let topSpeed: Double
    let coordinates: [CLLocation]
}

protocol TrackableDelegate {
    func traceChanged(trace: LocationTrace)
}

//TODO: store list of tracked devices and have menu in view to select which ones to watch
class CopilotTrackable: NSObject {
    private let userId: String
    private let deviceUUID: String
    private var lastTrace: LocationTrace?
    private var stopped = true
    private let workQueue = DispatchQueue.init(label: "CopilotTrackerQueue")
    private var delegate: TrackableDelegate?
    
    init(userId: String, deviceUUID: String) {
        self.userId = userId
        self.deviceUUID = deviceUUID
    }
    
    private func fetchTrace(completionHandler: @escaping (Error?) -> Void) {
        let url = URL(string: "\(Configuration.shared.apiGatewayCore)/users/\(self.userId)/devices/\(self.deviceUUID)/locations")!
        WebUplink.shared.get(url: url, completionHandler: {data, error in
            if let rawData = data {
                let rawCoordinates = rawData["coordinates"] as! [[Double]]
                let coordinates = rawCoordinates.map{lonlat in
                    return CLLocation(latitude: lonlat[1], longitude: lonlat[0])
                }
                let properties = rawData["properties"] as! [String: Any]
                let topSpeed = properties["topSpeed"] as! Double
                self.lastTrace = LocationTrace(topSpeed: topSpeed, coordinates: coordinates)
            }
            completionHandler(error)
        })
    }
    
    private func watchTrace() {
        NSLog("Updating trace for \(self.deviceUUID)")
        self.fetchTrace(completionHandler: {error in
            if(self.stopped) {
                return
            }
            if let delegate = self.delegate {
                delegate.traceChanged(trace: self.lastTrace!)
            }
            let dispatchTime = DispatchTime.now() + 60
            self.workQueue.asyncAfter(deadline: dispatchTime, execute: self.watchTrace)
        })
        
    }
    
    func start(delegate: TrackableDelegate) {
        self.stopped = false
        self.delegate = delegate
        self.watchTrace()
    }
    
    func stop() {
        self.stopped = true
    }
}
