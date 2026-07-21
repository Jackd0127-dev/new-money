import SwiftUI

enum CardsSection: String, Equatable {
    case summary
    case paymentAllocation
    case activeCards
}

struct CardsLayoutPolicy {
    static let toolbarActionId = "add"
    static let detailToolbarActionId = "card-detail-add-payment"
    static let detailToolbarTitle = "Payment"
    static let detailToolbarStyle = "textButton"
    static let repaymentFlowPlacement = "cardDetailToolbar"
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
        self.accessibilityLabel = "\(card.name), \(spentLabel) spent"
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
        case .none, .add(_), .editDone(_, _, _), .actions(_):
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
            MetricRow(label: "Total credit", value: MoneyParser.formatPence(totalCredit), valueColor: AppTheme.Colors.primaryText)
            MetricRow(label: "Owed", value: MoneyParser.formatPence(owed), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(
                label: available < 0 ? "Over limit" : "Available credit",
                value: MoneyParser.formatPence(abs(available)),
                valueColor: available < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText
            )
            if forecastOwed != owed || forecastAvailable != available {
                MetricRow(
                    label: forecastAvailable < 0 ? "Forecast over limit" : "Forecast availability",
                    value: MoneyParser.formatPence(abs(forecastAvailable)),
                    valueColor: forecastAvailable < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning
                )
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            cardPreview
                .frame(maxWidth: .infinity, alignment: .center)

            if showsTitle {
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
            } else {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Spent")
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

            ProgressView(value: min(1, Double(max(0, balancePence)) / Double(max(1, card.limitPence))))
                .tint(balancePence > card.limitPence ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
                .background(AppTheme.Colors.divider)

            HStack(spacing: AppTheme.Spacing.sm) {
                Pill(text: "Limit \(MoneyParser.formatPence(card.limitPence))", systemImage: "gauge")
                if let dueDay = card.dueDay {
                    Pill(text: "Due day \(dueDay)", systemImage: "calendar")
                }
            }

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

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var card: CreditCard
    @State private var isHistoryExpanded = true
    @State private var isCardPaymentPresented = false
    @State private var isCycleAdjustmentPresented = false
    @State private var isCardEditPresented = false
    @State private var isDeleteConfirmationPresented = false

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
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(currentCard.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
        }
    }

    private var statementSummaryCard: some View {
        AppCard {
            SectionTitle("Statement")
            MetricRow(label: "Statement day", value: statementDayLabel)
            if let currentStatementDate {
                MetricRow(label: "Current statement", value: friendlyDate(currentStatementDate))
            }
            MetricRow(label: "Next statement", value: nextStatementDate.map(friendlyDate) ?? "Not set")
            MetricRow(label: "Direct debit", value: nextDirectDebitDate.map(friendlyDate) ?? "Not set")
            MetricRow(label: "Current statement due", value: MoneyParser.formatPence(currentStatementDuePence), valueColor: currentStatementDuePence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.secondaryText)
            if heldCycleReservePence > 0 {
                MetricRow(label: "Held cycle reserve", value: MoneyParser.formatPence(heldCycleReservePence), valueColor: AppTheme.Colors.warning)
            }
            MetricRow(
                label: cardAvailability.actualAvailablePence < 0 ? "Over limit" : "Available",
                value: MoneyParser.formatPence(abs(cardAvailability.actualAvailablePence)),
                valueColor: cardAvailability.actualAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success
            )
            if cardAvailability.forecastAvailablePence != cardAvailability.actualAvailablePence {
                MetricRow(
                    label: cardAvailability.forecastAvailablePence < 0 ? "Forecast over limit" : "Forecast availability",
                    value: MoneyParser.formatPence(abs(cardAvailability.forecastAvailablePence)),
                    valueColor: cardAvailability.forecastAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning
                )
            }
            MetricRow(label: "Linked pot cover", value: MoneyParser.formatPence(linkedPotCoverPence), valueColor: AppTheme.Colors.primaryOrange)
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
                ForEach(linkedRows) { row in
                    CardPaymentAllocationRowCard(row: row)
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
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(historyRows) { row in
                        CardPaymentAllocationRowCard(row: row)
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
                    sortDate: recurringSortDate(payment)
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
                    sortDate: payment.dueDate
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
                    sortDate: String(pot.updatedAt.prefix(10))
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
                    sortDate: creditCardPotDate(pot)
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
                    sortDate: recurringSortDate(payment)
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
                    sortDate: payment.dueDate
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
                    sortDate: transaction.date
                )
            }

        let repayments = store.snapshot.creditCardRepayments
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { repayment in
                CardPaymentAllocationRow(
                    id: "history-repayment-\(repayment.id)",
                    title: repayment.note.isBlank ? "Card payment" : repayment.note,
                    detail: friendlyDate(repayment.date),
                    amount: MoneyParser.formatPence(repayment.amountPence),
                    amountColor: AppTheme.Colors.success,
                    context: "Payment",
                    symbol: "arrow.down.circle",
                    sortDate: repayment.date
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
                    sortDate: creditCardPotDate(pot)
                )
            }

        return (recurring + custom + spending + repayments + coverPots).sorted { $0.sortDate > $1.sortDate }
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

    private var currentStatementDate: String? {
        guard let statementDate = cycleAdjustmentSummary?.statementDate,
              statementDate <= store.todayIso else {
            return nil
        }

        return statementDate
    }

    private var nextDirectDebitDate: String? {
        cycleAdjustmentSummary?.directDebitDate ?? nextStatementPayment?.directDebitDate
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

    private var currentStatementDuePence: Int {
        nextStatementPayment?.actualDuePence ?? 0
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

private enum CreditCardCycleDateChoice: String, CaseIterable, Identifiable {
    case asExpected = "As expected"
    case awaiting = "Not yet"
    case actualDate = "Choose date"

    var id: String { rawValue }
}

private struct CreditCardCycleAdjustmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var card: CreditCard
    @State private var statementChoice: CreditCardCycleDateChoice
    @State private var directDebitChoice: CreditCardCycleDateChoice
    @State private var statementDate: Date
    @State private var directDebitDate: Date

    init(store: PlannerStore, card: CreditCard) {
        self.store = store
        self.card = card
        let cycle = PlannerDerivedData.creditCardCycleAdjustmentSummary(card: card, snapshot: store.snapshot, asOfDate: store.todayIso)
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
        PlannerDerivedData.creditCardCycleAdjustmentSummary(card: card, snapshot: store.snapshot, asOfDate: store.todayIso)
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
                                            Text(repayment.date)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                        }
                                        Spacer()
                                        Text(MoneyParser.formatPence(repayment.amountPence))
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
    @ObservedObject var store: PlannerStore
    var repayment: CreditCardRepayment

    private var currentRepayment: CreditCardRepayment {
        store.snapshot.creditCardRepayments.first(where: { $0.id == repayment.id }) ?? repayment
    }

    var body: some View {
        ScrollView {
            AppCard(glow: true) {
                SectionTitle("Card payment")
                MetricRow(label: "Amount", value: MoneyParser.formatPence(currentRepayment.amountPence), valueColor: currentRepayment.isRefunded ? AppTheme.Colors.tertiaryText : AppTheme.Colors.success)
                MetricRow(label: "Date", value: currentRepayment.date)
                MetricRow(label: "Note", value: currentRepayment.note.isBlank ? "Card payment" : currentRepayment.note)
                Toggle("This payment was refunded", isOn: Binding(
                    get: { currentRepayment.isRefunded },
                    set: { store.setCardRepaymentRefunded(id: repayment.id, refunded: $0) }
                ))
                .tint(AppTheme.Colors.primaryOrange)
                if currentRepayment.isRefunded {
                    Text("This payment is retained in history but no longer reduces the card balance or statement due.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.success)
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle("Card payment")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardPaymentAllocationRowCard: View {
    var row: CardPaymentAllocationRow

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                    Text(row.detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: AppTheme.Spacing.md)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(row.amount)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(row.amountColor)
                        .multilineTextAlignment(.trailing)
                    Pill(text: row.context, systemImage: row.symbol, color: row.amountColor)
                }
            }
        }
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
