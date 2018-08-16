//
//  MeshPacket.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 8/15/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

enum MeshPacketType: String, Codable {
    case handshake
    case sendRideStatistics
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
