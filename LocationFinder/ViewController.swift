//
//  ViewController.swift
//  LocationFinder
//
//  Created by Alex Gonczaruk on 2023-11-16.
//

import UIKit
import CoreLocation
import Network
import MobileCoreServices
import UniformTypeIdentifiers
import Foundation

class ViewController: UIViewController, CLLocationManagerDelegate, StreamDelegate {
    
    @IBOutlet var label: UILabel!
    @IBOutlet var label1: UILabel!
    var manager: CLLocationManager?
    
    let ipAddress = "192.168.2.36"
    let port: UInt32 = 8888
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: 1024)
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var connected: Bool = false // to indicate connected button press
    var success: Bool = false // to indicate successful connection
        
    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "connecting to GPS..."
        label1.text = "caddy is not connected"
        label1.textColor = UIColor.black
    }
    
    func sendMessage(message: String) {
        if connected == false {
            return
        }
        guard let data = message.data(using: .utf8) else {
            return
        }
        _ = data.withUnsafeBytes { outputStream?.write($0, maxLength: data.count)}
    }
    
    func checkForResponse() {
        DispatchQueue.global(qos: .background).async {
            self.buffer = [UInt8](repeating: 0, count: self.bufferSize)
            let bytesRead = self.inputStream?.read(&self.buffer, maxLength: self.bufferSize) ?? 0
            if bytesRead < 0 {
                if let _ = self.inputStream?.streamError {
                    return
                }
            }
            if let message = String(bytes: self.buffer, encoding: .utf8) {
                self.updateCaddyDistance(message: message)
            }
        }
    }
    
    func updateCaddyDistance(message: String) {
        DispatchQueue.main.async {
            if message.hasPrefix("PI:") {
                let components = message.components(separatedBy: "PI:")

                // Filter out empty strings and take the second component
                if let numberString = components.dropFirst().first, let number = Double(numberString) {
                    print("Received message: \(numberString)")
                    self.label1.text = "Golf caddy is \(numberString)m away"
                }
                
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        manager?.requestWhenInUseAuthorization()
        manager?.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let first = locations.first else {
            return
        }
        
        label.text = "\(round(first.coordinate.latitude*1000000000)/1000000000), \(round(first.coordinate.longitude*1000000000)/1000000000)"
        if let labelText = label?.text {
            let encodedMessage = "COORDINATE:\(labelText)"
            sendMessage(message: encodedMessage)
        }
        checkForResponse()
    }

    
    @IBAction func connection(_ sender: UIButton) {
        print("starting")
        sendMessage(message: "ACTION:START")
        checkForResponse()

    }
    @IBAction func stopbtn(_ sender: UIButton) {
        print("stopping")
        sendMessage(message: "ACTION:STOP")
        checkForResponse()
    }

    @IBAction func connectbtn(_ sender: UIButton) {
        if (connected == true) {
            return
        }
        connected = true
        print("connecting")
        Stream.getStreamsToHost(withName: ipAddress, port: Int(port), inputStream: &inputStream, outputStream: &outputStream)
        inputStream?.delegate = self
        outputStream?.delegate = self
        inputStream?.schedule(in: .current, forMode: .common)
        outputStream?.schedule(in: .current, forMode: .common)
        inputStream?.open()
        outputStream?.open()
        sendMessage(message: "ACTION:SOCKET IS OPEN")
    }
}



