//
//  RemoteProcessProtocol.swift
//  ProcessRunnerExample
//
//  Created by Suolapeikko
//

import Foundation

struct HelperConstants {
    static let machServiceName = "PS4RemoteSenderHelper"
}

/// Protocol with inter process method invocation methods that ProcessHelper supports
/// Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void
@objc(RemoteProcessProtocol)
protocol RemoteProcessProtocol {
    func getVersion(reply: @escaping (String) -> Void)
    func runCommand(path: [String], authData: NSData?, reply: @escaping (String) -> Void)
    func runCommand(path: [String], reply: @escaping (String) -> Void)
}
