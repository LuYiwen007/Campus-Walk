import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var lastError: String?
    @Published var user: UserDTO?

    private let api = APIClient.shared

    init() {
        isLoggedIn = api.authToken != nil
    }

    func restoreSession() async {
        guard api.authToken != nil else {
            isLoggedIn = false
            return
        }
        do {
            user = try await api.me()
            isLoggedIn = true
            lastError = nil
        } catch {
            api.clearToken()
            isLoggedIn = false
            lastError = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        lastError = nil
        do {
            let res = try await api.login(email: email, password: password)
            api.authToken = res.accessToken
            user = res.user
            isLoggedIn = true
        } catch {
            lastError = error.localizedDescription
            isLoggedIn = false
        }
    }

    func logout() {
        api.clearToken()
        user = nil
        isLoggedIn = false
    }
}
