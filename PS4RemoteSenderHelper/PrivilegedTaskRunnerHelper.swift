//
//  ProcessHelper.swift
//  ProcessRunnerExample
//
//  Created by Suolapeikko
//

import Foundation
import AppKit

class PrivilegedTaskRunnerHelper: NSObject, RemoteProcessProtocol, NSXPCListenerDelegate {
    
    var listener:NSXPCListener

    override init() {
        self.listener = NSXPCListener(machServiceName:HelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }
    
    /// Starts the helper daemon
    func run() {
        self.listener.resume()
        
        RunLoop.current.run()
    }
    
    /// Check that code sign certificates match
    func connectionIsValid(connection: NSXPCConnection ) -> Bool {
        
        let checker = CodesignChecker()
        var localCertificates: [SecCertificate] = []
        var remoteCertificates: [SecCertificate] = []
        let pid = connection.processIdentifier
        
        do {
            localCertificates = try checker.getCertificatesSelf()
            remoteCertificates = try checker.getCertificates(forPID: pid)
        }
        catch let error as CodesignCheckerError {
                NSLog(CodesignCheckerError.handle(error: error))
        }
        catch let error {
            NSLog("Something unexpected happened: \(error.localizedDescription)")
        }

        NSLog("Local certificates: \(localCertificates)")
        NSLog("Remote certificates: \(remoteCertificates)")

        let remoteApp = NSRunningApplication.init(processIdentifier: pid)

        // Compare certificates
        if(remoteApp != nil && (localCertificates == remoteCertificates)) {
            NSLog("Certificates match!")
            return true
        }
        
        return false
    }
    
    /// Called when the client connects to the helper daemon
    func listener(_ listener:NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        
        // ----------------------------------------------------------------------------------------------------
        //  Only accept new connections from applications using the same codesigning certificate as the helper
        // ----------------------------------------------------------------------------------------------------
        if (!connectionIsValid(connection: connection)) {
            
            NSLog("Codesign certificate validation failed")
            
            return false
        }
        
        connection.exportedInterface = NSXPCInterface(with: RemoteProcessProtocol.self)
        connection.exportedObject = self;
        connection.resume()
        
        return true
    }
    
     /// Functions to run from the main app
    func runCommand(path: [String], authData: NSData?, reply: @escaping (String) -> Void) {
        
        var authRef:AuthorizationRef?
        
        // Verify the passed authData looks reasonable
        if authData?.length == 0 || authData?.length != kAuthorizationExternalFormLength {
            NSLog("PrivilegedTaskRunnerHelper: Authorization data is malformed")
        }
        
        // Convert NSData passed through XPC to AuthorizationExternalForm
        let authExt: UnsafeMutablePointer<AuthorizationExternalForm> = UnsafeMutablePointer.allocate(capacity: kAuthorizationExternalFormLength * MemoryLayout<AuthorizationExternalForm>.size)
        memcpy(authExt, authData?.bytes, (authData?.length)!)
        _ = AuthorizationCreateFromExternalForm(authExt, &authRef)
        
        // Extract the AuthorizationRef from it's external form
        var status = AuthorizationCreateFromExternalForm(authExt, &authRef)
        
        if (status == errAuthorizationSuccess) {
            
            NSLog("PrivilegedTaskRunnerHelper: AuthorizationCreateFromExternalForm was successful")
            
            // Get the authorization right definition name of the function calling this
            let authName = "com.suolapeikko.examples.PrivilegedTaskRunner.runCommand"
            
            // Create an AuthorizationItem using that definition's name
            var authItem = AuthorizationItem(name: (authName as NSString).utf8String!, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
            
            // Create the AuthorizationRights for using the AuthorizationItem
            var authRight:AuthorizationRights = AuthorizationRights(count: 1, items:&authItem)
            
            // Check if the user is authorized for the AuthorizationRights. If not it might ask the user for their or an admins credentials
            status = AuthorizationCopyRights(authRef!, &authRight, nil, [ .extendRights, .interactionAllowed ], nil);

            if (status == errAuthorizationSuccess) {

                NSLog("PrivilegedTaskRunnerHelper: AuthorizationCopyRights was successful")
                
                var cmds: [CliCommand] = []
                path.forEach({
                    let arr = $0.split(separator: " ")
                    let path = String(arr.first!)
                    let args = Array(arr.dropFirst()).map({ String($0) })
                    cmds.append(CliCommand.init(launchPath: path, arguments: args) )
                })
                
                // Prepare cli command runner
                let command = ProcessHelper(commands: cmds)
                
                // Prepare result tuple
                var commandResult: String?
                
                // Execute cli commands and prepare for exceptions
                do {
                    commandResult = try command.execute()
                }
                catch {
                    commandResult = "Error"
                    NSLog("PrivilegedTaskRunnerHelper: Failed to run command")
                }
                
                reply(commandResult!)
            }
        }
        else {
            NSLog("PrivilegedTaskRunnerHelper: Authorization failed")
        }
    }

    /// Functions to run from the main app
    func runCommand(path: [String], reply: @escaping (String) -> Void) {
        
        var cmds: [CliCommand] = []
        path.forEach({
            let arr = $0.split(separator: " ")
            let path = String(arr.first!)
            let args = Array(arr.dropFirst()).map({ String($0) })
            cmds.append(CliCommand.init(launchPath: path, arguments: args) )
        })
        
        // Prepare cli command runner
        let command = ProcessHelper(commands: cmds)
        
        // Prepare result tuple
        var commandResult: String?
        
        // Execute cli commands and prepare for exceptions
        do {
            commandResult = try command.execute()
        }
        catch {
            NSLog("PrivilegedTaskRunnerHelper: Failed to run command")
            commandResult = "Error"
        }
        
        reply(commandResult!)
    }
    
    /// Return daemon's bundle version
    /// Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void
    func getVersion(reply: (String) -> Void) {
        reply(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String)
    }
}
