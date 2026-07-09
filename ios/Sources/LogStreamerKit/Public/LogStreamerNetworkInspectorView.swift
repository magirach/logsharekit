import Foundation

#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(WebKit)
import WebKit
#endif

/// Reusable in-app network inspector backed by the entries captured through `LogStreamer.makeInstrumentedSession`.
public struct LogStreamerNetworkInspectorView: View {
    @StateObject private var model = LogStreamerNetworkInspectorViewModel()
    @State private var searchText = ""
    @State private var methodFilter = "All"
    @State private var statusFilter = NetworkStatusFilter.all
    @State private var endpointFilter: String?
    @State private var isEndpointFilterPresented = false
    @State private var isSettingsPresented = false
    @State private var sharedFile: SharedFile?
    @State private var exportMessage: String?

    public init() {}

    public var body: some View {
        List {
            filtersSection
            if filteredEntries.isEmpty {
                emptyState
            } else {
                Section {
                    ForEach(filteredEntries) { entry in
                        NavigationLink {
                            LogStreamerNetworkEntryDetailView(entryID: entry.id)
                        } label: {
                            LogStreamerNetworkEntryRow(entry: entry)
                        }
                    }
                } footer: {
                    Text("\(filteredEntries.count) of \(model.summaries.count) requests")
                }
            }
        }
        .navigationTitle("Network Inspector")
        .searchable(text: $searchText, prompt: "Search request URL")
        .toolbar {
            ToolbarItemGroup(placement: toolbarPlacement) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Menu {
                    Button {
                        isEndpointFilterPresented = true
                    } label: {
                        Label("Filter Endpoints", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Button {
                        isSettingsPresented = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    Button {
                        Task { await shareSession() }
                    } label: {
                        Label("Share Session", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.summaries.isEmpty)

                    Button("Clear", role: .destructive) {
                        Task { await LogStreamer.clearNetworkEntries() }
                    }
                    .disabled(model.summaries.isEmpty)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .task {
            await model.refresh()
        }
        .sheet(isPresented: $isEndpointFilterPresented) {
            NavigationView {
                LogStreamerEndpointFilterSheet(
                    endpoints: model.endpoints,
                    selection: $endpointFilter
                )
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            NavigationView {
                LogStreamerNetworkInspectorSettingsView(settings: model.settings) { settings in
                    await model.updateSettings(settings)
                }
            }
        }
        .sheet(item: $sharedFile) { file in
#if canImport(UIKit)
            ActivityView(items: [file.url])
#else
            Text(file.url.path)
                .padding(24)
#endif
        }
        .alert("Export Ready", isPresented: exportAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .automatic
#else
        .navigationBarTrailing
#endif
    }

    private var filteredEntries: [LogStreamerNetworkEntrySummary] {
        model.summaries.filter { entry in
            let matchesMethod = methodFilter == "All" || entry.requestMethod == methodFilter
            let matchesStatus = statusFilter.matches(entry)
            let matchesEndpoint = endpointFilter == nil || entry.endpoint == endpointFilter
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch = entry.url.lowercased().contains(query)
            }
            return matchesMethod && matchesStatus && matchesEndpoint && matchesSearch
        }
    }

    private var filtersSection: some View {
        Section {
            Picker("Method", selection: $methodFilter) {
                Text("All").tag("All")
                ForEach(model.methods, id: \.self) { method in
                    Text(method).tag(method)
                }
            }

            Picker("Status", selection: $statusFilter) {
                ForEach(NetworkStatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Button {
                isEndpointFilterPresented = true
            } label: {
                HStack {
                    Text("Endpoint")
                    Spacer()
                    Text(endpointFilter ?? "All Endpoints")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if endpointFilter != nil {
                Button("Clear Endpoint Filter", role: .destructive) {
                    endpointFilter = nil
                }
            }

            if !model.settings.ignoredHosts.isEmpty {
                HStack {
                    Text("Ignored Hosts")
                    Spacer()
                    Text("\(model.settings.ignoredHosts.count)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Filters")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "network.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Network Logs")
                .font(.headline)
            Text("Run requests through LogStreamer to inspect them here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .listRowBackground(Color.clear)
    }

    private func shareSession() async {
        guard let url = await LogStreamer.exportNetworkSession() else { return }
#if canImport(UIKit)
        sharedFile = SharedFile(url: url)
#elseif canImport(AppKit)
        if let view = NSApp.keyWindow?.contentView {
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else {
            exportMessage = url.path
        }
#endif
    }

    private var exportAlertBinding: Binding<Bool> {
        Binding(
            get: { exportMessage != nil },
            set: { newValue in
                if !newValue {
                    exportMessage = nil
                }
            }
        )
    }
}

@MainActor
private final class LogStreamerNetworkInspectorViewModel: ObservableObject {
    @Published var summaries: [LogStreamerNetworkEntrySummary] = []
    @Published var settings = LogStreamerNetworkInspectorSettings()

    private var observerTask: Task<Void, Never>?

    var methods: [String] {
        Array(Set(summaries.map(\.requestMethod))).sorted()
    }

    var endpoints: [String] {
        Array(Set(summaries.map(\.endpoint))).sorted()
    }

    init() {
        observerTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .logStreamerNetworkInspectorDidChange) {
                await self?.refresh()
            }
        }
    }

    deinit {
        observerTask?.cancel()
    }

    func refresh() async {
        async let summaries = LogStreamer.networkEntrySummaries()
        async let settings = LogStreamer.networkInspectorSettings()
        self.summaries = await summaries
        self.settings = await settings
    }

    func updateSettings(_ settings: LogStreamerNetworkInspectorSettings) async {
        await LogStreamer.updateNetworkInspectorSettings(settings)
        await refresh()
    }
}

private struct LogStreamerNetworkEntryRow: View {
    let entry: LogStreamerNetworkEntrySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                Text(entry.requestMethod)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(methodColor.opacity(0.15))
                    .foregroundStyle(methodColor)
                    .clipShape(Capsule())

                Text(entry.statusSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(statusColor)

                Spacer()

                Text("\(entry.durationMs) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let contentType = entry.responseContentType ?? entry.requestContentType {
                    Text(compactContentTypeLabel(contentType))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            if let errorDescription = entry.errorDescription, !errorDescription.isEmpty {
                Text(errorDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func compactContentTypeLabel(_ contentType: String) -> String {
        let normalized = contentType
            .split(separator: ";")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? contentType

        switch normalized.lowercased() {
        case let type where type.contains("application/json"),
             let type where type.contains("+json"):
            return "JSON"
        case let type where type.contains("text/html"):
            return "HTML"
        case let type where type.contains("text/plain"):
            return "TEXT"
        case let type where type.contains("octet-stream"):
            return "BIN"
        default:
            return normalized
                .replacingOccurrences(of: "application/", with: "")
                .replacingOccurrences(of: "text/", with: "")
                .uppercased()
        }
    }

    private var methodColor: Color {
        switch entry.requestMethod.uppercased() {
        case "GET": return .green
        case "POST": return .blue
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .secondary
        }
    }

    private var statusColor: Color {
        guard let code = entry.responseStatusCode else {
            return entry.errorDescription == nil ? .secondary : .red
        }
        switch code {
        case 200..<300: return .green
        case 300..<400: return .orange
        default: return .red
        }
    }
}

private struct LogStreamerNetworkEntryDetailView: View {
    let entryID: UUID

    @State private var entry: LogStreamerNetworkEntry?
    @State private var sharedFile: SharedFile?
    @State private var exportMessage: String?

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summarySection(entry)
                        requestSection(entry)
                        responseSection(entry)
                        if let errorDescription = entry.errorDescription, !errorDescription.isEmpty {
                            inspectorCard(title: "Error") {
                                Text(errorDescription)
                                    .font(.footnote.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                ProgressView("Loading Request")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(entry?.requestMethod ?? "Request")
        .modifier(InlineNavigationTitleModifier())
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                Button {
                    Task { await shareEntry() }
                } label: {
                    Label("Share Request", systemImage: "square.and.arrow.up")
                }
                .disabled(entry == nil)
            }
        }
        .task(id: entryID) {
            await refresh()
        }
        .sheet(item: $sharedFile) { file in
#if canImport(UIKit)
            ActivityView(items: [file.url])
#else
            Text(file.url.path)
                .padding(24)
#endif
        }
        .alert("Export Ready", isPresented: exportAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .automatic
#else
        .navigationBarTrailing
#endif
    }

    private func refresh() async {
        entry = await LogStreamer.networkEntry(id: entryID)
    }

    private func shareEntry() async {
        guard let url = await LogStreamer.exportNetworkEntry(id: entryID) else { return }
#if canImport(UIKit)
        sharedFile = SharedFile(url: url)
#elseif canImport(AppKit)
        if let view = NSApp.keyWindow?.contentView {
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else {
            exportMessage = url.path
        }
#endif
    }

    private var exportAlertBinding: Binding<Bool> {
        Binding(
            get: { exportMessage != nil },
            set: { newValue in
                if !newValue {
                    exportMessage = nil
                }
            }
        )
    }

    private func summarySection(_ entry: LogStreamerNetworkEntry) -> some View {
        inspectorCard(title: "Summary") {
            inspectorRow(label: "URL", value: entry.url)
            inspectorRow(label: "Status", value: entry.statusSummary)
            inspectorRow(label: "Duration", value: "\(entry.durationMs) ms")
            inspectorRow(label: "Started", value: entry.startedAt)
            inspectorRow(label: "Finished", value: entry.finishedAt)
        }
    }

    private func requestSection(_ entry: LogStreamerNetworkEntry) -> some View {
        inspectorCard(title: "Request") {
            inspectorRow(label: "Method", value: entry.requestMethod)
            if let contentType = entry.requestContentType {
                inspectorRow(label: "Content-Type", value: contentType)
            }
            keyValueSection(values: entry.requestHeaders)
            bodyPreviewSection(
                title: "Request Body",
                body: entry.formattedRequestBody,
                kind: entry.requestBodyKind,
                contentType: entry.requestContentType
            )
            textSection(title: "cURL", value: entry.curlCommand)
        }
    }

    private func responseSection(_ entry: LogStreamerNetworkEntry) -> some View {
        inspectorCard(title: "Response") {
            inspectorRow(label: "Status", value: entry.statusSummary)
            if let contentType = entry.responseContentType {
                inspectorRow(label: "Content-Type", value: contentType)
            }
            keyValueSection(values: entry.responseHeaders)
            bodyPreviewSection(
                title: "Response Body",
                body: entry.formattedResponseBody,
                kind: entry.responseBodyKind,
                contentType: entry.responseContentType
            )
        }
    }

    private func inspectorCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func keyValueSection(values: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Headers")
                .font(.subheadline.weight(.semibold))
            if values.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(values.keys.sorted(), id: \.self) { key in
                    inspectorRow(label: key, value: values[key] ?? "")
                }
            }
        }
    }

    private func bodyPreviewSection(
        title: String,
        body: String?,
        kind: LogStreamerBodyContentKind,
        contentType: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if let body, !body.isEmpty {
                let preview = NetworkInspectorBodyFormatter.preview(for: body, kind: kind) ?? body
                NavigationLink {
                    LogStreamerNetworkBodyDetailView(
                        title: title,
                        content: body,
                        kind: kind,
                        contentType: contentType
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(kind.title)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.14))
                                .clipShape(Capsule())
                            Spacer()
                            Text("Open Detail")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                        Text(preview)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.primary)
                            .lineLimit(8)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Text("None")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func textSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inspectorRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LogStreamerNetworkBodyDetailView: View {
    let title: String
    let content: String
    let kind: LogStreamerBodyContentKind
    let contentType: String?

    @State private var htmlMode = HTMLDisplayMode.rendered

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(kind.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(Capsule())
                    if let contentType, !contentType.isEmpty {
                        Text(contentType)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                if kind == .html {
                    htmlContent
                } else {
                    textBody(content)
                }
            }
            .padding(20)
        }
        .navigationTitle(title)
        .modifier(InlineNavigationTitleModifier())
    }

    @ViewBuilder
    private var htmlContent: some View {
#if canImport(WebKit)
        Picker("HTML Preview", selection: $htmlMode) {
            ForEach(HTMLDisplayMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)

        if htmlMode == .rendered {
            HTMLPreviewView(html: content)
                .frame(minHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            textBody(content)
        }
#else
        textBody(content)
#endif
    }

    private func textBody(_ value: String) -> some View {
        Text(value)
            .font(.footnote.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct LogStreamerEndpointFilterSheet: View {
    let endpoints: [String]
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List {
            Button {
                selection = nil
                dismiss()
            } label: {
                endpointRow(title: "All Endpoints", isSelected: selection == nil)
            }
            .buttonStyle(.plain)

            ForEach(filteredEndpoints, id: \.self) { endpoint in
                Button {
                    selection = endpoint
                    dismiss()
                } label: {
                    endpointRow(title: endpoint, isSelected: selection == endpoint)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Endpoint Filter")
        .searchable(text: $searchText, prompt: "Search endpoints")
        .toolbar {
            ToolbarItem(placement: toolbarDismissPlacement) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var filteredEndpoints: [String] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return endpoints
        }
        let query = searchText.lowercased()
        return endpoints.filter { $0.lowercased().contains(query) }
    }

    private func endpointRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .lineLimit(1)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
    }
}

private struct LogStreamerNetworkInspectorSettingsView: View {
    @State private var draft: LogStreamerNetworkInspectorSettings
    @State private var newHost = ""

    let onSave: (LogStreamerNetworkInspectorSettings) async -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        settings: LogStreamerNetworkInspectorSettings,
        onSave: @escaping (LogStreamerNetworkInspectorSettings) async -> Void
    ) {
        _draft = State(initialValue: settings)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Persistence") {
                Toggle("Reset logs on app restart", isOn: $draft.resetOnAppLaunch)
                Text("When enabled, the saved inspector session is cleared the next time the app starts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Ignored Hosts") {
                HStack {
                    TextField("api.example.com", text: $newHost)
#if canImport(UIKit)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                    Button("Add") {
                        addHost()
                    }
                    .disabled(newHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if draft.ignoredHosts.isEmpty {
                    Text("No ignored hosts configured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.ignoredHosts, id: \.self) { host in
                        HStack {
                            Text(host)
                            Spacer()
                            Button(role: .destructive) {
                                draft.ignoredHosts.removeAll { $0 == host }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Inspector Settings")
        .toolbar {
            ToolbarItem(placement: toolbarLeadingPlacement) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: toolbarDismissPlacement) {
                Button("Save") {
                    Task {
                        await onSave(draft.normalized())
                        dismiss()
                    }
                }
            }
        }
    }

    private func addHost() {
        let normalizedHost = newHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedHost.isEmpty else { return }
        if !draft.ignoredHosts.contains(normalizedHost) {
            draft.ignoredHosts.append(normalizedHost)
            draft.ignoredHosts.sort()
        }
        newHost = ""
    }
}

private enum NetworkStatusFilter: String, CaseIterable, Identifiable {
    case all
    case success
    case redirect
    case failure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .success: return "2xx"
        case .redirect: return "3xx"
        case .failure: return "Fail"
        }
    }

    func matches(_ entry: LogStreamerNetworkEntrySummary) -> Bool {
        switch self {
        case .all:
            return true
        case .success:
            return entry.responseStatusCode.map { 200..<300 ~= $0 } ?? false
        case .redirect:
            return entry.responseStatusCode.map { 300..<400 ~= $0 } ?? false
        case .failure:
            if let code = entry.responseStatusCode {
                return code >= 400
            }
            return entry.errorDescription != nil
        }
    }
}

private struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

private enum HTMLDisplayMode: String, CaseIterable, Identifiable {
    case rendered
    case source

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rendered: return "Rendered"
        case .source: return "Source"
        }
    }
}

private var toolbarDismissPlacement: ToolbarItemPlacement {
#if os(macOS)
    .automatic
#else
    .navigationBarTrailing
#endif
}

private var toolbarLeadingPlacement: ToolbarItemPlacement {
#if os(macOS)
    .automatic
#else
    .navigationBarLeading
#endif
}

private struct InlineNavigationTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(macOS)
        content
#else
        content.navigationBarTitleDisplayMode(.inline)
#endif
    }
}

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if canImport(WebKit) && canImport(UIKit)
private struct HTMLPreviewView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        WKWebView(frame: .zero)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
#elseif canImport(WebKit) && canImport(AppKit)
private struct HTMLPreviewView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        WKWebView(frame: .zero)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}
#endif
#endif
