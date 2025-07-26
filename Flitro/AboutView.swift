import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Flitro Logo
            Image("AboutAppLogo")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)

            Text("Flitro")
                .font(.largeTitle)
                .bold()

            Text("A context manager for your Mac.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Website Link
            Link("Website", destination: URL(string: "https://flitro.fredericlavigne.com")!)
                .font(.title3)

            // GitHub Link
            Link("GitHub Repository", destination: URL(string: "https://github.com/l2fprod/flitro")!)
                .font(.title3)

            Divider()

            // AI Badge Logo
            VStack(spacing: 8) {
                Text("Powered by AI")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image("AboutMadeWithAI")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
            }
        }
        .padding(32)
        .frame(width: 340)
    }
}
