import Foundation

public class RuntimeList {

    public init() {}

    public func downloadableRuntimes() async throws -> DownloadableRuntimesResponse {
        let (data, _) = try await Current.network.dataTask(with: URLRequest.runtimes).async()
        var decodedResponse = try PropertyListDecoder().decode(DownloadableRuntimesResponse.self, from: data)

        let runtimes = decodedResponse.downloadables.map { runtime in
            var updatedRuntime = runtime

            // This loops through and matches up the simulatorVersion to the mappings
            let simulatorBuildUpdate = decodedResponse.sdkToSimulatorMappings.filter { SDKToSimulatorMapping in
                SDKToSimulatorMapping.simulatorBuildUpdate == runtime.simulatorVersion.buildUpdate
            }
            if simulatorBuildUpdate.isEmpty {
                updatedRuntime.sdkBuildUpdate = []
            } else {
                updatedRuntime.sdkBuildUpdate = simulatorBuildUpdate.map { $0.sdkBuildUpdate }
            }

            return updatedRuntime
        }

        decodedResponse.downloadables = runtimes

        return decodedResponse
    }

    public func installedRuntimes() async throws -> [InstalledRuntime] {
        let output = try await Current.shell.installedRuntimes().async()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let outputDictionary = try decoder.decode([String: InstalledRuntime].self, from: output.out.data(using: .utf8)!)
        return outputDictionary.values.sorted { first, second in
            return first.identifier.uuidString.compare(second.identifier.uuidString, options: .numeric) == .orderedAscending
        }
    }
}
