import Foundation

enum ShortcutNames {
    static let on = "DND Sync On"
    static let off = "DND Sync Off"
}

enum ShortcutRunError: LocalizedError {
    case compileFailed(String)
    case automationDenied
    case shortcutNotFound(String)
    case shortcutsUnavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .compileFailed(let message):
            return message
        case .automationDenied:
            return "Automation permission denied for Shortcuts"
        case .shortcutNotFound(let name):
            return "Shortcut not found: \(name). Import Shortcuts and tap Add first."
        case .shortcutsUnavailable:
            return "Shortcuts is not available"
        case .failed(let message):
            return message
        }
    }
}

enum ShortcutRunner {
    private static let errAEEventNotPermitted = -1743
    private static let errAEAccessDenied = -1744
    private static let errAENoSuchObject = -1728
    private static let procNotFound = -600
    private static let connectionInvalid = -609
    private static let appleEventsPermissionDenied = 1002

    static func run(named name: String) -> Result<Void, ShortcutRunError> {
        let source = """
        tell application "Shortcuts"
            run shortcut named \(appleScriptString(name))
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            return .failure(.compileFailed("Could not create AppleScript to run \(name)."))
        }

        var compileError: NSDictionary?
        guard script.compileAndReturnError(&compileError) else {
            return .failure(mapError(compileError, shortcutName: name, fallback: "AppleScript compile failed."))
        }

        var executeError: NSDictionary?
        _ = script.executeAndReturnError(&executeError)
        if let executeError {
            return .failure(mapError(executeError, shortcutName: name, fallback: "Running \(name) failed."))
        }
        return .success(())
    }

    static func exists(named name: String) -> Result<Bool, ShortcutRunError> {
        let source = """
        tell application "Shortcuts"
            exists shortcut named \(appleScriptString(name))
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            return .failure(.compileFailed("Could not create AppleScript to check \(name)."))
        }

        var compileError: NSDictionary?
        guard script.compileAndReturnError(&compileError) else {
            return .failure(mapError(compileError, shortcutName: name, fallback: "AppleScript compile failed."))
        }

        var executeError: NSDictionary?
        let result = script.executeAndReturnError(&executeError)
        if let executeError {
            let mapped = mapError(executeError, shortcutName: name, fallback: "Checking \(name) failed.")
            if case .shortcutNotFound = mapped {
                return .success(false)
            }
            return .failure(mapped)
        }
        return .success(result.booleanValue)
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func mapError(
        _ error: NSDictionary?,
        shortcutName: String,
        fallback: String
    ) -> ShortcutRunError {
        let number = error?[NSAppleScript.errorNumber] as? Int
        let message = (error?[NSAppleScript.errorMessage] as? String)
            ?? (error?[NSAppleScript.errorBriefMessage] as? String)
            ?? fallback
        let lowercased = message.lowercased()

        switch number {
        case errAEEventNotPermitted, errAEAccessDenied, appleEventsPermissionDenied:
            return .automationDenied
        case procNotFound, connectionInvalid:
            return .shortcutsUnavailable
        case errAENoSuchObject:
            return .shortcutNotFound(shortcutName)
        default:
            break
        }

        if lowercased.contains("not authorized")
            || lowercased.contains("not permitted")
            || lowercased.contains("not allowed to send apple events") {
            return .automationDenied
        }
        if lowercased.contains("can't get shortcut")
            || lowercased.contains("cannot get shortcut")
            || lowercased.contains("doesn’t understand")
            || lowercased.contains("doesn't understand") {
            return .shortcutNotFound(shortcutName)
        }
        if lowercased.contains("application isn’t running")
            || lowercased.contains("application isn't running")
            || lowercased.contains("connection is invalid") {
            return .shortcutsUnavailable
        }
        return .failed(message)
    }
}
