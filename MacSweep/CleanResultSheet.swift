import SwiftUI

struct CleanResultSheet: View {
    @ObservedObject var cleanEngine: CleanEngine
    @ObservedObject var scanEngine:  ScanEngine
    @Binding var isPresented: Bool
    @State private var animateCheck = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateCheck ? 1 : 0.5)
                    .opacity(animateCheck ? 1 : 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.success, Color(hex: "11998E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateCheck ? 1 : 0.3)
                    .opacity(animateCheck ? 1 : 0)
            }
            .animation(.spring(duration: 0.6), value: animateCheck)

            Text("Cleaning Complete!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .opacity(animateCheck ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.3), value: animateCheck)

            // Cleaned size
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Cleaned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: cleanEngine.cleanedSize, countStyle: .file))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.gradient)
                }

                if let disk = scanEngine.diskInfo {
                    VStack(spacing: 4) {
                        Text("Free Space")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(disk.freeFormatted)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
            }
            .opacity(animateCheck ? 1 : 0)
            .animation(.easeIn(duration: 0.4).delay(0.5), value: animateCheck)

            // Errors if any
            if !cleanEngine.errors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Some items could not be cleaned:")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    ForEach(cleanEngine.errors, id: \.self) { error in
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
                .frame(maxWidth: 400)
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.gradient)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
        .frame(width: 480, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateCheck = true
            }
        }
    }
}
