//
//  KeychainStorageManager.swift
//  TunnelExtension
//
//  Created by Roopesh Chander on 22/03/23.
//

import Foundation
import Security

class KeychainStorageManager {
    typealias KeychainReference = Data

    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func saveVPNConfig(vpnConfig: String) -> KeychainReference? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            self.logger.log("KeychainStorageManager.saveVPNConfig: Unable to determine bundle identifier")
            return nil
        }

        var ret: OSStatus = errSecSuccess
        let itemLabel = "VPN config for \(bundleIdentifier)"
        var access: SecAccess?
        ret = SecAccessCreate(itemLabel as CFString, nil /* only the creating app can access */, &access)
        guard ret == errSecSuccess else {
            self.logger.log("KeychainManager.saveVPNConfig: Could not create access object (ret: \(ret))")
            return nil
        }
        guard let secAccess = access else {
            self.logger.log("KeychainManager.saveVPNConfig: Could not get valid access object")
            return nil
        }

        let item: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                 kSecAttrLabel: "VPN config for \(bundleIdentifier)",
                               kSecAttrAccount: "\(bundleIdentifier): \(UUID().uuidString)",
                           kSecAttrDescription: "VPN Config",
                               kSecAttrService: bundleIdentifier,
                 kSecUseDataProtectionKeychain: false,
                        kSecAttrSynchronizable: false,
                            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                kSecAttrAccess: secAccess,
                                 kSecValueData: vpnConfig.data(using: .utf8) as Any,
                       kSecReturnPersistentRef: true]

        var ref: CFTypeRef?
        ret = SecItemAdd(item as CFDictionary, &ref)

        guard ret == errSecSuccess else {
            self.logger.log("KeychainStorageManager.saveVPNConfig: Could not save VPN config to keychain (ret: \(ret))")
            return nil
        }
        guard let keychainReference = ref as? Data else {
            self.logger.log("KeychainStorageManager.saveVPNConfig: Could not get reference to VPN config saved to keychain")
            return nil
        }

        return keychainReference
    }

    func retrieveVPNConfig(keychainReference: KeychainReference) -> String? {
        var result: CFTypeRef?
        let ret = SecItemCopyMatching([kSecValuePersistentRef: keychainReference,
                                               kSecReturnData: true] as CFDictionary,
                                      &result)
        guard ret == errSecSuccess else {
            self.logger.log("KeychainStorageManager.retrieveVPNConfig: Could not retrieve VPN config with keychain reference (ret: \(ret))")
            return nil
        }
        guard let data = result as? Data else {
            self.logger.log("KeychainStorageManager.retrieveVPNConfig: Could not get VPN config from keychain data")
            return nil
        }

        return String(data: data, encoding: String.Encoding.utf8)
    }

    func deleteVPNConfig(keychainReference: KeychainReference) {
        let ret = SecItemDelete([kSecValuePersistentRef: keychainReference] as CFDictionary)
        guard ret == errSecSuccess else {
            self.logger.log("KeychainStorageManager.deleteVPNConfig: Could not delete VPN config with keychain reference (ret: \(ret))")
            return
        }
    }
}
