//
//  VPNConfigManager.swift
//  TunnelExtension
//
//  Created by Roopesh Chander on 01/04/23.
//

import Foundation
import Security

class VPNConfigManager {
    let persistenceManager: PersistenceManager
    let keychainStorageManager: KeychainStorageManager
    let keychainCertificateManager: KeychainCertificateManager
    let logger: Logger

    init(persistenceManager: PersistenceManager,
         keychainStorageManager: KeychainStorageManager,
         keychainCertificateManager: KeychainCertificateManager,
         logger: Logger) {
        self.persistenceManager = persistenceManager
        self.keychainStorageManager = keychainStorageManager
        self.keychainCertificateManager = keychainCertificateManager
        self.logger = logger
    }

    func getVPNConfig(
        intermediateServerBaseURL: URL,
        profileId: String,
        vpnConfigType: VPNConfigType) async -> VPNConfigFetcher.VPNConfigData? {
            guard let deviceCertData = self.keychainCertificateManager.getDeviceCertificateData() else {
                self.logger.log("VPNConfigManager.getVPNConfig: No device certificate found")
                return nil
            }

            let deviceId = deviceCertData.deviceId
            self.logger.log("VPNConfigManager.getVPNConfig: Trying to retrieve saved VPN config")
            let savedVPNConfigData = getSavedVPNConfig(
                persistenceManager: self.persistenceManager,
                keychainStorageManager: self.keychainStorageManager,
                intermediateServerBaseURL: intermediateServerBaseURL,
                profileId: profileId,
                deviceId: deviceId,
                vpnConfigType: .wireguard)

            if let savedVPNConfigData = savedVPNConfigData {
                return savedVPNConfigData
            }

            guard let clientIdentity = keychainCertificateManager.getClientIdentity(
                with: deviceCertData.deviceCertificate) else {
                self.logger.log("VPNConfigManager.getVPNConfig: Could not locate client identity in keychain")
                return nil
            }

            self.logger.log("VPNConfigManager.getVPNConfig: Fetching VPN config from server")
            let fetchedVPNConfigData = await fetchVPNConfigFromServer(
                intermediateServerBaseURL: intermediateServerBaseURL,
                profileId: profileId,
                deviceId: deviceId,
                clientIdentity: clientIdentity)

        if let fetchedVPNConfigData = fetchedVPNConfigData {
            if let previousKeychainReference = self.persistenceManager.retrieveFromDisk()?.keychainReference {
                self.logger.log("VPNConfigManager.getVPNConfig: Deleting currently saved VPN config in keychain")
                self.keychainStorageManager.deleteVPNConfig(keychainReference: previousKeychainReference)
            }

            self.logger.log("VPNConfigManager.getVPNConfig: Saving new VPN config to keychain")
            guard let keychainReference = keychainStorageManager.saveVPNConfig(vpnConfig: fetchedVPNConfigData.vpnConfig) else {
                self.logger.log("VPNConfigManager.getVPNConfig: Could not save new VPN config to keychain")
                return fetchedVPNConfigData
            }

            let persistableData = PersistenceManager.PersistableData(
                intermediateServerBaseURL: intermediateServerBaseURL,
                profileId: profileId,
                deviceId: deviceId,
                vpnConfigType: fetchedVPNConfigData.vpnConfigType,
                vpnConfigExpiryDate: fetchedVPNConfigData.vpnConfigExpiryDate,
                keychainReference: keychainReference)
            self.logger.log("VPNConfigManager.getVPNConfig: Writing new VPN config metadata to disk")
            persistenceManager.saveToDisk(persistableData)

            // TODO: Schedule fetching VPN config at expiry time

            return fetchedVPNConfigData
        }

        return nil
    }
}

private extension VPNConfigManager {
    func getSavedVPNConfig(persistenceManager: PersistenceManager,
                           keychainStorageManager: KeychainStorageManager,
                           intermediateServerBaseURL: URL,
                           profileId: String,
                           deviceId: String,
                           vpnConfigType: VPNConfigType) -> VPNConfigFetcher.VPNConfigData? {

        guard let persistableData = persistenceManager.retrieveFromDisk() else {
            self.logger.log("VPNConfigManager.getSavedVPNConfig: No persisted VPN config data exists")
            return nil
        }

        if (persistableData.deviceId == deviceId) &&
            (persistableData.intermediateServerBaseURL == intermediateServerBaseURL) &&
            (persistableData.profileId == profileId) &&
            (persistableData.vpnConfigType == vpnConfigType) {
            if let vpnConfigExpiryDate = persistableData.vpnConfigExpiryDate,
               (vpnConfigExpiryDate.timeIntervalSince(Date()) > 60 * 2 /* 2 minutes */) {
                self.logger.log("VPNConfigManager.getSavedVPNConfig: Retrieved VPN config is about to expire (expires at \(vpnConfigExpiryDate)")
                return nil
            }
            if let vpnConfig = keychainStorageManager.retrieveVPNConfig(keychainReference: persistableData.keychainReference) {
                self.logger.log("VPNConfigManager.getSavedVPNConfig: Retrieved VPN config from keychain")
                return VPNConfigFetcher.VPNConfigData(
                    vpnConfig: vpnConfig,
                    vpnConfigType: vpnConfigType,
                    vpnConfigExpiryDate: persistableData.vpnConfigExpiryDate)
            } else {
                self.logger.log("VPNConfigManager.getSavedVPNConfig: Cannot retrieve VPN config from keychain")
            }
        } else {
            self.logger.log("VPNConfigManager.getSavedVPNConfig: Saved VPN config metadata (\(persistableData)) does not match the required metadata")
        }

        return nil
    }

    func fetchVPNConfigFromServer(intermediateServerBaseURL: URL,
                                  profileId: String,
                                  deviceId: String,
                                  clientIdentity: SecIdentity) async -> VPNConfigFetcher.VPNConfigData? {
        let fetcher = VPNConfigFetcher(clientIdentity: clientIdentity, logger: logger)
        return await fetcher.fetchVPNConfig(baseURL: intermediateServerBaseURL, profileId: profileId, deviceId: deviceId)
    }
}

