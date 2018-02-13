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

public class LocationStats: NSObject {
    private let homeLocation = CLLocation(latitude: 39.1595230, longitude: -77.2219680)
    private var lastLocation: CLLocation? = nil
    private var lastConditions: TrafficConditions? = nil
    
    func getDistanceFromHome() -> CLLocationDistance {
        return lastLocation!.distance(from: homeLocation)
    }
    
    func getLastLocation() -> CLLocation {
        return lastLocation!
    }
    
    func getTrafficConditions() -> TrafficConditions {
        return lastConditions!
    }
    
    func update(location: CLLocation, completionHandler: @escaping () -> Void) {
        lastLocation = location
        TrafficStatus.shared.fetch(location: location, completionHandler: {trafficConditions in
            self.lastConditions = trafficConditions
            completionHandler()
        })
    }
}

public protocol LocationTrackerDelegate: NSObjectProtocol {
    func didUpdateLocationStats(locationStats: LocationStats) -> Void
}

class LocationDelegateConfig {
    var delegate: LocationTrackerDelegate? = nil
    var maxUpdateFrequencyMs: Double = Configuration.shared.defaultLocationDelegateUpdateFrequencyMs
    var delegateLastUpdated: Date? = nil
    
    var lastUpdated: Date? = nil
    
    func shouldUpdate() -> Bool {
        if let updatedDate = lastUpdated {
            return Date().timeIntervalSince(updatedDate) >= self.maxUpdateFrequencyMs
        } else {
            return true
        }
    }
    
    func didUpdate() {
        self.lastUpdated = Date()
    }
}

class LocationTracker: NSObject, CLLocationManagerDelegate {
    private var delegateConfig: LocationDelegateConfig = LocationDelegateConfig()
    
    private var endpoint: URL? = nil
    private let locationManager = CLLocationManager()
    private var isTracking = false
    private let locationStats = LocationStats()
    
    private var segmentBuffer: [LocationSegment] = []
    
    private override init() {
        super.init()
        let deviceUUID = UIDevice.current.identifierForVendor!
        self.endpoint = URL(string: "\(Configuration.shared.apiGatewayCore)/devices/\(deviceUUID)/location")
    }
    
    private func sendLocations() {
        NSLog("Publishing locations")
        let trace = LocationTrace(locations: self.segmentBuffer)
        self.segmentBuffer = []
        NSLog("Sending \(self.segmentBuffer.count) locations to \(endpoint)")
        WebUplink.shared.post(url: endpoint!, body: trace){ (data, error) in
            NSLog("Data POST result \(data ?? [:])")
            //TODO
        }
    }
    
    func setDelegate(delegateConfig: LocationDelegateConfig) {
        self.delegateConfig = delegateConfig
    }
    
    func setDelegate(delegate: LocationTrackerDelegate) {
        self.delegateConfig = LocationDelegateConfig()
        self.delegateConfig.delegate = delegate
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let locationSegments = locations.map { location in
            return LocationSegment(
                altitude: location.altitude,
                course: location.course,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                speed: location.speed,
                epochMs: location.timestamp.timeIntervalSince1970 * 1000
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
        }
    }
    
    func stopTracking() {
        if isTracking {
            NSLog("Stopping location tracking")
            locationManager.stopUpdatingLocation()
        }
    }
    
    static let shared = LocationTracker()
}
