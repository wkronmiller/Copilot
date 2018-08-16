//
//  MeshDiscovery.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/7/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

import MultipeerConnectivity

protocol MeshConnectionDelegate {
    func connection(_ network: MeshNetwork, didConnect connection: MeshConnection)
    func connection(_ network: MeshNetwork, didDisconnect peerID: MCPeerID)

    //TODO: reconnected
}

protocol MeshBaseStationDelegate: MeshConnectionDelegate {
    func connection(_ network: MeshNetwork, gotRideStatistics rideStatistics: RideStatistics, connection: MeshConnection)
}

protocol MeshControllerDelegate: MeshConnectionDelegate {
    //TODO
}

// Accepts mesh clients
class MeshBaseStation: MeshNetwork {
    private func getBaseStationDelegate() -> MeshBaseStationDelegate? {
        if let delegate = self.delegate {
            return delegate as? MeshBaseStationDelegate
        }
        return nil
    }
    override func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        super.browser(browser, foundPeer: peerID, withDiscoveryInfo: info)
        NSLog("Inviting peer \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10.0)
    }
    
    override func gotRideStatistics(connection: MeshConnection, rideStatistics: RideStatistics) {
        self.getBaseStationDelegate()?.connection(self, gotRideStatistics: rideStatistics, connection: connection)
    }
}

class MeshNetworkController: MeshNetwork {
    //TODO
}

//TODO: break this into two classes, one for baseStations and one for controlllers
class MeshNetwork: NSObject, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {
    private let serviceType = "copilot-mpc"
    private let selfId: MCPeerID
    internal let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let advertiser: MCNearbyServiceAdvertiser
    
    private var openConnections: [MeshConnection] = []
    
    private var isAdvertising = false
    
    var delegate: MeshConnectionDelegate? = nil
    
    override init() {
        self.selfId = MCPeerID(displayName: UIDevice.current.identifierForVendor!.uuidString)
        self.session = MCSession(peer: self.selfId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.none)
        self.browser = MCNearbyServiceBrowser(peer: self.selfId, serviceType: self.serviceType)
        self.advertiser = MCNearbyServiceAdvertiser(peer: self.selfId, discoveryInfo: nil, serviceType: self.serviceType)
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
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("Lost peer \(peerID)")
    }
    
    private let encoder = JSONEncoder()
    
    private func sendHandshake(peer: MCPeerID, session: MCSession) {
        NSLog("Mesh sending handshake")
        
        if let username = Configuration.shared.getAccount()?.username {
            let handshakeData =
                HandshakeData(uuid: UIDevice.current.identifierForVendor!.uuidString, userId: username)
            
            let packet = MeshPacket.create(type: .handshake, payload: handshakeData)
            
            do {
                try session.send(packet.serialize(), toPeers: [peer], with: .reliable)
                NSLog("Mesh sent handshake")
            } catch {
                NSLog("Mesh Failed to send handshake \(error)")
            }
        } else {
            NSLog("Mesh Cannot send handshake without account info")
        }
    }

    func sendRideSummary(connection: MeshConnection, rideStatistics: RideStatistics) {
        //TODO
        let packet = MeshPacket.create(type: .sendRideStatistics, payload: rideStatistics)
        do {
            try connection.session.send(packet.serialize(), toPeers: [connection.peerID], with: .reliable)
        } catch {
            NSLog("Failed to send ride statistics \(error)")
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch(state) {
        case .connected:
            NSLog("Mesh connected to peer \(peerID)")
            self.sendHandshake(peer: peerID, session: session)
            NSLog("Sent handshake")
            break
        case .notConnected:
            NSLog("Mesh disconnected from peer \(peerID)")
            self.openConnections = self.openConnections.filter({connection in
                connection.peerID != peerID
            })
            self.delegate?.connection(self, didDisconnect: peerID)
            break
        case .connecting:
            NSLog("Mesh connecting to peer \(peerID)")
        }
    }
    
    internal func gotRideStatistics(connection: MeshConnection, rideStatistics: RideStatistics) {}
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("Mesh received data packet from peer \(peerID) \(String(data: data, encoding: .utf8))")
        let packet = MeshPacket.deserialize(data: data)
        NSLog("Mesh decoded packet as \(packet) with type \(packet.type.rawValue)")
        switch(packet.type) {
        case .handshake:
            NSLog("Mesh got handshake packet")
            let handshakeData: HandshakeData = packet.getPayload()
            let newConnection = MeshConnection(peerID: peerID, session: session, peerUserId: handshakeData.userId, peerUUID: handshakeData.uuid)
            self.openConnections.append(newConnection)
            self.delegate?.connection(self, didConnect: newConnection)
            return
        case .sendRideStatistics:
            let rideStatistics: RideStatistics = packet.getPayload()
            if let connection = self.openConnections.first(where: {connection in
                connection.peerID == peerID
            }) {
                NSLog("Got ride statistcis from \(connection)")
                self.gotRideStatistics(connection: connection, rideStatistics: rideStatistics)
            }
            break
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
    
    func getConnected() -> [MeshConnection] {
        return self.openConnections
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

