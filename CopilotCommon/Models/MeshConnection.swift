//
//  MeshConnection.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 8/15/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import MultipeerConnectivity

struct MeshConnection {
    let peerID: MCPeerID
    let session: MCSession
    let peerUserId: String
    let peerUUID: String
}
