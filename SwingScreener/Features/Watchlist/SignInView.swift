import SwiftUI

/// Email sign-in: enter your email, then tap the "Log In" link in the email on this iPhone.
/// If the email carries a one-time code instead, it can be typed here.
struct SignInView: View {
    @Environment(AuthStore.self) private var auth
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(codeSent)
                if codeSent {
                    TextField("Code (only if your email shows one)", text: $code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                }
            } header: {
                Text("Sign in to keep a watchlist")
            } footer: {
                Text(codeSent ? "We emailed a sign-in link to \(email). Open the email on this iPhone and tap Log In. It expires in about an hour." : "We'll email you a sign-in link. No password needed.")
            }

            if let message = error ?? auth.linkError {
                Section { Text(message).foregroundStyle(.red) }
            }

            Section {
                Button(action: { Task { await submit() } }) {
                    HStack {
                        Text(codeSent ? "Sign in with code" : "Email me a sign-in link")
                        if working { Spacer(); ProgressView() }
                    }
                }
                .disabled(working || !canSubmit)
                if codeSent {
                    Button("Send another link") { Task { await resend() } }
                        .disabled(working)
                    Button("Use a different email") { codeSent = false; code = ""; error = nil }
                        .disabled(working)
                }
            }
        }
    }

    private var canSubmit: Bool {
        codeSent ? code.filter(\.isNumber).count >= 6 : email.contains("@") && email.contains(".")
    }

    private func resend() async {
        working = true
        error = nil
        defer { working = false }
        do { try await auth.sendCode(to: email) }
        catch { self.error = APIError(error).localizedDescription }
    }

    private func submit() async {
        working = true
        error = nil
        defer { working = false }
        do {
            if codeSent {
                try await auth.verify(email: email, code: code)
            } else {
                try await auth.sendCode(to: email)
                codeSent = true
            }
        } catch {
            self.error = APIError(error).localizedDescription
        }
    }
}
