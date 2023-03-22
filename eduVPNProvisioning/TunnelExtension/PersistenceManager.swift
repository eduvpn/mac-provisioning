//
//  PersistenceManager.swift
//  TunnelExtension
//
//  Created by Roopesh Chander on 22/03/23.
//

import Foundation

enum VPNConfigType: String, Codable {
    case wireguard
}

class PersistenceManager {
    struct PersistableData: Codable {
        let intermediateServerBaseURL: URL
        let profileId: String
        let deviceId: String
        let vpnConfigType: VPNConfigType
        let vpnConfigExpiryDate: Date
        let keychainReference: KeychainStorageManager.KeychainReference

        var description: String {
            """
            server: \(intermediateServerBaseURL.absoluteString), profile id: \(profileId), \
            device id: \(deviceId), type: \(vpnConfigType), expiry: \(vpnConfigExpiryDate)
            """
        }
    }

    private var logger: Logger
    private var storageFileURL: URL? = nil

    init(logger: Logger) {
        self.logger = logger

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            logger.log("PersistenceManager: Unable to determine bundle identifier")
            return
        }

        guard let libraryDirURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            logger.log("PersistenceManager: Unable to determine library URL")
            return
        }

        guard let fileURL = URL(string: "data-\(bundleIdentifier).json", relativeTo: libraryDirURL) else {
            logger.log("PersistenceManager: Unable to form storage file URL")
            return
        }

        logger.log("PersistenceManager: Storage location: \(fileURL.path)")
        self.storageFileURL = fileURL
    }

    func saveToDisk(_ persistableData: PersistableData) {
        guard let storageFileURL = storageFileURL else {
            self.logger.log("PersistenceManager.saveToDisk: Error: Storage file URL is unavailable")
            return
        }
        do {
            try JSONEncoder().encode(persistableData).write(to: storageFileURL)
        } catch {
            self.logger.log("PersistenceManager.saveToDisk: Error: \(error)")
        }
    }

    func retrieveFromDisk() -> PersistableData? {
        guard let storageFileURL = storageFileURL else {
            self.logger.log("PersistenceManager.retrieveFromDisk: Storage file URL is unavailable")
            return nil
        }
        do {
            let data = try Data(contentsOf: storageFileURL)
            return try JSONDecoder().decode(PersistableData.self, from: data)
        } catch {
            self.logger.log("PersistenceManager.retrieveFromDisk: Error: \(error)")
        }
        return nil
    }
}
