//
//  LocationDatabase.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/16/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import SQLite3

class LocationDatabase: NSObject {
    private let db: OpaquePointer?
    
    private let tableName = "locations3"
    
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
        let statement = "create table if not exists \(tableName) (epochMs double primary key, altitude double, course double, latitude double, longitude double, speed double)"
        if sqlite3_exec(self.db, statement, nil, nil, nil) != SQLITE_OK {
            fatalError("Unable to initialize sqlite locations table")
        }
    }
    
    func addLocations(segments: [LocationSegment]) {
        NSLog("Database storing locations \(segments.last)")
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "insert into \(tableName) (epochMs, altitude, course, latitude, longitude, speed) values (?, ?, ?, ?, ?, ?)", -1, &statement, nil) != SQLITE_OK {
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
    
    func getLocations() -> [LocationSegment] {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(self.db, "select epochMs, altitude, course, latitude, longitude, speed from \(tableName) ORDER BY epochMs asc", -1, &statement, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(self.db!))
            NSLog("GetLocations sqlite prepared statement failed \(message)")
            return []
        }
        
        var locationSegments: [LocationSegment] = []
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
        
        return locationSegments
    }
    
    
    static let shared = LocationDatabase()
}
