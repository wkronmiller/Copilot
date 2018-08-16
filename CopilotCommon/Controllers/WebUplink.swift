//
//  CloudUplink.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/10/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation

class WebUplink: NSObject {
    private let queue = DispatchQueue(label: "WebUplink")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let session = URLSession(configuration: .default)
    
    override init() {
        super.init()
    }
    
    private func decode(data: Data) -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch let error {
            NSLog("Error during deserialization: \(error) of data \(String(data: data, encoding: .utf8) ?? "NO DATA")")
            return nil
        }
    }
    
    private func fetch(request: URLRequest, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        let task = session.dataTask(with: request) { (data, response, error) in
            NSLog("Got data \(data) error \(error) for request \(request)")
            completionHandler(data.flatMap(self.decode), error)
        }
        
        task.resume()
    }
    
    private func postData(url: URL, jwt: String?, body: Data, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        var request = URLRequest(url: url)
        if let token = jwt {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 1500
        request.httpBody = body
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        NSLog("Sending request \(request)")

        fetch(request: request, completionHandler: completionHandler)
    }
    
    internal func post<T>(url: URL, jwt: String?, body: T, completionHandler: @escaping ([String: Any]?, Error?) -> Void) where T: Encodable {
        let jsonData = try? self.encoder.encode(body)
        let body: Data = jsonData!
        self.postData(url: url, jwt: jwt, body: body, completionHandler: completionHandler)
    }
    
    func post<T>(url: URL, body: T, completionHandler: @escaping ([String: Any]?, Error?) -> Void) where T: Encodable {
        self.post(url: url, jwt: nil, body: body, completionHandler: completionHandler)
    }
    
    func get(url: URL, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 1500
        request.httpMethod = "GET"
        
        fetch(request: request, completionHandler: completionHandler)
    }

}
