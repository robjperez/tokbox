//
//  ViewController.swift
//  testreconnection
//
//  Created by Roberto Perez Cubero on 04/04/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok

class ViewController: UIViewController {
    let kApiKey = ""
    let kSessionId = ""
    let kToken = ""
    
    let reachability = Reachability(hostName: "www.tokbox.com")
    var session : OTSession?
    var publisher: OTPublisher?
    var subscribers = [OTSubscriber]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.reachabilityChanged(_:)), name: kReachabilityChangedNotification, object: reachability)
        reachability.startNotifier()
    }
    
    func createSessionAndConnect() {
        if self.session?.sessionConnectionStatus != OTSessionConnectionStatus.Connected {
            session = OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)
            NSLog("Connecting to session \(kSessionId)...\n")
            session!.connectWithToken(kToken, error: nil)
        } else {
            NSLog("Skipped createSessionAndConnect()\n")
        }
//        if self.session == nil {
//            self.session = OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)
//            NSLog("Connecting to session \(self.session)...\n")
//            self.session!.connectWithToken(kToken, error: nil)
//            firstTime = true
//        } else {
//            NSLog("Skipped createSessionAndConnect()\n")
//        }
    }
    
    func clearSubscribers() {
        for sub in subscribers {
            sub.view.removeFromSuperview()
        }

        subscribers.removeAll()
    }

//    var firstTime = true
    
    func reachabilityChanged(n: NSNotification) {
        print("Reachability Changed")
        
        print("Current status: \(reachability.currentReachabilityStatus())")
        switch reachability.currentReachabilityStatus() {
        case ReachableViaWiFi:
            fallthrough
        case ReachableViaWWAN:
            print("------> WAN OR WIFI")
//            if firstTime {
//                firstTime = false
//                return
//            }
            session?.disconnect(nil)
            createSessionAndConnect()
        case NotReachable:
            print("------> NOT REACHABLE")
            clearSubscribers()
            session?.disconnect(nil)
        default:
            print("Unknown network status")
        }
    }
}

extension ViewController: OTSessionDelegate {
    func sessionDidConnect(session: OTSession!) {
        print("Session Connected")
        
        if publisher == nil {
            publisher = OTPublisher(delegate: self)
        }
        session.publish(publisher, error: nil)
    }
    
    func sessionDidDisconnect(session: OTSession!) {
        print("Session Disconnected")
        self.session = nil
    }
    
    func session(session: OTSession!, didFailWithError error: OTError!) {
        print("Session failed with error: \(error)")
    }
    
    func session(session: OTSession!, streamCreated stream: OTStream!) {
        print("Stream created \(stream.streamId)")
        let subscriber = OTSubscriber(stream: stream, delegate: self)
        subscribers.append(subscriber)
        self.session?.subscribe(subscriber, error: nil)
    }
    
    func session(session: OTSession!, streamDestroyed stream: OTStream!) {
    }
}

extension ViewController: OTPublisherDelegate {
    func publisher(publisher: OTPublisherKit!, streamCreated stream: OTStream!) {
        print("Stream created")
        
        self.publisher?.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        self.view.addSubview(self.publisher!.view)
    }
    
    func publisher(publisher: OTPublisherKit!, streamDestroyed stream: OTStream!) {
        print("Stream destroyed")
        
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
