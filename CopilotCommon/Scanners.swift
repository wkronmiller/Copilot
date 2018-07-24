//
//  Scanners.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/19/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

struct Scanner {
    let name: String
    let state: String
    let county: String
    let url: URL
}

// Police Scanners
class Scanners: NSObject {
    private static let scanners: [Scanner] = [
        Scanner(name: "Montgomery County Police", state: "Maryland", county: "Montgomery", url: URL(string:"http://audio2.broadcastify.com/x018cpzdy2g5j7f.mp3")!)
    ]
    
    func getScanners() -> [Scanner] {
        return Scanners.scanners
    }
}
