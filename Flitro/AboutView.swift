import SwiftUI

struct AboutView: View {
    @State private var logoGlow: Bool = false
    @State private var shimmerPhase: CGFloat = 0.0
    var body: some View {
        ZStack {
            // Logo-matching gradient background with sparkles
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.91, green: 0.36, blue: 0.48), // #E85D7A pink
                Color(red: 0.95, green: 0.73, blue: 0.29), // #F2B94B orange
                Color(red: 0.49, green: 0.85, blue: 0.34), // #7ED957 green
                Color(red: 0.23, green: 0.49, blue: 0.87)  // #3A7DDF blue
            ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .overlay(
                    ForEach(0..<18) { i in
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: CGFloat.random(in: 8...18), height: CGFloat.random(in: 8...18))
                            .position(x: CGFloat.random(in: 0...360), y: CGFloat.random(in: 0...520))
                            .blur(radius: 1.5)
                    }
                )
            VStack(spacing: 40) {
                // Logo with glow
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 130, height: 130)
                        .blur(radius: 0.5)
                    Image("AboutAppLogo")
                        .resizable()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .shadow(color: Color.purple.opacity(logoGlow ? 0.7 : 0.3), radius: logoGlow ? 18 : 8)
                        .scaleEffect(logoGlow ? 1.08 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                logoGlow.toggle()
                            }
                        }
                }
                Text("Flitro")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.white.opacity(0.35), radius: 6, x: 0, y: 2)
                Text("Fast‑track Your Flow.")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                // Links as pill buttons
                HStack(spacing: 18) {
                    Link(destination: URL(string: "https://flitro.fredericlavigne.com")!) {
                        Label("Website", systemImage: "globe")
                            .font(.title3.bold())
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.pink]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.purple.opacity(0.18), radius: 4, x: 0, y: 2)
                    }
                    Link(destination: URL(string: "https://github.com/l2fprod/flitro")!) {
                        Label("GitHub", systemImage: "chevron.left.slash.chevron.right")
                            .font(.title3.bold())
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(LinearGradient(gradient: Gradient(colors: [Color.pink, Color.purple]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.pink.opacity(0.18), radius: 4, x: 0, y: 2)
                    }
                }
                // AI Badge Card with shimmer (no card)
                Image("AboutMadeWithAI")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.pink.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.top, 8)
                // App version and copyright
                VStack(spacing: 4) {
                    Text("Version " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"))
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                    Text(Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 12)
            }
        }
    }
}
