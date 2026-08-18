import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject private var authSession: FirebaseAuthSession
    @State private var showDeleteAccountAlert = false
    @State private var showLogOutConfirmation = false

    var body: some View {
        ScreenScaffold(
            title: "Account",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            SettingsPanel(
                title: "Signed-in account",
                subtitle: "Your login identity and cloud-sync status.",
                systemImage: "person.crop.circle",
                tint: AppTheme.Colors.success
            ) {
                if let user = currentAuthUser {
                    MetricRow(label: "Provider", value: user.providerLabel, valueColor: AppTheme.Colors.success)
                    if let email = user.email {
                        MetricRow(label: "Email", value: email)
                    }
                    if let phoneNumber = user.phoneNumber {
                        MetricRow(label: "Phone", value: phoneNumber)
                    }
                    MetricRow(label: "Cloud sync", value: authSession.cloudStatus)
                } else {
                    MetricRow(label: "Status", value: "Signed out", valueColor: AppTheme.Colors.warning)
                }
            }

            if currentAuthUser != nil {
                SettingsPanel(
                    title: "Account actions",
                    subtitle: "Sign out or permanently delete your login.",
                    systemImage: "exclamationmark.shield",
                    tint: AppTheme.Colors.danger,
                    isDestructive: true
                ) {
                    VStack(spacing: 0) {
                        Button(role: .destructive) {
                            showLogOutConfirmation = true
                        } label: {
                            CompactMenuRow(
                                title: ProfileMenuPresentationPolicy.logOutActionTitle,
                                systemImage: "rectangle.portrait.and.arrow.right",
                                isDestructive: true,
                                showsDisclosure: false
                            )
                        }

                        AppDivider()

                        Button(role: .destructive) {
                            showDeleteAccountAlert = true
                        } label: {
                            CompactMenuRow(
                                title: "Delete Account",
                                systemImage: "person.crop.circle.badge.minus",
                                isDestructive: true,
                                showsDisclosure: false
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTopDividerHidden()
        .alert("Delete account?", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await authSession.deleteAccount()
                }
            }
        } message: {
            Text("This deletes your account through the backend account endpoint. Local data on this iPhone is not reset by this action.")
        }
        .alert("Log out?", isPresented: $showLogOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button(ProfileMenuPresentationPolicy.logOutActionTitle, role: .destructive) {
                Task {
                    await authSession.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to log out of this account?")
        }
        .accessibilityIdentifier("account-settings-screen")
    }

    private var currentAuthUser: AuthUser? {
        switch authSession.state {
        case .emailVerificationRequired(let user),
             .syncing(let user, _),
             .ready(let user):
            user
        case .loading, .signedOut, .failed:
            nil
        }
    }
}
