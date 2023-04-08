//
//  ProviderConfiguration.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 06/04/23.
//

import Foundation
import NetworkExtension

struct ProviderConfiguration {
    let intermediateServerBaseURL: URL
    let profileId: String

    enum ProtocolProviderConfigurationKeys: String {
        // Keys in the provider configuration dictionary of the tunnel extension's
        // protocol configuration (NETunnelProviderProtocol.providerConfiguration).
        case intermediateServer = "intermediate-server"
        case profileId = "profile-id"
    }

    // Initialize from a NETunnelProviderProtocol.providerConfiguration dictionary
    init?(protocolProviderConfiguration: [String : Any], logger: Logger) {
        guard let server = protocolProviderConfiguration[ProtocolProviderConfigurationKeys.intermediateServer.rawValue] as? String else {
            logger.log("ProviderConfiguration.init: Protocol provider configuration doesn't have key \"\(ProtocolProviderConfigurationKeys.intermediateServer.rawValue)\"")
            return nil
        }
        guard let profileId = protocolProviderConfiguration[ProtocolProviderConfigurationKeys.profileId.rawValue] as? String else {
            logger.log("ProviderConfiguration.init: Protocol provider configuration doesn't have key \"\(ProtocolProviderConfigurationKeys.profileId.rawValue)\"")
            return nil
        }

        guard let intermediateServerBaseURL: URL = {
            if server.hasPrefix("http://") || server.hasPrefix("https://") {
                return URL(string: server)
            } else {
                return URL(string: "https://\(server)")
            }
        }() else {
            logger.log("ProviderConfiguration.init: Can't form URL from intermediate server value specified in protocol provider configuration: \"\(server)\"")
            return nil
        }

        self.intermediateServerBaseURL = intermediateServerBaseURL
        self.profileId = profileId
    }
}
