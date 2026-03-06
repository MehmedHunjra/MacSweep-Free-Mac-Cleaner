import SwiftUI
import AppKit
import ApplicationServices

// MARK: - First-Launch Onboarding View

/// A beautiful multi-step onboarding screen shown only on first launch.
/// Guides users through welcome, permissions, and legal acceptance.
/// Saved via @AppStorage so it only appears once.

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var acceptedPrivacy = false
    @State private var acceptedTerms = false
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    @State private var animateIn = false

    private let totalPages = 3

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated floating orbs
            floatingOrbs

            VStack(spacing: 0) {
                // Page content (scrollable so bottom bar never gets clipped)
                Group {
                    switch currentPage {
                    case 0: welcomePage
                    case 1: permissionsPage
                    case 2: legalPage
                    default: welcomePage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom bar with dots + button — always visible
                bottomBar
            }
        }
        .frame(minWidth: 700, minHeight: 520)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateIn = true
            }
        }
    }

    // MARK: - Background colors per page

    private var backgroundColors: [Color] {
        switch currentPage {
        case 0: return [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")]
        case 1: return [Color(hex: "1A0740"), Color(hex: "200952"), Color(hex: "2A0D60")]
        case 2: return [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "21262D")]
        default: return [Color(hex: "0F0C29"), Color(hex: "302B63")]
        }
    }

    // MARK: - Floating Orbs

    private var floatingOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "667EEA").opacity(0.08))
                .frame(width: 300, height: 300)
                .offset(x: -150, y: -100)
                .blur(radius: 60)

            Circle()
                .fill(Color(hex: "764BA2").opacity(0.06))
                .frame(width: 250, height: 250)
                .offset(x: 200, y: 150)
                .blur(radius: 50)
        }
        .opacity(animateIn ? 1 : 0)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                // App icon
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: Color(hex: "667EEA").opacity(0.4), radius: 16, y: 6)
                    .scaleEffect(animateIn ? 1 : 0.5)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(duration: 0.6, bounce: 0.3), value: animateIn)

                Text("Welcome to MacSweep")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: animateIn)

                Text("Your all-in-one Mac cleaner and optimizer.\nKeep your Mac fast, clean, and clutter-free.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: animateIn)

                // Feature highlights
                VStack(spacing: 8) {
                    featureRow(icon: "xmark.bin.fill", title: "Deep Clean", desc: "Remove system junk, caches, and logs", color: Color(hex: "FC5C7D"))
                    featureRow(icon: "chart.pie.fill", title: "Space Lens", desc: "Visualize what's taking up disk space", color: Color(hex: "4776E6"))
                    featureRow(icon: "shield.lefthalf.filled", title: "Privacy Protection", desc: "Clear browser data and digital footprints", color: Color(hex: "11998E"))
                    featureRow(icon: "bolt.fill", title: "Performance", desc: "Speed up your Mac with maintenance tools", color: Color(hex: "F5A623"))
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateIn)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func featureRow(icon: String, title: String, desc: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Page 2: Permissions

    private var permissionsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "11998E"), Color(hex: "38EF7D")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color(hex: "11998E").opacity(0.4), radius: 16, y: 6)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("Permissions Setup")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("MacSweep needs a few permissions to clean\nyour system effectively. Grant them below.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                VStack(spacing: 8) {
                    permissionCard(
                        icon: "internaldrive.fill",
                        title: "Full Disk Access",
                        desc: "Required to scan and clean system caches, logs, and application data across your Mac.",
                        color: Color(hex: "667EEA"),
                        action: {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        }
                    )

                    permissionCard(
                        icon: "hand.point.up.fill",
                        title: "Accessibility",
                        desc: "Optional — used for advanced process management and system monitoring features.",
                        color: Color(hex: "F5A623"),
                        action: {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    )

                    permissionCard(
                        icon: "bell.badge.fill",
                        title: "Notifications",
                        desc: "Optional — get alerts when scans complete or when disk space is low.",
                        color: Color(hex: "FF416C"),
                        action: {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications")!)
                        }
                    )
                }
                .padding(.horizontal, 40)

                Text("You can always change permissions later in\nSystem Settings → Privacy & Security")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func permissionCard(icon: String, title: String, desc: String, color: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer()

            Button("Grant") { action() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(color)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Page 3: Legal Acceptance

    private var legalPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "764BA2"), Color(hex: "667EEA")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color(hex: "764BA2").opacity(0.4), radius: 16, y: 6)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("Privacy & Terms")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Please review and accept our policies\nbefore using MacSweep.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                VStack(spacing: 10) {
                    // Privacy Policy checkbox
                    legalCheckItem(
                        checked: $acceptedPrivacy,
                        title: "Privacy Policy",
                        desc: "No data collection, no telemetry, no tracking — everything stays on your Mac.",
                        icon: "hand.raised.fill",
                        color: Color(hex: "667EEA"),
                        onReadMore: { showPrivacySheet = true }
                    )

                    // Terms of Service checkbox
                    legalCheckItem(
                        checked: $acceptedTerms,
                        title: "Terms of Service",
                        desc: "You are responsible for any files you choose to remove. MacSweep always shows a review list and confirmation before deleting.",
                        icon: "doc.text.fill",
                        color: Color(hex: "11998E"),
                        onReadMore: { showTermsSheet = true }
                    )
                }
                .padding(.horizontal, 40)

                // Important disclaimer
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: "F5A623"))
                        .font(.system(size: 13))
                    Text("MacSweep permanently deletes files at your direction. Always review items before cleaning. We recommend regular backups.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(2)
                }
                .padding(12)
                .background(Color(hex: "F5A623").opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(hex: "F5A623").opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 40)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showPrivacySheet) {
            LegalSheet(type: .privacy)
        }
        .sheet(isPresented: $showTermsSheet) {
            LegalSheet(type: .terms)
        }
    }

    private func legalCheckItem(checked: Binding<Bool>, title: String, desc: String, icon: String, color: Color, onReadMore: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            // Checkbox
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    checked.wrappedValue.toggle()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(checked.wrappedValue ? color : Color.white.opacity(0.1))
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(checked.wrappedValue ? color : Color.white.opacity(0.3), lineWidth: 1.5)
                        )

                    if checked.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Button("Read Full →") { onReadMore() }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                        .buttonStyle(.plain)
                }
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(checked.wrappedValue ? color.opacity(0.06) : Color.white.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(checked.wrappedValue ? color.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Capsule()
                        .fill(currentPage == page ? Color.white : Color.white.opacity(0.25))
                        .frame(width: currentPage == page ? 24 : 8, height: 8)
                        .animation(.spring(duration: 0.3), value: currentPage)
                }
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if currentPage < totalPages - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } else {
                        // Final page — complete onboarding
                        completeOnboarding()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(nextButtonTitle)
                            .font(.system(size: 14, weight: .bold))
                        if currentPage < totalPages - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isGetStartedEnabled
                                    ? LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(currentPage == totalPages - 1 && !isGetStartedEnabled)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.2))
    }

    private var nextButtonTitle: String {
        switch currentPage {
        case 0: return "Continue"
        case 1: return "Next"
        case 2: return "Get Started"
        default: return "Continue"
        }
    }

    private var isGetStartedEnabled: Bool {
        acceptedPrivacy && acceptedTerms
    }

    private func completeOnboarding() {
        guard isGetStartedEnabled else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}
