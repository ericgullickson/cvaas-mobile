import SwiftUI

struct LocateView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var searchTerm: String = ""
    @State private var state: LoadState = .idle
    @State private var recents: [String] = []
    @State private var searchTask: Task<Void, Never>?

    private let recentsStore = RecentSearchesStore()

    enum LoadState {
        case idle
        case loading
        case success(LocateResults)
        case empty
        case failure(CVError)
    }

    var body: some View {
        NavigationStack {
            Group {
                if auth.isConfigured {
                    content
                } else {
                    ConfigureCTA(featureName: "Endpoint Locator")
                }
            }
            .navigationTitle("Locate")
        }
        .onAppear { recents = recentsStore.load() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchBar
            stateView
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("MAC, IP, or hostname", text: $searchTerm)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.search)
                .onSubmit { search() }
            if !searchTerm.isEmpty {
                Button {
                    searchTerm = ""
                    state = .idle
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - State views

    @ViewBuilder
    private var stateView: some View {
        switch state {
        case .idle:
            idleView
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .success(let results):
            List {
                ForEach(results.devices) { device in
                    LocateResultRow(device: device)
                }
            }
            .listStyle(.insetGrouped)
        case .empty:
            ContentUnavailableView(
                "No matches",
                systemImage: "questionmark.circle",
                description: Text("No endpoints found for \"\(searchTerm)\".")
            )
        case .failure(let err):
            errorView(err)
        }
    }

    @ViewBuilder
    private var idleView: some View {
        if recents.isEmpty {
            ContentUnavailableView(
                "Find an endpoint",
                systemImage: "magnifyingglass",
                description: Text("Enter a MAC, IP, or hostname above.")
            )
        } else {
            List {
                Section {
                    ForEach(recents, id: \.self) { term in
                        Button {
                            searchTerm = term
                            search()
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text(term).font(.body.monospaced())
                                Spacer()
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        Button("Clear") {
                            recents = []
                            recentsStore.clear()
                        }
                        .font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func errorView(_ err: CVError) -> some View {
        ContentUnavailableView {
            Label(errorTitle(err), systemImage: errorIcon(err))
        } description: {
            Text(err.localizedDescription)
        } actions: {
            Button("Try again") { search() }
        }
    }

    private func errorTitle(_ err: CVError) -> String {
        switch err {
        case .auth: return "Authentication failed"
        case .notFound: return "Not found"
        case .rateLimited: return "Rate limited"
        case .service: return "Service error"
        case .network: return "Network error"
        case .decoding: return "Couldn't read response"
        case .invalidURL: return "Bad tenant URL"
        case .notConfigured: return "Not configured"
        }
    }

    private func errorIcon(_ err: CVError) -> String {
        switch err {
        case .auth: return "lock.slash"
        case .notFound: return "questionmark.circle"
        case .rateLimited: return "hourglass"
        case .network: return "wifi.slash"
        case .decoding, .service: return "exclamationmark.triangle"
        case .invalidURL, .notConfigured: return "gearshape"
        }
    }

    // MARK: - Search

    private func search() {
        let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { state = .idle; return }
        guard let url = URL(string: auth.tenantURL) else {
            state = .failure(.invalidURL)
            return
        }

        searchTask?.cancel()
        state = .loading
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        let service = EndpointLocationService(client: client)

        searchTask = Task { @MainActor in
            do {
                let resp = try await service.find(searchTerm: trimmed)
                if Task.isCancelled { return }
                let results = LocateResults(from: resp)
                state = results.devices.isEmpty ? .empty : .success(results)
                addRecent(trimmed)
            } catch let err as CVError {
                if Task.isCancelled { return }
                state = .failure(err)
            } catch {
                if Task.isCancelled { return }
                state = .failure(.network(URLError(.unknown)))
            }
        }
    }

    private func addRecent(_ term: String) {
        var updated = recents
        updated.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        updated.insert(term, at: 0)
        if updated.count > RecentSearchesStore.maxItems {
            updated = Array(updated.prefix(RecentSearchesStore.maxItems))
        }
        recents = updated
        recentsStore.save(updated)
    }
}
