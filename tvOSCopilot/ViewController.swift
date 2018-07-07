//
//  ViewController.swift
//  tvOSCopilot
//
//  Created by William Rory Kronmiller on 7/6/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    private let locationManager = CLLocationManager()
    
    private let baseMapOverlay: MKTileOverlay
    private let baseTileRenderer: MKTileOverlayRenderer
    private let radarMapOverlay: MKTileOverlay
    private let radarTileRenderer: MKTileOverlayRenderer
    
    required init?(coder aDecoder: NSCoder) {
        self.baseMapOverlay = MKTileOverlay(urlTemplate: Configuration.shared.baseMapTileUrl)
        self.baseTileRenderer = MKTileOverlayRenderer(tileOverlay: self.baseMapOverlay)
        baseMapOverlay.canReplaceMapContent = true
        
        self.radarMapOverlay = MKTileOverlay(urlTemplate: Configuration.shared.radarTileUrl)
        
        self.radarTileRenderer = MKTileOverlayRenderer(tileOverlay: self.radarMapOverlay)
        super.init(coder: aDecoder)
        
        locationManager.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()
        mapView.delegate = self
        
        mapView.add(baseMapOverlay, level: .aboveLabels)
        mapView.add(radarMapOverlay, level: .aboveLabels)
        mapView.showsUserLocation = true
        mapView.showsScale = true
        mapView.showsBuildings = true

        
        baseTileRenderer.reloadData()
        radarTileRenderer.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKTileOverlay {
            if overlay as! MKTileOverlay == self.baseMapOverlay {
                return baseTileRenderer
            }
            
            return radarTileRenderer
        }
        /**
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.purple
            renderer.lineWidth = 6
            return renderer
        }
         */
        return MKOverlayRenderer()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        NSLog("Got locations \(locations)")
        if let lastLoc = locations.last {
            let region = MKCoordinateRegionMakeWithDistance(lastLoc.coordinate, 1000, 1000)
            mapView.setRegion(region, animated: false)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Failed to get locations \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch(status) {
        case .denied:
            NSLog("Denied location permissions")
            break
        case .notDetermined:
            NSLog("Location status not determined")
            break
        case .authorizedWhenInUse:
            NSLog("Authorized to use location")
            self.locationManager.requestLocation()
            break
        default:
            NSLog("Location status changed \(status.rawValue)")
        }
    }

}

