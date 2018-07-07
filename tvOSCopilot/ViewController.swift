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
import AVKit

class TrafficCamAnnotation: NSObject, MKAnnotation {
    var address: URL
    var title: String?
    var coordinate: CLLocationCoordinate2D
    
    init(trafficCam: TrafficCam) {
        self.address = trafficCam.address
        self.title = trafficCam.name
        self.coordinate = trafficCam.location.coordinate
    }
}

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var playerContainer: UIView!
    
    private let locationManager = CLLocationManager()
    
    private let trafficCams = TrafficCams()
    
    private let baseMapOverlay: MKTileOverlay
    private let baseTileRenderer: MKTileOverlayRenderer
    private let radarMapOverlay: MKTileOverlay
    private let radarTileRenderer: MKTileOverlayRenderer
    private var radarLastRefreshed: Date? = nil
    
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
        mapView.showsScale = false

        
        baseTileRenderer.reloadData()
        radarTileRenderer.reloadData()
        radarLastRefreshed = Date()
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
    
    private func scaleImage(scale: Int, image: UIImage) -> UIImage {
        let size = CGSize(width: scale, height: scale)
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    private func ensureView(withIdentifier: String, annotation: MKAnnotation?) -> MKAnnotationView {
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: withIdentifier)
        if annotationView == nil {
            return MKAnnotationView(annotation: annotation, reuseIdentifier: withIdentifier)
        }
        return annotationView!
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        NSLog("Handling annotation \(annotation)")
        if annotation is MKUserLocation {
            NSLog("User location annotation")
            let annotationView = ensureView(withIdentifier: "userLocation", annotation: annotation)
            NSLog("Ensured annotation view \(annotationView)")
            annotationView.isEnabled = false
            let pinImage = UIImage(named: "crosshairs")!
            annotationView.image = scaleImage(scale: 50, image: pinImage)
            return annotationView
        }
        
        if annotation is TrafficCamAnnotation {
            let annotationView = ensureView(withIdentifier: "trafficCameras", annotation: annotation)
            annotationView.image = scaleImage(scale: 30, image: UIImage(named: "camera")!)
            annotationView.isEnabled = true
            annotationView.canShowCallout = true
            return annotationView
            
        }
        return nil
    }
    
    private var playing: AVPlayer? = nil
    
    //TODO: use specialized annotation
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        NSLog("Selected view \(view)")
        if view.annotation is TrafficCamAnnotation {
            let trafficAnnotation = view.annotation as! TrafficCamAnnotation
            let player = AVPlayer(url: trafficAnnotation.address)
            player.isMuted = true
            let playerLayer = AVPlayerLayer(player: player)
            DispatchQueue.main.async {
                self.playerContainer.layer.sublayers?.forEach{ $0.removeFromSuperlayer() }
                playerLayer.frame = self.playerContainer.bounds
                self.playerContainer.layer.addSublayer(playerLayer)
                player.play()
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        if view.annotation is TrafficCamAnnotation {
            //TODO
        }
    }
    
    private func showCameras(cameras: [TrafficCam]) {
        NSLog("Got cameras \(cameras)")
        let camAnnotations = cameras.map({cam in
            return TrafficCamAnnotation(trafficCam: cam)
        })
        
        mapView.addAnnotations(camAnnotations)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        NSLog("Got locations \(locations)")
        if let lastLoc = locations.last {
            let region = MKCoordinateRegionMakeWithDistance(lastLoc.coordinate, 1000, 1000)
            mapView.setRegion(region, animated: false)
            trafficCams.refreshNearby(location: lastLoc, completionHandler: {error in
                if error != nil {
                    NSLog("Error getting nearby traffic cameras \(error)")
                    return
                }
                self.showCameras(cameras: self.trafficCams.getNearbyCameras())
            })
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
    
    
    
    @IBAction func longPressed(_ sender: Any) {
        DispatchQueue.main.async {
            var doRefresh = true
            if let lastReloaded = self.radarLastRefreshed {
                doRefresh = (abs(lastReloaded.timeIntervalSinceNow) > 5)
            }
            if doRefresh {
                self.radarLastRefreshed = Date()
                NSLog("Refreshing radar data")
                self.radarTileRenderer.reloadData()
            }
        }
    }

}

