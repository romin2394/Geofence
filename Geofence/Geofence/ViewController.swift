//
//  ViewController.swift
//  Geofence
//
//  Created by Romin's Macbook  on 04/10/24.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var postalCode = ""
    var currentPostalCode: String?
    var geofences = [Geofence]()
    var isFirstLaunch = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.geofences.append(Geofence(geofenceId: "1", geofenceName: "Mumbai", latitude: 19.0176147, longitude: 72.8561644, radius: 200, isEnabled: true))
        self.geofences.append(Geofence(geofenceId: "2", geofenceName: "London", latitude:51.50998 , longitude: -0.1337, radius: 300, isEnabled: true))
        self.geofences.append(Geofence(geofenceId: "3", geofenceName: "Hong Kong", latitude:22.284681, longitude:114.158177 , radius: 400, isEnabled: true))
        self.geofences.append(Geofence(geofenceId: "4", geofenceName: "Paris", latitude:48.856788, longitude:2.351077 , radius: 400, isEnabled: false))
        
        self.setupLocationManager()
        
    }
    
    private func setupLocationManager() {
        DispatchQueue.global().async { [self] in
            locationManager.requestWhenInUseAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            mapView.showsUserLocation = true
            mapView.delegate = self
            locationManager.delegate = self
            locationManager.allowsBackgroundLocationUpdates = true
            
            if CLLocationManager.locationServicesEnabled() {
                locationManager.startUpdatingLocation()
                self.addPinOnMap()
                self.startGeofencing()
            }
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if error == nil {
                if let placemark = placemarks?.first, let postalCode = placemark.postalCode {
                    self.handlePostalCodeChange(newPostalCode: postalCode, location: location)
                }
            } else {
                print("Error in reverse geocoding: \(String(describing: error))")
            }
        }
    }
    
    private func handlePostalCodeChange(newPostalCode: String, location: CLLocation) {
        if let currentCode = currentPostalCode {
            if currentCode != newPostalCode {
                print("Postal code has changed from \(currentCode) to \(newPostalCode)")
            }
        } else {
            print("Initial postal code: \(newPostalCode)")
        }
        currentPostalCode = newPostalCode
    }
    
    private func addPinOnMap() {
        for geofence in geofences {
            let coordinate = CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)
            if !isPinAlreadyAdded(at: coordinate) {
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = geofence.geofenceName
                mapView.addAnnotation(annotation)
                
                //for overlay
                if geofence.isEnabled {
                    let circle = MKCircle(center: coordinate, radius: geofence.radius)
                    mapView.addOverlay(circle)
                }
            }
        }
    }
    
    private func startGeofencing() {
        for geofence in geofences {
            let geofenceRegionCenter = CLLocationCoordinate2DMake(geofence.latitude, geofence.longitude)
            let geofenceRegion = CLCircularRegion(center: geofenceRegionCenter, radius: geofence.radius, identifier: geofence.geofenceId)
            geofenceRegion.notifyOnEntry = geofence.isEnabled
            geofenceRegion.notifyOnExit = geofence.isEnabled
            
            locationManager.startMonitoring(for: geofenceRegion)
        }
    }
    
    private func isPinAlreadyAdded(at coordinate: CLLocationCoordinate2D) -> Bool {
        for annotation in mapView.annotations {
            if let pointAnnotation = annotation as? MKPointAnnotation {
                if pointAnnotation.coordinate.latitude == coordinate.latitude &&
                    pointAnnotation.coordinate.longitude == coordinate.longitude {
                    return true
                }
            }
        }
        return false
    }
    
    private func zoomToUserLocation(location: CLLocation) {
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(region, animated: true)
    }
    
    // MARK: Schedule Local Notification
    
    func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}

// MARK: - Extension

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let circleRenderer = MKCircleRenderer(circle: circleOverlay)
            circleRenderer.fillColor = UIColor.red.withAlphaComponent(0.1)
            circleRenderer.strokeColor = UIColor.red
            circleRenderer.lineWidth = 2
            return circleRenderer
        }
        return MKOverlayRenderer()
    }
}

extension ViewController: CLLocationManagerDelegate {
    
    // Handle authorization status
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            self.addPinOnMap()
            self.startGeofencing()
        case .denied, .restricted:
            print("Location access denied or restricted")
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if let userLocation = locations.first {
            if isFirstLaunch {
                zoomToUserLocation(location: userLocation)
                isFirstLaunch = false // Ensures zoom happens only once
            }
        }
        self.reverseGeocode(location: location)
        print("LA: \(locations.first!.coordinate.latitude), LO: \(locations.first!.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            if let geofence = geofences.first(where: {$0.geofenceId == region.identifier}) {
                self.scheduleNotification(title: "Hey there!", body: "Welcome to \(geofence.geofenceName)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            if let geofence = geofences.first(where: {$0.geofenceId == region.identifier}) {
                self.scheduleNotification(title: "Hey there!", body: "Goodbye from \(geofence.geofenceName)")
            }
        }
    }
}

