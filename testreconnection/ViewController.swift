//
//  ViewController.swift
//  testreconnection
//
//  Created by Roberto Perez Cubero on 04/04/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok
import ReachabilitySwift

class ViewController: UIViewController {
    static let kApiKey = ""
    static let kSessionId = ""
    static let kToken = ""
    
    var reachability: Reachability?
    var session : OTSession?
    var publisher: OTPublisher?
    var subscribers = [OTSubscriber]()
    var previousReachabilityStatus : Reachability.NetworkStatus = .NotReachable
    var needToReconnect = false
    var networkStatus : Reachability.NetworkStatus = .NotReachable
    
    var myPreviousStreamId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupReachability()
    }
    
    @IBOutlet weak var muteSub: UIButton!
    @IBOutlet weak var mutePub: UIButton!
    
    @IBAction func muteSub(sender: AnyObject) {
        if subscribers.count <= 0 { return }
        
        self.subscribers[0].subscribeToAudio = !self.subscribers[0].subscribeToAudio
        self.muteSub.setTitle(self.subscribers[0].subscribeToAudio ? "Mute Sub" : "Unmute Sub", forState: .Normal)
    }
    
    @IBAction func mutePub(sender: AnyObject) {
        guard let pub = self.publisher
            else {
                print("Pub not set")
                return
        }
        pub.publishAudio = !pub.publishAudio
        self.mutePub.setTitle(pub.publishAudio ? "Mute Pub": "Unmute Pub", forState: .Normal)
    }
    
    func setupReachability() {
        do {
            self.reachability = try Reachability.reachabilityForInternetConnection()
        } catch {
            NSLog("::: Reachability -> Unable to create Reachability")
            return
        }
        reachability!.whenReachable = { reachability in
            dispatch_async(dispatch_get_main_queue(), { 
                if reachability.currentReachabilityStatus != .NotReachable {
                    NSLog("::: Reachability -> Switch between Wifi and Cellular")
                    var error: OTError?
                    self.session?.disconnect(&error)
                }
                if reachability.isReachableViaWiFi() {
                    self.networkStatus = .ReachableViaWiFi
                    NSLog("::: Reachability -> Reachable via WiFi")
                    self.createSessionAndConnect()
                } else {
                    self.networkStatus = .ReachableViaWWAN
                    NSLog("::: Reachability -> Reachable via Cellular")
                    let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC)))
                    dispatch_after(delayTime, dispatch_get_main_queue()) {
                        self.createSessionAndConnect()
                    }
                }
            })
        }
        reachability!.whenUnreachable = { reachability in
            dispatch_async(dispatch_get_main_queue(), { 
                NSLog("::: Reachability -> Not reachable")
                self.networkStatus = .NotReachable
            })
        }
        
        do {
            try reachability!.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
    }
    
    func createSessionAndConnect() {
        self.clearSubscribers()
        let currentStatus = self.reachability!.currentReachabilityStatus
        EnableCellular.setCellularEnabled(currentStatus == .ReachableViaWWAN)
            // Enable 3G connectivty when connected to a WWAN
        assert(self.session?.sessionConnectionStatus != OTSessionConnectionStatus.Connected)
        self.session = OTSession(apiKey: ViewController.kApiKey, sessionId: ViewController.kSessionId, delegate: self)
        print("Connecting to session \(ViewController.kSessionId)... \(self.session)\n")
        self.session!.connectWithToken(ViewController.kToken, error: nil)
    }
    
    func clearSubscribers() {
        for sub in subscribers {
            sub.view.removeFromSuperview()
        }

        subscribers.removeAll()
    }
    
    func reachabilityChanged(n: NSNotification) {
        dispatch_async(dispatch_get_main_queue()) {
            print("Reachability Changed")
            let currentStatus = self.reachability!.currentReachabilityStatus
            
            print("Current status: \(currentStatus)")
            
            if self.previousReachabilityStatus == currentStatus {
                print("Reachability hasn't changed, exiting")
                return
            }

            self.previousReachabilityStatus = currentStatus
            
            if self.session?.sessionConnectionStatus == OTSessionConnectionStatus.Connected {
                self.needToReconnect = true
                if self.publisher != nil {
                    var error : OTError?
                    self.session?.unpublish(self.publisher, error: &error)
                    if error != nil {
                        print("Error: \(error)")
                    }
                    // Wait until stream destroyed callback is called
                    // Then it will disconnect and we will reconnect on the sessionDidDisconnect
                } else {
                    // OK, our publisher wasn't streaming yet, just disconnect from the session
                    // And reconnect on the diddisconnect callback
                    self.session?.disconnect(nil)
                }
            } else {
                // Our session is not connected just try to connect here
                self.createSessionAndConnect()
            }
        }
    }
}

extension ViewController: OTSessionDelegate {
    func sessionDidConnect(session: OTSession!) {
        print("Session Connected with id: \(session.connection.connectionId) - \(self.session?.connection.connectionId)")
        dispatch_async(dispatch_get_main_queue()) {
            self.publisher = OTPublisher(delegate: self)
            print("Publishing \(self.publisher) into session \(self.session) (\(self.session?.connection.connectionId))")
            
            var error : OTError?
            self.session?.publish(self.publisher, error: &error)
            if error != nil {
                print("Error: \(error)")
            }
        }
    }
    
    func sessionDidDisconnect(session: OTSession!) {
        print("Session Disconnected")
        if needToReconnect {
            print("Reconnecting after disconnect...")
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.createSessionAndConnect()
            }
        }
    }
    
    func session(session: OTSession!, didFailWithError error: OTError!) {
        print("Session failed with error: \(error)")
        if needToReconnect {
            createSessionAndConnect()
        }
    }
    
    func session(session: OTSession!, streamCreated stream: OTStream!) {
        if stream.streamId == self.myPreviousStreamId {
            print("Skipping stream since it was my previous stream before reconnecting")
            return
        }
        let subscriber = OTSubscriber(stream: stream, delegate: self)
        subscribers.append(subscriber)
        session.subscribe(subscriber, error: nil)
    }
    
    func session(session: OTSession!, streamDestroyed stream: OTStream!) {
    }
}

extension ViewController: OTPublisherDelegate {
    func publisher(publisher: OTPublisherKit!, streamCreated stream: OTStream!) {
        print("Publisher stream created: \(publisher.stream.streamId)")
        self.myPreviousStreamId = publisher.stream.streamId
        self.publisher?.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        self.view.addSubview(self.publisher!.view)
    }
    
    func publisher(publisher: OTPublisherKit!, streamDestroyed stream: OTStream!) {
        print("Publisher Stream destroyed: \(stream.streamId)")
        self.myPreviousStreamId = stream.streamId
        self.publisher?.view.removeFromSuperview()
        session?.disconnect(nil)
    }
    
    func publisher(publisher: OTPublisherKit!, didFailWithError error: OTError!) {
        print("Publisher Failed: \(publisher), \(error)")
    }
}

extension ViewController: OTSubscriberKitDelegate {
    
    func subscriberDidConnectToStream(subscriberKit: OTSubscriberKit!) {
        let sub = self.subscribers.filter { (sub) -> Bool in
            return sub.stream.streamId == subscriberKit.stream.streamId
        }[0]
        sub.view.frame = CGRect(origin: CGPoint(x: 0, y: 320),
                                size: CGSize(width: 160, height: 120))
        self.view.addSubview(sub.view)

        NSLog("Subscriber did connect to stream streamId: \(subscriberKit.stream.streamId)")
    }

    func subscriber(subscriber: OTSubscriberKit!, didFailWithError error: OTError!) {
        NSLog("Subscriber did fail -> \(error)")
    }
}
