//
//  LocationDatabase.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/16/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import SQLite3

public struct Acceleration: Codable {
    let epochMs: Double
    let x: Double
    let y: Double
    let z: Double
    
    func getMagnitude() -> Double {
        return sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
    }
}

class LocationDatabase: NSObject {
    private let queue = DispatchQueue(label: "LocationDatabase")
    private let db: OpaquePointer?
    
    private let locationTableName = "locations3"
    private let accelerometerTableName = "accelerometer"
    
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
        self.queue.async {
            let statement = "create table if not exists \(self.locationTableName) (epochMs double primary key, altitude double, course double, latitude double, longitude double, speed double)"
            if sqlite3_exec(self.db, statement, nil, nil, nil) != SQLITE_OK {
                fatalError("Unable to initialize sqlite locations table")
            }
        }
        self.queue.async {
            let statement = "create table if not exists \(self.accelerometerTableName) (epochMs double primary key, x double, y double, z double)"
            if sqlite3_exec(self.db, statement, nil, nil, nil) != SQLITE_OK {
                fatalError("Unable to initialize sqlite locations table")
            }
        }
    }
    
    func addAccelerometerData(acceleration: Acceleration) {
        self.queue.async {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(self.db, "insert into \(self.accelerometerTableName) (epochMs, x, y, z) values (?, ?, ?, ?)", -1, &statement, nil) != SQLITE_OK {
                let message = String(cString: sqlite3_errmsg(self.db!))
                NSLog("Sqlite acceleration prepared statement failed \(message)")
                return
            }
            
            sqlite3_bind_double(statement, 1, acceleration.epochMs)
            sqlite3_bind_double(statement, 2, acceleration.x)
            sqlite3_bind_double(statement, 3, acceleration.y)
            sqlite3_bind_double(statement, 4, acceleration.z)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let message = String(cString: sqlite3_errmsg(self.db!))
                NSLog("Failed to insert acceleration sqlite record \(message)")
                return
            }
            
            if sqlite3_finalize(statement) != SQLITE_OK {
                let message = String(cString: sqlite3_errmsg(self.db!))
                NSLog("Failed to finalize acceleration sqlite statement \(message)")
            }
        }
    }
    
    func addLocations(segments: [LocationSegment]) {
        self.queue.async {
            NSLog("Database storing locations \(segments.last)")
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(self.db, "insert into \(self.locationTableName) (epochMs, altitude, course, latitude, longitude, speed) values (?, ?, ?, ?, ?, ?)", -1, &statement, nil) != SQLITE_OK {
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
                sqlite3_bind_double(statement, 1, segment.epochMs)
                sqlite3_bind_double(statement, 2, segment.altitude)
                sqlite3_bind_double(statement, 3, segment.course)
                sqlite3_bind_double(statement, 4, segment.latitude)
                sqlite3_bind_double(statement, 5, segment.longitude)
                sqlite3_bind_double(statement, 6, segment.speed)
                
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
    }
    
    func getLocations(dateInterval: DateInterval) -> [LocationSegment] {
        let group = DispatchGroup()
        var locationSegments: [LocationSegment] = []
        group.enter()
        
        let query = "select epochMs, altitude, course, latitude, longitude, speed from \(self.locationTableName) WHERE epochMs >= \(floor(dateInterval.start.timeIntervalSince1970 * 1000)) AND epochMs <= \(ceil(dateInterval.end.timeIntervalSince1970 * 1000)) ORDER BY epochMs asc"
        
        self.queue.async(group: group) {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(self.db, query, -1, &statement, nil) != SQLITE_OK {
                let message = String(cString: sqlite3_errmsg(self.db!))
                NSLog("GetLocations sqlite prepared statement failed \(message)")
                
            } else {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let epochMs = sqlite3_column_double(statement, 0)
                    let altitude = sqlite3_column_double(statement, 1)
                    let course = sqlite3_column_double(statement, 2)
                    let latitude = sqlite3_column_double(statement, 3)
                    let longitude = sqlite3_column_double(statement, 4)
                    let speed = sqlite3_column_double(statement, 5)
                    
                    let locationSegment = LocationSegment(epochMs: epochMs, altitude: altitude, course: course, latitude: latitude, longitude: longitude, speed: speed)
                    locationSegments.append(locationSegment)
                }
                
                NSLog("Database contains location segments \(locationSegments.last)")
                
                if sqlite3_finalize(statement) != SQLITE_OK {
                    let message = String(cString: sqlite3_errmsg(self.db!))
                    NSLog("Failed to finalize sqlite statement \(message)")
                }
                
                group.leave()
            }
        }
        group.wait()
        return locationSegments
    }
    
    func getAccelerometerData(dateInterval: DateInterval) -> [Acceleration] {
        let group = DispatchGroup()
        var accelerationData: [Acceleration] = []
        group.enter()
        
        let query = "select epochMs, x, y, z from \(self.accelerometerTableName) WHERE epochMs >= \(floor(dateInterval.start.timeIntervalSince1970 * 1000)) AND epochMs <= \(ceil(dateInterval.end.timeIntervalSince1970 * 1000)) ORDER BY epochMs asc"
        
        self.queue.async {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(self.db, query, -1, &statement, nil) != SQLITE_OK {
                let message = String(cString: sqlite3_errmsg(self.db!))
                NSLog("Get accelerometer sqlite prepared statement failed \(message)")
                
            } else {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let epochMs = sqlite3_column_double(statement, 0)
                    let x = sqlite3_column_double(statement, 1)
                    let y = sqlite3_column_double(statement, 2)
                    let z = sqlite3_column_double(statement, 3)
                    accelerationData.append(Acceleration(epochMs: epochMs, x: x, y: y, z: z))
                }
                
                NSLog("Finalizing accelerometer query")
                
                if sqlite3_finalize(statement) != SQLITE_OK {
                    let message = String(cString: sqlite3_errmsg(self.db!))
                    NSLog("Failed to finalize accelerometer sqlite statement \(message)")
                }
                group.leave()
            }
        }
        group.wait()
        NSLog("Loaded acceleration data \(accelerationData)")
        return accelerationData
    }
    
    
    static let shared = LocationDatabase()
}
