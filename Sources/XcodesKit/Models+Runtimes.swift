import Foundation

public struct DownloadableRuntimesResponse: Decodable {
    public let sdkToSimulatorMappings: [SDKToSimulatorMapping]
    public let sdkToSeedMappings: [SDKToSeedMapping]
    public let refreshInterval: Int
    public var downloadables: [DownloadableRuntime]
    public let version: String
}

public struct DownloadableRuntime: Decodable {
    public let category: Category
    public let simulatorVersion: SimulatorVersion
    public let source: String?
    public let dictionaryVersion: Int
    public let contentType: ContentType
    public let platform: Platform
    public let identifier: String
    public let version: String
    public let fileSize: Int
    public let hostRequirements: HostRequirements?
    public let name: String
    public let authentication: Authentication?

    public var sdkBuildUpdate: [String]?

    public var betaNumber: Int? {
        enum Regex { static let shared = try! NSRegularExpression(pattern: "b[0-9]+$") }
        guard var foundString = Regex.shared.firstString(in: identifier) else { return nil }
        foundString.removeFirst()
        return Int(foundString)!
    }

    public var completeVersion: String {
        makeVersion(for: simulatorVersion.version, betaNumber: betaNumber)
    }

    public var visibleIdentifier: String {
        return platform.shortName + " " + completeVersion
    }
}

func makeVersion(for osVersion: String, betaNumber: Int?) -> String {
    let betaSuffix = betaNumber.flatMap { "-beta\($0)" } ?? ""
    return osVersion + betaSuffix
}

public struct SDKToSeedMapping: Decodable {
    public let buildUpdate: String
    public let platform: DownloadableRuntime.Platform
    public let seedNumber: Int
}

public struct SDKToSimulatorMapping: Decodable {
    public var sdkBuildUpdate: String
    public let simulatorBuildUpdate: String
    public let sdkIdentifier: String
}

extension DownloadableRuntime {
    public struct SimulatorVersion: Decodable {
        public let buildUpdate: String
        public let version: String
    }

    public struct HostRequirements: Decodable {
        let maxHostVersion: String?
        let excludedHostArchitectures: [String]?
        let minHostVersion: String?
        let minXcodeVersion: String?
    }

    public enum Authentication: String, Decodable {
        case virtual = "virtual"
    }

    public enum Category: String, Decodable {
        case simulator = "simulator"
    }

    public enum ContentType: String, Decodable {
        case diskImage = "diskImage"
        case package = "package"
        case cryptexDiskImage = "cryptexDiskImage"
        case patchableCryptexDiskImage = "patchableCryptexDiskImage"
    }

    public enum Platform: String, Decodable {
        case iOS = "com.apple.platform.iphoneos"
        case macOS = "com.apple.platform.macosx"
        case watchOS = "com.apple.platform.watchos"
        case tvOS = "com.apple.platform.appletvos"
        case visionOS = "com.apple.platform.xros"

        public var order: Int {
            switch self {
                case .iOS: return 1
                case .macOS: return 2
                case .watchOS: return 3
                case .tvOS: return 4
                case .visionOS: return 5
            }
        }

        public var shortName: String {
            switch self {
                case .iOS: return "iOS"
                case .macOS: return "macOS"
                case .watchOS: return "watchOS"
                case .tvOS: return "tvOS"
                case .visionOS: return "visionOS"
            }
        }
    }
}

public struct InstalledRuntime: Decodable {
    public let build: String
    public let deletable: Bool
    public let identifier: UUID
    public let kind: Kind
    public let lastUsedAt: Date?
    public let path: String
    public let platformIdentifier: Platform
    public let runtimeBundlePath: String
    public let runtimeIdentifier: String
    public let signatureState: String
    public let state: String
    public let version: String
    public let sizeBytes: Int?
}

extension InstalledRuntime {
    public enum Kind: String, Decodable {
        case bundled = "Bundled with Xcode"
        case cryptexDiskImage = "Cryptex Disk Image"
        case diskImage = "Disk Image"
        case legacyDownload = "Legacy Download"
        case patchableCryptexDiskImage = "Patchable Cryptex Disk Image"
    }

    public enum Platform: String, Decodable {
        case tvOS = "com.apple.platform.appletvsimulator"
        case iOS = "com.apple.platform.iphonesimulator"
        case watchOS = "com.apple.platform.watchsimulator"
        case visionOS = "com.apple.platform.xrsimulator"

        public var asPlatformOS: DownloadableRuntime.Platform {
            switch self {
                case .watchOS: return .watchOS
                case .iOS: return .iOS
                case .tvOS: return .tvOS
                case .visionOS: return .visionOS
            }
        }
    }
}
