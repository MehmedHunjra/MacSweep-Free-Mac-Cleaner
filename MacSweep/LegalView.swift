import SwiftUI

// MARK: - Legal Popup Sheets (Privacy Policy & Terms of Service)

/// Shows a Privacy Policy or Terms of Service sheet when the user taps the
/// corresponding link in Settings → About. The content clearly states that
/// MacSweep is a file-cleaning utility and the user bears full responsibility
/// for any files they choose to remove.

struct LegalSheet: View {
    enum LegalType: String {
        case privacy = "Privacy Policy"
        case terms   = "Terms of Service"
    }

    let type: LegalType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: type == .privacy ? "hand.raised.fill" : "doc.text.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(type == .privacy ? Color(hex: "667EEA") : Color(hex: "11998E"))
                Text(type.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            // Content
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    switch type {
                    case .privacy:
                        privacyPolicyContent
                    case .terms:
                        termsOfServiceContent
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Text("Last updated: March 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("I Understand") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 640, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Privacy Policy

    @ViewBuilder
    private var privacyPolicyContent: some View {
        legalHeading("Your Privacy Matters")

        legalParagraph("""
        MacSweep is a free, open-source macOS cleaning utility developed by Mehmed Hunjra. \
        We are committed to protecting your privacy. This Privacy Policy explains how MacSweep \
        handles your data.
        """)

        legalSection("1. Data Collection", """
        MacSweep does NOT collect, transmit, or store any personal data. \
        All operations — scanning, cleaning, and maintenance — are performed \
        entirely on your local machine. No data is ever sent to external servers, cloud services, \
        or third parties.
        """)

        legalSection("2. No Telemetry or Tracking", """
        MacSweep contains NO analytics, telemetry, crash reporting, or tracking of any kind. \
        We do not use cookies, identifiers, or any mechanism to monitor your usage. \
        Your system data stays on your Mac — period.
        """)

        legalSection("3. Local Data Access", """
        MacSweep accesses files and directories on your Mac solely to perform the cleaning \
        and maintenance operations you request. This includes scanning for caches, logs, \
        temporary files, browser data, application leftovers, and large files. \
        No file contents are read, analyzed, or transmitted — only metadata \
        (file names, paths, sizes) is displayed in the user interface so you can make informed decisions.
        """)

        legalSection("4. No Account Required", """
        MacSweep does not require registration, login, or any account. \
        There are no user accounts, no cloud storage, and no online features \
        that could expose your data.
        """)

        legalSection("5. Third-Party Services", """
        MacSweep does not integrate with any third-party services, APIs, or SDKs \
        that collect user data. The application operates entirely offline.
        """)

        legalSection("6. Open Source Transparency", """
        MacSweep is open source. You can inspect the entire source code to verify \
        that no data collection occurs. The source code is available on GitHub.
        """)

        legalSection("7. Children's Privacy", """
        MacSweep does not collect any personal information from anyone, including children. \
        The application is safe for all ages.
        """)

        legalSection("8. Changes to This Policy", """
        We may update this Privacy Policy from time to time. Any changes will be included \
        in future releases of the application. Your continued use of MacSweep after changes \
        constitutes acceptance of the updated policy.
        """)

        legalSection("9. Contact", """
        If you have any questions about this Privacy Policy, you can reach out via \
        GitHub or the social links in the About section.
        """)
    }

    // MARK: - Terms of Service

    @ViewBuilder
    private var termsOfServiceContent: some View {
        legalHeading("Terms of Service")

        legalParagraph("""
        By downloading, installing, or using MacSweep, you agree to the following terms.
        """)

        legalSection("1. Acceptance of Terms", """
        By using MacSweep, you acknowledge that you have read, understood, and agree \
        to be bound by these Terms of Service. If you do not agree, do not use the application.
        """)

        legalSection("2. Description of Service", """
        MacSweep is a macOS system cleaning and maintenance utility. It provides tools to scan, \
        review, and remove files such as system caches, logs, temporary files, browser data, \
        application leftovers, and large files. It also includes maintenance features like \
        flushing DNS cache, freeing RAM, and running system scripts.
        """)

        legalSection("3. User Responsibility — IMPORTANT", """
        MacSweep is a tool that performs file deletion at YOUR direction. \
        You are solely and entirely responsible for any files you choose to remove.

        • Before cleaning, MacSweep shows you a complete list of files that will be affected.
        • You can review each file, its path, and its size before taking any action.
        • You can select or deselect individual files, or use Select All / Select None.
        • A confirmation dialog is always shown before any destructive action.
        • MacSweep will NEVER delete files without your explicit confirmation.

        THE DEVELOPERS, CONTRIBUTORS, AND MAINTAINERS OF MACSWEEP ARE NOT RESPONSIBLE \
        FOR ANY DATA LOSS, FILE DELETION, OR SYSTEM ISSUES RESULTING FROM YOUR USE \
        OF THIS APPLICATION. All cleaning actions are initiated by you, the user, \
        and are performed at your own risk.
        """)

        legalSection("4. No Warranty", """
        MacSweep is provided "AS IS" without warranty of any kind, express or implied, \
        including but not limited to the warranties of merchantability, fitness for a \
        particular purpose, and non-infringement. The entire risk as to the quality \
        and performance of the application is with you.
        """)

        legalSection("5. Limitation of Liability", """
        In no event shall the developers, contributors, or maintainers of MacSweep \
        be liable for any direct, indirect, incidental, special, exemplary, or consequential \
        damages (including but not limited to loss of data, system downtime, or loss of profits) \
        arising out of the use or inability to use the application, even if advised of the \
        possibility of such damages.
        """)

        legalSection("6. File Deletion Disclaimer", """
        When you use MacSweep to clean or remove files:
        
        • Files are permanently deleted — they may NOT be recoverable.
        • MacSweep does not move files to Trash — selected items are removed directly.
        • You should always review the file list carefully before confirming deletion.
        • If you are unsure about a file, deselect it or use "Reveal in Finder" to inspect it.
        • We recommend maintaining regular backups of your important data using Time Machine \
        or another backup solution.
        """)

        legalSection("7. Intellectual Property", """
        MacSweep is open-source software. The source code is available under the terms \
        of its license on GitHub. You may not use the MacSweep name, logo, or branding \
        to endorse or promote products derived from this software without prior written permission.
        """)

        legalSection("8. Modifications", """
        We reserve the right to modify these Terms of Service at any time. \
        Changes will be included in future releases. Continued use of MacSweep \
        after changes constitutes acceptance of the modified terms.
        """)

        legalSection("9. Governing Law", """
        These terms shall be governed by and construed in accordance with applicable laws. \
        Any disputes arising from these terms shall be resolved through appropriate legal channels.
        """)
    }

    // MARK: - Formatting Helpers

    private func legalHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
    }

    private func legalParagraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .lineSpacing(4)
    }

    private func legalSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            Text(body)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}
