//
//  AppDelegate.swift
//  PS4 Remote Sender
//
//  Created by IH0kN3m on 10/28/18.
//  Copyright © 2018 ThatWeirdSoft. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var viewController: ViewController?

    func applicationWillTerminate(_ aNotification: Notification) {
        if viewController?.sendButton.title == "STOP" {
            viewController?.stopExecution(isCanceled: true)
        }
        viewController?.freeAuthorizationRef()
    }
}
