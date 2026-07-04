import SwiftUI

struct PremiumCardView: View {
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width * 0.63

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.06, blue: 0.10),
                                Color(red: 0.18, green: 0.11, blue: 0.38),
                                Color(red: 0.02, green: 0.02, blue: 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .purple.opacity(0.75),
                                .blue.opacity(0.25),
                                .clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 180
                        )
                    )
                    .frame(width: 260, height: 260)
                    .offset(x: width * 0.45, y: -70)
                    .blur(radius: 12)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.35),
                                .white.opacity(0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .opacity(0.55)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.55),
                                .white.opacity(0.12),
                                .white.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                cardContent
                    .padding(24)
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 18)
            .rotation3DEffect(
                .degrees(Double(dragOffset.height / -18)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.7
            )
            .rotation3DEffect(
                .degrees(Double(dragOffset.width / 18)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                            dragOffset = .zero
                        }
                    }
            )
        }
        .aspectRatio(1.586, contentMode: .fit)
        .padding()
    }

    private var cardContent: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("JACK")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text("VISA")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            chipView

            Spacer()

            Text("••••  ••••  ••••  2847")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARD HOLDER")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))

                    Text("JACK")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPIRES")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))

                    Text("09/29")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var chipView: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.78, blue: 0.38),
                        Color(red: 0.58, green: 0.42, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 48, height: 36)
            .overlay {
                VStack(spacing: 6) {
                    Rectangle()
                        .fill(.black.opacity(0.28))
                        .frame(height: 1)

                    Rectangle()
                        .fill(.black.opacity(0.28))
                        .frame(height: 1)
                }
                .padding(.horizontal, 6)
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        PremiumCardView()
            .frame(maxWidth: 380)
    }
}
