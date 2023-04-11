//
//  Logger.swift
//  TunnelExtension
//
//  Created by Roopesh Chander on 21/03/23.
//

import Foundation
import os.log

class Logger {

    enum AppComponent: String {
        case containerApp =  "APP"
        case tunnelExtension = "EXT"
    }

    static let logSeparator = "--- EOF ---"
    private var logFileHandle: UnsafeMutablePointer<FILE>?
    private let dateFormatter: DateFormatter
    private let osLog: OSLog
    private var timer: DispatchSourceTimer? = nil
    private var queue: DispatchQueue

    init(appComponent: Logger.AppComponent) {
        let appId = Bundle.main.bundleIdentifier ?? "eduVPNProvisioning"
        let osLog = OSLog(subsystem: appId, category: appComponent.rawValue)

        if let (fileURL, fileHandle) = Self.setup(osLog: osLog) {
            self.logFileHandle = fileHandle
            os_log("Writing log to file: %{public}@", log: osLog, fileURL.path)
        } else {
            self.logFileHandle = nil
            os_log("Not writing log to file")
        }

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.osLog = osLog
        self.queue = DispatchQueue(label: "LoggerQueue", qos: .background)
    }

    func log(_ message: String) {
        guard let logFileHandle = self.logFileHandle else {
            return
        }

        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp) \(message)\n"
        self.queue.sync {
            Self.write(line, to: logFileHandle, osLog: self.osLog)
        }

        os_log("%{public}@", log: self.osLog, message)

        // Flush to disk every 5 seconds
        if self.timer == nil {
            // We don't use an NSTimer here because:
            // https://developer.apple.com/forums/thread/687170
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + .seconds(5), leeway: .seconds(1))
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }

                let timestamp = self.dateFormatter.string(from: Date())
                let line = "\(timestamp) Flushing log to disk by timer\n"
                Self.write(line, to: logFileHandle, osLog: self.osLog)
                Self.flush(logFileHandle)

                self.timer = nil
            }
            timer.resume()
            self.timer = timer
        }
    }

    func flush() {
        if let logFileHandle = self.logFileHandle {
            log("Flushing log to disk")
            Self.flush(logFileHandle)
        }
    }

    deinit {
        if let logFileHandle = self.logFileHandle {
            log("Closing log file")
            Self.close(logFileHandle)
        }
    }
}

extension Logger {
    static func getLogFileDirectoryURL() -> URL? {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
    }

    static func getLogFileURL() -> URL? {
        if let logFileDirectoryURL = getLogFileDirectoryURL(),
           let bundleId = Bundle.main.bundleIdentifier {
            return logFileDirectoryURL.appendingPathComponent("\(bundleId).log")
        }
        return nil
    }

    static func createTemporaryLogFileURL() -> URL? {
        if let logFileDirectory = getLogFileDirectoryURL(),
           let bundleId = Bundle.main.bundleIdentifier {
            let uuidString = UUID().uuidString
            return logFileDirectory.appendingPathComponent("\(bundleId)_\(uuidString).temporary_log")
        }
        return nil
    }
}

private extension Logger {
    static func setup(osLog: OSLog) -> (URL, UnsafeMutablePointer<FILE>)? {
        guard let logFileURL = Self.getLogFileURL() else {
            return nil
        }
        var hasPreExistingLogEntries = false
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: logFileURL.path) {
            hasPreExistingLogEntries = Self.truncateEarlyLogEntries(logFileURL: logFileURL, logSeparator: Self.logSeparator, osLog: osLog)
        }
        guard let fileHandle = fopen(logFileURL.path, "a") else {
            return nil
        }
        if hasPreExistingLogEntries {
            write("\n\(Self.logSeparator)\n\n", to: fileHandle, osLog: osLog)
        }
        return (logFileURL, fileHandle)
    }

    static func write(_ message: String, to fileHandle: UnsafeMutablePointer<FILE>, osLog: OSLog) {
        if let cString = message.cString(using: .utf8) {
            let result = cString.withUnsafeBufferPointer{ cStringPointer in
                fputs(cStringPointer.baseAddress, fileHandle)
            }
            if result <= 0 {
                os_log("Error writing log message to file", log: osLog)
            }
        }
    }

    static func close(_ fileHandle: UnsafeMutablePointer<FILE>) {
        fclose(fileHandle)
    }

    static func flush(_ fileHandle: UnsafeMutablePointer<FILE>) {
        fflush(fileHandle)
    }

    @discardableResult
    static func truncateEarlyLogEntries(logFileURL: URL, logSeparator: String, osLog: OSLog) -> Bool {
        guard let tmpFileURL = Self.createTemporaryLogFileURL() else {
            return false
        }
        var tmpFileHandle: UnsafeMutablePointer<FILE>? = nil
        // let tmpFileHandle = fopen(tmpFileURL.path, "w")
        let logFileHandle = fopen(logFileURL.path, "r")

        var bufferPointer: UnsafeMutablePointer<CChar>? = nil
        var bufferSize: Int = 0

        var bytesRead = 0
        var isLogSeparatorFound = false
        var isSkippingEmptyLinesSequence = false
        var tmpFileHasLogEntries = false
        var origFileHasLogEntries = false
        repeat {
            bytesRead = getline(&bufferPointer, &bufferSize, logFileHandle)
            if bytesRead > 0, let bufferPointer = bufferPointer {
                let line = String(cString: bufferPointer)
                let isEmptyLine = (line == "\n")
                if !isEmptyLine {
                    origFileHasLogEntries = true
                }
                if isSkippingEmptyLinesSequence {
                    if isEmptyLine {
                        continue
                    } else {
                        isSkippingEmptyLinesSequence = false
                    }
                }
                if line.hasPrefix(logSeparator) {
                    isLogSeparatorFound = true
                    isSkippingEmptyLinesSequence = true
                    if tmpFileHandle == nil {
                        tmpFileHandle = fopen(tmpFileURL.path, "w")
                    }
                    continue
                }
                if isLogSeparatorFound, let tmpFileHandle = tmpFileHandle {
                    fwrite(bufferPointer, bytesRead, 1, tmpFileHandle)
                    tmpFileHasLogEntries = true
                }
            }
        } while (bytesRead > 0)

        if let logFileHandle = logFileHandle {
            fclose(logFileHandle)
        }
        if let tmpFileHandle = tmpFileHandle {
            fclose(tmpFileHandle)
        }
        bufferPointer?.deallocate()

        if isLogSeparatorFound {
            os_log("Truncating log", log: osLog, logFileURL.path)
            let fileManager = FileManager.default
            do {
                try fileManager.removeItem(at: logFileURL)
            } catch {
                os_log("Error removing log at \"%{public}@\": %{public}@", log: osLog, logFileURL.path, error.localizedDescription)
                return origFileHasLogEntries
            }
            do {
                try fileManager.moveItem(at: tmpFileURL, to: logFileURL)
            } catch {
                os_log("Error moving log at \"%{public}@\" to \"%{public}@\": %{public}@", log: osLog, tmpFileURL.path, logFileURL.path, error.localizedDescription)
                return false
            }
            return tmpFileHasLogEntries
        } else {
            os_log("Not truncating log", log: osLog, logFileURL.path)
            return origFileHasLogEntries
        }
    }
}
