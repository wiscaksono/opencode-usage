import Foundation
@testable import OpencodeUsage
import Testing

struct OpenCodeCredentialsTests {
    @Test func extractsAccessToken() {
        let raw = #"{"type":"oauth","access":"token-123","refresh":"refresh"}"#
        #expect(OpenCodeCredentials.accessToken(fromCredentialJSON: raw) == "token-123")
    }

    @Test func rejectsMissingAccessToken() {
        let raw = #"{"type":"oauth","refresh":"refresh"}"#
        #expect(OpenCodeCredentials.accessToken(fromCredentialJSON: raw) == nil)
    }

    @Test func rejectsEmptyAccessToken() {
        let raw = #"{"access":""}"#
        #expect(OpenCodeCredentials.accessToken(fromCredentialJSON: raw) == nil)
    }

    @Test func rejectsInvalidJSON() {
        #expect(OpenCodeCredentials.accessToken(fromCredentialJSON: "not json") == nil)
    }
}
