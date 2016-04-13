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

enum NetworkStatus {
    case Wifi
    case Cellular
    case NotReachable
}

class ViewController: UIViewController {
    let kApiKey = ""
    let kSessionId = ""
    let kToken = "
    "
    
    var reachability: Reachability?
    var session : OTSession?
    var publisher: OTPublisher?
    var subscribers = [OTSubscriber]()
    var networkStatus : NetworkStatus = .NotReachable
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupReachability()
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
                if self.networkStatus != .NotReachable {
                    NSLog("::: Reachability -> Switch between Wifi and Cellular")
                    var error: OTError?
                    self.session?.disconnect(&error)
                }
                if reachability.isReachableViaWiFi() {
                    self.networkStatus = .Wifi
                    NSLog("::: Reachability -> Reachable via WiFi")
                    self.createSessionAndConnect()
                } else {
                    self.networkStatus = .Cellular
                    NSLog("::: Reachability -> Reachable via Cellular")
                    let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC)))
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
        if self.session?.sessionConnectionStatus != OTSessionConnectionStatus.Connected {
            session = OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)
            NSLog("Connecting to session \(kSessionId)...\n")
            session!.connectWithToken(kToken, error: nil)
        } else {
            NSLog("Skipped createSessionAndConnect()\n")
        }
    }
    
    func clearSubscribers() {
        for sub in subscribers {
            sub.view.removeFromSuperview()
        }

        subscribers.removeAll()
    }
}

extension ViewController: OTSessionDelegate {
    func sessionDidConnect(session: OTSession!) {
        NSLog("Session Connected")
        
        if publisher == nil {
            publisher = OTPublisher(delegate: self)
        }
        session.publish(publisher, error: nil)
    }
    
    func sessionDidDisconnect(session: OTSession!) {
        NSLog("Session Disconnected")
        self.session = nil
    }
    
    func session(session: OTSession!, didFailWithError error: OTError!) {
        NSLog("Session failed with error: \(error)")
    }
    
    func session(session: OTSession!, streamCreated stream: OTStream!) {
        NSLog("Stream created \(stream.streamId)")
        let subscriber = OTSubscriber(stream: stream, delegate: self)
        subscribers.append(subscriber)
        self.session?.subscribe(subscriber, error: nil)
    }
    
    func session(session: OTSession!, streamDestroyed stream: OTStream!) {
    }
}

extension ViewController: OTPublisherDelegate {
    func publisher(publisher: OTPublisherKit!, streamCreated stream: OTStream!) {
        NSLog("Stream created")
        
        self.publisher?.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        self.view.addSubview(self.publisher!.view)
    }
    
    func publisher(publisher: OTPublisherKit!, streamDestroyed stream: OTStream!) {
        NSLog("Stream destroyed")
        
        session?.disconnect(nil)
    }
    
    func publisher(publisher: OTPublisherKit!, didFailWithError error: OTError!) { }
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
