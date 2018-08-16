//
//  CopilotApi.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/15/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

// Connection to API Server
class CopilotAPI: WebUplink {
    private var jwt: JWT? = nil
    
    private override init() {
        super.init()
    }
    
    private func fetchJWT(account: Account, completionHandler: @escaping () -> Void) {
        let url = URL(string:"\(Configuration.shared.apiGatewayCore)/users/\(account.username)/tokens")!
        let payload: [String: String] = ["password": account.password]
        super.post(url: url, jwt: nil, body: payload, completionHandler: {response, error in
            if(error != nil || response == nil) {
                //TODO: handle error in callback
                NSLog("Failed to get jwt \(error)")
                return
            }
            
            let token = response!["token"] as! String
            let expiresSeconds = response!["expiresSeconds"] as! Int
            self.jwt = JWT(token: token, expires: Date(timeIntervalSince1970: TimeInterval(expiresSeconds)))
            NSLog("Got jwt token")
            completionHandler()
        })
    }
    
    private func ensureJwt(account: Account, completionHandler: @escaping () -> Void) {
        if let existing = self.jwt {
            if existing.expires.timeIntervalSinceNow < 0 {
                completionHandler()
                return
            }
        }
        fetchJWT(account: account, completionHandler: completionHandler)
    }
    
    override func post<T>(url: URL, body: T, completionHandler: @escaping ([String : Any]?, Error?) -> Void) where T : Encodable {
        ensureJwt(account: Configuration.shared.getAccount()!, completionHandler: {
            super.post(url: url, jwt: self.jwt!.token, body: body, completionHandler: completionHandler)
        })
    }
    
    //TODO: find a cleaner solution
    static let shared = CopilotAPI()
}
