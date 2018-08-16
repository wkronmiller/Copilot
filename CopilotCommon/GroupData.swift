//
//  LocationSummary.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/27/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

public class GroupData {
    private let sharedDefaults: UserDefaults = UserDefaults.init(suiteName: "group.net.kronmiller.william.copilot")!
    
    var policeNearby: Int {
        get {
            return sharedDefaults.integer(forKey: "policeNearby")
        }
        set(number) {
            sharedDefaults.set(number, forKey: "policeNearby")
        }
    }
    
    var lastUpdated: Date? {
        get {
            return sharedDefaults.object(forKey: "lastUpdated") as? Date
        }
        set(date) {
           sharedDefaults.set(date, forKey: "lastUpdated")
        }
    }
}
