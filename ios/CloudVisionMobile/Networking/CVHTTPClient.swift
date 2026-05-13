import Foundation

/// Thin wrapper around URLSession that injects the service-account JWT and maps
/// HTTP statuses to `CVError`. All CVaaS REST resource calls go through here.
struct CVHTTPClient {
    let tenantURL: URL
    let jwt: String
    let session: URLSession

    init(tenantURL: URL, jwt: String, session: URLSession = .shared) {
        self.tenantURL = tenantURL
        self.jwt = jwt
        self.session = session
    }

    // MARK: - Single-result GET (used by F1 endpoint locator and single-device fetch)

    /// GET <tenant><path>?<query>, decode the JSON response as `T`.
    func get<T: Decodable>(path: String, query: [String: String] = [:]) async throws -> T {
        let request = try makeRequest(method: "GET", path: path, query: query, body: nil)
        let data = try await execute(request)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw CVError.decoding(error)
        }
    }

    // MARK: - POST with JSON body (used by F4 ChangeControlConfig + ApproveConfig Set)

    /// POST a JSON-encodable body to `<tenant><path>`, decode the response as `T`.
    func post<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        let encoder = JSONEncoder()
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            throw CVError.decoding(error)
        }
        let request = try makeRequest(method: "POST", path: path, query: [:], body: bodyData)
        let data = try await execute(request)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw CVError.decoding(error)
        }
    }

    // MARK: - NDJSON GET (used by `/all` resource endpoints — inventory, events)

    /// GET an `/all` endpoint that streams newline-delimited JSON rows, each wrapped
    /// in `{"result":{"value":<T>,"time":"...","type":"..."}}`. Returns the unwrapped values.
    func getAll<T: Decodable>(path: String, query: [String: String] = [:]) async throws -> [T] {
        let request = try makeRequest(method: "GET", path: path, query: query, body: nil)
        let data = try await execute(request)
        return decodeNDJSON(data: data)
    }

    // MARK: - Private helpers

    private func makeRequest(
        method: String,
        path: String,
        query: [String: String],
        body: Data?
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = tenantURL.scheme
        components.host = tenantURL.host
        components.port = tenantURL.port
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw CVError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw CVError.network(urlError)
        } catch {
            throw CVError.network(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw CVError.service(statusCode: -1, message: "No HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw CVError.auth
        case 404:
            throw CVError.notFound
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw CVError.rateLimited(retryAfterSeconds: retry)
        default:
            let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(200)) }
            throw CVError.service(statusCode: http.statusCode, message: snippet)
        }
    }

    /// Parse newline-delimited JSON. Bad/empty lines are skipped silently (the CVaaS stream
    /// occasionally includes blank lines between rows; we don't want one to fail the whole batch).
    private func decodeNDJSON<T: Decodable>(data: Data) -> [T] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var results: [T] = []
        text.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { return }
            if let envelope = try? Self.decoder.decode(StreamRowEnvelope<T>.self, from: lineData) {
                results.append(envelope.result.value)
            }
        }
        return results
    }

    private static let decoder = JSONDecoder()
}
