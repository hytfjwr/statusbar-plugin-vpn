import Foundation
import OSLog
import SystemConfiguration

private let logger = Logger(subsystem: "com.statusbar", category: "VPNService")

final class VPNService: @unchecked Sendable {
    struct VPNConnection {
        let id: String
        let name: String
        let isConnected: Bool
    }

    private static let configurationStorePath = "/Library/Preferences/com.apple.networkextension.plist"

    func fetchVPNs() async -> [VPNConnection] {
        let connectedIDs = connectedServiceIDs()
        return loadVPNConfigurations()
            .map { VPNConnection(id: $0.id, name: $0.name, isConnected: connectedIDs.contains($0.id)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Configuration enumeration

    /// Since macOS 26, VPN configurations created in System Settings exist only in the
    /// NetworkExtension store — they are no longer bridged into the legacy
    /// SCNetworkConnection service set, so `scutil --nc list` returns nothing for them.
    private func loadVPNConfigurations() -> [(id: String, name: String)] {
        guard let data = FileManager.default.contents(atPath: Self.configurationStorePath) else {
            logger.debug("cannot read \(Self.configurationStorePath)")
            return []
        }
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format),
              let root = plist as? [String: Any],
              let objects = root["$objects"] as? [Any],
              let top = root["$top"] as? [String: Any]
        else {
            logger.debug("unexpected NSKeyedArchiver shape in configuration store")
            return []
        }

        // Bookkeeping keys in $top that are not per-configuration UUIDs.
        let metadataKeys: Set<String> = ["Generation", "Index", "SCPreferencesSignature2", "Version"]

        var configurations: [(id: String, name: String)] = []
        for (uuid, ref) in top where !metadataKeys.contains(uuid) {
            guard let config = resolve(ref, in: objects) as? [String: Any],
                  // Non-VPN NEConfigurations (content filters etc.) carry $null here.
                  resolve(config["VPN"], in: objects) != nil,
                  let name = resolve(config["Name"], in: objects) as? String
            else { continue }
            configurations.append((id: uuid, name: name))
        }
        return configurations
    }

    /// Resolves an NSKeyedArchiver reference into the `$objects` table.
    /// Index 0 is the archiver's `$null` marker, mapped to `nil`.
    private func resolve(_ value: Any?, in objects: [Any]) -> Any? {
        guard let index = keyedArchiverUID(value), index != 0, index < objects.count else { return nil }
        return objects[index]
    }

    /// NSKeyedArchiver references decode as a private CoreFoundation type
    /// (CFKeyedArchiverUID) with no public accessor — KVC `value(forKey: "value")`
    /// raises an uncatchable NSUnknownKeyException. The wrapped index is only
    /// observable through its description, e.g. `<CFKeyedArchiverUID 0x...>{value = 134}`.
    private func keyedArchiverUID(_ value: Any?) -> Int? {
        guard let value else { return nil }
        let description = String(describing: value)
        guard description.hasPrefix("<CFKeyedArchiverUID"),
              let range = description.range(of: #"value = (\d+)"#, options: .regularExpression),
              let digits = description[range].split(separator: " ").last
        else { return nil }
        return Int(digits)
    }

    // MARK: - Connection state

    /// A VPN session is active iff `State:/Network/Service/<UUID>/IPSec` exists in the
    /// dynamic store, where `<UUID>` equals the configuration's identifier in the
    /// NetworkExtension store. Disconnected configurations leave no State: keys at all.
    private func connectedServiceIDs() -> Set<String> {
        guard let store = SCDynamicStoreCreate(nil, "VPNPlugin" as CFString, nil, nil),
              let keys = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/[^/]+/IPSec" as CFString) as? [String]
        else {
            return []
        }
        return Set(keys.compactMap { key in
            let components = key.split(separator: "/")
            guard components.count >= 2 else { return nil }
            return String(components[components.count - 2])
        })
    }
}
