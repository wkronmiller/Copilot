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
import SQLite3

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

class LocationDatabase: NSObject {
    private let db: OpaquePointer?
    
    override init() {
        let dbUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!.appendingPathComponent("copilotLocations.sqlite")
        var db: OpaquePointer?
        if sqlite3_open(dbUrl.path, &db) != SQLITE_OK {
            fatalError("Unable to open sqlite database")
        }
        self.db = db
        super.init()
    }
    
    func ensureTable() {
        let statement = "create table if not exists locations (uuid integer primary key autoincrement, latitude double, longitude double, altitude double, speed double, epoch double, private boolean)"
        if sqlite3_exec(self.db, statement, nil, nil, nil) != SQLITE_OK {
            fatalError("Unable to initialize sqlite locations table")
        }
    }
    
    func addLocations(segments: [LocationSegment]) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "insert into locations (latitude, longitude, altitude, speed, epoch, private) values (?, ?, ?, ?, ?, 0)", -1, &statement, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(self.db!))
            NSLog("Sqlite prepared statement failed \(message)")
            return
        }
        segments.forEach{segment in
            if sqlite3_reset(statement) != SQLITE_OK {
                let message = String(cString: sqlite3_errmsg(self.db!))
                NSLog("Failed to reset sqlite statement \(message)")
                return
            }
            sqlite3_bind_double(statement, 1, segment.latitude)
            sqlite3_bind_double(statement, 2, segment.longitude)
            sqlite3_bind_double(statement, 3, segment.altitude)
            sqlite3_bind_double(statement, 4, segment.speed)
            sqlite3_bind_double(statement, 5, segment.epochMs)
            if sqlite3_step(statement) != SQLITE_DONE {
                let message = String(cString: sqlite3_errmsg(self.db!))
                NSLog("Failed to insert sqlite record \(message)")
                return
            }
        }
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(self.db!))
            NSLog("Failed to finalize sqlite statement \(message)")
        }
    }
    
    func getLocations() { //TODO: finish this
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(self.db, "select epoch, latitude, longitude, speed from locations", -1, &statement, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(self.db!))
            NSLog("GetLocations sqlite prepared statement failed \(message)")
            return
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            //TODO: put into data structure
            let epochMs = sqlite3_column_double(statement, 1)
            let latitude = sqlite3_column_double(statement, 2)
            let longitude = sqlite3_column_double(statement, 3)
            let speed = sqlite3_column_double(statement, 4)
            NSLog("Loaded location \(epochMs) \(latitude) \(longitude) \(speed)")
        }
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(self.db!))
            NSLog("Failed to finalize sqlite statement \(message)")
        }
    }
}

class LocationTracker: NSObject, CLLocationManagerDelegate {
    private var delegateConfig: LocationReceiverConfig = LocationReceiverConfig()
    
    private let locationDatabase = LocationDatabase()
    
    private var endpoint: URL? = nil
    private let locationManager = CLLocationManager()
    private var isTracking = false
    var privacyEnabled = false
    private let locationStats = LocationStats()
    private var updateTimer: Timer? = nil
    private static var shared: LocationTracker? = nil
    private let appDelegate: UIApplicationDelegate
    
    private var segmentBuffer: [LocationSegment] = []
    
    private init(account: Account) {
        self.appDelegate = UIApplication.shared.delegate!
        super.init()
        let deviceUUID = UIDevice.current.identifierForVendor!
        self.endpoint = URL(string: "\(Configuration.shared.apiGatewayCore)/users/\(account.username)/devices/\(deviceUUID)/locations")
        UIApplication.shared.setMinimumBackgroundFetchInterval(60)
        self.locationDatabase.ensureTable()
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
        
        self.locationDatabase.addLocations(segments: locationSegments)
        
        if locationSegments.count < 1 {
            return
        }
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
        
        locationStats.update(location: locations.last!, completionHandler: {
            // Dispatch to delegate
            if self.delegateConfig.shouldUpdate() {
                self.delegateConfig.delegate?.didUpdateLocationStats(locationStats: self.locationStats)
                self.delegateConfig.didUpdate()
            }
        })
    }
    
    func startTracking() {
        if !isTracking {
            NSLog("Starting location tracking")
            locationManager.delegate = self
            locationManager.activityType = .automotiveNavigation
            locationManager.startUpdatingLocation()
            locationManager.requestAlwaysAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = false
            isTracking = true
            self.updateTimer = Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(sendLocations), userInfo: nil, repeats: true)
            //self.updateTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(sendLocations), userInfo: nil, repeats: true)
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
}
