//
//  Geocoder.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/2/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import MapKit
import CoreLocation

struct GeoAddress {
    let road: String?
    let county: String?
    let state: String?
    let postcode: String?
}

struct GeoLocation {
    let displayName: String
    let placeType: String
    let boundingBox: MKCoordinateRegion
    let address: GeoAddress
}

class Geocoder {
    var lastLocation: GeoLocation?

    private func extractAddress(rawAddress: [String: String]) -> GeoAddress {
        return GeoAddress(road: rawAddress["road"], county: rawAddress["county"], state: rawAddress["state"], postcode: rawAddress["postcode"])
    }
    
    private func boundingBoxToRegion(boundingBox: [Double]) -> MKCoordinateRegion {
        let latCenter = (boundingBox[0] + boundingBox[1]) / 2
        let lonCenter = (boundingBox[2] + boundingBox[3]) / 2
        let center = CLLocationCoordinate2D(latitude: latCenter, longitude: lonCenter)
        
        let latSpan = abs(boundingBox[0] - boundingBox[1])
        let lonSpan = abs(boundingBox[2] - boundingBox[3])
        let span = MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        
        let region = MKCoordinateRegion.init(center: center, span: span)
        return region
    }
    
    private func decodeLocation(rawData: [String: Any]) -> GeoLocation? {
        if let error = rawData["error"] {
            NSLog("Unable to decode location \(error)")
            return nil
        }
        
        let rawBoundingBox = (rawData["boundingbox"] as! [String]).map({location in
            return Double(location)!
        })
        
        let boundingBox = boundingBoxToRegion(boundingBox: rawBoundingBox)
        let address = self.extractAddress(rawAddress: rawData["address"] as! [String: String])
        
        return GeoLocation(displayName: rawData["display_name"] as! String, placeType: rawData["osm_type"] as! String, boundingBox: boundingBox, address: address)
    }
    func geocode(location: CLLocation, completionHandler: @escaping () -> Void) {
        let url = URL(string:"\(Configuration.shared.nominatimUrl)/reverse?format=json&lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)")!
        WebUplink.shared.get(url: url, completionHandler: {data, error in
            if(error != nil) {
                NSLog("Error geocoding \(error)")
                return
            }
            self.lastLocation = self.decodeLocation(rawData: data!)
            completionHandler()
        })
    }
}
