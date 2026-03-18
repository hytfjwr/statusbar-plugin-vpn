import StatusBarKit

@MainActor
public struct VPNPlugin: StatusBarPlugin {
    public let manifest = PluginManifest(
        id: "com.statusbar.vpn",
        name: "VPN"
    )

    public let widgets: [any StatusBarWidget]

    public init() {
        widgets = [VPNWidget()]
    }
}

// MARK: - Plugin Factory

@_cdecl("createStatusBarPlugin")
public func createStatusBarPlugin() -> UnsafeMutableRawPointer {
    let box = PluginBox { VPNPlugin() }
    return Unmanaged.passRetained(box).toOpaque()
}
