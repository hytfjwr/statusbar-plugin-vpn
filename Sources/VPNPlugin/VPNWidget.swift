import AppKit
import Combine
import StatusBarKit
import SwiftUI

// MARK: - VPNWidget

@MainActor
@Observable
public final class VPNWidget: StatusBarWidget {
    public let id = "vpn"
    public let position: WidgetPosition = .right
    public let updateInterval: TimeInterval? = 5
    public var sfSymbolName: String { "lock.shield" }

    private var timer: AnyCancellable?
    private let service = VPNService()
    private var vpnConnections: [VPNService.VPNConnection] = []
    private var popupPanel: PopupPanel?

    // System Settings is the only way to connect/disconnect on macOS 26:
    // NE-native configurations are invisible to `scutil --nc start/stop`.
    private static let vpnSettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension")!

    private var anyConnected: Bool {
        vpnConnections.contains { $0.isConnected }
    }

    public init() {}

    public func start() {
        update()
        timer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.update() }
    }

    public func stop() {
        timer?.cancel()
        popupPanel?.hidePopup()
    }

    private func update() {
        Task { @MainActor in
            let connections = await service.fetchVPNs()
            self.vpnConnections = connections
            if self.popupPanel?.isVisible == true {
                popupPanel?.updateContent(makePopupContent())
            }
        }
    }

    public func body() -> some View {
        HStack(spacing: 4) {
            Image(systemName: anyConnected ? "lock.shield.fill" : "lock.shield")
                .font(Theme.sfIconFont)
                .foregroundStyle(anyConnected ? AnyShapeStyle(Theme.accentBlue) : AnyShapeStyle(.primary))
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture { [weak self] in
            self?.togglePopup()
        }
    }

    private func togglePopup() {
        if popupPanel?.isVisible == true {
            popupPanel?.hidePopup()
        } else {
            showPopup()
        }
    }

    private func makePopupContent() -> VPNPopupContent {
        VPNPopupContent(connections: vpnConnections) {
            NSWorkspace.shared.open(Self.vpnSettingsURL)
        }
    }

    private func showPopup() {
        if popupPanel == nil {
            popupPanel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 200))
        }

        guard let (barFrame, screen) = PopupPanel.barTriggerFrame() else {
            return
        }

        popupPanel?.showPopup(relativeTo: barFrame, on: screen, content: makePopupContent())
    }
}

// MARK: - VPNPopupContent

struct VPNPopupContent: View {
    let connections: [VPNService.VPNConnection]
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PopupSectionHeader("VPN")

            if connections.isEmpty {
                PopupEmptyState(icon: "lock.shield", message: "No VPN configured")
            } else {
                VStack(spacing: 2) {
                    ForEach(connections, id: \.id) { vpn in
                        Button(action: onOpenSettings) {
                            HStack(spacing: 10) {
                                Image(systemName: vpn.isConnected ? "lock.shield.fill" : "lock.shield")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(vpn.isConnected ? Theme.accentBlue : Theme.secondary)
                                    .frame(width: 22, alignment: .center)
                                    .symbolRenderingMode(.hierarchical)

                                Text(vpn.name)
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(.primary)

                                Spacer()

                                PopupStatusBadge(
                                    vpn.isConnected ? "Connected" : "Disconnected",
                                    color: vpn.isConnected ? Theme.accentBlue : Theme.secondary
                                )
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .contentShape(RoundedRectangle(cornerRadius: Theme.popupItemCornerRadius, style: .continuous))
                        }
                        .buttonStyle(PopupButtonStyle())
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(.bottom, 8)
        .frame(width: 300)
    }
}
