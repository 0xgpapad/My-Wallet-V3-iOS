//
//  Logger.swift
//  Blockchain
//
//  Created by Chris Arriola on 7/24/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

/// Class in charge of logging debug/info/warning/error messages to a `LogDestination`.
@objc public class Logger: NSObject {

    private let destinations: [LogDestination] = [ConsoleLogDestination(),
                                                  SwiftyBeaverDestination()]

    private lazy var timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    public static let shared: Logger = {
        let logger = Logger()
        return logger
    }()

    @objc public class func sharedInstance() -> Logger { shared }

    // MARK: - Public

    public func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    public func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    public func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    public func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    public func error(_ error: Error) {
        log(error.localizedDescription, level: .error)
    }

    public func log (
        _ message: String,
        level: LogLevel,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        destinations.forEach {
            let statement = formatMessage(
                message,
                level: level,
                file: file,
                function: function,
                line: line
            )
            $0.log(statement: statement, level: level)
        }
    }

    // MARK: - Private

    private func formatMessage(
        _ message: String,
        level: LogLevel,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        let logLevelTitle = "\(level)".uppercased()
        return "\(timestamp) \(level.emoji) \(logLevelTitle) \(filename(from: file)).\(function):\(line) - \(message)"
    }

    private func filename(from file: String) -> String {
        if let lastComponent = file.components(separatedBy: "/").last {
            return lastComponent.components(separatedBy: ".").first ?? lastComponent
        }
        return file
    }
}
