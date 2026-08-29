import SwiftUI

enum CardsSection: String, Equatable {
    case summary
    case paymentAllocation
    case activeCards
}

struct CardsLayoutPolicy {
    static let toolbarActionId = "add"
    static let detailToolbarActionId = "card-detail-add-payment"
    static let detailToolbarTitle = "Pay"
    static let detailToolbarStyle = "textButton"
    static let repaymentFlowPlacement = "cardDetailToolbar"
    static let balanceHistoryToolbarActionId = "card-detail-balance-history"
    static let balanceHistoryToolbarSymbol = "list.bullet.rectangle"
    static let balanceHistoryPresentation = "toolbarToggle"
    static let balanceHistoryIncludesCurrentBalance = true
    static let balanceHistoryGroupsByStatement = true
    static let balanceHistoryStatementsDefaultExpanded = false
    static let balanceHistoryStatementHeading = "processedDate"
    static let balanceHistoryDueDatePlacement = "trailingBelowAmount"
    static let detailTopPresentation = "floatingNoOuterCard"
    static let rowPresentation = "floatingNoOuterCard"
    static let activeCardCollapsedPresentation = "overlappedStack"
    static let activeCardExpandedPresentation = "floatingTwoColumnGrid"
    static let activeCardExpandedColumnCount = 2
    static let activeCardExpandedUsesLazyGrid = true
    static let activeCardViewAllPillEnabled = true
    static let activeCardStackAnimation = "shortEaseInOut"
    static let activeCardCollapsedRenderLimit = 5
    static let activeCardUsesMatchedGeometry = false
    static let activeCardModelsAreRevisionCached = true
    static let statementSummarySeparatesCurrentAndNextStatement = true
    static let statementSummaryShowsPaycheckImpact = false
    static let cardBalanceTitle = "Card balance"
    static let currentStatementDueTitle = "Current statement due"
    static let forecastStatementDueTitle = "Forecast statement due"
    static let detailUsesSafeAreaAwareTopSpacing = true
    static let linkedRowsUseFlatPresentation = true
    static let linkedRowMinimumTapTarget: CGFloat = 54
    static let sections: [CardsSection] = [
        .summary,
        .activeCards
    ]

    static func toolbarMode(addAction: @escaping () -> Void) -> AppToolbarMode {
        .add(action: addAction)
    }
}

enum CardFormLayoutPolicy {
    static let dayFieldOrder = ["directDebitDay", "statementDay"]
    static let dayFieldPresentation = "compactSideBySideMenuBoxes"
    static let directDebitDayTitle = "Direct debit"
    static let statementDayTitle = "Statement"
    static let dayFieldTitleLineLimit = 1
    static let dayFieldTitleMinimumScaleFactor: CGFloat = 0.55
    static let dayFieldMinimumHeight: CGFloat = 64
    static let colorSwatchAlignment = "center"
    static let showsPlaceholderToolbar = false
    static let hidesNavigationDivider = true
    static let usesBillsStyleCard = true
    static let designSelectionPresentation = "navigationPushGroupedDesignBrowser"
    static let designGridColumnCount = 2
    static let preservesDesignAspectRatio = true
}

struct CreditCardPreviewModel: Identifiable, Equatable {
    var card: CreditCard
    var balancePence: Int
    var availability: CreditCardAvailabilitySummary
    var design: CreditCardDesign
    var spentLabel: String
    var limitPillTitle: String
    var duePillTitle: String
    var availablePillTitle: String
    var accessibilityLabel: String

    var id: String { card.id }

    init(card: CreditCard, balancePence: Int, availability: CreditCardAvailabilitySummary) {
        let design = CreditCardDesignCatalog.design(forStoredValue: card.designId ?? card.color)
        let spentLabel = creditCardSpentAmountLabel(balancePence)
        let availablePence = availability.actualAvailablePence

        self.card = card
        self.balancePence = balancePence
        self.availability = availability
        self.design = design
        self.spentLabel = spentLabel
        self.limitPillTitle = "Limit \(creditCardCompactMoney(card.limitPence))"
        self.duePillTitle = card.dueDay.map { "Due \($0)" } ?? "Due --"
        self.availablePillTitle = "Avail \(creditCardCompactMoney(availablePence))"
        self.accessibilityLabel = "\(card.name), card balance \(spentLabel)"
    }
}

func creditCardPreviewModels(
    cards: [CreditCard],
    snapshot: PlannerSnapshot,
    payPeriod: PayPeriod?,
    asOfDate: String
) -> [CreditCardPreviewModel] {
    cards.map { card in
        let balancePence = PlannerDerivedData.cardBalance(card: card, snapshot: snapshot)
        let availability = PlannerDerivedData.creditCardAvailabilitySummary(
            card: card,
            snapshot: snapshot,
            payPeriod: payPeriod,
            asOfDate: asOfDate
        )

        return CreditCardPreviewModel(
            card: card,
            balancePence: balancePence,
            availability: availability
        )
    }
}

struct CardsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    @State private var selectedCard: CreditCard?
    @State private var isAddCardPresented = false
    @State private var areCardsExpanded = false
    @State private var cardModels: [CreditCardPreviewModel]

    init(
        store: PlannerStore,
        navigationMode: ScreenNavigationMode = .root,
        toolbarMode: AppToolbarMode = .primaryDouble
    ) {
        self.store = store
        self.navigationMode = navigationMode
        self.toolbarMode = toolbarMode
        _cardModels = State(initialValue: Self.makeCardModels(store: store))
    }

    var body: some View {
        ScreenScaffold(
            title: "Cards",
            subtitle: "",
            navigationMode: navigationMode,
            toolbarMode: resolvedToolbarMode
        ) {
            ForEach(CardsLayoutPolicy.sections, id: \.rawValue) { section in
                cardsSection(section, cardModels: cardModels)
            }
        }
        .navigationTopDividerHidden()
        .sheet(item: $selectedCard) { card in
            CardDetailView(store: store, card: card)
        }
        .sheet(isPresented: $isAddCardPresented) {
            CardFormView(store: store)
        }
        .onChange(of: store.snapshotRevision) { _, _ in
            cardModels = Self.makeCardModels(store: store)
        }
    }

    private var resolvedToolbarMode: AppToolbarMode {
        switch toolbarMode {
        case .none, .add(_), .editDone(_, _, _), .editDoneAndAdd(_, _, _, _), .actions(_):
            toolbarMode
        case .primaryDouble, .secondarySingle, .modalSingle:
            CardsLayoutPolicy.toolbarMode {
                isAddCardPresented = true
            }
        }
    }

    @ViewBuilder
    private func cardsSection(_ section: CardsSection, cardModels: [CreditCardPreviewModel]) -> some View {
        switch section {
        case .summary:
            summary(cardModels: cardModels)
        case .paymentAllocation:
            EmptyView()
        case .activeCards:
            activeCardsSection(cardModels: cardModels)
        }
    }

    private func activeCardsSection(cardModels: [CreditCardPreviewModel]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if cardModels.isEmpty {
                SectionTitle("Active cards")
                AppCard {
                    EmptyStateView(title: "Add your first card", message: "Use Add in the toolbar to start tracking card balances and repayments.", systemImage: "creditcard")
                }
            } else {
                activeCardsHeader

                if areCardsExpanded {
                    LazyVGrid(columns: activeCardGridColumns, alignment: .center, spacing: AppTheme.Spacing.xl) {
                        ForEach(cardModels) { model in
                            cardButton(card: model.card) {
                                CreditCardGridTile(model: model)
                                    .equatable()
                            }
                        }
                    }
                    .transition(.opacity)
                } else {
                    collapsedCardStack(cardModels: cardModels)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
    }

    private var activeCardGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.md, alignment: .top),
            count: CardsLayoutPolicy.activeCardExpandedColumnCount
        )
    }

    private var activeCardsHeader: some View {
        HStack(alignment: .center) {
            Text("Active cards")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    areCardsExpanded.toggle()
                }
            } label: {
                Text(areCardsExpanded ? "Stack" : "View all")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.Colors.primaryOrange.opacity(0.13), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.Colors.primaryOrange.opacity(0.24), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(areCardsExpanded ? "Stack cards" : "View all cards")
        }
    }

    private func collapsedCardStack(cardModels: [CreditCardPreviewModel]) -> some View {
        let visibleModels = cardModels.prefix(CardsLayoutPolicy.activeCardCollapsedRenderLimit)
        return ZStack {
            ForEach(visibleModels.indices.reversed(), id: \.self) { index in
                let model = visibleModels[index]
                cardButton(card: model.card) {
                    FloatingCreditCardPreview(model: model)
                        .equatable()
                        .scaleEffect(stackScale(for: index))
                        .offset(x: stackOffset(for: index).width, y: stackOffset(for: index).height)
                        .opacity(stackOpacity(for: index))
                        .zIndex(Double(visibleModels.count - index))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: CreditCardVisualLayoutPolicy.rowPreviewHeight + 54)
    }

    private static func makeCardModels(store: PlannerStore) -> [CreditCardPreviewModel] {
        creditCardPreviewModels(
            cards: store.activeCards,
            snapshot: store.snapshot,
            payPeriod: store.selectedPayPeriod,
            asOfDate: store.todayIso
        )
    }

    private func cardButton<Content: View>(card: CreditCard, @ViewBuilder content: () -> Content) -> some View {
        Button {
            selectedCard = card
        } label: {
            content()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(card.name)")
    }

    private func stackOffset(for index: Int) -> CGSize {
        let visibleIndex = CGFloat(index)
        return CGSize(width: visibleIndex * 13, height: visibleIndex * -8)
    }

    private func stackScale(for index: Int) -> CGFloat {
        max(0.82, 1 - CGFloat(index) * 0.045)
    }

    private func stackOpacity(for index: Int) -> Double {
        max(0.32, 1 - Double(index) * 0.14)
    }

    private func summary(cardModels: [CreditCardPreviewModel]) -> some View {
        let totalCredit = cardModels.reduce(0) { $0 + $1.card.limitPence }
        let owed = cardModels.reduce(0) { $0 + $1.availability.actualOwedPence }
        let forecastOwed = cardModels.reduce(0) { $0 + $1.availability.forecastOwedPence }
        let available = cardModels.reduce(0) { $0 + $1.availability.actualAvailablePence }
        let forecastAvailable = cardModels.reduce(0) { $0 + $1.availability.forecastAvailablePence }
        return AppCard(glow: true) {
            CreditMetricGrid(
                items: [
                    .init(label: "Total credit", value: MoneyParser.formatPence(totalCredit)),
                    .init(label: "Owed", value: MoneyParser.formatPence(owed), valueColor: AppTheme.Colors.orangeHighlight),
                    .init(
                        label: available < 0 ? "Over limit" : "Available credit",
                        value: MoneyParser.formatPence(abs(available)),
                        valueColor: available < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText
                    )
                ] + (forecastOwed != owed || forecastAvailable != available ? [
                    .init(
                        label: forecastAvailable < 0 ? "Forecast over limit" : "Forecast availability",
                        value: MoneyParser.formatPence(abs(forecastAvailable)),
                        valueColor: forecastAvailable < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning
                    )
                ] : [])
            )
        }
    }

}

struct CreditCardRow: View {
    var card: CreditCard
    var balancePence: Int
    var availability: CreditCardAvailabilitySummary? = nil
    var showsTitle = true
    var matchedNamespace: Namespace.ID?
    var matchedID: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            cardPreview
                .frame(maxWidth: .infinity, alignment: .center)

            if showsTitle {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(card.provider.isEmpty ? "Card" : card.provider)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)

                        balanceAmount
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(card.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Text(card.provider.isEmpty ? "Card" : card.provider)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: AppTheme.Spacing.sm)

                        balanceAmount
                    }
                }
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(CardsLayoutPolicy.cardBalanceTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        balanceAmount
                        Text(card.provider.isEmpty ? "Card" : card.provider)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(CardsLayoutPolicy.cardBalanceTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            balanceAmount
                        }
                        Spacer()
                        Text(card.provider.isEmpty ? "Card" : card.provider)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            ProgressView(value: min(1, Double(max(0, balancePence)) / Double(max(1, card.limitPence))))
                .tint(balancePence > card.limitPence ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
                .background(AppTheme.Colors.divider)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Pill(text: "Limit \(MoneyParser.formatPence(card.limitPence))", systemImage: "gauge")
                    if let dueDay = card.dueDay {
                        Pill(text: "Due day \(dueDay)", systemImage: "calendar")
                    }
                }
            } else {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Pill(text: "Limit \(MoneyParser.formatPence(card.limitPence))", systemImage: "gauge")
                    if let dueDay = card.dueDay {
                        Pill(text: "Due day \(dueDay)", systemImage: "calendar")
                    }
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(cardAvailabilityLabel(actualAvailablePence))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(actualAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                    if forecastAvailablePence != actualAvailablePence {
                        Text(forecastAvailabilityLabel(forecastAvailablePence))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(forecastAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning)
                    }
                }
            } else {
                HStack {
                    Text(cardAvailabilityLabel(actualAvailablePence))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(actualAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                    Spacer()
                    if forecastAvailablePence != actualAvailablePence {
                        Text(forecastAvailabilityLabel(forecastAvailablePence))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(forecastAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cardPreview: some View {
        let preview = FloatingCreditCardPreview(
            card: card,
            balancePence: balancePence,
            availability: availability
        )
        if let matchedNamespace, let matchedID {
            preview
                .equatable()
                .matchedGeometryEffect(id: matchedID, in: matchedNamespace)
        } else {
            preview.equatable()
        }
    }

    private var balanceAmount: some View {
        Text(MoneyParser.formatPence(balancePence))
            .font(.title3.weight(.bold))
            .foregroundStyle(AppTheme.Colors.primaryOrange)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private var actualAvailablePence: Int {
        availability?.actualAvailablePence ?? card.limitPence - balancePence
    }

    private var forecastAvailablePence: Int {
        availability?.forecastAvailablePence ?? actualAvailablePence
    }

}

struct FloatingCreditCardPreview: View, Equatable {
    var model: CreditCardPreviewModel
    var maxWidth: CGFloat? = CreditCardVisualLayoutPolicy.rowCardMaxWidth

    init(model: CreditCardPreviewModel, maxWidth: CGFloat? = CreditCardVisualLayoutPolicy.rowCardMaxWidth) {
        self.model = model
        self.maxWidth = maxWidth
    }

    init(
        card: CreditCard,
        balancePence: Int,
        availability: CreditCardAvailabilitySummary? = nil,
        maxWidth: CGFloat? = CreditCardVisualLayoutPolicy.rowCardMaxWidth
    ) {
        let fallbackAvailability = CreditCardAvailabilitySummary(
            actualOwedPence: balancePence,
            forecastOwedPence: balancePence,
            actualAvailablePence: card.limitPence - balancePence,
            forecastAvailablePence: card.limitPence - balancePence
        )
        self.model = CreditCardPreviewModel(
            card: card,
            balancePence: balancePence,
            availability: availability ?? fallbackAvailability
        )
        self.maxWidth = maxWidth
    }

    var body: some View {
        StaticCreditCardPreviewFace(model: model)
        .frame(maxWidth: maxWidth ?? .infinity)
        .accessibilityLabel(model.accessibilityLabel)
    }
}

private struct StaticCreditCardPreviewFace: View, Equatable {
    var model: CreditCardPreviewModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let height = max(1, size.height)
            let inset = CreditCardVisualLayoutPolicy.contentInset(for: height)
            let cornerRadius = CreditCardVisualLayoutPolicy.cardCornerRadius
            let cardShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let innerWidth = max(0, size.width - inset * 2)
            let innerHeight = max(0, size.height - inset * 2)

            ZStack(alignment: .topLeading) {
                CreditCardArtworkBackground(
                    design: model.design,
                    cornerRadius: cornerRadius,
                    detail: CreditCardVisualLayoutPolicy.previewArtworkDetail
                )

                CreditCardFrontFaceContent(
                    design: model.design,
                    leadingTitle: cardFaceTitle,
                    leadingSubtitle: nil,
                    networkLabel: cardNetworkLabel,
                    facePills: cardFacePills
                )
                    .frame(width: innerWidth, height: innerHeight, alignment: .topLeading)
                    .padding(inset)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(cardShape)
            .contentShape(cardShape)
        }
        .aspectRatio(CreditCardVisualLayoutPolicy.cardAspectRatio, contentMode: .fit)
    }

    private var cardFaceTitle: String {
        let trimmedName = model.card.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? model.design.providerFallback.uppercased() : trimmedName
    }

    private var cardNetworkLabel: String {
        model.design.providerFallback.uppercased()
    }

    private var cardFacePills: [CreditCardFacePill] {
        [
            CreditCardFacePill(id: "limit", title: model.limitPillTitle, systemImage: "gauge"),
            CreditCardFacePill(id: "due", title: model.duePillTitle, systemImage: "calendar"),
            CreditCardFacePill(id: "available", title: model.availablePillTitle, systemImage: "creditcard")
        ]
    }
}

private struct CreditCardGridTile: View, Equatable {
    let model: CreditCardPreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            FloatingCreditCardPreview(model: model, maxWidth: nil)
                .equatable()
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 5) {
                Text(model.card.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(MoneyParser.formatPence(model.balancePence))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .lineLimit(1)

                ProgressView(value: min(1, Double(max(0, model.balancePence)) / Double(max(1, model.card.limitPence))))
                    .tint(model.balancePence > model.card.limitPence ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
                    .background(AppTheme.Colors.divider)

                Text(cardAvailabilityLabel(actualAvailablePence))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(actualAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private var actualAvailablePence: Int {
        model.availability.actualAvailablePence
    }
}

struct CardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var provider = ""
    @State private var limit = ""
    @State private var opening = ""
    @State private var openingStatement = ""
    @State private var statementDay = 1
    @State private var directDebitDay = 1
    @State private var color = CreditCardDesignCatalog.defaultDesign.storageHex

    var body: some View {
        NavigationStack {
            ScrollView {
                AppCard(glow: true) {
                    SectionTitle("Add card")
                    TextField("Card name", text: $name).textFieldStyle(AppTextFieldStyle())
                    TextField("Provider", text: $provider).textFieldStyle(AppTextFieldStyle())
                    MoneyField(title: "Credit limit", text: $limit)
                    MoneyField(title: "Opening balance", text: $opening)
                    MoneyField(title: "Existing statement due", text: $openingStatement)

                    dayFields

                    CreditCardDesignSelectionLink(selectedValue: $color, provider: provider)

                    PrimaryButton(title: "Add card", systemImage: "plus", isDisabled: name.isBlank || limit.isBlank) {
                        store.addCreditCard(
                            name: name,
                            provider: provider.isBlank ? "Card" : provider,
                            limitPence: MoneyParser.parsePoundsToPence(limit),
                            openingBalancePence: MoneyParser.parsePoundsToPence(opening),
                            openingStatementBalancePence: openingStatement.isBlank ? nil : MoneyParser.parsePoundsToPence(openingStatement),
                            statementDay: statementDay,
                            dueDay: directDebitDay,
                            dueDate: nil,
                            color: color
                        )
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .onAppear {
                    if color.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        color = CreditCardDesignCatalog.defaultDesign.storageHex
                    }
                }
            }
            .premiumScreenBackground()
            .navigationTitle("Add card")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private var dayFields: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            CreditCardDayMenuField(
                title: CardFormLayoutPolicy.directDebitDayTitle,
                value: directDebitDay,
                systemImage: "calendar.badge.clock",
                accessibilityLabel: "Direct debit day"
            ) { day in
                directDebitDay = day
            }
            .frame(maxWidth: .infinity)

            CreditCardDayMenuField(
                title: CardFormLayoutPolicy.statementDayTitle,
                value: statementDay,
                systemImage: "calendar",
                accessibilityLabel: "Statement day"
            ) { day in
                statementDay = day
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct CreditCardEditFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var card: CreditCard
    @State private var name: String
    @State private var provider: String
    @State private var limit: String
    @State private var opening: String
    @State private var openingStatement: String
    @State private var statementDay: Int
    @State private var directDebitDay: Int
    @State private var color: String

    init(store: PlannerStore, card: CreditCard) {
        self.store = store
        self.card = card
        _name = State(initialValue: card.name)
        _provider = State(initialValue: card.provider)
        _limit = State(initialValue: MoneyParser.formatPence(card.limitPence))
        _opening = State(initialValue: MoneyParser.formatPence(card.openingBalancePence ?? 0))
        _openingStatement = State(initialValue: card.openingStatementBalancePence.map { MoneyParser.formatPence($0) } ?? "")
        _statementDay = State(initialValue: card.statementDate.map { Calendar.current.component(.day, from: FinanceEngine.parseDate($0)) } ?? 1)
        _directDebitDay = State(initialValue: card.dueDay ?? 1)
        _color = State(initialValue: CreditCardDesignCatalog.design(forStoredValue: card.designId ?? card.color).storageHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                AppCard(glow: true) {
                    SectionTitle("Edit card")
                    TextField("Card name", text: $name).textFieldStyle(AppTextFieldStyle())
                    TextField("Provider", text: $provider).textFieldStyle(AppTextFieldStyle())
                    MoneyField(title: "Credit limit", text: $limit)
                    MoneyField(title: "Opening balance", text: $opening)
                    MoneyField(title: "Existing statement due", text: $openingStatement)

                    dayFields

                    CreditCardDesignSelectionLink(selectedValue: $color, provider: provider)

                    PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: name.isBlank || limit.isBlank) {
                        save()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .contentMargins(.top, AppTheme.Spacing.lg, for: .scrollContent)
            .premiumScreenBackground()
            .navigationTitle("Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var dayFields: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            CreditCardDayMenuField(
                title: CardFormLayoutPolicy.directDebitDayTitle,
                value: directDebitDay,
                systemImage: "calendar.badge.clock",
                accessibilityLabel: "Direct debit day"
            ) { day in
                directDebitDay = day
            }
            .frame(maxWidth: .infinity)

            CreditCardDayMenuField(
                title: CardFormLayoutPolicy.statementDayTitle,
                value: statementDay,
                systemImage: "calendar",
                accessibilityLabel: "Statement day"
            ) { day in
                statementDay = day
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func save() {
        var updatedCard = card
        updatedCard.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedCard.provider = provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Card" : provider.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedCard.limitPence = MoneyParser.parsePoundsToPence(limit)
        updatedCard.openingBalancePence = MoneyParser.parsePoundsToPence(opening)
        updatedCard.openingStatementBalancePence = openingStatement.isBlank ? nil : MoneyParser.parsePoundsToPence(openingStatement)
        updatedCard.statementDate = statementCycleAnchor()
        updatedCard.designId = nil
        updatedCard.dueDay = directDebitDay
        updatedCard.color = color
        store.updateCreditCard(updatedCard)
        dismiss()
    }

    private func statementCycleAnchor() -> String {
        let nextStatementDate = FinanceEngine.monthlyDate(onOrAfter: store.todayIso, day: statementDay)
        guard !openingStatement.isBlank, nextStatementDate > store.todayIso else {
            return nextStatementDate
        }
        return PlannerDerivedData.addIsoMonthsClamped(date: nextStatementDate, months: -1)
    }
}

private struct CreditCardDayMenuField: View {
    var title: String
    var value: Int
    var systemImage: String
    var accessibilityLabel: String
    var onSelect: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(1...31, id: \.self) { day in
                Button {
                    onSelect(day)
                } label: {
                    if day == value {
                        Label(creditCardDaySelectionValue(day), systemImage: "checkmark")
                    } else {
                        Text(creditCardDaySelectionValue(day))
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.Colors.primaryOrange.opacity(0.14))
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(CardFormLayoutPolicy.dayFieldTitleLineLimit)
                        .minimumScaleFactor(CardFormLayoutPolicy.dayFieldTitleMinimumScaleFactor)
                        .allowsTightening(true)
                    Text(creditCardDaySelectionValue(value))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .layoutPriority(1)

                Spacer(minLength: 2)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: CardFormLayoutPolicy.dayFieldMinimumHeight, alignment: .leading)
            .background(AppTheme.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(creditCardDaySelectionValue(value))
    }
}

func creditCardDaySelectionValue(_ day: Int) -> String {
    "Day \(day)"
}

enum CreditCardBalanceHistoryEntryKind: Equatable {
    case openingBalance
    case statementBalance
    case charge
    case refund
    case repayment
    case repaymentRefund
    case reconciliationAdjustment
}

enum CreditCardBalanceHistoryEditTarget: Equatable, Identifiable {
    case transaction(String)
    case recurring(paymentId: String, scheduledDueDate: String)
    case repayment(String)
    case statement(cardId: String, scheduledStatementDate: String)
    case card(String)

    var id: String {
        switch self {
        case .transaction(let id):
            "transaction-\(id)"
        case .recurring(let paymentId, let scheduledDueDate):
            "recurring-\(paymentId)-\(scheduledDueDate)"
        case .repayment(let id):
            "repayment-\(id)"
        case .statement(let cardId, let scheduledStatementDate):
            "statement-\(cardId)-\(scheduledStatementDate)"
        case .card(let id):
            "card-\(id)"
        }
    }
}

struct CreditCardBalanceHistoryEntry: Identifiable, Equatable {
    var id: String
    var title: String
    var date: String
    var amountPence: Int
    var kind: CreditCardBalanceHistoryEntryKind
    var editTarget: CreditCardBalanceHistoryEditTarget?
}

struct CreditCardBalanceHistorySection: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var balancePence: Int
    var statementDate: String?
    var directDebitDate: String?
    var status: CreditCardStatementStatus?
    var entries: [CreditCardBalanceHistoryEntry]
}

struct CreditCardBalanceHistoryData: Equatable {
    var currentBalancePence: Int
    var currentSection: CreditCardBalanceHistorySection
    var statementSections: [CreditCardBalanceHistorySection]

    static func make(card: CreditCard, snapshot: PlannerSnapshot, asOfDate: String) -> CreditCardBalanceHistoryData {
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: asOfDate)
            .filter { $0.cardId == card.id }
            .sorted { $0.statementDate > $1.statementDate }
        let latestStatementDate = statements
            .map(\.statementDate)
            .filter { $0 <= asOfDate }
            .max()
        let currentBalancePence = PlannerDerivedData.creditCardAvailabilitySummary(
            card: card,
            snapshot: snapshot,
            payPeriod: nil,
            asOfDate: asOfDate
        ).actualOwedPence
        let statementRepaymentIds = Set(statements.flatMap {
            matchedRepayments(for: $0, snapshot: snapshot, asOfDate: asOfDate).map(\.id)
        })
        let lockedStatementBalancePence = statements
            .filter { $0.statementDate <= asOfDate }
            .reduce(0) { $0 + $1.unpaidAmountPence }
        let currentCycleBalancePence = currentBalancePence - lockedStatementBalancePence
        let movements = currentMovementEntries(
            card: card,
            snapshot: snapshot,
            after: latestStatementDate,
            asOfDate: asOfDate,
            excludingRepaymentIds: statementRepaymentIds
        )
        var currentEntries = movements
        let unexplainedBalancePence = currentCycleBalancePence - currentEntries.reduce(0) { $0 + $1.amountPence }
        let createdDate = String(card.createdAt.prefix(10))
        let openingDate = latestStatementDate ?? (FinanceEngine.isIsoDate(createdDate) ? createdDate : asOfDate)

        if unexplainedBalancePence != 0 || currentEntries.isEmpty {
            currentEntries.append(
                CreditCardBalanceHistoryEntry(
                    id: "current-opening-\(card.id)-\(latestStatementDate ?? asOfDate)",
                    title: latestStatementDate == nil ? "Opening balance" : "Unstatemented balance",
                    date: openingDate,
                    amountPence: unexplainedBalancePence,
                    kind: .openingBalance,
                    editTarget: .card(card.id)
                )
            )
        }
        currentEntries.sort(by: entrySort)

        return CreditCardBalanceHistoryData(
            currentBalancePence: currentBalancePence,
            currentSection: CreditCardBalanceHistorySection(
                id: "current-\(card.id)",
                title: "Current balance",
                subtitle: latestStatementDate.map { "Since \(shortDate($0))" } ?? "All recorded activity",
                balancePence: currentCycleBalancePence,
                statementDate: nil,
                directDebitDate: nil,
                status: nil,
                entries: currentEntries
            ),
            statementSections: statements.map { statementSection(statement: $0, snapshot: snapshot, asOfDate: asOfDate) }
        )
    }

    private static func currentMovementEntries(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        after cutoffDate: String?,
        asOfDate: String,
        excludingRepaymentIds: Set<String>
    ) -> [CreditCardBalanceHistoryEntry] {
        func isCurrentTransaction(_ date: String) -> Bool {
            date <= asOfDate && cutoffDate.map { date >= $0 } ?? true
        }

        let cardTransactions = snapshot.transactions.filter {
            $0.deletedAt == nil &&
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == card.id
        }
        let charges = cardTransactions
            .filter { isCurrentTransaction($0.date) }
            .map {
                CreditCardBalanceHistoryEntry(
                    id: "current-charge-\($0.id)",
                    title: $0.note.isBlank ? "Card spending" : $0.note,
                    date: $0.date,
                    amountPence: $0.amountPence,
                    kind: .charge,
                    editTarget: transactionEditTarget(for: $0, snapshot: snapshot)
                )
            }
        let refunds = cardTransactions.compactMap { transaction -> CreditCardBalanceHistoryEntry? in
            guard transaction.hasRefund,
                  let refundedAt = transaction.refundedAt
            else { return nil }
            let refundDate = String(refundedAt.prefix(10))
            guard FinanceEngine.isIsoDate(refundDate), isCurrentTransaction(refundDate) else { return nil }
            return CreditCardBalanceHistoryEntry(
                id: "current-refund-\(transaction.id)-\(refundDate)",
                title: "\(transaction.note.isBlank ? "Card spending" : transaction.note) refund",
                date: refundDate,
                amountPence: -transaction.effectiveRefundedAmountPence,
                kind: .refund,
                editTarget: transactionEditTarget(for: transaction, snapshot: snapshot)
            )
        }

        let cardRepayments = snapshot.creditCardRepayments.filter {
            $0.deletedAt == nil &&
                $0.creditCardId == card.id &&
                !excludingRepaymentIds.contains($0.id)
        }
        let repayments = cardRepayments
            .filter { isCurrentTransaction($0.date) }
            .map {
                CreditCardBalanceHistoryEntry(
                    id: "current-repayment-\($0.id)",
                    title: $0.note.isBlank ? "Card payment" : $0.note,
                    date: $0.date,
                    amountPence: -$0.amountPence,
                    kind: .repayment,
                    editTarget: .repayment($0.id)
                )
            }
        let repaymentRefunds = cardRepayments.compactMap { repayment -> CreditCardBalanceHistoryEntry? in
            guard repayment.hasRefund,
                  let refundedAt = repayment.refundedAt
            else { return nil }
            let refundDate = String(refundedAt.prefix(10))
            guard FinanceEngine.isIsoDate(refundDate), isCurrentTransaction(refundDate) else { return nil }
            return CreditCardBalanceHistoryEntry(
                id: "current-repayment-refund-\(repayment.id)-\(refundDate)",
                title: "\(repayment.note.isBlank ? "Card payment" : repayment.note) returned",
                date: refundDate,
                amountPence: repayment.effectiveRefundedAmountPence,
                kind: .repaymentRefund,
                editTarget: .repayment(repayment.id)
            )
        }

        return (charges + refunds + repayments + repaymentRefunds).sorted(by: entrySort)
    }

    private static func statementSection(
        statement: CreditCardStatementSummary,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> CreditCardBalanceHistorySection {
        var entries = statement.transactions.map { transaction in
            CreditCardBalanceHistoryEntry(
                id: "statement-\(statement.id)-\(transaction.id)",
                title: transaction.name,
                date: transaction.date,
                amountPence: transaction.amountPence,
                kind: entryKind(for: transaction.source),
                editTarget: editTarget(
                    for: transaction,
                    cardId: statement.cardId,
                    snapshot: snapshot
                )
            )
        }

        if statement.reconciliationAdjustmentPence != 0 {
            entries.append(
                CreditCardBalanceHistoryEntry(
                    id: "statement-adjustment-\(statement.id)",
                    title: "Unitemised statement amount",
                    date: statement.statementDate,
                    amountPence: statement.reconciliationAdjustmentPence,
                    kind: .reconciliationAdjustment,
                    editTarget: .statement(
                        cardId: statement.cardId,
                        scheduledStatementDate: statement.scheduledStatementDate
                    )
                )
            )
        }

        let repayments = matchedRepayments(for: statement, snapshot: snapshot, asOfDate: asOfDate)

        for repayment in repayments {
            entries.append(
                CreditCardBalanceHistoryEntry(
                    id: "statement-repayment-\(statement.id)-\(repayment.id)",
                    title: repayment.note.isBlank ? "Card payment" : repayment.note,
                    date: repayment.date,
                    amountPence: -repayment.amountPence,
                    kind: .repayment,
                    editTarget: .repayment(repayment.id)
                )
            )
            if repayment.hasRefund,
               let refundedAt = repayment.refundedAt {
                let refundDate = String(refundedAt.prefix(10))
                if FinanceEngine.isIsoDate(refundDate), refundDate <= asOfDate {
                    entries.append(
                        CreditCardBalanceHistoryEntry(
                            id: "statement-repayment-refund-\(statement.id)-\(repayment.id)-\(refundDate)",
                            title: "\(repayment.note.isBlank ? "Card payment" : repayment.note) returned",
                            date: refundDate,
                            amountPence: repayment.effectiveRefundedAmountPence,
                            kind: .repaymentRefund,
                            editTarget: .repayment(repayment.id)
                        )
                    )
                }
            }
        }

        return CreditCardBalanceHistorySection(
            id: "statement-\(statement.id)",
            title: "\(processedDate(statement.statementDate)) processed",
            subtitle: statementStatusLabel(statement.status),
            balancePence: statement.statementAmountPence,
            statementDate: statement.statementDate,
            directDebitDate: statement.directDebitDate,
            status: statement.status,
            entries: entries.sorted(by: entrySort)
        )
    }

    private static func matchedRepayments(
        for statement: CreditCardStatementSummary,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> [CreditCardRepayment] {
        snapshot.creditCardRepayments.filter { repayment in
            guard repayment.deletedAt == nil,
                  repayment.creditCardId == statement.cardId,
                  repayment.date <= asOfDate
            else { return false }

            if let repaymentStatementDate = repayment.statementDate {
                return repaymentStatementDate == statement.scheduledStatementDate ||
                    repaymentStatementDate == statement.statementDate
            }
            return repayment.date > statement.statementDate && repayment.date <= statement.directDebitDate
        }
    }

    private static func entryKind(for source: CreditCardStatementTransactionSource) -> CreditCardBalanceHistoryEntryKind {
        switch source {
        case .openingStatement:
            .openingBalance
        case .spending, .recurring, .custom:
            .charge
        case .refund:
            .refund
        }
    }

    private static func editTarget(
        for statementTransaction: CreditCardStatementTransaction,
        cardId: String,
        snapshot: PlannerSnapshot
    ) -> CreditCardBalanceHistoryEditTarget {
        if let transaction = snapshot.transactions.first(where: {
            $0.deletedAt == nil && $0.id == statementTransaction.id
        }) {
            return transactionEditTarget(for: transaction, snapshot: snapshot)
        }
        if statementTransaction.source == .refund,
           let transaction = snapshot.transactions.first(where: { transaction in
            guard transaction.deletedAt == nil,
                     let refundedAt = transaction.refundedAt
               else { return false }
               let refundDate = String(refundedAt.prefix(10))
               guard FinanceEngine.isIsoDate(refundDate) else { return false }
               return "refund-\(transaction.id)-\(refundDate)" == statementTransaction.id
           }) {
            return transactionEditTarget(for: transaction, snapshot: snapshot)
        }
        return .card(cardId)
    }

    static func transactionEditTarget(
        for transaction: Transaction,
        snapshot: PlannerSnapshot
    ) -> CreditCardBalanceHistoryEditTarget {
        guard let paymentId = transaction.recurringPaymentId else {
            return .transaction(transaction.id)
        }

        for prefix in ["card-recurring-\(paymentId)-", "recurring-\(paymentId)-"]
        where transaction.id.hasPrefix(prefix) {
            let scheduledDueDate = String(transaction.id.dropFirst(prefix.count))
            if FinanceEngine.isIsoDate(scheduledDueDate) {
                return .recurring(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
            }
        }

        let scheduledDueDate = snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil &&
                $0.paymentId == paymentId &&
                ($0.actualDueDate == transaction.date || $0.scheduledDueDate == transaction.date)
        }?.scheduledDueDate ?? transaction.date
        return .recurring(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
    }

    private static func entrySort(_ lhs: CreditCardBalanceHistoryEntry, _ rhs: CreditCardBalanceHistoryEntry) -> Bool {
        if lhs.date == rhs.date { return lhs.id < rhs.id }
        return lhs.date < rhs.date
    }

    private static func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }

    private static func processedDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.wide))
    }

    private static func statementStatusLabel(_ status: CreditCardStatementStatus) -> String {
        switch status {
        case .upcoming:
            ""
        case .paid:
            "Paid"
        case .overdue:
            "Overdue"
        case .awaitingConfirmation:
            "Awaiting confirmation"
        }
    }
}

private enum CardDetailTab {
    case overview
    case balanceHistory
}

enum CardLinkedRowDestination: Equatable, Identifiable {
    case recurring(paymentId: String, scheduledDueDate: String)
    case customPayment(String)
    case pot(String)
    case coverPot(String)
    case transaction(String)
    case repayment(String)

    var id: String {
        switch self {
        case .recurring(let paymentId, let scheduledDueDate): "recurring-\(paymentId)-\(scheduledDueDate)"
        case .customPayment(let id): "custom-\(id)"
        case .pot(let id): "pot-\(id)"
        case .coverPot(let id): "cover-pot-\(id)"
        case .transaction(let id): "transaction-\(id)"
        case .repayment(let id): "repayment-\(id)"
        }
    }
}

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: PlannerStore
    var card: CreditCard
    @State private var selectedTab: CardDetailTab = .overview
    @State private var isHistoryExpanded = true
    @State private var isCardPaymentPresented = false
    @State private var isCycleAdjustmentPresented = false
    @State private var isCardEditPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var balanceHistoryEditTarget: CreditCardBalanceHistoryEditTarget?
    @State private var linkedRowDestination: CardLinkedRowDestination?
    @State private var selectedStatementSection: CreditCardBalanceHistorySection?

    private var currentCard: CreditCard {
        store.snapshot.creditCards.first(where: { $0.id == card.id }) ?? card
    }

    private var cardAvailability: CreditCardAvailabilitySummary {
        PlannerDerivedData.creditCardAvailabilitySummary(
            card: currentCard,
            snapshot: store.snapshot,
            payPeriod: store.selectedPayPeriod,
            asOfDate: store.todayIso
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .balanceHistory:
                        balanceHistoryContent
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .transition(.opacity)
            }
            .premiumScreenBackground()
            .navigationTitle(currentCard.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(id: CardsLayoutPolicy.balanceHistoryToolbarActionId, placement: .topBarTrailing) {
                    Button(action: toggleBalanceHistory) {
                        Image(systemName: selectedTab == .balanceHistory ? "creditcard" : CardsLayoutPolicy.balanceHistoryToolbarSymbol)
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel(selectedTab == .balanceHistory ? "Show card overview" : "Show balance history")
                    .accessibilityHint("Switches between the card overview and its statement-grouped balance ledger")
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(id: CardsLayoutPolicy.detailToolbarActionId, placement: .topBarTrailing) {
                    Button {
                        isCardPaymentPresented = true
                    } label: {
                        Text(CardsLayoutPolicy.detailToolbarTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel("Add Card Payment")
                }
            }
            .sheet(isPresented: $isCardPaymentPresented) {
                CardPaymentFlowSheetView(store: store, initialCardId: currentCard.id)
            }
            .sheet(isPresented: $isCycleAdjustmentPresented) {
                CreditCardCycleAdjustmentSheet(store: store, card: currentCard)
            }
            .sheet(isPresented: $isCardEditPresented) {
                CreditCardEditFormView(store: store, card: currentCard)
            }
            .sheet(item: $balanceHistoryEditTarget) { target in
                CreditCardBalanceHistoryEditorSheet(store: store, target: target)
            }
            .sheet(item: $linkedRowDestination) { destination in
                CardLinkedRecordEditorSheet(store: store, destination: destination)
            }
            .sheet(item: $selectedStatementSection) { section in
                CreditCardStatementDetailEditorView(
                    store: store,
                    cardId: currentCard.id,
                    scheduledStatementDate: section.statementDate ?? store.todayIso
                )
            }
        }
    }

    private var overviewContent: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Button {
                isCardEditPresented = true
            } label: {
                CreditCardRow(
                    card: currentCard,
                    balancePence: PlannerDerivedData.cardBalance(card: currentCard, snapshot: store.snapshot),
                    availability: cardAvailability,
                    showsTitle: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(currentCard.name)")
            .accessibilityHint("Opens the card details editor")
            .accessibilityIdentifier("edit-credit-card-\(currentCard.id)")
            statementSummaryCard
            linkedSection
            historySection
            SecondaryButton(title: "Delete card", systemImage: "trash", role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            .confirmationDialog(
                "Delete \(currentCard.name)?",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Delete card", role: .destructive, action: deleteCard)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the card and its saved details from New Money.")
            }
        }
    }

    private var balanceHistoryContent: some View {
        let history = CreditCardBalanceHistoryData.make(
            card: currentCard,
            snapshot: store.snapshot,
            asOfDate: store.todayIso
        )

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Balance ledger")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.cardEyebrow)
                    .textCase(.uppercase)
                Text(MoneyParser.formatPence(history.currentBalancePence))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Every recorded movement grouped by current balance and statement.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            CreditCardBalanceHistorySectionView(
                store: store,
                section: history.currentSection,
                onOpenStatement: {},
                onEdit: { balanceHistoryEditTarget = $0 }
            )

            if !history.statementSections.isEmpty {
                SectionTitle("Statements")
                ForEach(history.statementSections) { section in
                    CreditCardBalanceHistorySectionView(
                        store: store,
                        section: section,
                        onOpenStatement: { selectedStatementSection = section },
                        onEdit: { balanceHistoryEditTarget = $0 }
                    )
                }
            }
        }
        .accessibilityIdentifier("card-balance-history-\(currentCard.id)")
    }

    private func toggleBalanceHistory() {
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
        withAnimation(animation) {
            selectedTab = selectedTab == .overview ? .balanceHistory : .overview
        }
    }

    private var statementSummaryCard: some View {
        AppCard {
            SectionTitle("Statement")
            CreditMetricGrid(items: statementMetrics)
            if let cycleAdjustmentSummary, cycleAdjustmentSummary.isStatementHeld || cycleAdjustmentSummary.isDirectDebitHeld {
                Text("This cycle is on hold. New card spending is kept reserved until you confirm the bank dates.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.warning)
            }
            Button {
                isCycleAdjustmentPresented = true
            } label: {
                Label("Check this cycle", systemImage: "calendar.badge.exclamationmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.Colors.primaryOrange)
        }
    }

    private var linkedSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Linked to this card")
            if linkedRows.isEmpty {
                AppCard {
                    EmptyStateView(title: "Nothing linked", message: "Bills, one-off payments, and pots linked to this card will appear here.", systemImage: "link")
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(linkedRows.enumerated()), id: \.element.id) { index, row in
                        Button { linkedRowDestination = row.destination } label: {
                            CardPaymentAllocationRowCard(row: row)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this linked record for editing")
                        if index < linkedRows.count - 1 { AppDivider() }
                    }
                }
            }
        }
    }

    private var historySection: some View {
        DisclosureGroup(isExpanded: $isHistoryExpanded) {
            if historyRows.isEmpty {
                AppCard {
                    EmptyStateView(title: "No card history", message: "Charges, payments, cover pots, and card spending will appear here.", systemImage: "clock.arrow.circlepath")
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(historyRows.enumerated()), id: \.element.id) { index, row in
                        Button { linkedRowDestination = row.destination } label: {
                            CardPaymentAllocationRowCard(row: row)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this card history record for editing")
                        if index < historyRows.count - 1 { AppDivider() }
                    }
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
        } label: {
            SectionTitle("Card history")
        }
        .tint(AppTheme.Colors.primaryOrange)
    }

    private var linkedRows: [CardPaymentAllocationRow] {
        let recurring = store.snapshot.recurringPayments
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "linked-recurring-\(payment.id)",
                    title: payment.name,
                    detail: recurringLinkedDetail(payment),
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.warning,
                    context: "Bill",
                    symbol: "calendar.badge.clock",
                    sortDate: recurringSortDate(payment),
                    destination: .recurring(paymentId: payment.id, scheduledDueDate: payment.dueDate ?? store.todayIso)
                )
            }

        let custom = store.snapshot.customPayments
            .filter { $0.deletedAt == nil && $0.status != .archived && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "linked-custom-\(payment.id)",
                    title: payment.name,
                    detail: friendlyDate(payment.dueDate),
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.primaryOrange,
                    context: "One-off",
                    symbol: "calendar.badge.plus",
                    sortDate: payment.dueDate,
                    destination: .customPayment(payment.id)
                )
            }

        let linkedPots = store.snapshot.pots
            .filter { !$0.archived && $0.linkedCreditCardId == currentCard.id }
            .map { pot in
                CardPaymentAllocationRow(
                    id: "linked-pot-\(pot.id)",
                    title: pot.name,
                    detail: "\(pot.type.rawValue.capitalized) pot",
                    amount: MoneyParser.formatPence(pot.balancePence),
                    amountColor: AppTheme.Colors.primaryOrange,
                    context: "Pot",
                    symbol: "wallet.pass",
                    sortDate: String(pot.updatedAt.prefix(10)),
                    destination: .pot(pot.id)
                )
            }

        let coverPots = store.snapshot.creditCardPots
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id && $0.status == .active }
            .map { pot in
                CardPaymentAllocationRow(
                    id: "linked-cover-\(pot.id)",
                    title: pot.name,
                    detail: coverPotSourceLabel(pot.source),
                    amount: MoneyParser.formatPence(pot.amountPence),
                    amountColor: AppTheme.Colors.success,
                    context: "Cover pot",
                    symbol: "wallet.pass",
                    sortDate: creditCardPotDate(pot),
                    destination: .coverPot(pot.id)
                )
            }

        return (recurring + custom + linkedPots + coverPots).sorted { $0.sortDate > $1.sortDate }
    }

    private var historyRows: [CardPaymentAllocationRow] {
        let recurring = store.snapshot.recurringPayments
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "history-recurring-\(payment.id)",
                    title: payment.name,
                    detail: "\(payment.frequency.rawValue.capitalized) · \(payment.dueDay.map { "Day \($0)" } ?? "No due day")",
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.warning,
                    context: "Bill",
                    symbol: "calendar.badge.clock",
                    sortDate: recurringSortDate(payment),
                    destination: .recurring(paymentId: payment.id, scheduledDueDate: payment.dueDate ?? store.todayIso)
                )
            }

        let custom = store.snapshot.customPayments
            .filter { $0.deletedAt == nil && $0.status != .archived && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "history-custom-\(payment.id)",
                    title: payment.name,
                    detail: friendlyDate(payment.dueDate),
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.primaryOrange,
                    context: "One-off",
                    symbol: "calendar.badge.plus",
                    sortDate: payment.dueDate,
                    destination: .customPayment(payment.id)
                )
            }

        let spending = store.snapshot.transactions
            .filter { $0.deletedAt == nil && $0.type == .spending && $0.creditCardId == currentCard.id }
            .map { transaction in
                CardPaymentAllocationRow(
                    id: "history-spending-\(transaction.id)",
                    title: transaction.note.isBlank ? "Card spending" : transaction.note,
                    detail: friendlyDate(transaction.date),
                    amount: "-\(MoneyParser.formatPence(transaction.amountPence))",
                    amountColor: AppTheme.Colors.orangeHighlight,
                    context: "Spending",
                    symbol: "receipt",
                    sortDate: transaction.date,
                    destination: .transaction(transaction.id)
                )
            }

        let refunds = store.snapshot.transactions
            .filter {
                $0.deletedAt == nil &&
                    $0.type == .spending &&
                    $0.creditCardId == currentCard.id &&
                    $0.hasRefund
            }
            .compactMap { transaction -> CardPaymentAllocationRow? in
                guard let refundedAt = transaction.refundedAt else { return nil }
                let refundDate = String(refundedAt.prefix(10))
                guard FinanceEngine.isIsoDate(refundDate) else { return nil }
                let transactionName = transaction.note.isBlank ? "Card spending" : transaction.note
                return CardPaymentAllocationRow(
                    id: "history-refund-\(transaction.id)-\(refundDate)",
                    title: "\(transactionName) refund",
                    detail: friendlyDate(refundDate),
                    amount: "+\(MoneyParser.formatPence(transaction.effectiveRefundedAmountPence))",
                    amountColor: AppTheme.Colors.success,
                    context: "Refund",
                    symbol: "arrow.uturn.backward.circle.fill",
                    sortDate: refundDate,
                    destination: .transaction(transaction.id)
                )
            }

        let repayments = store.snapshot.creditCardRepayments
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { repayment in
                CardPaymentAllocationRow(
                    id: "history-repayment-\(repayment.id)",
                    title: repayment.note.isBlank ? "Card payment" : repayment.note,
                    detail: friendlyDate(repayment.date),
                    amount: MoneyParser.formatPence(repayment.netAmountPence),
                    amountColor: AppTheme.Colors.success,
                    context: "Payment",
                    symbol: "arrow.down.circle",
                    sortDate: repayment.date,
                    destination: .repayment(repayment.id)
                )
            }

        let coverPots = store.snapshot.creditCardPots
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { pot in
                CardPaymentAllocationRow(
                    id: "history-cover-\(pot.id)",
                    title: pot.name,
                    detail: "\(friendlyDate(creditCardPotDate(pot))) · \(coverPotSourceLabel(pot.source))",
                    amount: "-\(MoneyParser.formatPence(pot.amountPence))",
                    amountColor: AppTheme.Colors.success,
                    context: "Cover pot",
                    symbol: "wallet.pass",
                    sortDate: creditCardPotDate(pot),
                    destination: .coverPot(pot.id)
                )
            }

        return (recurring + custom + spending + refunds + repayments + coverPots).sorted { $0.sortDate > $1.sortDate }
    }

    private func recurringSortDate(_ payment: RecurringPayment) -> String {
        payment.dueDate ?? "9999-12-\(String(format: "%02d", payment.dueDay ?? 1))"
    }

    private func recurringLinkedDetail(_ payment: RecurringPayment) -> String {
        var parts = [payment.frequency.rawValue.capitalized, payment.dueDay.map { "Day \($0)" } ?? "No due day"]
        if let potId = payment.potId,
           let pot = store.snapshot.pots.first(where: { $0.id == potId }) {
            parts.append(pot.name)
        }
        return parts.joined(separator: " · ")
    }

    private func creditCardPotDate(_ pot: CreditCardPot) -> String {
        pot.payday ?? pot.periodStartDate ?? String(pot.createdAt.prefix(10))
    }

    private func coverPotSourceLabel(_ source: CreditCardPotSource) -> String {
        switch source {
        case .paycheck:
            return "Paycheck cover"
        case .external:
            return "External cover"
        }
    }

    private var statementDayLabel: String {
        guard let statementDate = currentCard.statementDate else { return "Not set" }
        let day = Calendar.current.component(.day, from: FinanceEngine.parseDate(statementDate))
        return "Day \(day)"
    }

    private var nextStatementDate: String? {
        PlannerDerivedData.creditCardNextStatementDate(
            card: currentCard,
            snapshot: store.snapshot,
            asOfDate: store.todayIso
        )
    }

    private var statementSummaries: [CreditCardStatementSummary] {
        PlannerDerivedData.creditCardStatementSummaries(
            snapshot: store.snapshot,
            asOfDate: store.todayIso
        )
        .filter { $0.cardId == currentCard.id }
    }

    private var activeStatementSummary: CreditCardStatementSummary? {
        if let scheduledStatementDate = cycleAdjustmentSummary?.scheduledStatementDate,
           let summary = statementSummaries.first(where: { $0.scheduledStatementDate == scheduledStatementDate }) {
            return summary
        }

        return statementSummaries.first {
            $0.statementDate <= store.todayIso && $0.status != .paid
        } ?? statementSummaries.first { $0.statementDate <= store.todayIso }
    }

    private var currentStatementDate: String? {
        guard let statementDate = activeStatementSummary?.statementDate,
              statementDate <= store.todayIso else {
            return nil
        }

        return statementDate
    }

    private var nextDirectDebitDate: String? {
        activeStatementSummary?.directDebitDate ?? cycleAdjustmentSummary?.directDebitDate ?? nextStatementPayment?.directDebitDate
    }

    private var cycleAdjustmentSummary: CreditCardCycleAdjustmentSummary? {
        PlannerDerivedData.creditCardCycleAdjustmentSummary(
            card: currentCard,
            snapshot: store.snapshot,
            asOfDate: store.todayIso
        )
    }

    private var nextStatementPayment: CreditCardStatementPayment? {
        PlannerDerivedData.creditCardStatementPayments(
            card: currentCard,
            snapshot: store.snapshot,
            startDate: store.todayIso,
            endDate: FinanceEngine.addIsoDays(date: store.todayIso, days: 90),
            asOfDate: store.todayIso
        )
        .first
    }

    private var displayedStatementDuePence: Int {
        activeStatementSummary?.unpaidAmountPence ?? nextStatementPayment?.forecastDuePence ?? 0
    }

    private var statementDueLabel: String {
        activeStatementSummary == nil
            ? CardsLayoutPolicy.forecastStatementDueTitle
            : CardsLayoutPolicy.currentStatementDueTitle
    }

    private var statementMetrics: [CreditMetricGrid.Item] {
        var items = [
            CreditMetricGrid.Item(label: "Statement day", value: statementDayLabel)
        ]

        if let currentStatementDate {
            items.append(.init(label: "Current statement", value: friendlyDate(currentStatementDate)))
        }

        items.append(.init(label: "Next statement", value: nextStatementDate.map(friendlyDate) ?? "Not set"))
        items.append(.init(label: "Direct debit", value: nextDirectDebitDate.map(friendlyDate) ?? "Not set"))
        items.append(
            .init(
                label: statementDueLabel,
                value: MoneyParser.formatPence(displayedStatementDuePence),
                valueColor: displayedStatementDuePence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.secondaryText
            )
        )

        if heldCycleReservePence > 0 {
            items.append(
                .init(
                    label: "Held cycle reserve",
                    value: MoneyParser.formatPence(heldCycleReservePence),
                    valueColor: AppTheme.Colors.warning
                )
            )
        }

        items.append(
            .init(
                label: cardAvailability.actualAvailablePence < 0 ? "Over limit" : "Available",
                value: MoneyParser.formatPence(abs(cardAvailability.actualAvailablePence)),
                valueColor: cardAvailability.actualAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success
            )
        )

        if cardAvailability.forecastAvailablePence != cardAvailability.actualAvailablePence {
            items.append(
                .init(
                    label: cardAvailability.forecastAvailablePence < 0 ? "Forecast over limit" : "Forecast availability",
                    value: MoneyParser.formatPence(abs(cardAvailability.forecastAvailablePence)),
                    valueColor: cardAvailability.forecastAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning
                )
            )
        }

        items.append(
            .init(
                label: "Linked pot cover",
                value: MoneyParser.formatPence(linkedPotCoverPence),
                valueColor: AppTheme.Colors.primaryOrange
            )
        )
        return items
    }

    private var heldCycleReservePence: Int {
        PlannerDerivedData.creditCardHeldCycleReservePence(card: currentCard, snapshot: store.snapshot, asOfDate: store.todayIso)
    }

    private var linkedPotCoverPence: Int {
        FinanceEngine.getLinkedCreditCardPotPence(pots: store.snapshot.pots, creditCardId: currentCard.id)
    }

    private func deleteCard() {
        store.deleteCreditCard(id: currentCard.id)
        dismiss()
    }

    private func friendlyDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct CreditCardBalanceHistorySectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: PlannerStore
    var section: CreditCardBalanceHistorySection
    var onOpenStatement: () -> Void
    var onEdit: (CreditCardBalanceHistoryEditTarget) -> Void
    @State private var isExpanded: Bool

    init(
        store: PlannerStore,
        section: CreditCardBalanceHistorySection,
        onOpenStatement: @escaping () -> Void,
        onEdit: @escaping (CreditCardBalanceHistoryEditTarget) -> Void
    ) {
        self.store = store
        self.section = section
        self.onOpenStatement = onOpenStatement
        self.onEdit = onEdit
        _isExpanded = State(
            initialValue: section.statementDate == nil || CardsLayoutPolicy.balanceHistoryStatementsDefaultExpanded
        )
    }

    var body: some View {
        AppCard {
            if section.statementDate == nil {
                header
            } else {
                HStack(spacing: 0) {
                    Button(action: onOpenStatement) {
                        header
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(statementAccessibilityLabel)")
                    .accessibilityHint("Opens the complete statement and all editable movements")

                    Button(action: toggleExpanded) {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse statement" : "Expand statement")
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    if section.entries.isEmpty {
                        Text("No recorded movements")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    } else {
                        ForEach(section.entries) { entry in
                            AppDivider()
                            if let editTarget = entry.editTarget {
                                Button {
                                    onEdit(editTarget)
                                } label: {
                                    CreditCardBalanceHistoryEntryRow(
                                        entry: entry,
                                        showsEditIndicator: true,
                                        auditAction: auditAction(for: entry.editTarget)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens this movement for editing")
                                .accessibilityIdentifier("card-balance-entry-\(entry.id)")
                            } else {
                                CreditCardBalanceHistoryEntryRow(entry: entry, showsEditIndicator: false, auditAction: nil)
                                    .accessibilityIdentifier("card-balance-entry-\(entry.id)")
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                if !section.subtitle.isBlank {
                    Text(section.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            VStack(alignment: .trailing, spacing: 3) {
                Text(MoneyParser.formatPence(section.balancePence))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(section.balancePence > 0 ? AppTheme.Colors.primaryText : AppTheme.Colors.success)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let directDebitDate = section.directDebitDate {
                    Text("Due \(compactDate(directDebitDate))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func toggleExpanded() {
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
        withAnimation(animation) {
            isExpanded.toggle()
        }
    }

    private var statementAccessibilityLabel: String {
        var parts = [section.title, MoneyParser.formatPence(section.balancePence)]
        if let directDebitDate = section.directDebitDate {
            parts.append("Due \(compactDate(directDebitDate))")
        }
        parts.append(isExpanded ? "Expanded" : "Collapsed")
        return parts.joined(separator: ", ")
    }

    private func compactDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
    }

    private var statusColor: Color {
        switch section.status {
        case .paid:
            AppTheme.Colors.success
        case .overdue:
            AppTheme.Colors.danger
        case .upcoming, .awaitingConfirmation:
            AppTheme.Colors.warning
        case nil:
            AppTheme.Colors.secondaryText
        }
    }

    private func auditAction(for target: CreditCardBalanceHistoryEditTarget?) -> PlannerAuditAction? {
        guard let target else { return nil }
        switch target {
        case .transaction(let id):
            return store.auditAction(for: .transaction, id: id)
        case .recurring(let paymentId, _):
            return store.auditAction(for: .recurringPayment, id: paymentId)
        case .repayment(let id):
            return store.auditAction(for: .creditCardRepayment, id: id)
        case .card(let id):
            return store.auditAction(for: .creditCard, id: id)
        case .statement(let cardId, let scheduledStatementDate):
            return store.snapshot.auditEvents.reversed().first { event in
                event.action != .baseline && event.changes.contains { change in
                    guard change.recordKind == .creditCardCycle,
                          let json = change.afterJSON ?? change.beforeJSON,
                          let cycle = PlannerAuditEngine.decode(CreditCardCycleOverride.self, json: json)
                    else { return false }
                    return cycle.creditCardId == cardId && cycle.scheduledStatementDate == scheduledStatementDate
                }
            }?.action
        }
    }
}

struct CreditCardBalanceHistoryEntryRow: View {
    var entry: CreditCardBalanceHistoryEntry
    var showsEditIndicator: Bool
    var auditAction: PlannerAuditAction?

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(symbolColor)
                .frame(width: 28, height: 28)
                .background(symbolColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    if let auditAction {
                        HistoryAuditStatusPill(action: auditAction)
                    }
                }
                Text(fullDate(entry.date))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Text(signedMoney(entry.amountPence))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if showsEditIndicator {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .frame(width: 20, height: 44, alignment: .center)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch entry.kind {
        case .openingBalance:
            "arrow.turn.down.right"
        case .statementBalance:
            "doc.text"
        case .charge:
            "creditcard"
        case .refund:
            "arrow.uturn.backward.circle.fill"
        case .repayment:
            "arrow.down.circle"
        case .repaymentRefund:
            "arrow.uturn.up.circle"
        case .reconciliationAdjustment:
            "equal.circle"
        }
    }

    private var symbolColor: Color {
        switch entry.kind {
        case .refund, .repayment:
            AppTheme.Colors.success
        case .repaymentRefund, .reconciliationAdjustment:
            entry.amountPence < 0 ? AppTheme.Colors.success : AppTheme.Colors.warning
        case .openingBalance, .statementBalance, .charge:
            AppTheme.Colors.primaryOrange
        }
    }

    private var amountColor: Color {
        entry.amountPence < 0 ? AppTheme.Colors.success : AppTheme.Colors.primaryText
    }

    private func signedMoney(_ amountPence: Int) -> String {
        if amountPence < 0 {
            return "-\(MoneyParser.formatPence(abs(amountPence)))"
        }
        if amountPence > 0 {
            return "+\(MoneyParser.formatPence(amountPence))"
        }
        return MoneyParser.formatPence(0)
    }

    private func fullDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct CreditCardStatementDetailEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var cardId: String
    var scheduledStatementDate: String
    @State private var editTarget: CreditCardBalanceHistoryEditTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    if let section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Statement")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.cardEyebrow)
                                .textCase(.uppercase)
                            Text(section.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                            HStack(alignment: .firstTextBaseline) {
                                Text(MoneyParser.formatPence(section.balancePence))
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Spacer()
                                if let directDebitDate = section.directDebitDate {
                                    Text("Due \(compactDate(directDebitDate))")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                            }
                        }

                        if let statementTarget {
                            SecondaryButton(title: "Edit statement total", systemImage: "pencil") {
                                editTarget = statementTarget
                            }
                        }

                        SectionTitle("Every statement movement")
                        AppCard {
                            if section.entries.isEmpty {
                                EmptyStateView(
                                    title: "No statement movements",
                                    message: "Payments and adjustments included in this locked statement appear here.",
                                    systemImage: "doc.text"
                                )
                            } else {
                                ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                    if let target = entry.editTarget {
                                        Button {
                                            editTarget = target
                                        } label: {
                                            CreditCardBalanceHistoryEntryRow(
                                                entry: entry,
                                                showsEditIndicator: true,
                                                auditAction: auditAction(for: target)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityHint("Opens this statement movement for editing")
                                    } else {
                                        CreditCardBalanceHistoryEntryRow(entry: entry, showsEditIndicator: false, auditAction: nil)
                                    }
                                    if index < section.entries.count - 1 { AppDivider() }
                                }
                            }
                        }
                    } else {
                        AppCard {
                            EmptyStateView(
                                title: "Statement unavailable",
                                message: "This statement could not be rebuilt from the current ledger.",
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Statement")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $editTarget) { target in
                CreditCardBalanceHistoryEditorSheet(store: store, target: target)
            }
        }
    }

    private var section: CreditCardBalanceHistorySection? {
        guard let card = store.snapshot.creditCards.first(where: { $0.id == cardId }) else { return nil }
        return CreditCardBalanceHistoryData.make(card: card, snapshot: store.snapshot, asOfDate: store.todayIso)
            .statementSections
            .first { $0.statementDate == scheduledStatementDate }
    }

    private var statementTarget: CreditCardBalanceHistoryEditTarget? {
        section?.entries.compactMap(\.editTarget).first {
            if case .statement = $0 { return true }
            return false
        }
    }

    private func auditAction(for target: CreditCardBalanceHistoryEditTarget) -> PlannerAuditAction? {
        switch target {
        case .transaction(let id): store.auditAction(for: .transaction, id: id)
        case .recurring(let id, _): store.auditAction(for: .recurringPayment, id: id)
        case .repayment(let id): store.auditAction(for: .creditCardRepayment, id: id)
        case .card(let id): store.auditAction(for: .creditCard, id: id)
        case .statement:
            store.snapshot.auditEvents.reversed().first { event in
                event.action != .baseline && event.changes.contains { $0.recordKind == .creditCardCycle }
            }?.action
        }
    }

    private func compactDate(_ value: String) -> String {
        FinanceEngine.parseDate(value).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

struct CreditCardBalanceHistoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var target: CreditCardBalanceHistoryEditTarget

    @ViewBuilder
    var body: some View {
        switch target {
        case .transaction(let id):
            if let transaction = store.snapshot.transactions.first(where: { $0.id == id && $0.deletedAt == nil }) {
                NavigationStack {
                    SpendingTransactionDetailView(store: store, transaction: transaction)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                            }
                        }
                }
            } else {
                missingRecord
            }
        case .recurring(let paymentId, let scheduledDueDate):
            if store.snapshot.recurringPayments.contains(where: { $0.id == paymentId && $0.deletedAt == nil }) {
                CreditCardRecurringOccurrenceEditorView(
                    store: store,
                    paymentId: paymentId,
                    scheduledDueDate: scheduledDueDate
                )
            } else {
                missingRecord
            }
        case .repayment(let id):
            if let repayment = store.snapshot.creditCardRepayments.first(where: { $0.id == id && $0.deletedAt == nil }) {
                NavigationStack {
                    CardRepaymentDetailView(store: store, repayment: repayment)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                            }
                        }
                }
            } else {
                missingRecord
            }
        case .statement(let cardId, let scheduledStatementDate):
            CreditCardStatementLedgerEditorView(
                store: store,
                cardId: cardId,
                scheduledStatementDate: scheduledStatementDate
            )
        case .card(let id):
            if let card = store.snapshot.creditCards.first(where: { $0.id == id && $0.deletedAt == nil }) {
                CreditCardEditFormView(store: store, card: card)
            } else {
                missingRecord
            }
        }
    }

    private var missingRecord: some View {
        NavigationStack {
            ContentUnavailableView(
                "Movement unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("This record is no longer available to edit.")
            )
            .premiumScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct CreditCardRecurringOccurrenceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var paymentId: String
    var scheduledDueDate: String
    @State private var amount: String
    @State private var date: Date
    @State private var refundEnabled: Bool
    @State private var refundAmount: String

    init(store: PlannerStore, paymentId: String, scheduledDueDate: String) {
        self.store = store
        self.paymentId = paymentId
        self.scheduledDueDate = scheduledDueDate
        let payment = store.snapshot.recurringPayments.first { $0.id == paymentId }
        let override = store.snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil && $0.paymentId == paymentId && $0.scheduledDueDate == scheduledDueDate
        }
        let grossAmountPence = override?.amountPenceOverride ?? payment?.amountPence ?? 0
        let refundedAmountPence = override?.effectiveRefundedAmountPence(originalAmountPence: grossAmountPence) ?? 0
        _amount = State(initialValue: RefundAmountEditor.inputValue(for: grossAmountPence))
        _date = State(initialValue: FinanceEngine.parseDate(override?.actualDueDate ?? scheduledDueDate))
        _refundEnabled = State(initialValue: refundedAmountPence > 0)
        _refundAmount = State(initialValue: RefundAmountEditor.inputValue(for: refundedAmountPence > 0 ? refundedAmountPence : grossAmountPence))
    }

    private var payment: RecurringPayment? {
        store.snapshot.recurringPayments.first { $0.id == paymentId && $0.deletedAt == nil }
    }

    private var occurrenceOverride: RecurringPaymentOccurrenceOverride? {
        store.snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil && $0.paymentId == paymentId && $0.scheduledDueDate == scheduledDueDate
        }
    }

    private var grossAmountPence: Int {
        occurrenceOverride?.amountPenceOverride ?? payment?.amountPence ?? 0
    }

    private var refundedAmountPence: Int {
        occurrenceOverride?.effectiveRefundedAmountPence(originalAmountPence: grossAmountPence) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment") {
                    LabeledContent("Bill", value: payment?.name ?? "Card payment")
                    LabeledContent("Scheduled", value: displayDate(scheduledDueDate))
                    MoneyField(title: "Amount", text: $amount)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if refundedAmountPence > 0 {
                    Section {
                        Text("Original payment editing is locked while a refund is recorded. Remove the refund first if the original details need changing.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.warning)
                    }
                }

                Section("Refund") {
                    RefundAmountEditor(
                        originalAmountPence: grossAmountPence,
                        isEnabled: $refundEnabled,
                        amount: $refundAmount
                    )
                    Button("Save refund") {
                        store.setRecurringBillOccurrenceRefundAmount(
                            paymentId: paymentId,
                            scheduledDueDate: scheduledDueDate,
                            amountPence: refundEnabled ? MoneyParser.parsePoundsToPence(refundAmount) : 0
                        )
                        dismiss()
                    }
                    .disabled(!refundIsValid)
                }
            }
            .navigationTitle("Edit payment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setRecurringBillOccurrenceAmount(
                            paymentId: paymentId,
                            scheduledDueDate: scheduledDueDate,
                            amountPence: MoneyParser.parsePoundsToPence(amount)
                        )
                        store.confirmRecurringBillOccurrence(
                            paymentId: paymentId,
                            scheduledDueDate: scheduledDueDate,
                            actualDueDate: FinanceEngine.toIsoDate(date)
                        )
                        dismiss()
                    }
                    .disabled(refundedAmountPence > 0 || MoneyParser.parsePoundsToPence(amount) <= 0)
                }
            }
        }
    }

    private var refundIsValid: Bool {
        guard refundEnabled else { return refundedAmountPence > 0 }
        let refundPence = MoneyParser.parsePoundsToPence(refundAmount)
        return refundPence > 0 && refundPence <= grossAmountPence
    }

    private func displayDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct CreditCardStatementLedgerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var cardId: String
    var scheduledStatementDate: String
    @State private var amount: String
    @State private var statementDate: Date

    init(store: PlannerStore, cardId: String, scheduledStatementDate: String) {
        self.store = store
        self.cardId = cardId
        self.scheduledStatementDate = scheduledStatementDate
        let summary = PlannerDerivedData.creditCardStatementSummaries(
            snapshot: store.snapshot,
            asOfDate: store.todayIso
        ).first { $0.cardId == cardId && $0.scheduledStatementDate == scheduledStatementDate }
        _amount = State(initialValue: RefundAmountEditor.inputValue(for: summary?.statementAmountPence ?? 0))
        _statementDate = State(initialValue: FinanceEngine.parseDate(summary?.statementDate ?? scheduledStatementDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Statement") {
                    LabeledContent("Scheduled", value: displayDate(scheduledStatementDate))
                    DatePicker("Processed date", selection: $statementDate, displayedComponents: .date)
                    MoneyField(title: "Locked amount", text: $amount)
                }
                Section {
                    Text("Changing this bank statement updates the locked statement, direct-debit amount, card balance, and every derived total.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .navigationTitle("Edit statement")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setCreditCardCycleAmount(
                            cardId: cardId,
                            scheduledStatementDate: scheduledStatementDate,
                            amountPence: MoneyParser.parsePoundsToPence(amount)
                        )
                        store.confirmCreditCardStatement(
                            cardId: cardId,
                            scheduledStatementDate: scheduledStatementDate,
                            actualStatementDate: FinanceEngine.toIsoDate(statementDate)
                        )
                        dismiss()
                    }
                    .disabled(MoneyParser.parsePoundsToPence(amount) <= 0)
                }
            }
        }
    }

    private func displayDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private enum CreditCardCycleDateChoice: String, CaseIterable, Identifiable {
    case asExpected = "As expected"
    case awaiting = "Not yet"
    case actualDate = "Choose date"

    var id: String { rawValue }
}

struct CreditCardCycleAdjustmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var card: CreditCard
    var scheduledStatementDate: String?
    @State private var statementChoice: CreditCardCycleDateChoice
    @State private var directDebitChoice: CreditCardCycleDateChoice
    @State private var statementDate: Date
    @State private var directDebitDate: Date

    init(store: PlannerStore, card: CreditCard, scheduledStatementDate: String? = nil) {
        self.store = store
        self.card = card
        self.scheduledStatementDate = scheduledStatementDate
        let cycle = Self.resolveCycle(
            store: store,
            card: card,
            scheduledStatementDate: scheduledStatementDate
        )
        let override = cycle.flatMap { summary in
            store.snapshot.creditCardCycleOverrides.first {
                $0.deletedAt == nil && $0.creditCardId == card.id && $0.scheduledStatementDate == summary.scheduledStatementDate
            }
        }
        _statementChoice = State(initialValue: override?.statementState == .awaitingConfirmation ? .awaiting : (override?.statementState == .confirmed ? .actualDate : .asExpected))
        _directDebitChoice = State(initialValue: override?.directDebitState == .awaitingPayment ? .awaiting : (override?.directDebitState == .confirmed ? .actualDate : .asExpected))
        _statementDate = State(initialValue: FinanceEngine.parseDate(override?.actualStatementDate ?? cycle?.statementDate ?? store.todayIso))
        _directDebitDate = State(initialValue: FinanceEngine.parseDate(override?.actualDirectDebitDate ?? cycle?.directDebitDate ?? store.todayIso))
    }

    private var cycle: CreditCardCycleAdjustmentSummary? {
        Self.resolveCycle(store: store, card: card, scheduledStatementDate: scheduledStatementDate)
    }

    private static func resolveCycle(
        store: PlannerStore,
        card: CreditCard,
        scheduledStatementDate: String?
    ) -> CreditCardCycleAdjustmentSummary? {
        if let scheduledStatementDate,
           let statement = PlannerDerivedData.creditCardStatementSummaries(
               snapshot: store.snapshot,
               asOfDate: store.todayIso
           ).first(where: {
               $0.cardId == card.id && $0.scheduledStatementDate == scheduledStatementDate
           }) {
            let cycleOverride = store.snapshot.creditCardCycleOverrides.first {
                $0.deletedAt == nil &&
                    $0.creditCardId == card.id &&
                    $0.scheduledStatementDate == scheduledStatementDate
            }
            return CreditCardCycleAdjustmentSummary(
                scheduledStatementDate: scheduledStatementDate,
                statementDate: statement.statementDate,
                directDebitDate: statement.directDebitDate,
                isStatementHeld: cycleOverride?.statementState == .awaitingConfirmation,
                isDirectDebitHeld: cycleOverride?.directDebitState == .awaitingPayment
            )
        }
        return PlannerDerivedData.creditCardCycleAdjustmentSummary(
            card: card,
            snapshot: store.snapshot,
            asOfDate: store.todayIso
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This changes only this card cycle. Your usual statement and direct-debit days stay the same.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Button("Enable statement and direct-debit reminders") {
                        store.requestCreditCardCycleReminderPermission()
                    }
                }

                if let cycle {
                    Section("Statement") {
                        LabeledContent("Expected") { Text(displayDate(cycle.scheduledStatementDate)) }
                        Picker("Statement status", selection: $statementChoice) {
                            ForEach(CreditCardCycleDateChoice.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if statementChoice == .actualDate {
                            DatePicker("Statement date", selection: $statementDate, displayedComponents: .date)
                        }
                        if statementChoice == .awaiting {
                            Text("Automatic settlement is paused. Spending after the expected date remains reserved until you confirm it.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.warning)
                        }
                    }

                    Section("Direct debit") {
                        LabeledContent("Expected") { Text(displayDate(cycle.directDebitDate)) }
                        Picker("Direct debit status", selection: $directDebitChoice) {
                            ForEach(CreditCardCycleDateChoice.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if directDebitChoice == .actualDate {
                            DatePicker("Direct debit date", selection: $directDebitDate, displayedComponents: .date)
                        }
                        if directDebitChoice == .awaiting {
                            Text("Use this only when the bank has not taken the payment. Any app-generated payment for this cycle will be safely reversed and rescheduled.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.warning)
                        }
                    }
                } else {
                    ContentUnavailableView("Statement setup needed", systemImage: "calendar.badge.exclamationmark", description: Text("Add a statement day and direct-debit day before adjusting a cycle."))
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .navigationTitle("Check this cycle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(cycle == nil)
                }
            }
        }
    }

    private func save() {
        guard let cycle else { return }
        switch statementChoice {
        case .asExpected:
            store.clearCreditCardStatementAdjustment(cardId: card.id, scheduledStatementDate: cycle.scheduledStatementDate)
        case .awaiting:
            store.markCreditCardStatementAwaiting(cardId: card.id, scheduledStatementDate: cycle.scheduledStatementDate)
        case .actualDate:
            store.confirmCreditCardStatement(cardId: card.id, scheduledStatementDate: cycle.scheduledStatementDate, actualStatementDate: FinanceEngine.toIsoDate(statementDate))
        }
        switch directDebitChoice {
        case .asExpected:
            store.clearCreditCardDirectDebitAdjustment(cardId: card.id, scheduledStatementDate: cycle.scheduledStatementDate)
        case .awaiting:
            store.markCreditCardDirectDebitAwaiting(cardId: card.id, scheduledStatementDate: cycle.scheduledStatementDate)
        case .actualDate:
            store.confirmCreditCardDirectDebit(cardId: card.id, scheduledStatementDate: cycle.scheduledStatementDate, actualDirectDebitDate: FinanceEngine.toIsoDate(directDebitDate))
        }
    }

    private func displayDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

struct CardPaymentFlowSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var initialCardId: String? = nil
    @State private var repaymentCardId = ""
    @State private var repaymentAmount = ""
    @State private var repaymentDate = Date()
    @State private var repaymentNote = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    repaymentCard
                    if !cardRepayments.isEmpty {
                        AppCard {
                            SectionTitle("Recorded payments")
                            ForEach(cardRepayments) { repayment in
                                NavigationLink {
                                    CardRepaymentDetailView(store: store, repayment: repayment)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(repayment.note.isBlank ? "Card payment" : repayment.note)
                                                .foregroundStyle(AppTheme.Colors.primaryText)
                                            Text(cardRepaymentSubtitle(repayment))
                                                .font(.caption)
                                                .foregroundStyle(repayment.hasRefund ? AppTheme.Colors.success : AppTheme.Colors.secondaryText)
                                        }
                                        Spacer()
                                        Text(MoneyParser.formatPence(repayment.netAmountPence))
                                            .foregroundStyle(repayment.isRefunded ? AppTheme.Colors.tertiaryText : AppTheme.Colors.success)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Card payments")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if let initialCardId,
                   store.activeCards.contains(where: { $0.id == initialCardId }) {
                    repaymentCardId = initialCardId
                } else if repaymentCardId.isEmpty {
                    repaymentCardId = store.activeCards.first?.id ?? ""
                }
            }
        }
    }

    private var repaymentCard: some View {
        AppCard(glow: true) {
            SectionTitle("Record payment")
            Picker("Card", selection: $repaymentCardId) {
                Text("Choose card").tag("")
                ForEach(store.activeCards) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.primaryOrange)
            MoneyField(title: "Amount", text: $repaymentAmount)
            DatePicker("Date", selection: $repaymentDate, displayedComponents: .date)
                .tint(AppTheme.Colors.primaryOrange)
            TextField("Note", text: $repaymentNote).textFieldStyle(AppTextFieldStyle())
            PrimaryButton(title: "Record payment", systemImage: "arrow.down.circle", isDisabled: repaymentCardId.isEmpty || MoneyParser.parsePoundsToPence(repaymentAmount) <= 0) {
                store.recordCardRepayment(
                    cardId: repaymentCardId,
                    amountPence: MoneyParser.parsePoundsToPence(repaymentAmount),
                    date: repaymentDate.isoDateString,
                    note: repaymentNote
                )
                repaymentAmount = ""
                repaymentNote = ""
            }
        }
    }

    private var cardRepayments: [CreditCardRepayment] {
        store.snapshot.creditCardRepayments
            .filter { $0.deletedAt == nil && (repaymentCardId.isEmpty || $0.creditCardId == repaymentCardId) }
            .sorted { $0.date > $1.date }
    }
}

private struct CardRepaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var repayment: CreditCardRepayment
    @State private var amount: String
    @State private var date: Date
    @State private var note: String
    @State private var refundEnabled: Bool
    @State private var refundAmount: String

    init(store: PlannerStore, repayment: CreditCardRepayment) {
        self.store = store
        self.repayment = repayment
        _amount = State(initialValue: RefundAmountEditor.inputValue(for: repayment.amountPence))
        _date = State(initialValue: FinanceEngine.parseDate(repayment.date))
        _note = State(initialValue: repayment.note)
        _refundEnabled = State(initialValue: repayment.hasRefund)
        _refundAmount = State(initialValue: RefundAmountEditor.inputValue(for: repayment.effectiveRefundedAmountPence))
    }

    private var currentRepayment: CreditCardRepayment {
        store.snapshot.creditCardRepayments.first(where: { $0.id == repayment.id }) ?? repayment
    }

    var body: some View {
        ScrollView {
            AppCard(glow: true) {
                SectionTitle("Card payment")
                MoneyField(title: "Amount", text: $amount)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .tint(AppTheme.Colors.primaryOrange)
                TextField("Note", text: $note)
                    .textFieldStyle(AppTextFieldStyle())
                MetricRow(label: "Net payment", value: MoneyParser.formatPence(currentRepayment.netAmountPence), valueColor: currentRepayment.isRefunded ? AppTheme.Colors.tertiaryText : AppTheme.Colors.success)
                if currentRepayment.hasRefund {
                    Text("Original payment editing is locked while a refund is recorded. Remove the refund first if the original details need changing.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.warning)
                }
                PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSaveChanges) {
                    store.updateCardRepayment(
                        id: repayment.id,
                        amountPence: MoneyParser.parsePoundsToPence(amount),
                        date: FinanceEngine.toIsoDate(date),
                        note: note
                    )
                    dismiss()
                }
                AppDivider()
                SectionTitle("Refund")
                RefundAmountEditor(
                    originalAmountPence: currentRepayment.amountPence,
                    isEnabled: $refundEnabled,
                    amount: $refundAmount
                )
                Text("Only the returned amount is added back to the card balance and statement due. The payment remains in history.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                PrimaryButton(title: "Save refund", systemImage: "arrow.uturn.backward", isDisabled: !refundIsValid) {
                    store.setCardRepaymentRefundAmount(
                        id: repayment.id,
                        amountPence: refundEnabled ? MoneyParser.parsePoundsToPence(refundAmount) : 0
                    )
                    dismiss()
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle("Card payment")
        .navigationBarTitleDisplayMode(.inline)
        .navigationTopDividerHidden()
    }

    private var refundIsValid: Bool {
        guard refundEnabled else { return currentRepayment.hasRefund }
        let amountPence = MoneyParser.parsePoundsToPence(refundAmount)
        return amountPence > 0 && amountPence <= currentRepayment.amountPence
    }

    private var canSaveChanges: Bool {
        !currentRepayment.hasRefund && MoneyParser.parsePoundsToPence(amount) > 0
    }
}

private func cardRepaymentSubtitle(_ repayment: CreditCardRepayment) -> String {
    guard repayment.hasRefund else { return repayment.date }
    let status = repayment.isPartiallyRefunded
        ? "Refunded \(MoneyParser.formatPence(repayment.effectiveRefundedAmountPence))"
        : "Refunded"
    return "\(repayment.date) · \(status)"
}

private struct CardLinkedRecordEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var destination: CardLinkedRowDestination

    @ViewBuilder
    var body: some View {
        switch destination {
        case .recurring(let paymentId, let scheduledDueDate):
            CreditCardRecurringOccurrenceEditorView(
                store: store,
                paymentId: paymentId,
                scheduledDueDate: scheduledDueDate
            )
        case .customPayment(let id):
            if let payment = store.snapshot.customPayments.first(where: { $0.id == id && $0.deletedAt == nil }) {
                CreditCardCustomPaymentEditorView(store: store, payment: payment)
            } else {
                unavailable
            }
        case .pot(let id):
            if let pot = store.snapshot.pots.first(where: { $0.id == id && !$0.archived }) {
                NavigationStack {
                    PotEditView(store: store, pot: pot)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                        }
                }
            } else {
                unavailable
            }
        case .coverPot(let id):
            if let pot = store.snapshot.creditCardPots.first(where: { $0.id == id && $0.deletedAt == nil }) {
                CreditCardCoverPotEditorView(store: store, pot: pot)
            } else {
                unavailable
            }
        case .transaction(let id):
            CreditCardBalanceHistoryEditorSheet(store: store, target: .transaction(id))
        case .repayment(let id):
            CreditCardBalanceHistoryEditorSheet(store: store, target: .repayment(id))
        }
    }

    private var unavailable: some View {
        NavigationStack {
            ContentUnavailableView(
                "Record unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("This linked record was deleted or is no longer available.")
            )
            .premiumScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}

private struct CreditCardCustomPaymentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var payment: CustomPayment
    @State private var name: String
    @State private var amount: String
    @State private var dueDate: Date
    @State private var status: CustomPaymentStatus
    @State private var isDeleteConfirmationPresented = false

    init(store: PlannerStore, payment: CustomPayment) {
        self.store = store
        self.payment = payment
        _name = State(initialValue: payment.name)
        _amount = State(initialValue: RefundAmountEditor.inputValue(for: payment.amountPence))
        _dueDate = State(initialValue: FinanceEngine.parseDate(payment.dueDate))
        _status = State(initialValue: payment.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("One-off payment") {
                    TextField("Name", text: $name)
                    MoneyField(title: "Amount", text: $amount)
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    Picker("Status", selection: $status) {
                        Text("Unpaid").tag(CustomPaymentStatus.unpaid)
                        Text("Paid").tag(CustomPaymentStatus.paid)
                        Text("Archived").tag(CustomPaymentStatus.archived)
                    }
                }
                Section {
                    Button("Delete payment", role: .destructive) { isDeleteConfirmationPresented = true }
                }
            }
            .navigationTitle("Edit payment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateCustomPayment(
                            id: payment.id,
                            name: name,
                            amountPence: MoneyParser.parsePoundsToPence(amount),
                            dueDate: FinanceEngine.toIsoDate(dueDate),
                            creditCardId: payment.creditCardId,
                            status: status
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || MoneyParser.parsePoundsToPence(amount) <= 0)
                }
            }
            .confirmationDialog("Delete this payment?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
                Button("Delete payment", role: .destructive) {
                    store.deleteCustomPayment(id: payment.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

private struct CreditCardCoverPotEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var pot: CreditCardPot
    @State private var name: String
    @State private var amount: String
    @State private var source: CreditCardPotSource
    @State private var status: CreditCardPotStatus
    @State private var note: String
    @State private var isDeleteConfirmationPresented = false

    init(store: PlannerStore, pot: CreditCardPot) {
        self.store = store
        self.pot = pot
        _name = State(initialValue: pot.name)
        _amount = State(initialValue: RefundAmountEditor.inputValue(for: pot.amountPence))
        _source = State(initialValue: pot.source)
        _status = State(initialValue: pot.status)
        _note = State(initialValue: pot.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Credit card cover") {
                    TextField("Name", text: $name)
                    MoneyField(title: "Amount", text: $amount)
                    Picker("Source", selection: $source) {
                        Text("Paycheck").tag(CreditCardPotSource.paycheck)
                        Text("External").tag(CreditCardPotSource.external)
                    }
                    Picker("Status", selection: $status) {
                        Text("Active").tag(CreditCardPotStatus.active)
                        Text("Applied").tag(CreditCardPotStatus.applied)
                        Text("Cancelled").tag(CreditCardPotStatus.cancelled)
                    }
                    TextField("Note", text: $note, axis: .vertical)
                }
                Section {
                    Button("Delete cover pot", role: .destructive) { isDeleteConfirmationPresented = true }
                }
            }
            .navigationTitle("Edit cover pot")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateCreditCardPot(
                            id: pot.id,
                            name: name,
                            amountPence: MoneyParser.parsePoundsToPence(amount),
                            source: source,
                            status: status,
                            note: note
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || MoneyParser.parsePoundsToPence(amount) <= 0)
                }
            }
            .confirmationDialog("Delete this cover pot?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
                Button("Delete cover pot", role: .destructive) {
                    store.deleteCreditCardPot(id: pot.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

private struct CardPaymentAllocationRowCard: View {
    var row: CardPaymentAllocationRow

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Image(systemName: row.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.amountColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("\(row.context) · \(row.detail)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Text(row.amount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(row.amountColor)
                .multilineTextAlignment(.trailing)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .frame(width: 18)
                .accessibilityHidden(true)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: CardsLayoutPolicy.linkedRowMinimumTapTarget,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.context), \(row.amount), \(row.detail)")
    }
}

private struct CardPaymentAllocationRow: Identifiable {
    var id: String
    var title: String
    var detail: String
    var amount: String
    var amountColor: Color
    var context: String
    var symbol: String
    var sortDate: String
    var destination: CardLinkedRowDestination
}

private func cardAvailabilityLabel(_ availablePence: Int) -> String {
    availablePence < 0
        ? "Over limit by \(MoneyParser.formatPence(abs(availablePence)))"
        : "Available \(MoneyParser.formatPence(availablePence))"
}

private func forecastAvailabilityLabel(_ availablePence: Int) -> String {
    availablePence < 0
        ? "Forecast over limit by \(MoneyParser.formatPence(abs(availablePence)))"
        : "Forecast available \(MoneyParser.formatPence(availablePence))"
}

private func creditCardSpentAmountLabel(_ pence: Int) -> String {
    let amount = max(0, pence)
    let pounds = amount / 100
    let pennies = amount % 100
    let poundsText = pounds < 10 ? "0\(pounds)" : "\(pounds)"
    let penniesText = pennies < 10 ? "0\(pennies)" : "\(pennies)"
    return "\(poundsText).\(penniesText)"
}

private func creditCardCompactMoney(_ pence: Int) -> String {
    let prefix = pence < 0 ? "-" : ""
    let amount = abs(pence)
    let pounds = amount / 100
    let pennies = amount % 100

    if pennies == 0 {
        return "\(prefix)£\(pounds)"
    }

    let penniesText = pennies < 10 ? "0\(pennies)" : "\(pennies)"
    return "\(prefix)£\(pounds).\(penniesText)"
}

func creditCardLinkBadges(card: CreditCard, snapshot: PlannerSnapshot) -> [CreditCardLinkBadge] {
    let linkedPots = snapshot.pots.filter {
        $0.deletedAt == nil &&
        !$0.archived &&
        $0.linkedCreditCardId == card.id
    }
    let linkedPotIds = Set(linkedPots.map(\.id))

    let hasPotLink = !linkedPots.isEmpty || snapshot.creditCardPots.contains {
        $0.deletedAt == nil &&
        $0.status == .active &&
        $0.creditCardId == card.id
    }

    let hasBillLink = snapshot.recurringPayments.contains { payment in
        guard payment.deletedAt == nil, payment.active else { return false }
        if payment.creditCardId == card.id { return true }
        guard let potId = payment.potId else { return false }
        return linkedPotIds.contains(potId)
    } || snapshot.customPayments.contains {
        $0.deletedAt == nil &&
        $0.status != .archived &&
        $0.creditCardId == card.id
    }

    let hasDebtLink = linkedPots.contains { pot in
        guard let debtId = pot.linkedDebtId else { return false }
        return snapshot.debts.contains {
            $0.id == debtId &&
            $0.deletedAt == nil &&
            $0.status.isActiveLike
        }
    }

    var badges: [CreditCardLinkBadge] = []
    if hasPotLink { badges.append(.pot) }
    if hasBillLink { badges.append(.bill) }
    if hasDebtLink { badges.append(.debt) }
    return badges
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfBlank: String? {
        isBlank ? nil : self
    }
}
