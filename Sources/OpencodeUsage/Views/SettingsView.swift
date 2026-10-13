import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Binding var isPresented: Bool
    let isFirstSetup: Bool

    @State private var apiKey: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var progressAccent: Bool = AppSettings.progressAccent
    @State private var showCredits: Bool = AppSettings.showCredits
    @FocusState private var isTextFieldFocused: Bool

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

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Show available credits")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $showCredits)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: showCredits) { _, newValue in
                            AppSettings.setShowCredits(newValue)
                        }
                }
                Text("Awaiting upstream API support")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            isTextFieldFocused = true
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
