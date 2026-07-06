import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class LoginModel {
  static let shared = LoginModel()

  enum Phase: Equatable {
    case idle
    case awaitingCode
    case exchanging
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  private(set) var isLoggedIn: Bool
  private(set) var accountPlan: String?
  var pastedCode: String = ""

  private let oauthService = OAuthService()
  private var challenge: OAuthChallenge?

  init() {
    let tokens = TokenStore.load()
    isLoggedIn = tokens != nil
    accountPlan = tokens?.subscriptionType
  }

  func startLogin() {
    let challenge = oauthService.makeChallenge()
    self.challenge = challenge
    pastedCode = ""
    phase = .awaitingCode
    NSWorkspace.shared.open(challenge.authorizeURL)
  }

  func submitCode() async {
    guard let challenge,
      !pastedCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }

    phase = .exchanging
    do {
      let tokens = try await oauthService.exchange(pastedCode: pastedCode, challenge: challenge)
      TokenStore.save(tokens)
      isLoggedIn = true
      accountPlan = tokens.subscriptionType
      pastedCode = ""
      self.challenge = nil
      phase = .idle
      await UsageModel.shared.refresh(force: true)
    } catch {
      phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }
  }

  func cancel() {
    phase = .idle
    pastedCode = ""
    challenge = nil
  }

  func logout() {
    TokenStore.clear()
    isLoggedIn = false
    accountPlan = nil
    phase = .idle
    Task { await UsageModel.shared.refresh(force: true) }
  }
}
