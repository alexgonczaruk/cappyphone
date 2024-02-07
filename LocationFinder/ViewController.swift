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
    @IBOutlet var STOP: UIButton!
    @IBOutlet var START: UIButton!
    @IBOutlet var ConnectBtn: UIButton!
    @IBOutlet var yourImageView: UIImageView!
    var manager: CLLocationManager?
    
    let ipAddress = "192.168.2.52"
    let port: UInt32 = 8888
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: 1024)
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var connected: Bool = false // to indicate connected button press
    var success: Bool = false // to indicate successful connection
    
    var ReadyToSend = true
        
    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "connecting to GPS..."
        label1.text = "caddy is not connected"
        label1.textColor = UIColor.black
        
        START.layer.borderWidth = 0.0 // No border
        START.layer.cornerRadius = 35.0
        START.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20.0)
        START.setTitleColor(UIColor.white, for: .normal)
        START.backgroundColor = UIColor(red: 0.0, green: 191/255.0, blue: 1.0, alpha: 1.0)
        
        
        STOP.layer.borderColor = UIColor(red: 0.0, green: 191/255.0, blue: 1.0, alpha: 1.0).cgColor
        
        STOP.layer.cornerRadius = 35.0
        
        STOP.layer.borderWidth = 5.0
        STOP.layer.borderColor = UIColor(red: 0.0, green: 191/255.0, blue: 1.0, alpha: 1.0).cgColor

        // STOP.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20.0) // Adjust the font size
        // STOP.setTitleColor(UIColor.blue, for: .normal)
        rotateImage()
    }
    
    func rotateImage() {
            // Create a rotation animation
            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotationAnimation.toValue = NSNumber(value: Double.pi * 2) // Full rotation (360 degrees)
            rotationAnimation.duration = 5.0 // Time taken for one complete rotation
            rotationAnimation.isCumulative = true
            rotationAnimation.repeatCount = Float.infinity // Infinite loop

            // Apply the rotation animation to yourImageView's layer
            yourImageView.layer.add(rotationAnimation, forKey: "rotationAnimation")
        }
    
    func sendMessage(message: String) {
        if connected == false {
            print("not connected")
            return
        }
        
        guard let data = message.data(using: .utf8) else {
            return
        }
        if ReadyToSend == true {
            print("SENDING: \(message)")
            _ = data.withUnsafeBytes { outputStream?.write($0, maxLength: data.count)}
            ReadyToSend = false
        }
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
                self.receiveData(message: message)
            }
        }
    }
    
    func receiveData(message: String) {
        // self.ConnectBtn.setTitle("Connected", for: .normal)
        // self.ConnectBtn.setTitleColor(UIColor.green, for: .normal)
        DispatchQueue.main.async {
            if message.hasPrefix("PI:") {
                let components = message.components(separatedBy: "PI:")

                // Filter out empty strings and take the second component
                if let numberString = components.dropFirst().first, let number = Double(numberString) {
                    print("Received message: \(numberString)")
                    self.label1.text = "Golf caddy is \(numberString)m away"
                }
                
            } else if message.hasPrefix("ACTION:") {
                let components = message.components(separatedBy: "ACTION:")
                
                if let action = components.dropFirst().first {
                    if action.contains("STOP") {
                        print("STOPPING!!! OBSTACLE")
                        self.label1.text = "Obstacle Detected. Caddy set to STOP"
                    }
                } else {
                    print("No second element in the 'components' array.")
                }
            } else if message.hasPrefix("SETUP:") {
                print("CONNECTION HAS BEEN ESTABLISHED")
            }
            self.ReadyToSend = true
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



