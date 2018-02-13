//
//  FirstViewController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/4/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import MapKit

class PoliceAnnotation: NSObject, MKAnnotation {
    var uuid: String
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(uuid: String, location: CLLocation) {
        self.uuid = uuid
        self.coordinate = location.coordinate
        self.subtitle = uuid
    }
}

// https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png

// https://cartocdn_{s}.global.ssl.fastly.net/base-dark/{z}/{x}/{y}.png

class MapViewController: UIViewController, LocationTrackerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var distanceFromHome: UILabel!
    @IBOutlet weak var trafficConditions: UILabel!
    
    private var policeAnnotations: [PoliceAnnotation] = []
    private var annotationsLastUpdated: Date? = nil
    private var processingAnnotations: Bool = false
    private let overlay: MKTileOverlay
    private let tileRenderer: MKTileOverlayRenderer
    
    required init?(coder aDecoder: NSCoder) {
        self.overlay = MKTileOverlay(urlTemplate: Configuration.shared.mapTileUrl)
        self.tileRenderer = MKTileOverlayRenderer(tileOverlay: self.overlay)
        overlay.canReplaceMapContent = true
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        LocationTracker.shared.startTracking()
        LocationTracker.shared.setDelegate(delegate: self)
        mapView.delegate = self
        
        mapView.add(overlay, level: .aboveLabels)
        
        let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: 0, longitude: 0), Configuration.shared.defaultZoomMeters, Configuration.shared.defaultZoomMeters)
        mapView.setRegion(region, animated: false)
        
        tileRenderer.reloadData()
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let delegateConfig = LocationDelegateConfig()
        delegateConfig.delegate = self
        delegateConfig.maxUpdateFrequencyMs = 1
        LocationTracker.shared.setDelegate(delegateConfig: delegateConfig)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return tileRenderer
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func updatePoliceAnnotations(locationStats: LocationStats) {
        if(processingAnnotations) {
            return
        }
        
        if let lastUpdated = annotationsLastUpdated {
            if lastUpdated.timeIntervalSince(Date()) < Configuration.shared.updateAnnotationFrequencyMs {
                return
            }
        }
        
        self.processingAnnotations = true
        
        NSLog("Updating police locations")

        let police = locationStats.getTrafficConditions().alerts
            .filter { alert in
                return (alert.type == "POLICE")
            }
        
        let newAnnotations: [PoliceAnnotation] = police.map{alert in
            PoliceAnnotation(uuid: alert.uuid, location: alert.location)
        }
        
        let newPoliceUids = newAnnotations.map{annotation in
            annotation.uuid
        }
        
        let currentPoliceUids = self.policeAnnotations.map{annotation in
            annotation.uuid
        }
        
        let annotationsToAdd = newAnnotations.filter{newAnnotation in
            return currentPoliceUids.contains(newAnnotation.uuid) == false
        }
        
        let annotationsToRemove = self.policeAnnotations.filter{policeAnnotation in
            return newPoliceUids.contains(policeAnnotation.uuid) == false
        }
        
        self.mapView.removeAnnotations(annotationsToRemove)
        self.mapView.addAnnotations(annotationsToAdd)
        self.policeAnnotations = newAnnotations
        self.annotationsLastUpdated = Date()
        self.processingAnnotations = false
        
        NSLog("Updated police annotations \(self.policeAnnotations.count) \(self.mapView.annotations.count)")
    }
    
    func didUpdateLocationStats(locationStats: LocationStats) {
        let location = locationStats.getLastLocation()

        let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        
        
        DispatchQueue.main.async {
            self.mapView.region.center = center
            //self.mapView.setRegion(region, animated: true)
        }

        DispatchQueue.main.async {
            self.distanceFromHome.text = "\(Int(locationStats.getDistanceFromHome() / 1000)) km"
        }
        
        let maxDistance: Double = 10 * 1000 // 10 km
        
        let jams = locationStats.getTrafficConditions().jams.filter{jam in
            return jam.line
                .filter{coordinate in
                    return coordinate.distance(from: location) < maxDistance
                }
                .isEmpty == false
        }
        
        DispatchQueue.main.async {
            self.trafficConditions.text = "\(jams.count)"
        }
        
        DispatchQueue.main.async {
            self.updatePoliceAnnotations(locationStats: locationStats)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NSLog("Map view unloaded")
    }
}

