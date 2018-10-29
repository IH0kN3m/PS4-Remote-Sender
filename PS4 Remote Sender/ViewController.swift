//
//  ViewController.swift
//  PS4 Remote Sender
//
//  Created by IH0kN3m on 10/28/18.
//  Copyright © 2018 ThatWeirdSoft. All rights reserved.
//

import Cocoa
import ServiceManagement

class ViewController: NSViewController {
    
    // MARK: __IB__
    
    @IBOutlet private var ps4IpTextField:           NSTextField!
    @IBOutlet private var mainPkgFilesTextField:    NSTextField!
    @IBOutlet private var mainPkgFilesButton:       NSButton!
    @IBOutlet private var updatePkgFilesTextField:  NSTextField!
    @IBOutlet private var updatePkgFilesButton:     NSButton!
    @IBOutlet private var consoleView:              NSTextView!
    @IBOutlet var sendButton:                       NSButton!
    
    @IBAction private func mainPkgFilesButtonPressed(_ sender: NSButton) {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["pkg"]
        panel.beginSheetModal(for: window, completionHandler: {
            if $0 == NSApplication.ModalResponse.OK {
                var path: [String] = []
                panel.urls.forEach({ path.append($0.absoluteString.replacingOccurrences(of: "file://", with: "") ) })
                if path.count == 1 {
                    self.mainPkgFilesTextField.stringValue = path.first ?? ""
                
                } else {
                    self.mainPkgFilesTextField.placeholderString = "Multiple FPKG's..."
                    self.mainPkgFilesTextField.stringValue = ""
                }
                self.console("\n * \(self.mainPkgPath.count == 0 ? "Added" : "Replaced to") \( path.count == 1 ? "Main FPKG" : "Multiple Main FPKG's"):")
                path.forEach({ self.console("\n \($0)") })
                self.mainPkgPath = path
                
            } else if $0 != NSApplication.ModalResponse.OK && $0 != NSApplication.ModalResponse.cancel {
                self.console("\n * Cannot add FPKG... Maybe check file's permissions?")
            }
        })
    }
    
    @IBAction private func updatePkgFilesButtonPressed(_ sender: NSButton) {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["pkg"]
        panel.beginSheetModal(for: window, completionHandler: {
            if $0 == NSApplication.ModalResponse.OK {
                var path: [String] = []
                panel.urls.forEach({ path.append($0.absoluteString.replacingOccurrences(of: "file://", with: "") ) })
                if path.count == 1 {
                    self.updatePkgFilesTextField.stringValue = path.first ?? ""
                
                } else {
                    self.updatePkgFilesTextField.placeholderString = "Multiple FPKG's..."
                    self.updatePkgFilesTextField.stringValue = ""
                }
                self.console("\n * \(self.updatePkgsPath.count == 0 ? "Added" : "Replaced to") \(path.count == 1 ? "Update FPKG" : "Multiple Update FPKG's"):")
                path.forEach({ self.console(" \($0)") })
                self.updatePkgsPath = path
            
            } else if $0 != NSApplication.ModalResponse.OK && $0 != NSApplication.ModalResponse.cancel {
                self.console("\n * Cannot add FPKG... Maybe check file's permissions?")
            }
        })
    }
    
    @IBAction private func sendButtonPressed(_ sender: NSButton) {
        if sendButton.title == "STOP" {
            stopExecution(isCanceled: false)
            return
        
        } else if mainPkgPath.count == 0 && updatePkgsPath.count == 0 {
            console("\n * Choose FPKG to install!")
            return
        
        }
        let ip = ps4IpTextField.stringValue
        if ip == "" {
            console("\n * Write PS4 IP adress!")
            return

        } else if !validateIpAddress(ipToValidate: ip) {
            console("\n * Wrong IP adress, please check if format is correct")
            return
        }
        
        console("\n\n\n ––––––––––––––––––––––––––––––––––––––––\n * Starting execution...")
        sendButton.title = "STOP"
        sendButton.isEnabled = false
        var cmds: [String] = []
        
        cmds.append("/bin/rm -rf /Library/WebServer/Documents/*.pkg")
        console("\n * Added to queue: Cleaning up hosting folder. Just in case...")
        
        mainPkgPath.forEach({ cmds.append("/bin/mv \($0) /Library/WebServer/Documents") })
        updatePkgsPath.forEach({ cmds.append("/bin/mv \($0) /Library/WebServer/Documents") })
        console("\n * Added to queue: Moving FPKG files...")
        
        cmds.append("/usr/sbin/apachectl start")
        console("\n * Added to queue: Starting server...")
        
        console("\n * Executing scripts...")
        shell(cmds)
        
        DispatchQueue.global(qos: .userInitiated).async {
            sleep(2)
            DispatchQueue.main.async {
                if self.consoleView.string.contains("XPC error") {
                    self.stopExecution(isCanceled: true)
                    return
                }
                self.console("\n * Hosting folder has been cleaned up \n * All FPKG's moved to hosted folder \n * Server successfully started")
                if self.executeRequest(ip) {
                    self.console("\n\n\n * Success! All links are sent to PS4 \n * Press the STOP button after PS4 finishes downloading FPKG's \n * WARNING! Do NOT close application without pressing the STOP button, as it may leave some temporary trash in system and can cause some issues.")
                    self.sendButton.isEnabled = true
                    
                } else {
                    self.stopExecution(isCanceled: true)
                    self.sendButton.isEnabled = true
                }
            }
        }
    }
    
    override var representedObject: Any? { didSet {} }
    private var connection: NSXPCConnection?
    private var authRef: AuthorizationRef?
    private var mainPkgPath: [String] = []
    private var updatePkgsPath: [String] = []
    
    // MARK __LIFE CYCLE__
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (NSApplication.shared.delegate as? AppDelegate)?.viewController = self
        
        consoleView.isEditable = false
        ps4IpTextField.formatter = nil
        ps4IpTextField.stringValue = (UserDefaults.standard.value(forKey: "ps4Ip") as? String) ?? ""
        
        // Create an empty authorization reference
        initAuthorizationRef()
        
        // Check if there's an existing PrivilegedTaskRunnerHelper already installed
        if checkIfHelperDaemonExists() {
            checkHelperVersionAndUpdateIfNecessary()
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.appearance = NSAppearance(named:NSAppearance.Name.vibrantDark)
        
        // Needs to be set manually to re-render content inside view, as changing window appearance somehow
        // Resets rendered text making it invisible... Neat bug, Apple
        consoleView.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    // MARK: __EXECUTION__
    
    @discardableResult
    private func shell(_ commands: [String]) -> Int32 {
        // Install new helper tool to execute terminal commands as root
        if(!checkIfHelperDaemonExists()) {
            installHelperDaemon()
        }
        
        commands.forEach({ console("\n $\($0)") })
        
        // If linked helper tool is runnig as root,
        // There is no need to ask for permission... yet
        callHelperWithoutAuthorization(commands)
        
        return 0
    }
    
    private func executeRequest(_ ip: String) -> Bool {
        self.console("\n\n\n * Getting current WiFi IP address...")
        let selfIp = self.getWiFiAddress()
        self.console("\n * WiFi addres on interface en0 is: \(selfIp ?? "Unknown...")")
        if selfIp == nil { return false }
        
        var mainPkgLinks: [String] = []
        if mainPkgPath.count != 0 {
            self.console("\n * Forming direct links to Main FPKG's...")
            self.mainPkgPath.forEach({
                let link = "http://\(selfIp ?? ""):80/\(String($0.split(separator: "/").last ?? ""))"
                mainPkgLinks.append(link)
                self.console("\n * Created link: \(link)")
            })
        }
        
        var updatePkgLinks: [String] = []
        if updatePkgsPath.count != 0 {
            self.console("\n * Creating direct links to Update FPKG's...")
            self.updatePkgsPath.forEach({
                let link = "http://\(selfIp ?? ""):80/\(String($0.split(separator: "/").last ?? ""))"
                updatePkgLinks.append(link)
                self.console("\n * Created link: \(link)")
            })
        }
        
        self.console("\n * Creating JSON files for requests...")
        let mainJson: [String:Any] = ["type":"direct", "packages":mainPkgLinks]
        let updateJson: [String:Any] = ["type":"direct", "packages":updatePkgLinks]
        
        self.console("\n * Creating requests...")
        let group = DispatchGroup()
        
        if mainPkgLinks.count != 0 {
            if let url = URL(string: "http://\(ip):12800/api/install") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let mainJsonData = try? JSONSerialization.data(withJSONObject: mainJson, options: .prettyPrinted) {
                    request.httpBody = mainJsonData
                    
                } else {
                    self.console("\n * Error serializing Main FPKG's JSON...")
                    return false
                }
                group.enter()
                self.console("\n * Sending request for Main FPKG's... \n * URL: \(url)")
                let result = self.sendRequest(request, in: group)
                self.console("\n * Main FPKG's request code: \(result.1) \n * Main FPKG's request result: \(result.0)")
                if result.0.contains("fail") {
                    if result.0.contains("500") {
                        self.console("\n * Try to restart PS4 and make sure to use simple .pkg naming")
                    }
                    return false
                }
                if let err = result.2 {
                    self.console("\n * ERROR! Main FPKG's request returned: \(err.localizedDescription)")
                    return false
                }
                
            } else {
                self.console("\n * Failed to create request. Is PS4's ip address is right? \n * Current PS4's ip: \(ip)")
                return false
            }
        }
        if updatePkgLinks.count != 0 {
            if let url = URL(string: "http://\(ip):12800/api/install") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let updateJsonData = try? JSONSerialization.data(withJSONObject: updateJson, options: .prettyPrinted) {
                    request.httpBody = updateJsonData
                    
                } else {
                    self.console("\n * Error serializing Update FPKG's JSON...")
                    return false
                }
                group.enter()
                self.console("\n * Sending request for Update FPKG's... \n * URL: \(url)")
                let result = self.sendRequest(request, in: group)
                self.console("\n * Update FPKG's request code: \(result.1) \n * Update FPKG's request result: \(result.0)")
                if result.0.contains("fail") {
                    self.console("\n * ERROR! Main FPKG's request returned error.")
                    return false
                }
                if let err = result.2 {
                    self.console("\n * ERROR! Main FPKG's request returned: \(err.localizedDescription)")
                    return false
                }
                
            } else {
                self.console("\n * Failed to create request. Is PS4's ip address is right? \n * Current PS4's ip: \(ip)")
                return false
            }
        }
        return true
    }
    
    func stopExecution(isCanceled: Bool) {
        console("\n\n\n ––––––––––––––––––––––––––––––––––––––––\n * Stopping execution...")
        sendButton.isEnabled = false
        
        var cmds: [String] = []
        mainPkgPath.forEach({
            let split = String($0.split(separator: "/").last ?? "")
            cmds.append("/bin/mv /Library/WebServer/Documents/\(split) \($0.replacingOccurrences(of: split, with: ""))")
        })
        updatePkgsPath.forEach({
            let split = String($0.split(separator: "/").last ?? "")
            cmds.append("/bin/mv /Library/WebServer/Documents/\(split) \($0.replacingOccurrences(of: split, with: ""))")
        })
        console("\n * Added to queue: Moving FPKG's back to original folder...")
        
        cmds.append("/usr/sbin/apachectl stop")
        console("\n * Added to queue: Stopping server...")
        
        cmds.append("/bin/rm -rf /Library/WebServer/Documents/*.pkg")
        console("\n * Added to queue: Cleaning up hosted folder from unregistered FPKG's...")
        
        cmds.append("/bin/rm -rf /Library/PrivilegedHelperTools/PS4RemoteSenderHelper")
        console("\n * Added to queue: Cleaning up execution helper tool...")
        
        console("\n * Added to queue: Closing connection with helper...")
        console("\n * Added to queue: Saving prefs to persistent container...")
        
        console("\n * Executing scripts...")
        shell(cmds)
        
        DispatchQueue.global(qos: .userInitiated).async {
            sleep(2)
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.ps4IpTextField.stringValue, forKey: "ps4Ip")
                self.connection = nil
                
                self.console("\n * All FPKG's have been moved to original folders \n * Server stopped \n * Hosted folder has been cleaned up from unrigistered FPKG's \n * Connection to helper was closed \n * Prefs saved to persistence \n * Execution helper tool has been... executed \n\n\n * \(isCanceled ? "Execution was aborted. Look above for more information." : "All Done! Yay!")")
                self.sendButton.title = "SEND"
                self.sendButton.isEnabled = true
            }
        }
    }
    
    func sendRequest(_ request: URLRequest, in group: DispatchGroup) -> (String, Int, Error?) {
        var retResult = ""
        var retResponse = 0
        var retErr: Error?
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            defer {
                group.leave()
            }
            
            retResult = String(data: data ?? Data(), encoding: .utf8) ?? ""
            retErr = error
            if let httpResponse = response as? HTTPURLResponse {
                retResponse = httpResponse.statusCode
            }
            }.resume()
        group.wait()
        return (retResult, retResponse, retErr)
    }
    
    // MARK: __HELPER CONNECTION AND XPC CONNECTION MANAGING__
    // Shamelessly copy - pasted from Suolapeikko©
    
    // Initialize AuthorizationRef, as we need to manage it's lifecycle
    private func initAuthorizationRef() {
        
        // Create an empty AuthorizationRef
        let status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        if (status != OSStatus(errAuthorizationSuccess)) {
            console("\n * AuthorizationCreate failed :(")
            return
        }
    }
    
    /// Install new helper daemon
    private func installHelperDaemon() {
        
        console("\n * Privileged Helper daemon was not found, installing a new one...")
        // Create authorization reference for the user
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [], &authRef)
        
        // Check if the reference is valid
        guard authStatus == errAuthorizationSuccess else {
            console("\n * Authorization failed: \(authStatus)")
            return
        }
        
        // Ask user for the admin privileges to install the
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let flags: AuthorizationFlags = [[], .interactionAllowed, .extendRights, .preAuthorize]
        authStatus = AuthorizationCreate(&authRights, nil, flags, &authRef)
        
        // Check if the authorization went succesfully
        guard authStatus == errAuthorizationSuccess else {
            console("\n * Couldn't obtain admin privileges: \(authStatus)")
            return
        }
        
        // Launch the privileged helper using SMJobBless tool
        var error: Unmanaged<CFError>? = nil
        
        if(SMJobBless(kSMDomainSystemLaunchd, HelperConstants.machServiceName as CFString, authRef, &error) == false) {
            let blessError = error!.takeRetainedValue() as Error
            console("\n * Bless Error: \(blessError)")
        } else {
            console("\n * \(HelperConstants.machServiceName) installed successfully")
        }
        
        // Release the Authorization Reference
        AuthorizationFree(authRef!, [])
    }
    
    /// Compare app's helper version to installed daemon's version and update if necessary
    private func checkHelperVersionAndUpdateIfNecessary() {
        
        // Daemon path
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/\(HelperConstants.machServiceName)")
        let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL)
        let helperInfo = helperBundleInfo! as NSDictionary
        let helperVersion = helperInfo["CFBundleVersion"] as! String
        
        console("\n * PrivilegedTaskRunner Bundle Version => \(helperVersion)")
        
        // When the connection is valid, do the actual inter process call
        let xpcService = prepareXPC()?.remoteObjectProxyWithErrorHandler() { error -> Void in
            DispatchQueue.main.async {
                self.console("\n * XPC error: \(error)")
            }
            } as? RemoteProcessProtocol
        
        xpcService?.getVersion(reply: {
            installedVersion in
            DispatchQueue.main.async {
                self.console("\n * PrivilegedTaskRunner Helper Installed Version => \(installedVersion)")
            }
            if(installedVersion != helperVersion) {
                self.installHelperDaemon()
            }
            else {
                DispatchQueue.main.async {
                    self.console("\n * Bundle version matches privileged helper version, so no need to install helper")
                }
            }
        })
    }
    
    /// Free AuthorizationRef, as we need to manage it's lifecycle
    func freeAuthorizationRef() {
        AuthorizationFree(authRef!, AuthorizationFlags.destroyRights)
    }
    
    /// Prepare XPC connection for inter process call
    ///
    /// - returns: A reference to the prepared instance variable
    private func prepareXPC() -> NSXPCConnection? {
        
        // Check that the connection is valid before trying to do an inter process call to helper
        if(connection==nil) {
            connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: NSXPCConnection.Options.privileged)
            connection?.remoteObjectInterface = NSXPCInterface(with: RemoteProcessProtocol.self)
            connection?.invalidationHandler = {
                self.connection?.invalidationHandler = nil
                OperationQueue.main.addOperation() {
                    self.connection = nil
                    self.console("\n * XPC Connection Invalidated")
                }
            }
            connection?.resume()
        }
        
        return connection
    }
    
    /// Call Helper using XPC without authorization
    private func callHelperWithoutAuthorization(_ commands: [String]) {
        
        // When the connection is valid, do the actual inter process call
        let xpcService = prepareXPC()?.remoteObjectProxyWithErrorHandler() { error -> Void in
            DispatchQueue.main.async {
                self.console("\n * XPC error: \(error)")
            }
            } as? RemoteProcessProtocol
        
        xpcService?.runCommand(path: commands, reply: {
            reply in
            
            if reply == "Error" {
                // Let's update GUI asynchronously
                DispatchQueue.global(qos: .background).async {
                    // Background Thread
                    DispatchQueue.main.async {
                        // Run UI Updates
                        self.console("\n * Failed to execute without permission, trying to go hard way...")
                    }
                }
                self.callHelperWithAuthorization(commands)
            
            } else {
                // Let's update GUI asynchronously
                DispatchQueue.global(qos: .background).async {
                    // Background Thread
                    DispatchQueue.main.async {
                        // Run UI Updates
                        self.console("\n * Commands successfully executed.\n * Result: \(reply) \n * Let's wait a sec...")
                    }
                }
            }
        })
    }
    
    /// Call Helper using XPC with authorization
    private func callHelperWithAuthorization(_ commands: [String]) {
        
        var authRefExtForm = AuthorizationExternalForm()
        let timeout = 50
        
        // Make an external form of the AuthorizationRef
        var status = AuthorizationMakeExternalForm(authRef!, &authRefExtForm)
        if (status != OSStatus(errAuthorizationSuccess)) {
            console("\n * AuthorizationMakeExternalForm failed")
            return
        }
        
        // Add all or update required authorization right definition to the authorization database
        var currentRight:CFDictionary?
        
        // Try to get the authorization right definition from the database
        status = AuthorizationRightGet(AppAuthorizationRights.shellRightName.utf8String!, &currentRight)
        
        if (status == errAuthorizationDenied) {
            
            var defaultRules = AppAuthorizationRights.shellRightDefaultRule
            defaultRules.updateValue(timeout as AnyObject, forKey: "timeout")
            status = AuthorizationRightSet(authRef!, AppAuthorizationRights.shellRightName.utf8String!, defaultRules as CFDictionary, AppAuthorizationRights.shellRightDescription, nil, "Common" as CFString)
            console("\n * Adding authorization right to the security database")
        }
        
        // We need to put the AuthorizationRef to a form that can be passed through inter process call
        let authData = NSData.init(bytes: &authRefExtForm, length:kAuthorizationExternalFormLength)
        
        // When the connection is valid, do the actual inter process call
        let xpcService = prepareXPC()?.remoteObjectProxyWithErrorHandler() { error -> Void in
            NSLog("AppviewController: XPC error: \(error)")
            } as? RemoteProcessProtocol
        
        xpcService?.runCommand(path: commands, authData: authData, reply: {
            reply in
            // Let's update GUI asynchronously
            DispatchQueue.global(qos: .background).async {
                // Background Thread
                DispatchQueue.main.async {
                    // Run UI Updates
                    self.console("\n * Commands successfully executed.\n * Result: \(reply) \n * Let's wait a sec...")
                }
            }
        })
    }
    
    // MARK: __Utils__
    
    // For neatness reason, helper tool has to be deleted after execution, because then it's useless
    // But if its somehow here, why not just use it?
    private func checkIfHelperDaemonExists() -> Bool {
        return FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/PS4RemoteSenderHelper")
    }
    
    private func console(_ string: String) {
        self.consoleView.string += string
        self.consoleView.scrollToEndOfDocument(self)
    }
    
    // From some answer on stackowerflow, couldn't find source...
    private func validateIpAddress(ipToValidate: String) -> Bool {
        let pattern_2 = "(25[0-5]|2[0-4]\\d|1\\d{2}|\\d{1,2})\\.(25[0-5]|2[0-4]\\d|1\\d{2}|\\d{1,2})\\.(25[0-5]|2[0-4]\\d|1\\d{2}|\\d{1,2})\\.(25[0-5]|2[0-4]\\d|1\\d{2}|\\d{1,2})"
        let regexText_2 = NSPredicate(format: "SELF MATCHES %@", pattern_2)
        let result_2 = regexText_2.evaluate(with: ipToValidate)
        return result_2
    }
    
    // Return IP address of WiFi interface (en0) as a String, or `nil`
    private func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
}
