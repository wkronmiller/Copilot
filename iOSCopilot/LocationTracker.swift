//
//  LocationTracker.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/5/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation

public protocol LocationTrackerDelegate: NSObjectProtocol {
    func didUpdateLocationStats(locationStats: LocationStats) -> Void
}

class LocationReceiverConfig {
    private var isUpdating: Bool = false
    var delegate: LocationTrackerDelegate? = nil
    var maxUpdateFrequencyMs: Double = Configuration.shared.defaultLocationDelegateUpdateFrequencyMs
    var delegateLastUpdated: Date? = nil
    
    var lastUpdated: Date? = nil
    
    func shouldUpdate() -> Bool {
        if isUpdating {
            return false
        }
        if let updatedDate = lastUpdated {
            return abs(updatedDate.timeIntervalSinceNow * 1000) >= self.maxUpdateFrequencyMs
        } else {
            return true
        }
    }
    
    func setUpdating() {
        self.isUpdating = true
    }
    
    func didUpdate() {
        self.isUpdating = false
        self.lastUpdated = Date()
    }
}

class LocationTracker: NSObject, CLLocationManagerDelegate {
    private var delegateConfig: LocationReceiverConfig = LocationReceiverConfig()
    
    private var endpoint: URL? = nil
    private let locationManager = CLLocationManager()
    private var isTracking = false
    var privacyEnabled = false
    private let locationStats = LocationStats()
    private var updateTimer: Timer? = nil
    
    private var segmentBuffer: [LocationSegment] = []
    
    private override init() {
        super.init()
        let deviceUUID = UIDevice.current.identifierForVendor!
        self.endpoint = URL(string: "\(Configuration.shared.apiGatewayCore)/devices/\(deviceUUID)/location")
    }
    
    @objc private func sendLocations() {
        if self.segmentBuffer.isEmpty {
            NSLog("No location segments to broadcast")
            return
        }
        
        NSLog("Publishing locations")
        let trace = LocationTrace(locations: self.segmentBuffer)
        NSLog("Sending \(self.segmentBuffer.count) locations to \(endpoint)")
        self.segmentBuffer = []
        WebUplink.shared.post(url: endpoint!, body: trace){ (data, error) in
            if error != nil {
                NSLog("Send Location Error \(error!)")
            }
            NSLog("Data POST result \(data ?? [:])")
        }
    }
    
    private func initDelegate() {
        // Initialize delegate with cached data
        if let delegate = self.delegateConfig.delegate {
            if self.locationStats.hasData() {
                delegate.didUpdateLocationStats(locationStats: locationStats)
            }
        }
    }
    
    func setDelegate(delegateConfig: LocationReceiverConfig) {
        self.delegateConfig = delegateConfig
        initDelegate()
    }
    
    func setDelegate(delegate: LocationTrackerDelegate) {
        self.delegateConfig = LocationReceiverConfig()
        self.delegateConfig.delegate = delegate
        initDelegate()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locationSegments = locations.map { location in
            return LocationSegment(
                altitude: location.altitude,
                course: location.course,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                speed: location.speed,
                epochMs: location.timestamp.timeIntervalSince1970 * 1000,
                privacyEnabled: privacyEnabled
            )
        }
        
        self.segmentBuffer += locationSegments
        NSLog("Got locations update \(locationSegments.count)")

        if(segmentBuffer.count > 20) {
            sendLocations()
        }
        
        if let last = locations.last {
            locationStats.update(location: last, completionHandler: {
                // Dispatch to delegate
                if self.delegateConfig.shouldUpdate() {
                    self.delegateConfig.delegate?.didUpdateLocationStats(locationStats: self.locationStats)
                    self.delegateConfig.didUpdate()
                }
            })
        }
    }
    
    func startTracking() {
        if !isTracking {
            NSLog("Starting location tracking")
            locationManager.delegate = self
            locationManager.activityType = .automotiveNavigation
            locationManager.startUpdatingLocation()
            locationManager.requestAlwaysAuthorization()
            isTracking = true
            self.updateTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(sendLocations), userInfo: nil, repeats: true)
        }
    }
    
    func stopTracking() {
        if isTracking {
            NSLog("Stopping location tracking")
            locationManager.stopUpdatingLocation()
            self.updateTimer?.invalidate()
            self.updateTimer = nil
        }
    }
    
    static let shared = LocationTracker()
}
