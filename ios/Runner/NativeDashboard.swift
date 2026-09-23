import SwiftUI
import UIKit

/// The read-only payload Flutter sends when it asks iOS to present the
/// incremental SwiftUI dashboard. SSH, monitor polling and credentials remain
/// owned by Flutter/Rust; this is deliberately presentation data only.
struct NativeDashboardPayload: Decodable {
    let revision: Int
    let servers: [NativeDashboardServer]
}

struct NativeDashboardServer: Identifiable, Hashable, Decodable {
    enum ConnectionState: String, Hashable, Decodable { case online, offline }

    let id: String
    let name: String
    let address: String
    let state: ConnectionState
    let cpuPercent: Int?
    let memoryPercent: Int?
    let diskPercent: Int?
}

/// A local presentation store, not a second monitor store. Flutter replaces
/// it as a whole with immutable snapshots.
@MainActor
final class NativeDashboardStore: ObservableObject {
    enum LoadState { case loading, content, empty, failed }

    @Published private(set) var servers: [NativeDashboardServer] = []
    @Published private(set) var loadState: LoadState = .loading
    private(set) var revision = -1

    func apply(json: String) throws {
        let payload = try JSONDecoder().decode(
            NativeDashboardPayload.self, from: Data(json.utf8)
        )
        guard payload.revision > revision else { return }
        revision = payload.revision
        servers = payload.servers
        loadState = servers.isEmpty ? .empty : .content
    }
}

struct NativeDashboardView: View {
    @ObservedObject var store: NativeDashboardStore
    let onClose: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                if horizontalSizeClass == .compact {
                    NavigationStack { NativeDashboardContent(store: store) }
                } else {
                    NativeDashboardSplitView(store: store)
                }
            } else {
                NavigationView { NativeDashboardLegacyContent(store: store) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel(NativeDashboardText.close)
            }
        }
    }
}

/// iOS 15 fallback. The app's deployment target still includes iOS 15, while
/// NavigationStack and NavigationSplitView require iOS 16.
private struct NativeDashboardLegacyContent: View {
    @ObservedObject var store: NativeDashboardStore

    var body: some View {
        Group {
            switch store.loadState {
            case .loading:
                ProgressView(NativeDashboardText.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                NativeDashboardPlaceholder(symbol: "server.rack", title: NativeDashboardText.emptyTitle, message: NativeDashboardText.emptyMessage)
            case .failed:
                NativeDashboardPlaceholder(symbol: "exclamationmark.triangle", title: NativeDashboardText.errorTitle, message: NativeDashboardText.errorMessage)
            case .content:
                List(store.servers) { server in
                    NavigationLink(destination: NativeServerDetail(server: server)) {
                        NativeServerRow(server: server)
                    }
                }
            }
        }
        .navigationTitle(NativeDashboardText.title)
    }
}

private struct NativeDashboardContent: View {
    @ObservedObject var store: NativeDashboardStore

    var body: some View {
        Group {
            switch store.loadState {
            case .loading:
                ProgressView(NativeDashboardText.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                NativeDashboardPlaceholder(symbol: "server.rack", title: NativeDashboardText.emptyTitle, message: NativeDashboardText.emptyMessage)
            case .failed:
                NativeDashboardPlaceholder(symbol: "exclamationmark.triangle", title: NativeDashboardText.errorTitle, message: NativeDashboardText.errorMessage)
            case .content:
                List(store.servers) { server in
                    NavigationLink(value: server) { NativeServerRow(server: server) }
                }
                .navigationDestination(for: NativeDashboardServer.self) { NativeServerDetail(server: $0) }
            }
        }
        .navigationTitle(NativeDashboardText.title)
    }
}

private struct NativeDashboardSplitView: View {
    @ObservedObject var store: NativeDashboardStore
    @State private var selection: NativeDashboardServer.ID?

    var body: some View {
        NavigationSplitView {
            switch store.loadState {
            case .content:
                List(store.servers, selection: $selection) { NativeServerRow(server: $0).tag($0.id) }
            case .loading:
                ProgressView(NativeDashboardText.loading)
            case .empty:
                NativeDashboardPlaceholder(symbol: "server.rack", title: NativeDashboardText.emptyTitle, message: NativeDashboardText.emptyMessage)
            case .failed:
                NativeDashboardPlaceholder(symbol: "exclamationmark.triangle", title: NativeDashboardText.errorTitle, message: NativeDashboardText.errorMessage)
            }
        } detail: {
            if let selected = store.servers.first(where: { $0.id == selection }) {
                NativeServerDetail(server: selected)
            } else {
                NativeDashboardPlaceholder(symbol: "server.rack", title: NativeDashboardText.selectionTitle, message: NativeDashboardText.selectionMessage)
            }
        }
        .navigationTitle(NativeDashboardText.title)
        .task(id: store.servers) {
            if selection == nil || !store.servers.contains(where: { $0.id == selection }) {
                selection = store.servers.first?.id
            }
        }
    }
}

private struct NativeDashboardPlaceholder: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.largeTitle)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct NativeServerRow: View {
    let server: NativeDashboardServer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(server.name).font(.headline)
                Spacer()
                Image(systemName: server.state == .online ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(server.state == .online ? .green : .secondary)
                    .accessibilityLabel(server.state == .online ? NativeDashboardText.online : NativeDashboardText.offline)
            }
            Text(server.address).font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NativeServerDetail: View {
    let server: NativeDashboardServer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(server.name).font(.largeTitle.bold())
                Text(server.address).foregroundStyle(.secondary)
                Label(server.state == .online ? NativeDashboardText.online : NativeDashboardText.offline, systemImage: server.state == .online ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(server.state == .online ? .green : .secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                    NativeMetricCard(title: NativeDashboardText.cpu, value: server.cpuPercent, tint: .blue)
                    NativeMetricCard(title: NativeDashboardText.memory, value: server.memoryPercent, tint: .purple)
                    NativeMetricCard(title: NativeDashboardText.disk, value: server.diskPercent, tint: .orange)
                }
            }
            .padding()
        }
        .navigationTitle(server.name)
    }
}

private struct NativeMetricCard: View {
    let title: String
    let value: Int?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if let value {
                Text("\(value)%").font(.title2.bold()).monospacedDigit()
                ProgressView(value: Double(value), total: 100).tint(tint)
            } else {
                Text(NativeDashboardText.unavailable).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading).padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(value.map { "\(title), \($0) percent" } ?? "\(title), \(NativeDashboardText.unavailable)")
    }
}

enum NativeDashboardPresentationError: Error {
    case notPresented
}

/// Owns presentation lifecycle only. The observable store contains the latest
/// Flutter snapshot, while polling and business state remain in Flutter.
@MainActor
final class NativeDashboardCoordinator: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = NativeDashboardCoordinator()

    var onClosed: (() -> Void)?

    private var store: NativeDashboardStore?
    private weak var controller: UIViewController?
    private var closing = false

    var isPresented: Bool { controller != nil && !closing }

    func present(json: String, from root: UIViewController) throws {
        if let store, isPresented {
            try store.apply(json: json)
            return
        }

        let store = NativeDashboardStore()
        try store.apply(json: json)
        let controller = UIHostingController(
            rootView: NativeDashboardView(
                store: store,
                onClose: { [weak self] in self?.dismiss() }
            )
        )
        controller.modalPresentationStyle = .fullScreen
        controller.presentationController?.delegate = self
        self.store = store
        self.controller = controller
        closing = false
        root.topMostViewController.present(controller, animated: true)
    }

    func update(json: String) throws {
        guard let store, isPresented else {
            throw NativeDashboardPresentationError.notPresented
        }
        try store.apply(json: json)
    }

    func dismiss() {
        guard !closing else { return }
        guard let controller, isPresented else {
            finishClosing()
            return
        }
        closing = true
        controller.dismiss(animated: true) { [weak self] in
            self?.finishClosing()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finishClosing()
    }

    private func finishClosing() {
        guard store != nil || controller != nil else { return }
        store = nil
        controller = nil
        closing = false
        onClosed?()
    }
}

private extension UIViewController {
    var topMostViewController: UIViewController {
        if let presentedViewController { return presentedViewController.topMostViewController }
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.topMostViewController ?? navigationController
        }
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.topMostViewController ?? tabBarController
        }
        return self
    }
}

private enum NativeDashboardText {
    private static var isChinese: Bool { Locale.current.languageCode == "zh" }
    static var title: String { isChinese ? "服务器" : "Servers" }
    static var loading: String { isChinese ? "正在加载服务器…" : "Loading servers…" }
    static var emptyTitle: String { isChinese ? "没有服务器" : "No Servers" }
    static var emptyMessage: String { isChinese ? "请先在 ServerBox 中添加服务器。" : "Add a server in ServerBox first." }
    static var errorTitle: String { isChinese ? "无法加载服务器" : "Unable to Load Servers" }
    static var errorMessage: String { isChinese ? "服务器数据格式无效。" : "The server snapshot is invalid." }
    static var selectionTitle: String { isChinese ? "选择服务器" : "Select a Server" }
    static var selectionMessage: String { isChinese ? "从列表中选择一台服务器以查看状态。" : "Choose a server from the list to view its status." }
    static var online: String { isChinese ? "在线" : "Online" }
    static var offline: String { isChinese ? "离线" : "Offline" }
    static var unavailable: String { isChinese ? "暂不可用" : "Unavailable" }
    static var close: String { isChinese ? "关闭" : "Close" }
    static var cpu: String { "CPU" }
    static var memory: String { isChinese ? "内存" : "Memory" }
    static var disk: String { isChinese ? "磁盘" : "Disk" }
}

#Preview("iPhone") {
    let store = NativeDashboardStore()
    try? store.apply(json: NativeDashboardFixture.json)
    return NativeDashboardView(store: store, onClose: {})
}

enum NativeDashboardFixture {
    static let json = #"""
    {"revision":1,"servers":[
      {"id":"preview-1","name":"STD20","address":"192.0.2.20:22","state":"online","cpuPercent":3,"memoryPercent":47,"diskPercent":41},
      {"id":"preview-2","name":"Backup","address":"[2001:db8::2]:22","state":"offline","cpuPercent":null,"memoryPercent":0,"diskPercent":62}
    ]}
    """#
}
