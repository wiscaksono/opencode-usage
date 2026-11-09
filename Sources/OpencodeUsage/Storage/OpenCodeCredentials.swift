import Foundation
import SQLite3

/// Reads the OpenCode Console OAuth token from the local OpenCode SQLite
/// database. The token is only used for the usage request; it is never logged.
enum OpenCodeCredentials {
    private static let query = """
    select value from credential where integration_id = 'opencode' limit 1
    """

    /// Path to `opencode.db`, overridable with `OPENCODE_DB`.
    static var databaseURL: URL {
        if let path = ProcessInfo.processInfo.environment["OPENCODE_DB"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/opencode/opencode.db")
    }

    /// Returns the OAuth access token, or `nil` when OpenCode is not signed in.
    static func accessToken() -> String? {
        guard let raw = credentialValue() else { return nil }
        return accessToken(fromCredentialJSON: raw)
    }

    /// Extracts `access` from the credential JSON. Internal for tests.
    static func accessToken(fromCredentialJSON raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let credential = try? JSONDecoder().decode(Credential.self, from: data),
              let token = credential.access,
              !token.isEmpty
        else {
            return nil
        }
        return token
    }

    private struct Credential: Decodable {
        let access: String?
    }

    private static func credentialValue() -> String? {
        let path = databaseURL.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database
        else {
            sqlite3_close(database)
            return nil
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            sqlite3_finalize(statement)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0)
        else {
            return nil
        }
        return String(cString: text)
    }
}
