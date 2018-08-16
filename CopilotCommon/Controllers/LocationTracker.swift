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
import CoreMotion

public protocol LocationTrackerDelegate: NSObjectProtocol {
    func didUpdateLocationStats(locationStats: LocationStats) -> Void
}

//TODO: complete the refactor away from this model
class LocationReceiverConfig {
    private var isUpdating: Bool = false
    var delegate: LocationTrackerDelegate? = nil
    var maxUpdateFrequencyMs: Double = Configuration.shared.defaultLocationDelegateUpdateFrequencyMs
    var delegateLastUpdated: Date? = nil
    
    var lastUpdated: Date? = nil
    
    func shouldUpdate() -> Bool {
        if isUpdating {
            NSLog("Already updating")
            return false
        }
        if let updatedDate = lastUpdated {
            let timeDiff = abs(updatedDate.timeIntervalSinceNow * 1000)
            let intervalPassed = timeDiff >= self.maxUpdateFrequencyMs
            NSLog("Checking updated date. Time diff \(timeDiff). Interval passed \(intervalPassed)")
            return intervalPassed
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

// Global location data delegate, distributes location data to rest of app
class LocationTracker: NSObject, CLLocationManagerDelegate {
    private var trackingLevel: CLLocationDistance = CLLocationDistance(5000) // 5km resolution
    
    private var delegateConfig: LocationReceiverConfig = LocationReceiverConfig()
    
    private var endpoint: URL? = nil
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private var isTracking = false
    var privacyEnabled = false
    private let locationStats = LocationStats()
    private var updateTimer: Timer? = nil
    private static var shared: LocationTracker? = nil
    private let appDelegate: UIApplicationDelegate
    
    private let operationQueue = OperationQueue()
    
    private var segmentBuffer: [LocationSegment] = []
    
    private init(account: Account) {
        self.appDelegate = UIApplication.shared.delegate!
        super.init()
        let deviceUUID = UIDevice.current.identifierForVendor!
        self.endpoint = URL(string: "\(Configuration.shared.apiGatewayCore)/users/\(account.username)/devices/\(deviceUUID)/locations")
        UIApplication.shared.setMinimumBackgroundFetchInterval(90)
        LocationDatabase.shared.ensureTable()
    }
    
    static func get(account: Account) -> LocationTracker {
        if let existing = shared {
            return existing
        }
        shared = LocationTracker(account: account)
        return shared!
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
        CopilotAPI.shared.post(url: endpoint!, body: trace){ (data, error) in
            if error != nil {
                NSLog("Send Location Error \(error!)")
            }
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
    
    func clearDelegate() {
        self.delegateConfig.delegate = nil
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
    
    private func sendToCloud(locationSegments: [LocationSegment]) {
        let last = locationSegments.last!
        let fastest = locationSegments.reduce(last, {max, current in
            if(max.speed < current.speed) {
                return current
            }
            return max
        })
        let slowest = locationSegments.reduce(last, {min, current in
            if(min.speed > current.speed) {
                return current
            }
            return min
        })
        
        let summarizedSegments = [slowest, fastest]
            .sorted{a, b in
                return a.epochMs < b.epochMs
            }
            .filter({segment in
                segment.epochMs != last.epochMs
            })
            + [last]
        
        self.segmentBuffer += summarizedSegments
        //self.segmentBuffer += locationSegments //TODO: store full location trace
        
        NSLog("Got locations update \(summarizedSegments)")
        
        if(segmentBuffer.count > 120) {
            sendLocations()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locationSegments = locations.map { location in
            return LocationSegment(
                epochMs: location.timestamp.timeIntervalSince1970 * 1000,
                altitude: location.altitude,
                course: location.course,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                speed: location.speed
            )
        }
        
        LocationDatabase.shared.addLocations(segments: locationSegments)
        if locationSegments.count < 1 {
            return
        }
        
        if Configuration.shared.getUploadLocationsToCloud() {
            self.sendToCloud(locationSegments: locationSegments)
        }
        
        locationStats.update(location: locations.last!, completionHandler: {
            // Dispatch to delegate
            if self.delegateConfig.shouldUpdate() {
                self.delegateConfig.delegate?.didUpdateLocationStats(locationStats: self.locationStats)
                self.delegateConfig.didUpdate()
            }
        })
    }
    
    private func handleAccelerometer(data: CMAccelerometerData) {
        let acceleration = Acceleration(epochMs: Date().timeIntervalSince1970 * 1000, x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z)
        LocationDatabase.shared.addAccelerometerData(acceleration: acceleration)
    }
    
    func setTrackingLevel(distanceFilter: CLLocationDistance) {
        self.trackingLevel = distanceFilter
        self.locationManager.distanceFilter = distanceFilter
        if self.isTracking {
            self.locationManager.stopUpdatingLocation()
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func startTracking() {
        if !isTracking {
            NSLog("Starting location tracking")
            locationManager.delegate = self
            locationManager.activityType = .automotiveNavigation
            locationManager.startUpdatingLocation()
            locationManager.requestAlwaysAuthorization()
            locationManager.distanceFilter = self.trackingLevel
            locationManager.pausesLocationUpdatesAutomatically = true
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = false
            isTracking = true
            self.updateTimer = Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(sendLocations), userInfo: nil, repeats: true)
            
            if self.motionManager.isAccelerometerAvailable {
                self.motionManager.accelerometerUpdateInterval = 0.5 // Every half second
                self.motionManager.startAccelerometerUpdates(to: self.operationQueue){ data, error in
                    if error != nil {
                        NSLog("Error getting accelerometer data \(error!)")
                    } else {
                        self.handleAccelerometer(data: data!)
                    }
                }
            } else {
                NSLog("Accelerometer data unavailable")
            }
        }
    }
    
    func stopTracking() {
        if isTracking {
            NSLog("Stopping location tracking")
            locationManager.stopUpdatingLocation()
            self.updateTimer?.invalidate()
            self.updateTimer = nil
            
            self.motionManager.stopAccelerometerUpdates()
        }
    }
}
