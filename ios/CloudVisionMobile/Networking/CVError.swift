import Foundation

enum CVError: Error, LocalizedError {
    case auth
    case notFound
    case rateLimited(retryAfterSeconds: Int?)
    case service(statusCode: Int, message: String?)
    case network(URLError)
    case decoding(Error)
    case invalidURL
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .auth:
            return "Authentication failed. Check the tenant URL and service-account JWT in Settings."
        case .notFound:
            return "Not found."
        case .rateLimited(let retry):
            if let s = retry { return "Rate limited. Retry in \(s)s." }
            return "Rate limited. Try again shortly."
        case .service(let code, let msg):
            return "Service error (\(code))\(msg.map { ": \($0)" } ?? "")."
        case .network(let urlErr):
            return "Network error: \(urlErr.localizedDescription)"
        case .decoding:
            return "Could not parse response."
        case .invalidURL:
            return "Tenant URL is not valid."
        case .notConfigured:
            return "Configure the tenant and JWT in Settings."
        }
    }
}
