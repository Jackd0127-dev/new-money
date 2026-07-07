import SwiftUI

enum CreditCardLinkBadge: String, CaseIterable, Identifiable {
    case pot
    case bill
    case debt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pot: "Pot"
        case .bill: "Bill"
        case .debt: "Debt"
        }
    }

    var systemImage: String {
        switch self {
        case .pot: "wallet.pass"
        case .bill: "doc.text"
        case .debt: "exclamationmark.shield"
        }
    }

    var color: Color {
        switch self {
        case .pot: AppTheme.Colors.success
        case .bill: AppTheme.Colors.warning
        case .debt: AppTheme.Colors.danger
        }
    }
}

private enum CardFlipAxis {
    case horizontal
    case vertical

    var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch self {
        case .horizontal:
            return (x: 0, y: 1, z: 0)
        case .vertical:
            return (x: 1, y: 0, z: 0)
        }
    }
}

private struct CardFlip {
    var axis: CardFlipAxis
    var direction: Double
}

struct PremiumCardView: View {
    var badges: [CreditCardLinkBadge] = []
    var cardNumber = "••••  ••••  ••••  2847"
    var cardHolder = "JACK"
    var expiryDate = "09/29"
    var provider = "VISA"
    var networkLabel = "VISA"
    var leadingTitle: String? = nil
    var leadingSubtitle: String? = nil
    var facePills: [CreditCardFacePill] = []
    var horizontalPadding: CGFloat = 16
    var designId: String? = nil
    var isInteractive = true
    var shadowRadius: CGFloat = 18
    var artworkDetail: CreditCardArtworkDetail = CreditCardVisualLayoutPolicy.fullArtworkDetail

    @State private var dragOffset: CGSize = .zero
    @State private var isShowingBack = false
    @State private var flipProgressDegrees = 0.0
    @State private var activeFlip = CardFlip(axis: .horizontal, direction: 1)
    private let cardAspectRatio = CreditCardVisualLayoutPolicy.cardAspectRatio
    private let cornerRadius = CreditCardVisualLayoutPolicy.cardCornerRadius
    private let contentInset: CGFloat = 18
    private let flipDragThreshold: CGFloat = 72

    private var resolvedDesign: CreditCardDesign {
        CreditCardDesignCatalog.design(forStoredValue: designId)
    }

    private var providerLabel: String {
        let trimmedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedProvider.isEmpty ? resolvedDesign.providerFallback : trimmedProvider.uppercased()
    }

    private var resolvedNetworkLabel: String {
        let trimmedNetwork = networkLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNetwork.isEmpty ? "VISA" : trimmedNetwork.uppercased()
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width / cardAspectRatio
            let horizontalTiltAngle = Double(dragOffset.width / 22)
            let verticalTiltAngle = Double(dragOffset.height / -18)
            let xFlipAngle = activeFlip.axis == .vertical ? flipProgressDegrees * activeFlip.direction : 0
            let yFlipAngle = activeFlip.axis == .horizontal ? flipProgressDegrees * activeFlip.direction : 0

            cardStack(width: width, height: height)
            .frame(width: width, height: height)
            .shadow(color: AppTheme.Colors.strongShadow, radius: shadowRadius, x: 0, y: shadowRadius > 0 ? 12 : 0)
            .premiumCardTransform(
                isEnabled: isInteractive,
                xAngle: xFlipAngle + verticalTiltAngle,
                yAngle: yFlipAngle + horizontalTiltAngle
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .premiumCardInteraction(isEnabled: isInteractive) { value in
                commitFlip(tapFlip(for: value.location, width: width, height: height))
            } onDragChanged: { value in
                dragOffset = value.translation
            } onDragEnded: { value in
                endDrag(value)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isShowingBack ? "Shows the front of the card" : "Shows the back of the card")
        }
        .aspectRatio(cardAspectRatio, contentMode: .fit)
        .padding(.horizontal, horizontalPadding)
    }

    @ViewBuilder
    private func cardStack(width: CGFloat, height: CGFloat) -> some View {
        if isInteractive {
            ZStack {
                cardShell(width: width, height: height) {
                    currentFaceContent
                }
                .flipFace(angle: flipProgressDegrees, isFront: true)

                cardShell(width: width, height: height) {
                    nextFaceContent
                }
                .rotation3DEffect(
                    .degrees(-180 * activeFlip.direction),
                    axis: activeFlip.axis.rotationAxis,
                    perspective: 0.7
                )
                .flipFace(angle: flipProgressDegrees, isFront: false)
            }
        } else {
            cardShell(width: width, height: height) {
                frontCardContent
            }
        }
    }

    @ViewBuilder
    private var currentFaceContent: some View {
        if isShowingBack {
            backCardContent
        } else {
            frontCardContent
        }
    }

    @ViewBuilder
    private var nextFaceContent: some View {
        if isShowingBack {
            frontCardContent
        } else {
            backCardContent
        }
    }

    private func tapFlip(for location: CGPoint, width: CGFloat, height: CGFloat) -> CardFlip {
        let isMiddleColumn = location.x >= width * 0.32 && location.x <= width * 0.68

        if isMiddleColumn && location.y <= height * 0.44 {
            return CardFlip(axis: .vertical, direction: 1)
        }

        if isMiddleColumn && location.y >= height * 0.56 {
            return CardFlip(axis: .vertical, direction: -1)
        }

        return CardFlip(axis: .horizontal, direction: location.x < width / 2 ? -1 : 1)
    }

    private func commitFlip(_ flip: CardFlip) {
        guard flipProgressDegrees == 0 else { return }

        activeFlip = flip
        withAnimation(.easeInOut(duration: 0.42)) {
            dragOffset = .zero
            flipProgressDegrees = 180
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            var transaction = SwiftUI.Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isShowingBack.toggle()
                flipProgressDegrees = 0
            }
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        let predictedHorizontalDistance = value.predictedEndTranslation.width
        let predictedVerticalDistance = value.predictedEndTranslation.height
        let horizontalCommitDistance = abs(predictedHorizontalDistance) > abs(horizontalDistance)
            ? predictedHorizontalDistance
            : horizontalDistance
        let verticalCommitDistance = abs(predictedVerticalDistance) > abs(verticalDistance)
            ? predictedVerticalDistance
            : verticalDistance
        let isHorizontalIntent = abs(horizontalDistance) > abs(verticalDistance) * 1.15
        let isVerticalIntent = abs(verticalDistance) > abs(horizontalDistance) * 1.15
        let shouldFlipHorizontally = isHorizontalIntent && (
            abs(horizontalDistance) >= flipDragThreshold ||
            abs(predictedHorizontalDistance) >= flipDragThreshold * 1.35
        )
        let shouldFlipVertically = isVerticalIntent && (
            abs(verticalDistance) >= flipDragThreshold ||
            abs(predictedVerticalDistance) >= flipDragThreshold * 1.35
        )

        if shouldFlipHorizontally {
            commitFlip(CardFlip(axis: .horizontal, direction: horizontalCommitDistance < 0 ? -1 : 1))
        } else if shouldFlipVertically {
            commitFlip(CardFlip(axis: .vertical, direction: verticalCommitDistance < 0 ? 1 : -1))
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                dragOffset = .zero
            }
        }
    }

    private func cardShell<Content: View>(
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let scaledContentInset = min(contentInset, CreditCardVisualLayoutPolicy.contentInset(for: height))
        let innerWidth = max(0, width - scaledContentInset * 2)
        let innerHeight = max(0, height - scaledContentInset * 2)

        return ZStack(alignment: .topLeading) {
            CreditCardArtworkBackground(
                design: resolvedDesign,
                cornerRadius: cornerRadius,
                detail: artworkDetail
            )

            content()
                .frame(width: innerWidth, height: innerHeight, alignment: .topLeading)
                .padding(scaledContentInset)
        }
        .frame(width: width, height: height)
    }

    private var frontCardContent: some View {
        CreditCardFrontFaceContent(
            design: resolvedDesign,
            leadingTitle: leadingTitle ?? providerLabel,
            leadingSubtitle: leadingSubtitle,
            networkLabel: resolvedNetworkLabel,
            badges: badges,
            facePills: facePills
        )
    }

    private var backCardContent: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let spacing = min(8, max(5, height * 0.045))
            let topHeight = min(20, max(14, height * 0.12))
            let stripeHeight = min(34, max(24, height * 0.22))
            let signatureHeight = min(30, max(22, height * 0.19))
            let numberSize = min(15, max(11, height * 0.085))
            let labelSize = min(8, max(6, height * 0.048))
            let valueSize = min(10, max(8, height * 0.064))

            VStack(alignment: .leading, spacing: spacing) {
                HStack {
                    Text(cardHolder)
                        .font(.system(size: min(15, max(11, height * 0.09)), weight: .semibold, design: .rounded))
                        .foregroundStyle(resolvedDesign.foregroundColor.opacity(0.84))
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "wave.3.right")
                        .font(.system(size: min(18, max(14, height * 0.10)), weight: .semibold))
                        .foregroundStyle(resolvedDesign.foregroundColor.opacity(0.82))
                }
                .frame(height: topHeight)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.92), Color.black.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: stripeHeight)
                    .overlay(alignment: .trailing) {
                        Text(providerLabel)
                            .font(.system(size: min(14, max(10, height * 0.08)), weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .padding(.trailing, 18)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, -contentInset)

                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                        .frame(height: signatureHeight)
                        .overlay(alignment: .leading) {
                            Text(cardHolder)
                                .font(.system(size: min(11, max(8, height * 0.06)), weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.70))
                                .padding(.leading, 12)
                                .lineLimit(1)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CVV")
                            .font(.system(size: min(8, max(6, height * 0.044)), weight: .bold, design: .rounded))
                            .foregroundStyle(resolvedDesign.mutedForegroundColor.opacity(0.62))
                        Text("921")
                            .font(.system(size: min(10, max(8, height * 0.06)), weight: .bold, design: .rounded))
                            .foregroundStyle(resolvedDesign.foregroundColor)
                    }
                    .frame(width: 40, alignment: .leading)
                }

                Text(cardNumber)
                    .font(.system(size: numberSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(resolvedDesign.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 26) {
                    cardDetailBlock(title: "CARD HOLDER", value: cardHolder, labelSize: labelSize, valueSize: valueSize)
                    cardDetailBlock(title: "EXPIRES", value: expiryDate, labelSize: labelSize, valueSize: valueSize)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private func cardDetailBlock(title: String, value: String, labelSize: CGFloat, valueSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                .foregroundStyle(resolvedDesign.mutedForegroundColor.opacity(0.66))

            Text(value)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .foregroundStyle(resolvedDesign.foregroundColor)
                .lineLimit(1)
        }
    }

}

struct CreditCardFacePill: Identifiable, Hashable {
    var id: String
    var title: String
    var systemImage: String?

    init(id: String, title: String, systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }

    init(badge: CreditCardLinkBadge) {
        self.id = badge.id
        self.title = badge.title
        self.systemImage = badge.systemImage
    }
}

struct CreditCardFrontFaceContent: View {
    var design: CreditCardDesign
    var leadingTitle: String
    var leadingSubtitle: String?
    var networkLabel: String
    var badges: [CreditCardLinkBadge] = []
    var facePills: [CreditCardFacePill] = []

    private var resolvedFacePills: [CreditCardFacePill] {
        if !facePills.isEmpty {
            return Array(facePills.prefix(3))
        }

        return badges.prefix(3).map { CreditCardFacePill(badge: $0) }
    }

    var body: some View {
        GeometryReader { proxy in
            let height = max(1, proxy.size.height)
            let providerSize = min(22, max(7, height * 0.108))
            let providerSubtitleSize = min(9, max(4.8, height * 0.044))
            let creditSize = min(12, max(5, height * 0.059))
            let networkSize = min(13, max(5.5, height * 0.064))
            let creditTracking = min(1.4, max(0.45, height * 0.0068))
            let networkTracking = min(1.2, max(0.40, height * 0.0059))

            VStack(alignment: .leading) {
                HStack(alignment: .top, spacing: max(4, height * 0.025)) {
                    VStack(alignment: .leading, spacing: max(1, height * 0.008)) {
                        Text(leadingTitle)
                            .font(.system(size: providerSize, weight: .bold, design: .rounded))
                            .foregroundStyle(design.foregroundColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        if let leadingSubtitle {
                            Text(leadingSubtitle)
                                .font(.system(size: providerSubtitleSize, weight: .semibold, design: .rounded))
                                .foregroundStyle(design.mutedForegroundColor.opacity(0.76))
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                        }
                    }

                    Spacer(minLength: 0)

                    CreditCardFaceBadgeStrip(
                        pills: resolvedFacePills,
                        foregroundColor: design.foregroundColor,
                        contentHeight: height
                    )
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: max(4, height * 0.025)) {
                    Text("CREDIT")
                        .font(.system(size: creditSize, weight: .semibold, design: .rounded))
                        .tracking(creditTracking)
                        .foregroundStyle(design.mutedForegroundColor.opacity(0.74))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 0)

                    Text(networkLabel)
                        .font(.system(size: networkSize, weight: .black, design: .rounded))
                        .tracking(networkTracking)
                        .foregroundStyle(design.foregroundColor.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

private struct CreditCardFaceBadgeStrip: View {
    var pills: [CreditCardFacePill]
    var foregroundColor: Color
    var contentHeight: CGFloat

    var body: some View {
        if !pills.isEmpty {
            HStack(spacing: max(2, contentHeight * 0.012)) {
                ForEach(pills) { pill in
                    CreditCardFaceBadgePill(
                        pill: pill,
                        foregroundColor: foregroundColor,
                        contentHeight: contentHeight
                    )
                }
            }
        }
    }
}

private struct CreditCardFaceBadgePill: View {
    var pill: CreditCardFacePill
    var foregroundColor: Color
    var contentHeight: CGFloat

    var body: some View {
        HStack(spacing: max(1, contentHeight * 0.010)) {
            if let systemImage = pill.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: min(8, max(4, contentHeight * 0.039)), weight: .bold))
            }
            Text(pill.title)
                .font(.system(size: min(9, max(4.5, contentHeight * 0.042)), weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, min(7, max(2.5, contentHeight * 0.030)))
        .padding(.vertical, min(5, max(2, contentHeight * 0.024)))
        .background(foregroundColor.opacity(0.18))
        .overlay {
            Capsule()
                .stroke(foregroundColor.opacity(0.32), lineWidth: 1)
        }
        .clipShape(Capsule())
    }
}

struct CreditCardLinkBadgePill: View {
    var badge: CreditCardLinkBadge
    var isCompact = false
    var foregroundColor: Color = AppTheme.Colors.controlText

    var body: some View {
        HStack(spacing: isCompact ? 3 : 5) {
            Image(systemName: badge.systemImage)
                .font(.system(size: isCompact ? 8 : 10, weight: .bold))
            Text(badge.title)
                .font(.system(size: isCompact ? 9 : 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, isCompact ? 7 : 9)
        .padding(.vertical, isCompact ? 5 : 6)
        .background(foregroundColor.opacity(0.18))
        .overlay {
            Capsule()
                .stroke(foregroundColor.opacity(0.32), lineWidth: 1)
        }
        .clipShape(Capsule())
    }
}

private func isBackVisible(for angle: Double) -> Bool {
    let normalizedAngle = ((angle.truncatingRemainder(dividingBy: 360)) + 360)
        .truncatingRemainder(dividingBy: 360)
    return normalizedAngle >= 90 && normalizedAngle <= 270
}

private struct CardFlipFaceVisibility: AnimatableModifier {
    var angle: Double
    var isFront: Bool

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let isVisible = isFront ? !isBackVisible(for: angle) : isBackVisible(for: angle)

        content
            .opacity(isVisible ? 1 : 0)
    }
}

private extension View {
    func flipFace(angle: Double, isFront: Bool) -> some View {
        modifier(CardFlipFaceVisibility(angle: angle, isFront: isFront))
    }

    @ViewBuilder
    func premiumCardTransform(isEnabled: Bool, xAngle: Double, yAngle: Double) -> some View {
        if isEnabled {
            self
                .rotation3DEffect(
                    .degrees(xAngle),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.7
                )
                .rotation3DEffect(
                    .degrees(yAngle),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.7
                )
        } else {
            self
        }
    }

    @ViewBuilder
    func premiumCardInteraction(
        isEnabled: Bool,
        onTap: @escaping (SpatialTapGesture.Value) -> Void,
        onDragChanged: @escaping (DragGesture.Value) -> Void,
        onDragEnded: @escaping (DragGesture.Value) -> Void
    ) -> some View {
        if isEnabled {
            self
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded(onTap)
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged(onDragChanged)
                        .onEnded(onDragEnded)
                )
        } else {
            self
        }
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.appBackground.ignoresSafeArea()

        PremiumCardView(
            badges: [.pot, .bill, .debt],
            designId: CreditCardDesignCatalog.defaultDesign.storageHex
        )
        .frame(maxWidth: 380)
    }
}
