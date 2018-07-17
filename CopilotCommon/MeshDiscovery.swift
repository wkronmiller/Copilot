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
    func connection(_ network: MeshNetwork, gotLocations: [LocationSegment], connection: MeshConnection)
    //TODO: reconnected
}

enum MeshPacketType: String, Codable {
    case handshake
    case sendLocations
    case requestLocations
}

struct HandshakeData: Codable {
    let uuid: String
    let userId: String
}

class MeshPacket: Codable {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    
    var type: MeshPacketType
    var payload: Data
    
    init(type: MeshPacketType, payload: Data) {
        self.type = type
        self.payload = payload
    }
    
    static func create<T: Codable>(type: MeshPacketType, payload: T) -> MeshPacket {
        let encoded = try! MeshPacket.encoder.encode(payload)
        return MeshPacket(type: type, payload: encoded)
    }
    
    func serialize() -> Data {
        return try! MeshPacket.encoder.encode(self)
    }
    
    static func deserialize(data: Data) -> MeshPacket {
        return try! MeshPacket.decoder.decode(self, from: data)
    }
    
    func getPayload<T: Codable>() -> T {
        return try! MeshPacket.decoder.decode(T.self, from: self.payload)
    }
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
    
    private let encoder = JSONEncoder()
    
    private func sendHandshake(peer: MCPeerID, session: MCSession) {
        NSLog("Sending device UUID")
        
        let handshakeData =
            HandshakeData(uuid: UIDevice.current.identifierForVendor!.uuidString, userId: Configuration.shared.getAccount()!.username)
        
        let packet = MeshPacket.create(type: .handshake, payload: handshakeData)
        
        do {
            try session.send(packet.serialize(), toPeers: [peer], with: .reliable)
        } catch {
            NSLog("Failed to send handshake \(error)")
        }
    }
    
    private func sendLocations(peer: MCPeerID, session: MCSession) {
        NSLog("Sending device location history")
        
        let locationSegments = LocationDatabase.shared.getLocations()
        let packet = MeshPacket.create(type: .sendLocations, payload: locationSegments)
        do {
            try session.send(packet.serialize(), toPeers: [peer], with: .reliable)
        } catch {
            NSLog("Failed to send location segments \(error)")
        }
    }
    
    func requestLocations(connection: MeshConnection) {
        let emptyPayload: [String: String] = [:]
        let packet = MeshPacket.create(type: .requestLocations, payload: emptyPayload)
        do {
            try connection.session.send(packet.serialize(), toPeers: [connection.peerID], with: .reliable)
        } catch {
            NSLog("Failed to request location segments \(error)")
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
        let packet = MeshPacket.deserialize(data: data)
        NSLog("Decoded packet as \(packet)")
        switch(packet.type) {
        case .handshake:
            let handshakeData: HandshakeData = packet.getPayload()
            let newConnection = MeshConnection(peerID: peerID, session: session, peerUserId: handshakeData.userId, peerUUID: handshakeData.uuid)
            self.openConnections.append(newConnection)
            self.delegate?.connection(self, didConnect: newConnection)
            return
        case .sendLocations:
            NSLog("Got location traces")
            let locationSegments: [LocationSegment] = packet.getPayload()
            if let connection = self.openConnections.first(where: {connection in
                connection.peerID == peerID
            }) {
                self.delegate?.connection(self, gotLocations: locationSegments, connection: connection)
            } else {
                NSLog("Could not find connection for peer that sent locations \(peerID)")
            }
            return
        case .requestLocations:
            NSLog("Got location trace request")
            //TODO: ask for permission
            self.sendLocations(peer: peerID, session: session)
            return
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

