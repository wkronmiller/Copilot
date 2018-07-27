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

class MapViewController: UIViewController, LocationTrackerDelegate, MKMapViewDelegate {

    @IBOutlet weak var currentLocationLabel: UILabel!
    
    @IBOutlet weak var mapView: MKMapView!
    
    private let annotationViewReuseId = "traffic_annotation_view"
    
    private var policeAnnotations: [PoliceAnnotation] = []
    private var trafficLines: [MKGeodesicPolyline] = []
    private var annotationsLastUpdated: Date? = nil
    private var processingAnnotations: Bool = false
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
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        AppDelegate.locationTracker!.startTracking()
        AppDelegate.locationTracker!.setDelegate(delegate: self)
        mapView.delegate = self
        
        mapView.add(baseMapOverlay, level: .aboveLabels)
        mapView.add(radarMapOverlay, level: .aboveLabels)
        
        let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: 0, longitude: 0), Configuration.shared.defaultZoomMeters, Configuration.shared.defaultZoomMeters)
        mapView.setRegion(region, animated: false)
        
        baseTileRenderer.reloadData()
        radarTileRenderer.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let delegateConfig = LocationReceiverConfig()
        delegateConfig.delegate = self
        delegateConfig.maxUpdateFrequencyMs = 1
        AppDelegate.locationTracker!.setDelegate(delegateConfig: delegateConfig)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKTileOverlay {
            if overlay as! MKTileOverlay == self.baseMapOverlay {
                return baseTileRenderer
            }
            
            return radarTileRenderer
        }
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.lightGray
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func updateTrafficJamAnnotations(trafficConditions: TrafficConditions) {
        self.trafficLines.forEach{ line in
            self.mapView.remove(line)
        }
        
        let lines: [MKGeodesicPolyline] = trafficConditions.jams
            .map { jam in
                return jam.line
            }
            .map { locations in
                return locations.map{ location in
                    return location.coordinate
                }
            }
            .map { coordinates in
                let polyline = MKGeodesicPolyline(coordinates: coordinates, count: coordinates.count)
                return polyline
            }
        self.trafficLines = lines
        
        self.trafficLines.forEach { polyline in
            mapView.add(polyline)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationViewReuseId)
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationViewReuseId)
        }
        
        if annotation is PoliceAnnotation {
            let image = UIImage(named: "ic_security")!
            let scale = 30
            let size = CGSize(width: scale, height: scale)
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            
            UIGraphicsBeginImageContext(size)
            image.draw(in: rect)
            annotationView?.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        
        return annotationView
    }

    private func updatePoliceAnnotations(trafficConditions: TrafficConditions) {
        NSLog("Updating police locations")
        
        let police = trafficConditions.getPoliceLocations()
        
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
        
        NSLog("Updated police annotations \(self.policeAnnotations.count) \(self.mapView.annotations.count)")
    }
    
    private func updateTrafficConditionAnnotations(trafficConditions: TrafficConditions) {
        if let lastUpdated = self.annotationsLastUpdated {
            if abs(lastUpdated.timeIntervalSinceNow * 1000) < Configuration.shared.updateAnnotationFrequencyMs {
                NSLog("Skipping traffic annotation update since already updated \(lastUpdated.timeIntervalSinceNow) seconds ago")
                return
            }
        }
        NSLog("Map view controller is updating traffic conditions")
        DispatchQueue.main.async {
            if(self.processingAnnotations) {
                return
            }
            self.processingAnnotations = true
            self.updatePoliceAnnotations(trafficConditions: trafficConditions)
            self.updateTrafficJamAnnotations(trafficConditions: trafficConditions)
            self.annotationsLastUpdated = Date()
            self.processingAnnotations = false
        }
    }
    
    func didUpdateLocationStats(locationStats: LocationStats) {
        if(UIApplication.shared.applicationState == .background) {
            return
        }
        
        let location = locationStats.getLastLocation()

        let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        if let waypointName = locationStats.getTrafficStatus().getWaypoint()?.name {
            DispatchQueue.main.async {
                self.currentLocationLabel.text = waypointName
                NSLog("Current location name \(waypointName)")
            }
        } else {
            DispatchQueue.main.async {
                self.currentLocationLabel.text = "Unknown Location"
            }
        }
        
        DispatchQueue.main.async {
            self.mapView.region.center = center
            //self.mapView.setRegion(region, animated: true)
        }
        
        if let trafficConditions = locationStats.getTrafficStatus().getLastStatus() {
            self.updateTrafficConditionAnnotations(trafficConditions: trafficConditions)
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.locationTracker!.clearDelegate()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NSLog("Map view unloaded")
    }
}

