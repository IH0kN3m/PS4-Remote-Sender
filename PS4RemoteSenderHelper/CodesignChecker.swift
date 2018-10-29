//
//  CodesignChecker.swift
//  PrivilegedTaskRunner
//
//  Created by Antti Tulisalo on 20/09/2018.
//

import Foundation
import Security

struct CodesignCheckerError : Error
{
    enum Category
    {
        case SecCodeCopySelf
        case SecCodeCopyStaticCode
        case SecCodeCopyGuestWithAttributes
        case SecStaticCodeCreateWithPath
        case SecCodeCopySigningInformation
        case GenericError
    }
    
    let type: Category
    let description: String
    let methodName: String
    let fileName: String
    let lineNumber: Int
    
    static func handle(error: CodesignCheckerError) -> String
    {
        let readableError = """
        \nERROR - operation: [\(error.type)];
        reason: [\(error.description)];
        in method: [\(error.methodName)];
        in file: [\(error.fileName)];
        at line: [\(error.lineNumber)]\n
        """
        print(readableError)
        return readableError
    }
    
}


// https://developer.apple.com/documentation/security/code_signing_services
struct CodesignChecker {

    let kSecCSDefaultFlags = SecCSFlags.init(rawValue: 0)
    
    let kSecCSCustomFlags = SecCSFlags.init(rawValue: kSecCSDoNotValidateResources | kSecCSCheckNestedCode)
    
    // https://developer.apple.com/documentation/security/1401695-seccodecopystaticcode
    private func prepareSelf() throws -> SecStaticCode? {
        
        var secCodeSelf: SecCode?
        var secStaticCode: SecStaticCode?
        
        var resultCode = SecCodeCopySelf(kSecCSDefaultFlags, &secCodeSelf)
        
        guard resultCode == errSecSuccess, let secCode = secCodeSelf else {
            
            throw CodesignCheckerError(type: .SecCodeCopySelf, description: String(describing: SecCopyErrorMessageString(resultCode, nil)), methodName: #function, fileName: #file, lineNumber: #line)
        }

        resultCode = SecCodeCopyStaticCode(secCode, kSecCSDefaultFlags, &secStaticCode)
        
        guard resultCode == errSecSuccess, secStaticCode != nil else {
            
            throw CodesignCheckerError(type: .SecCodeCopyStaticCode, description: String(describing: SecCopyErrorMessageString(resultCode, nil)), methodName: #function, fileName: #file, lineNumber: #line)
        }

        return secStaticCode
    }

    // https://developer.apple.com/documentation/security/1395560-seccodecopyguestwithattributes
    private func prepare(withPID pid: pid_t) throws -> SecStaticCode? {
        
        var secCodePID: SecCode?
        var secStaticCode: SecStaticCode?

        let kSecAttributes = [
            kSecGuestAttributePid : pid
        ]

        var resultCode = SecCodeCopyGuestWithAttributes(nil, kSecAttributes as CFDictionary, kSecCSDefaultFlags, &secCodePID)

        guard resultCode == errSecSuccess, let secCode = secCodePID else {

            throw CodesignCheckerError(type: .SecCodeCopyGuestWithAttributes, description: String(describing: SecCopyErrorMessageString(resultCode, nil)), methodName: #function, fileName: #file, lineNumber: #line)
        }
        
        resultCode = SecCodeCopyStaticCode(secCode, kSecCSDefaultFlags, &secStaticCode)
        
        guard resultCode == errSecSuccess, secStaticCode != nil else {
            
            throw CodesignCheckerError(type: .SecCodeCopyStaticCode, description: String(describing: SecCopyErrorMessageString(resultCode, nil)), methodName: #function, fileName: #file, lineNumber: #line)
        }
        
        return secStaticCode
    }

    // https://developer.apple.com/documentation/security/1396899-secstaticcodecreatewithpath
    private func prepare(withURL url: URL) throws -> SecStaticCode? {
        
        var secStaticCode: SecStaticCode?
        
        let resultCode = SecStaticCodeCreateWithPath(url as CFURL, [], &secStaticCode)
        
        guard resultCode == errSecSuccess && secStaticCode != nil else {
            
            throw CodesignCheckerError(type: .SecStaticCodeCreateWithPath, description: String(describing: SecCopyErrorMessageString(resultCode, nil)), methodName: #function, fileName: #file, lineNumber: #line)
        }
        
        return secStaticCode
    }

    // Checking the validity of IDs
    private func isValid(secStaticCode: SecStaticCode) -> Bool {
        
        guard CFGetTypeID(secStaticCode) == SecStaticCodeGetTypeID() else {
            return false
        }
        
        let resultCode = SecStaticCodeCheckValidity(secStaticCode, kSecCSCustomFlags, nil)
        
        guard resultCode == errSecSuccess else {

            return false
        }
        
        return true
    }
    
    // https://developer.apple.com/documentation/security/1395809-seccodecopysigninginformation
    private func getCertificates(secStaticCode: SecStaticCode) throws -> [SecCertificate] {
        
        var secCodeInfoCFDict:  CFDictionary?
        let resultCode = SecCodeCopySigningInformation(secStaticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &secCodeInfoCFDict)

        guard resultCode == errSecSuccess, let secCodeInfo = secCodeInfoCFDict as? [String: Any] else {
            
            throw CodesignCheckerError(type: .SecCodeCopySigningInformation, description: String(describing: SecCopyErrorMessageString(resultCode, nil)), methodName: #function, fileName: #file, lineNumber: #line)
        }
        
        guard let secCertificates = secCodeInfo[kSecCodeInfoCertificates as String] as? [SecCertificate] else {
            
            throw CodesignCheckerError(type: .GenericError, description: "Failed to obtain certificates from the information dictionary", methodName: #function, fileName: #file, lineNumber: #line)
        }
        
        return secCertificates
    }
    
    public func getCertificatesSelf() throws -> [SecCertificate] {
        
        let secStaticCode: SecStaticCode?
        var certificates: [SecCertificate] = []
        
        do {
            try secStaticCode = prepareSelf()
            
            if(!isValid(secStaticCode: secStaticCode!)) {
                throw CodesignCheckerError(type: .GenericError, description: "Validation failed", methodName: #function, fileName: #file, lineNumber: #line)
            }
            
            try certificates = getCertificates(secStaticCode: secStaticCode!)
        }
        catch let error {
            throw error
        }
        
        return certificates
    }
    
    public func getCertificates(forPID pid: pid_t) throws -> [SecCertificate] {
        
        let secStaticCode: SecStaticCode?
        var certificates: [SecCertificate] = []
        
        do {
            try secStaticCode = prepare(withPID: pid)
            
            if(!isValid(secStaticCode: secStaticCode!)) {
                throw CodesignCheckerError(type: .GenericError, description: "Validation failed", methodName: #function, fileName: #file, lineNumber: #line)
            }
            
            try certificates = getCertificates(secStaticCode: secStaticCode!)
        }
        catch let error {
            throw error
        }
        
        return certificates
    }
    
    public func getCertificates(forURL url: URL) throws -> [SecCertificate] {
        
        let secStaticCode: SecStaticCode?
        var certificates: [SecCertificate] = []
        
        do {
            try secStaticCode = prepare(withURL: url)
            
            if(!isValid(secStaticCode: secStaticCode!)) {
                throw CodesignCheckerError(type: .GenericError, description: "Validation failed", methodName: #function, fileName: #file, lineNumber: #line)
            }
            
            try certificates = getCertificates(secStaticCode: secStaticCode!)
        }
        catch let error {
            throw error
        }
        
        return certificates
    }
}
