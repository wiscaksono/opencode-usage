import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Binding var isPresented: Bool
    let isFirstSetup: Bool

    @State private var apiKey: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var progressAccent: Bool = AppSettings.progressAccent
    @State private var showPercentages: Bool = AppSettings.menuBarStyle == .badges
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginReady: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    /// Shown when macOS parks the launch-at-login registration until the
    /// user allows the app in System Settings.
    private static let launchApprovalHint =
        "macOS is waiting for you to allow OpenCode Usage in System Settings > General > Login Items."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            formView
            if let error = errorMessage {
                errorView(error)
            }
            Divider()
            buttonRow
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your OpenCode API key:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("sk-...", text: $apiKey)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .onChange(of: apiKey) { _, _ in
                    errorMessage = nil
                }

            Divider().padding(.vertical, 2)

            HStack {
                Text("Accent-tinted progress bar")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $progressAccent)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: progressAccent) { _, newValue in
                        AppSettings.setProgressAccent(newValue)
                    }
            }

            HStack {
                Text("Show percentages in menu bar")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $showPercentages)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: showPercentages) { _, newValue in
                        AppSettings.setMenuBarStyle(newValue ? .badges : .logo)
                    }
            }

            HStack {
                Text("Launch at login")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) { oldValue, newValue in
                        // Skip the initial sync from onAppear and any
                        // no-op change where the toggle already matches
                        // the system state.
                        guard launchAtLoginReady,
                              newValue != LaunchAtLogin.isEnabled
                        else { return }
                        do {
                            try LaunchAtLogin.setEnabled(newValue)
                            errorMessage = LaunchAtLogin.needsApproval ? Self.launchApprovalHint : nil
                        } catch {
                            launchAtLogin = oldValue
                            errorMessage = "Could not update launch-at-login: \(error.localizedDescription)"
                        }
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            isTextFieldFocused = true
            launchAtLogin = LaunchAtLogin.isEnabled
            launchAtLoginReady = true
            if LaunchAtLogin.needsApproval {
                errorMessage = Self.launchApprovalHint
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: 8) {
            Button {
                save()
            } label: {
                HStack(spacing: 4) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                    }
                    Text("Save")
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

            if !isFirstSetup {
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func save() {
        isSaving = true
        errorMessage = nil

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            isSaving = false
            errorMessage = "API key is empty"
            return
        }

        do {
            try AppSettings.setAPIKey(key)
        } catch {
            isSaving = false
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
            return
        }
        isSaving = false
        isPresented = false
        viewModel.credentialsUpdated()
    }
}
