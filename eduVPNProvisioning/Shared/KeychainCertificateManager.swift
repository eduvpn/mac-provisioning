//
//  KeychainCertificateManager.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 22/03/23.
//

import Foundation
import Security

class KeychainCertificateManager {
    let issuerNames: [String]
    let logger: Logger

    struct DeviceCertificateData {
        let deviceCertificate: SecCertificate
        let deviceId: String
    }

    init(issuerNames: [String], logger: Logger) {
        self.issuerNames = issuerNames
        self.logger = logger
    }

    func getDeviceCertificateData() -> DeviceCertificateData? {
        if let issuerDER = getIssuerDER(),
           let deviceCertificate = getDeviceCertificate(issuerDER: issuerDER),
           let deviceCertificateCommonName = getCertificateCommonName(certificate: deviceCertificate) {
            let deviceId = getDeviceId(certificateCommonName: deviceCertificateCommonName)
            self.logger.log("KeychainCertificateManager.getDeviceCertificateData: Got certificate data")
            return DeviceCertificateData(deviceCertificate: deviceCertificate, deviceId: deviceId)
        }
        self.logger.log("KeychainCertificateManager.getDeviceCertificateData: Could not get device certificate data")
        return nil
    }

    func getClientIdentity(with certificate: SecCertificate) -> SecIdentity? {
        var identity: SecIdentity?
        let ret = SecIdentityCreateWithCertificate(nil, certificate, &identity)
        guard ret == errSecSuccess else {
            self.logger.log("KeychainCertificateManager.getClientIdentity: Could not find client identity (ret: \(ret))")
            return nil
        }
        self.logger.log("KeychainCertificateManager.getClientIdentity: Found client identity")
        return identity
    }

}

extension KeychainCertificateManager {
    private func getIssuerDER() -> CFData? {
        for issuerName in self.issuerNames {
            self.logger.log("KeychainCertificateManager.getIssuerDER: Looking for issuer certificate named \"\(issuerName)\"")
            let query: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                        kSecMatchSubjectContains as String: issuerName,
                                        kSecReturnRef as String: kCFBooleanTrue as Any]
            var result: CFTypeRef?
            let ret = SecItemCopyMatching(query as CFDictionary, &result)
            if ret == errSecSuccess {
                let issuerCertificate = result as! SecCertificate
                if let issuerCFData = SecCertificateCopyNormalizedSubjectSequence(issuerCertificate) {
                    self.logger.log("KeychainCertificateManager.getIssuerDER: Found issuer certificate named \"\(issuerName)\"")
                    return issuerCFData
                } else {
                    self.logger.log("KeychainCertificateManager.getIssuerDER: Could not get subject sequence for issuer certificate named \"\(issuerName)\"")
                }
            } else {
                self.logger.log("KeychainCertificateManager.getIssuerDER: Could not find issuer certificate named \"\(issuerName)\" (ret: \(ret))")
            }
        }

        self.logger.log("KeychainCertificateManager.getIssuerDER: Issuer DER is unavailable")

        return nil
    }

    private func getDeviceCertificate(issuerDER: CFData) -> SecCertificate? {
        let query: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                    kSecAttrIssuer as String: issuerDER as Any,
                                    kSecReturnRef as String: kCFBooleanTrue as Any]
        var result: CFTypeRef?
        let ret = SecItemCopyMatching(query as CFDictionary, &result)
        if ret == errSecSuccess {
            return (result as! SecCertificate)
        }
        self.logger.log("KeychainCertificateManager.getDeviceCertificate: Device certificate is unavailable (ret: \(ret))")
        return nil
    }

    private func getCertificateCommonName(certificate: SecCertificate) -> String? {
        var commonNameCFStr: CFString?
        let ret = withUnsafeMutablePointer(to: &commonNameCFStr) { commonNameCFStrPtr -> OSStatus in
            SecCertificateCopyCommonName(certificate, commonNameCFStrPtr)
        }
        if ret == errSecSuccess {
            if let commonName = (commonNameCFStr as? String) {
                self.logger.log("KeychainCertificateManager.getCertificateCommonName: Common name is \"\(commonName)\"")
                return commonName
            }
        }
        self.logger.log("KeychainCertificateManager.getCertificateCommonName: Common name is unavailable (ret: \(ret))")
        return nil
    }

    private func getDeviceId(certificateCommonName commonName: String) -> String {
        if let firstDashIndex = commonName.firstIndex(of: "-") {
            let afterFirstDashIndex = commonName.index(after: firstDashIndex)
            let deviceId = String(commonName[afterFirstDashIndex...])
            if !deviceId.isEmpty {
                self.logger.log("KeychainCertificateManager.getDeviceId: Device id is \"\(deviceId)\"")
                return deviceId
            }
        }
        self.logger.log("KeychainCertificateManager.getDeviceId: Device id is \"\(commonName)\"")
        return commonName
    }
}
