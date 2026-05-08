import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = "demo@campuswalk.local"
    @State private var password = "CampusWalk2026!"
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Campus Walk")
                    .font(.largeTitle.bold())
                Text("使用邮箱登录以同步对话与路线")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("邮箱")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("密码")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                }

                if let err = auth.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        isBusy = true
                        await auth.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
                        isBusy = false
                    }
                } label: {
                    if isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("登录")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || email.isEmpty || password.isEmpty)

                Text("测试账号：demo@campuswalk.local / CampusWalk2026!")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
