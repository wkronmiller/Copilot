//
//  MeshDiscovery.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/7/18.
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

protocol MeshConnectionDelegate {
    func connection(_ network: MeshNetwork, didConnect connection: MeshConnection)
    func connection(_ network: MeshNetwork, didDisconnect peerID: MCPeerID)
    
    //TODO: reconnected
}

enum MeshPacketType: String {
    case handshake
}

class MeshNetwork: NSObject, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {
    private let serviceType = "copilot-mpc"
    private let selfId: MCPeerID
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let advertiser: MCNearbyServiceAdvertiser
    
    private var openConnections: [MeshConnection] = []
    
    private let isBaseStation: Bool
    
    private var isAdvertising = false
    
    var delegate: MeshConnectionDelegate? = nil
    
    init(isBaseStation: Bool) {
        self.selfId = MCPeerID(displayName: UIDevice.current.identifierForVendor!.uuidString)
        self.session = MCSession(peer: self.selfId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.none)
        self.browser = MCNearbyServiceBrowser(peer: self.selfId, serviceType: self.serviceType)
        self.advertiser = MCNearbyServiceAdvertiser(peer: self.selfId, discoveryInfo: nil, serviceType: self.serviceType)
        self.isBaseStation = isBaseStation
        super.init()
        self.session.delegate = self
        self.browser.delegate = self
        self.advertiser.delegate = self
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("Failed to start advertising \(error)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("Got invitation from peer \(peerID)")
        invitationHandler(true, self.session)
        NSLog("Accepted invitation from peer \(peerID)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("Found peer \(peerID)")
        let existingConnection = self.openConnections.contains{ connection in
            return connection.peerID == peerID
        }
        if(existingConnection) {
            NSLog("Mesh already has connection to peer \(peerID)")
        }
        if(self.isBaseStation) {
            NSLog("Inviting peer \(peerID)")
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10.0)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("Lost peer \(peerID)")
    }
    
    private func sendHandshake(peer: MCPeerID, session: MCSession) {
        NSLog("Sending device UUID")
        let uuid = UIDevice.current.identifierForVendor!.uuidString
        let userId = Configuration.shared.getAccount()!.username
        let packet: [String: String] = ["type": MeshPacketType.handshake.rawValue, "uuid": uuid, "userId": userId]
        let encoder = JSONEncoder()
        do {
            let json = try encoder.encode(packet)
            try session.send(json, toPeers: [peer], with: MCSessionSendDataMode.reliable)
            //TODO
        } catch {
            NSLog("Failed to send UUID \(error)")
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch(state) {
        case .connected:
            NSLog("Connected to peer \(peerID)")
            if(self.isBaseStation == false) {
                self.sendHandshake(peer: peerID, session: session)
            }
            break
        case .notConnected:
            NSLog("Mesh disconnected from peer \(peerID)")
            self.openConnections = self.openConnections.filter({connection in
                connection.peerID != peerID
            })
            self.delegate?.connection(self, didDisconnect: peerID)
            break
        case .connecting:
            NSLog("Connecting to peer \(peerID)")
        }
    }

    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("Received data packet from peer \(peerID) \(String(data: data, encoding: .utf8))")
        do {
            let packet = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            NSLog("Decoded packet as \(packet)")
            let type = packet["type"] as! String
            switch(type) {
            case MeshPacketType.handshake.rawValue:
                let uuid = packet["uuid"] as! String
                let userId = packet["userId"] as! String
                NSLog("Got UUID from device \(uuid)")
                let newConnection = MeshConnection(peerID: peerID, session: session, peerUserId: userId, peerUUID: uuid)
                self.openConnections.append(newConnection)
                self.delegate?.connection(self, didConnect: newConnection)
                return
            default:
                return
            }
        } catch {
            NSLog("Failed to deserialize packet \(data): \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("Received data stream naemd \(streamName) from peer \(peerID)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("Started receiving resource \(resourceName) from peer \(peerID)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("Finished receiving resource \(resourceName) from peer \(peerID)")
    }
    
    func startAdvertising() {
        self.advertiser.startAdvertisingPeer()
        self.browser.startBrowsingForPeers()
        NSLog("Mesh is advertising")
    }
    
    func stopAdvertising() {
        self.advertiser.stopAdvertisingPeer()
        self.browser.stopBrowsingForPeers()
        NSLog("Mesh is not advertising")
    }
    
    func toggleAdvertising() -> Bool {
        if(isAdvertising) {
            self.isAdvertising = false
            self.stopAdvertising()
        } else {
            self.isAdvertising = true
            self.startAdvertising()
        }
        return self.isAdvertising
    }
}

