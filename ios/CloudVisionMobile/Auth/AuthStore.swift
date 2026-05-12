import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published var tenantURL: String
    @Published var jwt: String

    private static let serviceName = "com.gullickson.CloudVisionMobile.auth"
    private static let tenantKey = "tenantURL"
    private static let jwtKey = "jwt"
    private let keychain = KeychainStore(service: AuthStore.serviceName)

    init() {
        let kc = KeychainStore(service: AuthStore.serviceName)
        self.tenantURL = (try? kc.read(key: AuthStore.tenantKey)) ?? ""
        self.jwt = (try? kc.read(key: AuthStore.jwtKey)) ?? ""
    }

    var isConfigured: Bool {
        !jwt.isEmpty && validTenantURL
    }

    var validTenantURL: Bool {
        guard !tenantURL.isEmpty,
              let url = URL(string: tenantURL),
              url.scheme == "https",
              let host = url.host else { return false }
        return host.hasSuffix(".arista.io")
    }

    func save() throws {
        try keychain.write(key: AuthStore.tenantKey, value: tenantURL)
        try keychain.write(key: AuthStore.jwtKey, value: jwt)
    }

    func signOut() throws {
        try keychain.delete(key: AuthStore.tenantKey)
        try keychain.delete(key: AuthStore.jwtKey)
        tenantURL = ""
        jwt = ""
    }
}
