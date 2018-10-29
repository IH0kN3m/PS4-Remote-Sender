//
//  AppAuthorizationRights.swift
//  PrivilegedTaskRunner
//
//  Created by Suolapeikko
//

import Foundation

struct AppAuthorizationRights {
    
    // Define all authorization right definitions this application will use (only one for this app)
    static let shellRightName: NSString = "PS4RemoteSenderHelper"
    static let shellRightDefaultRule: Dictionary = shellAdminRightsRule
    static let shellRightDescription: CFString = "PS4 Remote Sender Helper wants to run the command '/bin/ls /var/db/sudo/'" as CFString

    // Set up authorization rules (only one for this app)
    static var shellAdminRightsRule: [String:Any] = ["class" : "user",
                                                     "group" : "admin",
                                                     "timeout" : 0,
                                                     "version" : 1]
}
