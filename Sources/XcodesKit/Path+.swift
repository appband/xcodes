import Path
import Foundation

extension Path {
    // Get Home even if we are running as root

    static var environmentHome: Path {
        if let homePathString = ProcessInfo.processInfo.environment["HOME"], let path = Path(homePathString) {
            return path
        }

        do {
            return try Path.home.realpath()
        } catch {
            preconditionFailure(error.localizedDescription)
        }
    }
    static let environmentApplicationSupport = environmentHome/"Library/Application Support"
    static let environmentCaches = environmentHome/"Library/Caches"
    public static let environmentDownloads = environmentHome/"Downloads"

    static let oldXcodesApplicationSupport = environmentApplicationSupport/"ca.brandonevans.xcodes"
    static let xcodesApplicationSupport = environmentApplicationSupport/"com.robotsandpencils.xcodes"
    static let xcodesCaches = environmentCaches/"com.robotsandpencils.xcodes"
    static let cacheFile = xcodesApplicationSupport/"available-xcodes.json"
    static let configurationFile = xcodesApplicationSupport/"configuration.json"

    @discardableResult
    func setCurrentUserAsOwner() -> Path {
        let user = ProcessInfo.processInfo.environment["SUDO_USER"] ?? NSUserName()
        try? FileManager.default.setAttributes([.ownerAccountName: user], ofItemAtPath: string)
        return self
    }
}
