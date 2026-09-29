import SwiftUI

/// Email one-time-code sign-in: enter email, get a code, type it in.
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
                    TextField("Code from the email", text: $code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                }
            } header: {
                Text("Sign in to keep a watchlist")
            } footer: {
                Text(codeSent ? "We emailed a code to \(email). It expires in about an hour." : "We'll email you a one-time code. No password needed.")
            }

            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }

            Section {
                Button(action: { Task { await submit() } }) {
                    HStack {
                        Text(codeSent ? "Sign in" : "Email me a code")
                        if working { Spacer(); ProgressView() }
                    }
                }
                .disabled(working || !canSubmit)
                if codeSent {
                    Button("Use a different email") { codeSent = false; code = ""; error = nil }
                        .disabled(working)
                }
            }
        }
    }

    private var canSubmit: Bool {
        codeSent ? code.filter(\.isNumber).count >= 6 : email.contains("@") && email.contains(".")
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
