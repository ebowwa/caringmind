//
//  Logger.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/26/24.
//

import Foundation
import os.log

/// A centralized logger for managing console logs with different log levels.
public class Logger {
    
    // MARK: - Log Levels
    
    /// Defines the severity levels for logging.
    public enum LogLevel: String {
        case debug = "D: DEBUG"
        case info = "I: INFO"
        case warning = "W: WARNING"
        case error = "E: ERROR"
        case localTranscribing = "T: LOCAL TRANSCRIBING" // Added case
    }
    
    // MARK: - Singleton Instance
    
    /// Shared singleton instance of Logger, with injected dependencies.
    public static var shared: Logger = Logger()

    // Dependency injection for enhanced flexibility in testing and lifecycle management.
    public static func configure(logger: Logger) {
        shared = logger
    }

    // MARK: - Private Initializer
    
    private init() {}
    
    // MARK: - Logging Methods
    
    /// Logs a message with the specified log level.
    ///
    /// - Parameters:
    ///   - level: The severity level of the log.
    ///   - message: The message to log.
    ///   - file: The file name where the log is called. Defaults to the caller's file.
    ///   - function: The function name where the log is called. Defaults to the caller's function.
    ///   - line: The line number where the log is called. Defaults to the caller's line number.
    public func log(_ level: LogLevel, message: String,
                    file: String = #file,
                    function: String = #function,
                    line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.rawValue) [\(fileName):\(line) \(function)] - \(message)"
        
        // Simplified to use `os_log` directly for production stability.
        os_log("%{public}@", log: OSLog.default, type: logType(for: level), logMessage)
    }
    
    /// Maps the custom LogLevel to os_log's LogType.
    ///
    /// - Parameter level: The custom log level.
    /// - Returns: Corresponding OSLogType.
    private func logType(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug:
            return .debug
        case .info, .localTranscribing: // Similar log type for info levels
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Logs a debug message.
    public func debug(_ message: String,
                      file: String = #file,
                      function: String = #function,
                      line: Int = #line) {
        log(.debug, message: message, file: file, function: function, line: line)
    }
    
    /// Logs an info message.
    public func info(_ message: String,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(.info, message: message, file: file, function: function, line: line)
    }
    
    /// Logs a warning message.
    public func warning(_ message: String,
                        file: String = #file,
                        function: String = #function,
                        line: Int = #line) {
        log(.warning, message: message, file: file, function: function, line: line)
    }
    
    /// Logs an error message.
    public func error(_ message: String,
                      file: String = #file,
                      function: String = #function,
                      line: Int = #line) {
        log(.error, message: message, file: file, function: function, line: line)
    }
    
    /// Logs a local transcribing message.
    public func localTranscribing(_ message: String,
                                  file: String = #file,
                                  function: String = #function,
                                  line: Int = #line) {
        log(.localTranscribing, message: message, file: file, function: function, line: line)
    }
}
