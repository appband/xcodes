import Foundation
import Path

extension Path {
    public var isAppBundle: Bool {
        switch self.type {
        case .directory:
            return self.extension == "app" && self.isSymlink == false
        case .file, .symlink:
            return false
        case .none:
            return false
        }
    }

    public var infoPlist: InfoPlist? {
        guard let path = try? self.realpath() else { return nil }
        let infoPlistPath = path.join("Contents").join("Info.plist")
        guard
            let infoPlistData = try? Data(contentsOf: infoPlistPath.url),
            let infoPlist = try? PropertyListDecoder().decode(InfoPlist.self, from: infoPlistData)
        else { return nil }

        return infoPlist
    }
}
