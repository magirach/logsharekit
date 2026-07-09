import SwiftUI
import LogStreamerKit

struct ContentView: View {
    @StateObject var viewModel: ExampleViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    snapshotSection
                    controlsSection
                    networkInspectorSection
                    uploadsSection
                }
                .padding(20)
            }
            .navigationTitle("SPM Example")
            .task {
                await viewModel.start()
            }
        }
    }

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library State")
                .font(.headline)
            Text("Session: \(viewModel.snapshot.sessionId ?? "-")")
            Text("State: \(viewModel.snapshot.state)")
            Text("Buffered Events: \(viewModel.snapshot.bufferedEvents)")
            Text("Last Error: \(viewModel.snapshot.lastError ?? "-")")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            Button("Simulate Start Push") {
                Task { await viewModel.simulateStartPush() }
            }
            .buttonStyle(.borderedProminent)

            Button("Write App Log") {
                viewModel.writeLog()
            }
            .buttonStyle(.bordered)

            Button("Run Mixed Network Demo") {
                Task { await viewModel.runNetworkRequestDemo() }
            }
            .buttonStyle(.bordered)

            Text("Generates JSON, POST body echo, HTML, text, binary, and error responses.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Simulate Stop Push") {
                Task { await viewModel.simulateStopPush() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var uploadsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mock Backend")
                .font(.headline)
            Text("Consent callbacks: \(viewModel.backendSnapshot.consentShownCount)")
            Text("Cancel callbacks: \(viewModel.backendSnapshot.cancelCount)")
            Text("Uploaded batches: \(viewModel.backendSnapshot.uploadBatchCount)")
            Text("Uploaded events: \(viewModel.backendSnapshot.uploadedEventCount)")
            Text("Last path: \(viewModel.backendSnapshot.lastPath ?? "-")")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var networkInspectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Inspector")
                .font(.headline)
            Text("Captured requests: \(viewModel.networkEntries.count)")
                .foregroundStyle(.secondary)
            NavigationLink("Open Inspector") {
                LogStreamerNetworkInspectorView()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
