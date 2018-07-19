//
//  Scanners.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/19/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

// Police Scanners
class Scanners: NSObject {
    let scanners: [String: [String: URL]] = [
        "Maryland": [
            "Montgomery": URL(string:"http://audio2.broadcastify.com/4mn1w2q8trcgyv9.mp3?nc=37173583")!
        ]
    ]
}
