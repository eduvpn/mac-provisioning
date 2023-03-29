//
//  VPNConfigFetcher.swift
//  TunnelExtension
//
//  Created by Roopesh Chander on 22/03/23.
//

import Foundation

class VPNConfigFetcher: NSObject {
    struct VPNConfigData {
        let vpnConfig: String
        let vpnConfigType: VPNConfigType
        let vpnConfigExpiryDate: Date?
    }

    private enum VPNConfigFetcherError: Error {
        case nonHTTPResponse
        case httpFailure(data: Data, response: HTTPURLResponse)
        case missingContentType
        case serverError(message: String, url: URL)
        case incorrectContentType(contentType: String)
        case incorrectEncodingForWgQuickConfig
        case missingInterfaceInWgQuickConfig(wgQuickConfig: String)

        var description: String {
            switch self {
                case .nonHTTPResponse:
                    return "Non-HTTP response"
                case .httpFailure(let data, let response):
                    let urlString = response.url?.absoluteString ?? ""
                    return "HTTP failure when requesting URL \"\(urlString)\": Status code: \(response.statusCode), Data: \"\(String(data: data, encoding: .utf8) ?? "")\""
                case .missingContentType:
                    return "HTTP response does not specify Content-Type"
                case .serverError(let message, let url):
                    return "Server error while fetching \"\(url.absoluteString)\": \(message)"
                case .incorrectContentType(let contentType):
                    return "Incorrect content type: \(contentType)"
                case .incorrectEncodingForWgQuickConfig:
                    return "Received wg-quick config data is not UTF-8"
                case .missingInterfaceInWgQuickConfig(let wgQuickConfig):
                    return "Received wg-quick config doesn't have an \"Interface\" section: \(wgQuickConfig)"
            }
        }
    }

    struct ServerErrorContainer: Codable {
        let error: String
    }

    let clientIdentity: SecIdentity
    let logger: Logger

    init(clientIdentity: SecIdentity, logger: Logger) {
        self.clientIdentity = clientIdentity
        self.logger = logger
    }

    func fetchVPNConfig(baseURL: URL, profileId: String, deviceId: String) async -> VPNConfigData? {
        let urlPath = "/profile"
        let urlQueryItems = "profile_id=\(profileId)&user_id=\(deviceId)"

        guard let fetchURL = URL(string: "\(urlPath)?\(urlQueryItems)", relativeTo: baseURL) else {
            self.logger.log("VPNConfigFetcher.fetchVPNConfig: Cannot form fetch URL from base URL \"\(baseURL)\"")
            return nil
        }

        self.logger.log("VPNConfigFetcher.fetchVPNConfig: Fetching URL: \(fetchURL.absoluteString)")
        var request = URLRequest(url: fetchURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let session = URLSession(configuration: URLSessionConfiguration.ephemeral,
                                 delegate: self,
                                 delegateQueue: OperationQueue.main)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VPNConfigFetcherError.nonHTTPResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw VPNConfigFetcherError.httpFailure(data: data, response: httpResponse)
            }
            guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") else {
                throw VPNConfigFetcherError.missingContentType
            }

            var expiryDate: Date? = nil
            if let expiresString = httpResponse.value(forHTTPHeaderField: "Expires") {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let expiresDate = dateFormatter.date(from: expiresString) {
                    expiryDate = expiresDate
                } else {
                    self.logger.log("VPNConfigFetcher.fetchVPNConfig: Could not parse Expiry response header value: \(expiresString)")
                }
            }

            if contentType == "application/x-wireguard-profile" {
                guard let wgQuickConfig = String(data: data, encoding: .utf8) else {
                    throw VPNConfigFetcherError.incorrectEncodingForWgQuickConfig
                }
                guard wgQuickConfig.contains("Interface") else {
                    throw VPNConfigFetcherError.missingInterfaceInWgQuickConfig(wgQuickConfig: wgQuickConfig)
                }
                self.logger.log("VPNConfigFetcher.fetchVPNConfig: Got WireGuard config expiring at \(expiryDate?.description ?? "unknown time")")
                let vpnConfigData = VPNConfigData(
                    vpnConfig: wgQuickConfig,
                    vpnConfigType: .wireguard,
                    vpnConfigExpiryDate: expiryDate)
                return vpnConfigData
            } else if contentType == "application/json" {
                let serverErrorContainer = try JSONDecoder().decode(ServerErrorContainer.self, from: data)
                let errorMessage = serverErrorContainer.error
                throw VPNConfigFetcherError.serverError(message: errorMessage, url: fetchURL)
            } else {
                throw VPNConfigFetcherError.incorrectContentType(contentType: contentType)
            }
        } catch {
            self.logger.log("VPNConfigFetcher.fetchVPNConfig: Error: \(error.localizedDescription)")
        }
        return nil
    }
}

extension VPNConfigFetcher: URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        if authenticationMethod == NSURLAuthenticationMethodServerTrust {
            //  Always trust the server
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else if authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            // Give client identity when requested
            let identityCredential = URLCredential(identity: self.clientIdentity, certificates: nil, persistence: .forSession)
            completionHandler(.useCredential, identityCredential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
