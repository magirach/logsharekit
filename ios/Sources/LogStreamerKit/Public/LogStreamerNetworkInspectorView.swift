import Foundation

#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Reusable in-app network inspector backed by the entries captured through `LogStreamer.makeInstrumentedSession`.
public struct LogStreamerNetworkInspectorView: View {
    @StateObject private var model = LogStreamerNetworkInspectorViewModel()
    @State private var searchText = ""
    @State private var methodFilter = "All"
    @State private var statusFilter = NetworkStatusFilter.all

    public init() {}

    public var body: some View {
        List {
            filtersSection
            if filteredEntries.isEmpty {
                emptyState
            } else {
                ForEach(filteredEntries) { entry in
                    NavigationLink {
                        LogStreamerNetworkEntryDetailView(entry: entry)
                    } label: {
                        LogStreamerNetworkEntryRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Network Inspector")
        .searchable(text: $searchText, prompt: "Search URL, host, path")
        .toolbar {
            ToolbarItemGroup(placement: toolbarPlacement) {
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                Button("Clear") {
                    Task { await LogStreamer.clearNetworkEntries() }
                }
                .disabled(model.entries.isEmpty)
            }
        }
        .task {
            await model.refresh()
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .automatic
#else
        .navigationBarTrailing
#endif
    }

    private var filteredEntries: [LogStreamerNetworkEntry] {
        model.entries.filter { entry in
            let matchesMethod = methodFilter == "All" || entry.requestMethod == methodFilter
            let matchesStatus = statusFilter.matches(entry)
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch = entry.url.lowercased().contains(query)
                    || entry.host.lowercased().contains(query)
                    || entry.path.lowercased().contains(query)
                    || entry.statusSummary.lowercased().contains(query)
            }
            return matchesMethod && matchesStatus && matchesSearch
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
}

@MainActor
private final class LogStreamerNetworkInspectorViewModel: ObservableObject {
    @Published var entries: [LogStreamerNetworkEntry] = []
    private var refreshTask: Task<Void, Never>?

    var methods: [String] {
        Array(Set(entries.map(\.requestMethod))).sorted()
    }

    init() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    func refresh() async {
        entries = await LogStreamer.networkEntries()
    }
}

private struct LogStreamerNetworkEntryRow: View {
    let entry: LogStreamerNetworkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.requestMethod)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
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
            Text(entry.host)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(entry.path)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
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
    let entry: LogStreamerNetworkEntry
    @State private var copiedText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summarySection
                textSection(title: "cURL", value: entry.curlCommand, copyLabel: "Copy cURL")
                keyValueSection(title: "Request Headers", values: entry.requestHeaders)
                textSection(title: "Request Body", value: entry.requestBody, copyLabel: "Copy Request Body")
                keyValueSection(title: "Response Headers", values: entry.responseHeaders)
                textSection(title: "Response Body", value: entry.responseBody, copyLabel: "Copy Response Body")
                if let errorDescription = entry.errorDescription, !errorDescription.isEmpty {
                    textSection(title: "Error", value: errorDescription, copyLabel: nil)
                }
            }
            .padding(20)
        }
        .navigationTitle(entry.requestMethod)
        .modifier(InlineNavigationTitleModifier())
        .alert("Copied", isPresented: copiedAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(copiedText ?? "")
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            inspectorRow(label: "URL", value: entry.url)
            inspectorRow(label: "Status", value: entry.statusSummary)
            inspectorRow(label: "Duration", value: "\(entry.durationMs) ms")
            inspectorRow(label: "Started", value: entry.startedAt)
            inspectorRow(label: "Finished", value: entry.finishedAt)
        }
    }

    private func keyValueSection(title: String, values: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
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

    private func textSection(title: String, value: String?, copyLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let copyLabel, let value, !value.isEmpty {
                    Button(copyLabel) {
                        copyToPasteboard(value)
                        copiedText = copyLabel
                    }
                    .font(.caption)
                }
            }
            Text(displayValue(value))
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private var copiedAlertBinding: Binding<Bool> {
        Binding(
            get: { copiedText != nil },
            set: { newValue in
                if !newValue {
                    copiedText = nil
                }
            }
        )
    }

    private func copyToPasteboard(_ value: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = value
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
#endif
    }

    private func displayValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "None" }
        return value
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

    func matches(_ entry: LogStreamerNetworkEntry) -> Bool {
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

private struct InlineNavigationTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(macOS)
        content
#else
        content.navigationBarTitleDisplayMode(.inline)
#endif
    }
}
#endif
