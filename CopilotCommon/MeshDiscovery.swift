//
//  MeshDiscovery.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/7/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

import MultipeerConnectivity

protocol ConnectionEventDelegate {
    func connection(_ network: MeshNetwork, didConnect peerID: String)
    func connection(_ network: MeshNetwork, didDisconnect peerID: String)
}

class MeshNetwork: NSObject, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {
    private let serviceType = "copilot-windhorse-mpc"
    private let selfId: MCPeerID
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let advertiser: MCNearbyServiceAdvertiser
    
    private let isBaseStation: Bool
    
    private var isAdvertising = false
    
    var delegate: ConnectionEventDelegate? = nil
    
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
        if(self.isBaseStation) {
            NSLog("Inviting peer \(peerID)")
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10.0)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("Lost peer \(peerID)")
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch(state) {
        case .connected:
            NSLog("Connected to peer \(peerID)")
            self.delegate?.connection(self, didConnect: peerID.displayName)
            break
        case .notConnected:
            NSLog("Disconnected from peer \(peerID)")
            self.delegate?.connection(self, didDisconnect: peerID.displayName)
            break
        case .connecting:
            NSLog("Connecting to peer \(peerID)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("Received data packet from peer \(peerID)")
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
    }
    
    func stopAdvertising() {
        self.advertiser.stopAdvertisingPeer()
        self.browser.stopBrowsingForPeers()
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

