import SwiftUI

private func shortDate(_ isoDate: String) -> String {
    FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
}

private let activityDisplayDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, d MMM yyyy"
    return formatter
}()

private func activityDisplayDate(_ value: String) -> String {
    activityDisplayDateFormatter.string(from: FinanceEngine.parseDate(value.prefixDateLabel))
}

private extension String {
    var formattedDayLabel: String {
        FinanceEngine.parseDate(self).formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    var prefixDateLabel: String {
        String(prefix(10))
    }
}

enum CreditRoute: String, CaseIterable, Equatable {
    case cards
    case debts

    var title: String {
        switch self {
        case .cards: "Cards"
        case .debts: "Debts"
        }
    }

    var subtitle: String {
        switch self {
        case .cards: "Balances, limits, repayments, and card activity."
        case .debts: "Balances, reserves, minimums, and payoff progress."
        }
    }

    var symbol: String {
        switch self {
        case .cards: "creditcard"
        case .debts: "exclamationmark.shield"
        }
    }
}

enum CreditDetailPresentation: Equatable {
    case navigationPush
}

struct CreditLayoutPolicy {
    static let summaryPresentation: CreditDetailPresentation = .navigationPush
    static let summaryDetailUsesInlineTitle = true
    static let summaryPrimaryMetric = "totalCreditLimit"
    static let cardsPlacement = "belowSummaryAboveDueSoon"
    static let cardsPresentation = "lazyHStack"
    static let cardsUseCardsViewRow = false
    static let cardsUseFloatingPreview = true
    static let cardsShowOuterRowBox = false
    static let removesPhysicalCardStrip = true
    static let cardRowWidth: CGFloat = CreditCardVisualLayoutPolicy.rowCardMaxWidth
    static let cardRowCornerRadius: CGFloat = AppTheme.Radius.md
    static let cardRowsUseHorizontalScroll = true
    static let dueSoonPresentation = "stackedFourItemPreviews"
    static let dueSoonCards = ["directDebits", "nextStatements"]
    static let dueSoonPreviewItemLimit = 4
    static let dueSoonPreviewOpensFullList = true
    static let directDebitFullListIsUntruncated = true
    static let nextStatementsIncludeEveryActiveCard = true
    static let dueSoonHeadersShowLeadingSymbols = false
    static let dueSoonHeadersShowSubtitles = false
    static let creditMetricsUseAlignedGrid = true
    static let creditMetricsStackAtAccessibilitySizes = true
    static let scheduleHeaderMinimumTapTarget: CGFloat = 44
    static let directDebitsDisclosureId = "credit-direct-debits-disclosure"
    static let directDebitsContentId = "credit-direct-debits-content"
    static let nextStatementsDisclosureId = "credit-next-statements-disclosure"
    static let nextStatementsContentId = "credit-next-statements-content"
    static let scheduleContentTopAdjustment: CGFloat = -12
    static let dueSoonTopAdjustment: CGFloat = -10
    static let ledgerRowMinimumTapTarget: CGFloat = 54
    static let previousStatementsStartCollapsed = true
    static let directDebitFutureStatus = "Due"
    static let statementDetailShowsBankReconciliation = true
}

enum ActivitySection: String, Equatable {
    case recentActivity
    case yearNet
    case income
    case spending
}

enum ActivityDetailPresentation: Equatable {
    case navigationPush
}

struct ActivityLayoutPolicy {
    static let sections: [ActivitySection] = [
        .recentActivity,
        .yearNet
    ]
    static let recentActivityInitialVisibleCount = 1
    static let recentActivityRevealIncrement = 2
    static let recentActivityMarkerStyle = "coloredDot"
    static let recentActivityDateFormat = "EEE, d MMM yyyy"
    static let recentActivityDetailPresentation: ActivityDetailPresentation = .navigationPush
    static let recentActivityDetailUsesInlineTitle = true
    static let recentActivityDetailToolbarActions = ["trash", "edit"]
    static let recentActivityDeleteRequiresConfirmation = true
    static let recentActivityDeleteIsPermanent = true
    static let recentActivityShowsGeneratedPayPeriodSummaries = false
    static let recentActivityShowsGeneratedAutomaticPaychecks = false
    static let recentActivityShowsZeroValuePaychecks = false
    static let paycheckActivityDateSource = "payday"
    static let yearNetChartMetric = "currentYearIncomeMinusSpending"
    static let yearNetDetailPresentation: ActivityDetailPresentation = .navigationPush
    static let yearNetDetailUsesInlineTitle = true
    static let showsDetailRecordId = false
    static let incomeDetailToolbarMode = "editDoneAndAdd"
    static let spendingDetailToolbarMode = "editDoneAndAdd"
    static let incomeDetailUsesNativeToolbarMorph = true
    static let spendingDetailUsesNativeToolbarMorph = true
    static let incomeEditRequiresDeletableItem = true
    static let spendingEditRequiresDeletableItem = true
    static let editDeleteBadgeRequiresConfirmation = true
    static let transactionEditorHidesTopSpacing = true
    static let transactionEditorHidesNavigationDivider = true
    static let transactionEditorRoutePickerPresentation = "selectionFieldBox"
    static let transactionEditorDeletePlacement = "topRightToolbar"
    static let transactionEditorDeleteRequiresConfirmation = true

    static func recentActivityVisibleCount(afterSeeMoreTaps taps: Int, totalCount: Int) -> Int {
        min(
            max(0, totalCount),
            recentActivityInitialVisibleCount + max(0, taps) * recentActivityRevealIncrement
        )
    }

    static func paycheckActivityDate(paycheck: Paycheck, payPeriod: PayPeriod?) -> String {
        payPeriod?.payday ?? paycheck.createdAt.prefixDateLabel
    }
}

enum ActivityTimelineLayoutPolicy {
    static let toolbarActionId = "activity-infinity-toolbar-action"
    static let toolbarSymbol = "infinity"
    static let presentation = "placeholder"
    static let isPlaceholderOnly = true
    static let opensTimeline = false
    static let branchStyle = "slowVariableStoryWalkthrough"
    static let autoScrollsWhileRevealing = true
    static let includesAccountCreation = true
    static let usesVariableNaturalBranches = true
    static let revealsCardBeforeDrawingNextBranch = true
    static let scrollFollowMode = "branchMidpointThenEventCard"
    static let scrollsToBranchBeforeNextCard = true
    static let scrollUsesCardFocusAnchors = true
    static let eventSources = [
        "account",
        "income",
        "spending",
        "bills",
        "billGroups",
        "pots",
        "cards",
        "cardRepayments",
        "debts",
        "debtPayments",
        "debtReserves",
        "customPayments",
        "dailyBriefs"
    ]
    static let branchRevealDelaySeconds = 0.95
    static let cardRevealDurationSeconds = 0.72
    static let cardReadDelaySeconds = 0.72
    static let branchDrawDurationSeconds = 1.08
    static let branchSettleDelaySeconds = 0.24
    static let autoScrollDurationSeconds = 0.82
}

enum ActivityTimelineLane: String, CaseIterable {
    case right
    case left
    case center
    case innerRight
    case innerLeft
}

struct ActivityTimelineEventLayout {
    var index: Int
    var lane: ActivityTimelineLane
    var cardLeading: CGFloat
    var cardTop: CGFloat
    var cardWidth: CGFloat
    var anchorPoint: CGPoint
}

enum ActivityTimelineBranchLayoutPolicy {
    static let lanePattern: [ActivityTimelineLane] = [.right, .left, .center, .innerRight, .innerLeft, .center]
    static let connectorEndpointPolicy = "eventAnchorToEventAnchor"
    static let avoidsFixedLeftRail = true
    static let nodeOverlapsEventCard = true
    static let nodeAnchorPolicy = "cardEdgeOverlap"
    static let nodeRevealFollowsCardOffset = true
    static let branchFocusUsesConnectorMidpoint = true
    static let rowHeight: CGFloat = 258
    static let cardTopInset: CGFloat = 34
    static let minimumCardWidth: CGFloat = 238
    static let maximumCardWidth: CGFloat = 314
    static let preferredCardWidthFraction: CGFloat = 0.72
    static let bottomPadding: CGFloat = 84

    static func lane(for index: Int) -> ActivityTimelineLane {
        lanePattern[abs(index % lanePattern.count)]
    }

    static func totalHeight(eventCount: Int) -> CGFloat {
        guard eventCount > 0 else { return 0 }
        return CGFloat(eventCount) * rowHeight + bottomPadding
    }

    static func layout(for index: Int, containerWidth: CGFloat) -> ActivityTimelineEventLayout {
        let lane = lane(for: index)
        let width = max(1, containerWidth)
        let cardWidth = min(maximumCardWidth, min(width, max(minimumCardWidth, width * preferredCardWidthFraction)))
        let maxLeading = max(0, width - cardWidth)
        let verticalNudge = verticalOffset(for: index)
        let cardTop = CGFloat(index) * rowHeight + cardTopInset + verticalNudge
        let cardLeading: CGFloat

        switch lane {
        case .left:
            cardLeading = 0
        case .innerLeft:
            cardLeading = maxLeading * 0.22
        case .center:
            cardLeading = maxLeading * 0.5
        case .innerRight:
            cardLeading = maxLeading * 0.78
        case .right:
            cardLeading = maxLeading
        }

        let anchorPoint = CGPoint(
            x: anchorX(for: lane, cardLeading: cardLeading, cardWidth: cardWidth, index: index),
            y: cardTop + 42
        )

        return ActivityTimelineEventLayout(
            index: index,
            lane: lane,
            cardLeading: cardLeading,
            cardTop: cardTop,
            cardWidth: cardWidth,
            anchorPoint: anchorPoint
        )
    }

    static func cardFocusPoint(for layout: ActivityTimelineEventLayout) -> CGPoint {
        CGPoint(
            x: layout.cardLeading + layout.cardWidth / 2,
            y: layout.cardTop + 96
        )
    }

    static func branchFocusPoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
    }

    private static func verticalOffset(for index: Int) -> CGFloat {
        [0, 18, 4, 24, 10, 28][abs(index % 6)]
    }

    private static func anchorX(for lane: ActivityTimelineLane, cardLeading: CGFloat, cardWidth: CGFloat, index: Int) -> CGFloat {
        let edgeInset: CGFloat = 14
        switch lane {
        case .right:
            return cardLeading + edgeInset
        case .left:
            return cardLeading + cardWidth - edgeInset
        case .center:
            return cardLeading + (index.isMultiple(of: 2) ? edgeInset : cardWidth - edgeInset)
        case .innerRight:
            return cardLeading + edgeInset
        case .innerLeft:
            return cardLeading + cardWidth - edgeInset
        }
    }
}

private struct ActivityTabPresentation {
    var yearlyNetData: ActivityYearlyNetChartData
    var entries: [ActivityEntry]
}

struct ActivityView: View {
    @ObservedObject var store: PlannerStore
    var rootTabResetRevision: Int?
    var presentationCache: PlannerTabPresentationCache?
    var presentationContext: PlannerTabPresentationContext?
    @State private var filter: ActivityFilter = .all
    @State private var searchText = ""
    @State private var recentActivitySeeMoreTapCount = 0

    var body: some View {
        ScreenScaffold(
            title: "Activity",
            subtitle: "Transactions, spending, income, and pay-period history.",
            navigationMode: .tabRoot,
            toolbarMode: .none,
            rootTabResetRevision: rootTabResetRevision
        ) {
            ForEach(ActivityLayoutPolicy.sections, id: \.rawValue) { section in
                activitySection(section)
            }
        }
        .onChange(of: filter) {
            resetRecentActivityVisibleCount()
        }
        .onChange(of: searchText) {
            resetRecentActivityVisibleCount()
        }
    }

    @ViewBuilder
    private func activitySection(_ section: ActivitySection) -> some View {
        switch section {
        case .recentActivity:
            activityFeed
        case .yearNet:
            activityYearNet
        case .income, .spending:
            EmptyView()
        }
    }

    private var activityControls: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Picker("Activity filter", selection: $filter) {
                    ForEach(ActivityFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Search activity", text: $searchText)
                    .textFieldStyle(AppTextFieldStyle())
            }
        }
    }

    @ViewBuilder
    private var activityYearNet: some View {
        let data = tabPresentation.yearlyNetData

        NavigationLink {
            ActivityYearlyNetDetailView(data: data)
        } label: {
            ActivityYearlyNetCard(data: data)
        }
        .buttonStyle(.plain)
    }

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Recent activity")
            if shouldShowActivityControls {
                activityControls
            }
            if filteredEntries.isEmpty {
                AppCard {
                    EmptyStateView(title: "No matching activity", message: "Spending, paychecks, and pay periods will appear here.", systemImage: "list.bullet.rectangle")
                }
            } else {
                AppCard {
                    let entries = filteredEntries
                    let visibleEntries = Array(entries.prefix(recentActivityVisibleCount))
                    ForEach(visibleEntries) { entry in
                        NavigationLink {
                            ActivityEntryDetailView(store: store, entry: entry)
                        } label: {
                            ActivityEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)

                        if entry.id != visibleEntries.last?.id {
                            AppDivider()
                        }
                    }

                    if visibleEntries.count < entries.count {
                        AppDivider()
                        Button(action: revealMoreRecentActivity) {
                            Label("See more", systemImage: "chevron.down")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows two more activity items")
                    }
                }
            }
        }
    }

    private var recentActivityVisibleCount: Int {
        ActivityLayoutPolicy.recentActivityVisibleCount(
            afterSeeMoreTaps: recentActivitySeeMoreTapCount,
            totalCount: filteredEntries.count
        )
    }

    private func revealMoreRecentActivity() {
        recentActivitySeeMoreTapCount += 1
    }

    private func resetRecentActivityVisibleCount() {
        recentActivitySeeMoreTapCount = 0
    }

    private var filteredEntries: [ActivityEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return activityEntries
            .filter { entry in
                filter == .all || entry.kind == filter
            }
            .filter { entry in
                guard !query.isEmpty else { return true }
                return entry.title.localizedStandardContains(query) ||
                    entry.detail.localizedStandardContains(query) ||
                    (entry.sourceBadge?.label.localizedStandardContains(query) ?? false)
            }
    }

    private var shouldShowActivityControls: Bool {
        activityEntries.count > 4 || filter != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activityEntries: [ActivityEntry] {
        tabPresentation.entries
    }

    private var tabPresentation: ActivityTabPresentation {
        let context = presentationContext ?? PlannerTabPresentationContext(
            snapshot: store.snapshot,
            activePlannerAccountId: store.activePlannerAccountId,
            snapshotRevision: store.snapshotRevision,
            todayIso: store.todayIso,
            selectedPayPeriod: store.selectedPayPeriod
        )

        guard let presentationCache else {
            return Self.makePresentation(context: context)
        }

        return presentationCache.value(for: context.key(for: .activity)) {
            Self.makePresentation(context: context)
        }
    }

    static func warmPresentation(cache: PlannerTabPresentationCache, context: PlannerTabPresentationContext) {
        let _: ActivityTabPresentation = cache.value(for: context.key(for: .activity)) {
            makePresentation(context: context)
        }
    }

    private static func makePresentation(context: PlannerTabPresentationContext) -> ActivityTabPresentation {
        ActivityTabPresentation(
            yearlyNetData: ActivityYearlyNetChartData.make(
                snapshot: context.snapshot,
                todayIso: context.todayIso
            ),
            entries: makeActivityEntries(snapshot: context.snapshot)
        )
    }

    fileprivate static func makeActivityEntries(snapshot: PlannerSnapshot) -> [ActivityEntry] {
        let potsById = snapshot.pots.reduce(into: [String: Pot]()) { result, pot in
            result[pot.id] = pot
        }
        let cardsById = snapshot.creditCards.reduce(into: [String: CreditCard]()) { result, card in
            result[card.id] = card
        }
        let banksById = snapshot.bankAccounts.reduce(into: [String: BankAccount]()) { result, account in
            result[account.id] = account
        }
        let recurringById = snapshot.recurringPayments.reduce(into: [String: RecurringPayment]()) { result, payment in
            result[payment.id] = payment
        }
        let periodsById = snapshot.payPeriods.reduce(into: [String: PayPeriod]()) { result, period in
            result[period.id] = period
        }

        let spending = snapshot.transactions
            .filter { $0.type == .spending && $0.deletedAt == nil }
            .map { transaction in
                let amount = "-\(MoneyParser.formatPence(transaction.netAmountPence))"
                let date = activityDisplayDate(transaction.date)
                var detailRows = [
                    ActivityDetailRow(label: "Net amount", value: amount, valueColor: AppTheme.Colors.orangeHighlight),
                    ActivityDetailRow(label: "Date", value: date),
                    ActivityDetailRow(label: "Type", value: formattedActivityLabel(transaction.type.rawValue)),
                    ActivityDetailRow(label: "Payment method", value: activityPaymentMethodLabel(transaction.paymentMethod))
                ]

                if transaction.hasRefund {
                    detailRows.insert(
                        ActivityDetailRow(
                            label: transaction.isPartiallyRefunded ? "Partial refund" : "Refund",
                            value: MoneyParser.formatPence(transaction.effectiveRefundedAmountPence),
                            valueColor: AppTheme.Colors.success
                        ),
                        at: 1
                    )
                }

                if let potId = transaction.potId {
                    detailRows.append(ActivityDetailRow(label: "Pot", value: potsById[potId]?.name ?? potId))
                }
                if let creditCardId = transaction.creditCardId {
                    detailRows.append(ActivityDetailRow(label: "Credit card", value: cardsById[creditCardId]?.name ?? creditCardId))
                }
                if let recurringPaymentId = transaction.recurringPaymentId {
                    detailRows.append(ActivityDetailRow(label: "Linked bill", value: recurringById[recurringPaymentId]?.name ?? recurringPaymentId))
                }
                if let payPeriodId = transaction.payPeriodId, let period = periodsById[payPeriodId] {
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))"))
                } else if let payPeriodId = transaction.payPeriodId {
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: payPeriodId))
                }
                if !transaction.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detailRows.append(ActivityDetailRow(label: "Note", value: transaction.note))
                }

                return ActivityEntry(
                    id: transaction.id,
                    kind: .spending,
                    title: transaction.note.isEmpty ? "Spending" : transaction.note,
                    detail: date,
                    amount: amount,
                    typeLabel: "Spending",
                    color: AppTheme.Colors.orangeHighlight,
                    sortDate: transaction.date,
                    detailRows: detailRows,
                    recordRows: activityRecordRows(createdAt: transaction.createdAt, updatedAt: transaction.updatedAt),
                    source: .transaction(transaction.id),
                    auditAction: latestAuditAction(snapshot: snapshot, kind: .transaction, id: transaction.id),
                    sourceBadge: activitySourceBadge(
                        transaction: transaction,
                        potsById: potsById,
                        cardsById: cardsById,
                        banksById: banksById
                    )
                )
            }

        let transfers = snapshot.transactions
            .filter { $0.deletedAt == nil && $0.potBankTransferDirection != nil }
            .compactMap { transaction -> ActivityEntry? in
                guard let direction = transaction.potBankTransferDirection,
                      let potId = transaction.potId,
                      let bankId = transaction.bankAccountId
                else { return nil }
                let pot = potsById[potId]
                let bank = banksById[bankId]
                let fromName = direction == .bankToPot ? (bank?.name ?? "Bank") : (pot?.name ?? "Pot")
                let toName = direction == .bankToPot ? (pot?.name ?? "Pot") : (bank?.name ?? "Bank")
                let date = activityDisplayDate(transaction.date)
                return ActivityEntry(
                    id: transaction.id,
                    kind: .all,
                    title: transaction.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Transfer to \(toName)" : transaction.note,
                    detail: date,
                    amount: MoneyParser.formatPence(transaction.netAmountPence),
                    typeLabel: "Transfer",
                    color: AppTheme.Colors.primaryOrange,
                    sortDate: transaction.date,
                    detailRows: [
                        ActivityDetailRow(label: "Amount", value: MoneyParser.formatPence(transaction.netAmountPence)),
                        ActivityDetailRow(label: "From", value: fromName),
                        ActivityDetailRow(label: "To", value: toName),
                        ActivityDetailRow(label: "Date", value: date)
                    ],
                    recordRows: activityRecordRows(createdAt: transaction.createdAt, updatedAt: transaction.updatedAt),
                    source: .transfer(transaction.id),
                    auditAction: latestAuditAction(snapshot: snapshot, kind: .transaction, id: transaction.id),
                    sourceBadge: ActivitySourceBadge(
                        label: fromName,
                        color: direction == .bankToPot ? Color(hex: bank?.color ?? "") : Color(hex: pot?.color ?? "")
                    )
                )
            }

        let income = snapshot.paychecks
            .filter { $0.deletedAt == nil }
            .filter { ActivityLayoutPolicy.recentActivityShowsGeneratedAutomaticPaychecks || !$0.id.hasPrefix("paycheck-pay-period-") }
            .filter { ActivityLayoutPolicy.recentActivityShowsZeroValuePaychecks || paycheckActivityAmount($0) > 0 }
            .map { paycheck in
                let period = periodsById[paycheck.payPeriodId]
                let activityDate = ActivityLayoutPolicy.paycheckActivityDate(paycheck: paycheck, payPeriod: period)
                let amountPence = paycheckActivityAmount(paycheck)
                var detailRows = [
                    ActivityDetailRow(label: "Amount", value: MoneyParser.formatPence(amountPence), valueColor: AppTheme.Colors.success),
                    ActivityDetailRow(label: "Recorded", value: activityDisplayDate(paycheck.createdAt)),
                    ActivityDetailRow(label: "Hours worked", value: String(format: "%.2f", paycheck.hoursWorked)),
                    ActivityDetailRow(label: "Hourly rate", value: MoneyParser.formatPence(paycheck.hourlyRatePence)),
                    ActivityDetailRow(label: "Calculated pay", value: MoneyParser.formatPence(paycheck.calculatedAmountPence))
                ]

                if let actualAmountPence = paycheck.actualAmountPence {
                    detailRows.append(ActivityDetailRow(label: "Actual pay", value: MoneyParser.formatPence(actualAmountPence), valueColor: AppTheme.Colors.success))
                }
                if let period {
                    detailRows.append(ActivityDetailRow(label: "Payday", value: activityDisplayDate(period.payday)))
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))"))
                    detailRows.append(ActivityDetailRow(label: "Status", value: formattedActivityLabel(period.status.rawValue)))
                }

                return ActivityEntry(
                    id: paycheck.id,
                    kind: .income,
                    title: "Paycheck",
                    detail: activityDisplayDate(activityDate),
                    amount: MoneyParser.formatPence(amountPence),
                    typeLabel: "Income",
                    color: AppTheme.Colors.success,
                    sortDate: activityDate,
                    detailRows: detailRows,
                    recordRows: activityRecordRows(createdAt: paycheck.createdAt, updatedAt: paycheck.updatedAt),
                    source: .paycheck(paycheck.id),
                    auditAction: latestAuditAction(snapshot: snapshot, kind: .paycheck, id: paycheck.id)
                )
            }

        let oneOffIncome = snapshot.oneOffIncomes
            .filter { $0.deletedAt == nil }
            .map { income in
                var detailRows = [
                    ActivityDetailRow(label: "Amount", value: MoneyParser.formatPence(income.amountPence), valueColor: AppTheme.Colors.success),
                    ActivityDetailRow(label: "Date", value: activityDisplayDate(income.date)),
                    ActivityDetailRow(label: "Type", value: "One-off income")
                ]

                if let payPeriodId = income.payPeriodId, let period = periodsById[payPeriodId] {
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))"))
                }
                if !income.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detailRows.append(ActivityDetailRow(label: "Note", value: income.note))
                }

                return ActivityEntry(
                    id: income.id,
                    kind: .income,
                    title: income.name,
                    detail: activityDisplayDate(income.date),
                    amount: MoneyParser.formatPence(income.amountPence),
                    typeLabel: "One-off",
                    color: AppTheme.Colors.success,
                    sortDate: income.date,
                    detailRows: detailRows,
                    recordRows: activityRecordRows(createdAt: income.createdAt, updatedAt: income.updatedAt),
                    source: .oneOffIncome(income.id),
                    auditAction: latestAuditAction(snapshot: snapshot, kind: .oneOffIncome, id: income.id)
                )
            }

        return (spending + transfers + income + oneOffIncome + payPeriodSummaryEntries(snapshot: snapshot)).sorted { $0.sortDate > $1.sortDate }
    }

    private static func activitySourceBadge(
        transaction: Transaction,
        potsById: [String: Pot],
        cardsById: [String: CreditCard],
        banksById: [String: BankAccount]
    ) -> ActivitySourceBadge {
        switch transaction.paymentMethod {
        case .creditCard:
            let card = transaction.creditCardId.flatMap { cardsById[$0] }
            return ActivitySourceBadge(label: card?.name ?? "Credit card", color: Color(hex: card?.color ?? ""))
        case .bankAccount:
            let bank = transaction.bankAccountId.flatMap { banksById[$0] }
            return ActivitySourceBadge(label: bank?.name ?? "Bank", color: Color(hex: bank?.color ?? ""))
        case .pot:
            let pot = transaction.potId.flatMap { potsById[$0] }
            return ActivitySourceBadge(label: pot?.name ?? "Pot", color: Color(hex: pot?.color ?? ""))
        case .income, nil:
            return ActivitySourceBadge(label: "Money left", color: AppTheme.Colors.success)
        }
    }

    private static func payPeriodSummaryEntries(snapshot: PlannerSnapshot) -> [ActivityEntry] {
        guard ActivityLayoutPolicy.recentActivityShowsGeneratedPayPeriodSummaries else { return [] }

        return snapshot.payPeriods.map { period in
            var detailRows = [
                ActivityDetailRow(label: "Income", value: MoneyParser.formatPence(PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: period)), valueColor: AppTheme.Colors.success),
                ActivityDetailRow(label: "Start", value: activityDisplayDate(period.startDate)),
                ActivityDetailRow(label: "End", value: activityDisplayDate(period.endDate)),
                ActivityDetailRow(label: "Payday", value: activityDisplayDate(period.payday)),
                ActivityDetailRow(label: "Next payday", value: activityDisplayDate(period.nextPayday)),
                ActivityDetailRow(label: "Status", value: formattedActivityLabel(period.status.rawValue))
            ]
            if let payFrequency = period.payFrequency {
                detailRows.append(ActivityDetailRow(label: "Frequency", value: formattedActivityLabel(payFrequency.rawValue)))
            }

            return ActivityEntry(
                id: "period-\(period.id)",
                kind: .income,
                title: "Pay period",
                detail: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))",
                amount: MoneyParser.formatPence(PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: period)),
                typeLabel: "Pay period",
                color: AppTheme.Colors.primaryOrange,
                sortDate: period.startDate,
                detailRows: detailRows,
                recordRows: activityRecordRows(createdAt: period.createdAt, updatedAt: period.updatedAt),
                source: .payPeriod(period.id),
                auditAction: latestAuditAction(snapshot: snapshot, kind: .payPeriod, id: period.id)
            )
        }
    }

    private static func paycheckActivityAmount(_ paycheck: Paycheck) -> Int {
        paycheck.actualAmountPence ?? paycheck.calculatedAmountPence
    }

    private static func activityRecordRows(createdAt: String, updatedAt: String) -> [ActivityDetailRow] {
        [
            ActivityDetailRow(label: "Created", value: activityDisplayDate(createdAt)),
            ActivityDetailRow(label: "Updated", value: activityDisplayDate(updatedAt))
        ]
    }

    private static func activityPaymentMethodLabel(_ method: PaymentMethod?) -> String {
        switch method {
        case .income:
            PaymentMethod.income.displayName
        case .bankAccount:
            PaymentMethod.bankAccount.displayName
        case .creditCard:
            PaymentMethod.creditCard.displayName
        case .pot:
            PaymentMethod.pot.displayName
        case nil:
            "Manual"
        }
    }

    private static func formattedActivityLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func latestAuditAction(snapshot: PlannerSnapshot, kind: PlannerAuditRecordKind, id: String) -> PlannerAuditAction? {
        snapshot.auditEvents.reversed().first { event in
            event.action != .baseline && event.changes.contains { $0.recordKind == kind && $0.recordId == id }
        }?.action
    }

}

struct ActivityAccountTimelineView: View {
    @ObservedObject var store: PlannerStore
    @State private var storyProgress = 0.0

    private var account: PlannerAccount? {
        store.activePlannerAccount
            ?? store.plannerAccounts.first { $0.id == store.activePlannerAccountId }
            ?? store.plannerAccounts.first
    }

    private var events: [ActivityTimelineEvent] {
        ActivityTimelineData.make(
            snapshot: store.snapshot,
            account: account,
            todayIso: store.todayIso
        )
    }

    private var timelineIdentity: String {
        "\(events.count)-\(events.first?.id ?? "empty")-\(events.last?.id ?? "empty")"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    timelineHero

                    if events.isEmpty {
                        AppCard {
                            EmptyStateView(
                                title: "Nothing to walk through yet",
                                message: "Your account timeline will build as you add spending, income, bills, pots, cards, and debts.",
                                systemImage: "point.3.connected.trianglepath.dotted"
                            )
                        }
                    } else {
                        timelineRows
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .padding(.bottom, 110)
            }
            .premiumScreenBackground()
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task(id: timelineIdentity) {
                await animateTimeline(proxy: proxy)
            }
        }
    }

    private var timelineHero: some View {
        AppCard(glow: true) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Gradients.primary)
                    Image(systemName: "infinity")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.controlText)
                }
                .frame(width: 58, height: 58)
                .shadow(color: AppTheme.Colors.accentGlow, radius: 18, y: 8)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(account?.name ?? "Account")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(heroSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AppTheme.Spacing.sm) {
                        Pill(text: "\(events.count) events", systemImage: "sparkles", color: AppTheme.Colors.primaryOrange)
                        Pill(text: "\(revealedCount)/\(events.count)", systemImage: "play.fill", color: AppTheme.Colors.success)
                    }

                    ProgressView(value: events.isEmpty ? 0 : min(storyProgress, maxStoryProgress) / maxStoryProgress)
                        .tint(AppTheme.Colors.primaryOrange)
                        .background(AppTheme.Colors.divider)
                }
            }
        }
    }

    private var heroSubtitle: String {
        guard let first = events.first, let last = events.last else {
            return "A living walkthrough of everything that has happened in this account."
        }

        return "\(timelineDateLabel(first.sortKey)) to \(timelineDateLabel(last.sortKey))"
    }

    private var timelineRows: some View {
        ActivityTimelineCanvas(
            events: events,
            activeCardIndex: activeCardIndex,
            cardProgress: { phaseProgress(index: $0, phase: 0) },
            branchProgress: { phaseProgress(index: $0, phase: 1) }
        )
    }

    @MainActor
    private func animateTimeline(proxy: ScrollViewProxy) async {
        storyProgress = 0
        guard !events.isEmpty else { return }

        for index in events.indices {
            if Task.isCancelled { return }

            await sleep(seconds: index == 0 ? 0.24 : ActivityTimelineLayoutPolicy.branchRevealDelaySeconds)

            if Task.isCancelled { return }

            withAnimation(.spring(response: ActivityTimelineLayoutPolicy.cardRevealDurationSeconds, dampingFraction: 0.88)) {
                storyProgress = Double(index * 2 + 1)
            }

            withAnimation(.easeInOut(duration: ActivityTimelineLayoutPolicy.autoScrollDurationSeconds)) {
                proxy.scrollTo(events[index].cardScrollID, anchor: .center)
            }

            guard index < events.count - 1 else { continue }

            await sleep(seconds: ActivityTimelineLayoutPolicy.cardReadDelaySeconds)

            if Task.isCancelled { return }

            withAnimation(.easeInOut(duration: ActivityTimelineLayoutPolicy.branchDrawDurationSeconds)) {
                storyProgress = Double(index * 2 + 2)
                proxy.scrollTo(events[index].branchScrollID, anchor: .center)
            }

            await sleep(seconds: ActivityTimelineLayoutPolicy.branchSettleDelaySeconds)

            if Task.isCancelled { return }

            withAnimation(.easeInOut(duration: ActivityTimelineLayoutPolicy.autoScrollDurationSeconds * 0.72)) {
                proxy.scrollTo(events[index + 1].cardScrollID, anchor: .center)
            }
        }
    }

    private var maxStoryProgress: Double {
        max(1, Double(events.count * 2 - 1))
    }

    private var revealedCount: Int {
        min(events.count, max(0, Int((storyProgress + 1) / 2)))
    }

    private var activeCardIndex: Int {
        guard !events.isEmpty else { return 0 }
        return min(events.count - 1, max(0, Int((storyProgress - 1) / 2)))
    }

    private func phaseProgress(index: Int, phase: Int) -> Double {
        min(1, max(0, storyProgress - Double(index * 2 + phase)))
    }

    private func sleep(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

private struct ActivityTimelineCanvas: View {
    var events: [ActivityTimelineEvent]
    var activeCardIndex: Int
    var cardProgress: (Int) -> Double
    var branchProgress: (Int) -> Double

    var body: some View {
        GeometryReader { proxy in
            let layouts = events.indices.map {
                ActivityTimelineBranchLayoutPolicy.layout(for: $0, containerWidth: proxy.size.width)
            }
            let totalHeight = ActivityTimelineBranchLayoutPolicy.totalHeight(eventCount: events.count)

            ZStack(alignment: .topLeading) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .position(ActivityTimelineBranchLayoutPolicy.cardFocusPoint(for: layouts[index]))
                        .id(event.cardScrollID)
                        .accessibilityHidden(true)
                }

                ForEach(Array(events.indices.dropLast()), id: \.self) { index in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .position(
                            ActivityTimelineBranchLayoutPolicy.branchFocusPoint(
                                from: layouts[index].anchorPoint,
                                to: layouts[index + 1].anchorPoint
                            )
                        )
                        .id(events[index].branchScrollID)
                        .accessibilityHidden(true)
                }

                ForEach(Array(events.indices.dropLast()), id: \.self) { index in
                    ActivityTimelineBranchConnector(
                        start: layouts[index].anchorPoint,
                        end: layouts[index + 1].anchorPoint,
                        variant: index
                    )
                    .trim(from: 0, to: CGFloat(branchProgress(index)))
                    .stroke(
                        events[index].color.opacity(index == activeCardIndex ? 0.95 : 0.66),
                        style: StrokeStyle(lineWidth: index == activeCardIndex ? 2.9 : 2.2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: events[index].color.opacity(index == activeCardIndex ? 0.34 : 0.16), radius: index == activeCardIndex ? 12 : 6)
                    .frame(width: proxy.size.width, height: totalHeight, alignment: .topLeading)
                    .allowsHitTesting(false)
                }

                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    let layout = layouts[index]
                    let progress = cardProgress(index)
                    let revealOffset = cardRevealOffset(for: layout, progress: progress, containerWidth: proxy.size.width)

                    ActivityTimelineEventCard(event: event, isActive: index == activeCardIndex)
                        .frame(width: layout.cardWidth, alignment: .topLeading)
                        .offset(x: layout.cardLeading + revealOffset, y: layout.cardTop)
                        .opacity(progress)
                        .scaleEffect(CGFloat(0.93 + (0.07 * progress)), anchor: cardScaleAnchor(for: layout.lane))
                        .zIndex(2)

                    ActivityTimelineNode(event: event, isActive: index == activeCardIndex, isRevealed: progress > 0.08)
                        .frame(width: 44, height: 44)
                        .position(x: layout.anchorPoint.x + revealOffset, y: layout.anchorPoint.y)
                        .opacity(progress > 0 ? 1 : 0.25)
                        .zIndex(3)
                }
            }
            .frame(width: proxy.size.width, height: totalHeight, alignment: .topLeading)
        }
        .frame(height: ActivityTimelineBranchLayoutPolicy.totalHeight(eventCount: events.count))
    }

    private func cardRevealOffset(for layout: ActivityTimelineEventLayout, progress: Double, containerWidth: CGFloat) -> CGFloat {
        guard progress < 1 else { return 0 }
        let centerX = layout.cardLeading + layout.cardWidth / 2
        let direction: CGFloat = centerX > containerWidth / 2 ? 1 : -1
        return direction * CGFloat(1 - progress) * 28
    }

    private func cardScaleAnchor(for lane: ActivityTimelineLane) -> UnitPoint {
        switch lane {
        case .left, .innerLeft:
            .trailing
        case .right, .innerRight:
            .leading
        case .center:
            .center
        }
    }
}

private struct ActivityTimelineNode: View {
    var event: ActivityTimelineEvent
    var isActive: Bool
    var isRevealed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(event.color.opacity(isActive ? 0.24 : 0.14))
                .frame(width: isActive ? 44 : 36, height: isActive ? 44 : 36)
                .blur(radius: isActive ? 1 : 0)

            Circle()
                .fill(AppTheme.Colors.elevatedSurface)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(event.color.opacity(isActive ? 0.95 : 0.58), lineWidth: isActive ? 2 : 1)
                )

            Image(systemName: event.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(event.color)
        }
        .opacity(isRevealed ? 1 : 0.25)
        .scaleEffect(isRevealed ? 1 : 0.74)
        .shadow(color: isActive ? event.color.opacity(0.46) : .clear, radius: 16, y: 4)
    }
}

private struct ActivityTimelineBranchConnector: Shape {
    var start: CGPoint
    var end: CGPoint
    var variant: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let controls = branchControls(in: rect)

        path.move(to: start)
        path.addCurve(
            to: end,
            control1: controls.first,
            control2: controls.second
        )
        return path
    }

    private func branchControls(in rect: CGRect) -> (first: CGPoint, second: CGPoint) {
        let deltaX = end.x - start.x
        let deltaY = max(1, end.y - start.y)
        let profile = branchProfile
        let direction: CGFloat = deltaX >= 0 ? 1 : -1
        let wave = min(max(abs(deltaX) * 0.42 + profile.wave, 28), 112) * direction
        let firstX = clamp(start.x + deltaX * profile.firstX + wave, min: rect.minX + 20, max: rect.maxX - 20)
        let secondX = clamp(end.x - deltaX * profile.secondX - wave * profile.returnStrength, min: rect.minX + 20, max: rect.maxX - 20)

        return (
            CGPoint(x: firstX, y: start.y + deltaY * profile.firstY),
            CGPoint(x: secondX, y: start.y + deltaY * profile.secondY)
        )
    }

    private var branchProfile: (firstX: CGFloat, firstY: CGFloat, secondX: CGFloat, secondY: CGFloat, wave: CGFloat, returnStrength: CGFloat) {
        switch abs(variant % 6) {
        case 0:
            return (0.12, 0.24, 0.16, 0.72, 38, 0.52)
        case 1:
            return (0.22, 0.18, 0.22, 0.76, 58, 0.72)
        case 2:
            return (0.14, 0.34, 0.12, 0.64, 30, 0.48)
        case 3:
            return (0.30, 0.22, 0.18, 0.82, 68, 0.58)
        case 4:
            return (0.18, 0.28, 0.28, 0.70, 44, 0.66)
        default:
            return (0.26, 0.16, 0.16, 0.78, 52, 0.44)
        }
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

private struct ActivityTimelineEventCard: View {
    var event: ActivityTimelineEvent
    var isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.dateLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(event.color)
                    Text(event.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                if let amountLabel = event.amountLabel {
                    Text(amountLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(event.amountColor)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 7)
                        .background(event.amountColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(event.detail)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppTheme.Spacing.sm) {
                Text(event.typeLabel.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(event.color)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(event.color.opacity(0.12))
                    .clipShape(Capsule())

                if let secondaryLabel = event.secondaryLabel {
                    Text(secondaryLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.elevatedSurface)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Gradients.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(isActive ? event.color.opacity(0.62) : AppTheme.Colors.border, lineWidth: isActive ? 1.4 : 1)
        )
        .shadow(color: isActive ? event.color.opacity(0.20) : AppTheme.Colors.shadow, radius: isActive ? 18 : 10, y: isActive ? 8 : 4)
    }
}

private enum ActivityTimelineData {
    static func make(snapshot: PlannerSnapshot, account: PlannerAccount?, todayIso: String) -> [ActivityTimelineEvent] {
        let potsById = snapshot.pots.reduce(into: [String: Pot]()) { result, pot in result[pot.id] = pot }
        let cardsById = snapshot.creditCards.reduce(into: [String: CreditCard]()) { result, card in result[card.id] = card }
        let debtsById = snapshot.debts.reduce(into: [String: Debt]()) { result, debt in result[debt.id] = debt }
        let payPeriodsById = snapshot.payPeriods.reduce(into: [String: PayPeriod]()) { result, period in result[period.id] = period }
        let billGroupsById = snapshot.billGroups.reduce(into: [String: BillGroup]()) { result, group in result[group.id] = group }

        var events: [ActivityTimelineEvent] = []
        let accountCreatedAt = account?.createdAt ?? snapshot.settings.createdAt
        let accountName = account?.name ?? "Account"

        events.append(
            ActivityTimelineEvent(
                id: "account-created-\(account?.id ?? "single")",
                sortKey: accountCreatedAt,
                title: "Account created",
                detail: "\(accountName) started tracking money here.",
                typeLabel: "Account",
                secondaryLabel: "Start",
                amountPence: nil,
                amountStyle: .neutral,
                color: AppTheme.Colors.primaryOrange,
                symbol: "person.crop.circle"
            )
        )

        for group in snapshot.billGroups {
            events.append(
                ActivityTimelineEvent(
                    id: "bill-group-created-\(group.id)",
                    sortKey: group.createdAt,
                    title: "Bill group created",
                    detail: group.name,
                    typeLabel: "Bills",
                    secondaryLabel: "Group",
                    amountPence: nil,
                    amountStyle: .neutral,
                    color: Color(hex: group.color),
                    symbol: "folder"
                )
            )
            appendDeletedEvent(prefix: "bill-group", name: group.name, deletedAt: group.deletedAt, typeLabel: "Bills", color: Color(hex: group.color), symbol: "archivebox", into: &events)
        }

        for pot in snapshot.pots {
            events.append(
                ActivityTimelineEvent(
                    id: "pot-created-\(pot.id)",
                    sortKey: pot.createdAt,
                    title: "Pot created",
                    detail: "\(pot.name) opened as \(prettyLabel(pot.type.rawValue)).",
                    typeLabel: "Pot",
                    secondaryLabel: pot.category,
                    amountPence: pot.balancePence,
                    amountStyle: .positive,
                    color: Color(hex: pot.color),
                    symbol: "wallet.pass"
                )
            )
            appendDeletedEvent(prefix: "pot", name: pot.name, deletedAt: pot.deletedAt, typeLabel: "Pot", color: Color(hex: pot.color), symbol: "archivebox", into: &events)
        }

        for card in snapshot.creditCards {
            events.append(
                ActivityTimelineEvent(
                    id: "card-created-\(card.id)",
                    sortKey: card.createdAt,
                    title: "Card added",
                    detail: "\(card.name) from \(card.provider.isEmpty ? "Card" : card.provider).",
                    typeLabel: "Credit",
                    secondaryLabel: "Limit \(MoneyParser.formatPence(card.limitPence))",
                    amountPence: card.openingBalancePence ?? card.openingStatementBalancePence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.warning,
                    symbol: "creditcard"
                )
            )
            appendDeletedEvent(prefix: "card", name: card.name, deletedAt: card.deletedAt, typeLabel: "Credit", color: AppTheme.Colors.warning, symbol: "archivebox", into: &events)
        }

        for debt in snapshot.debts {
            events.append(
                ActivityTimelineEvent(
                    id: "debt-created-\(debt.id)",
                    sortKey: debt.createdAt,
                    title: "Debt added",
                    detail: "\(debt.name) with \(debt.lender).",
                    typeLabel: "Debt",
                    secondaryLabel: prettyLabel(debt.status.rawValue),
                    amountPence: debt.currentBalancePence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.danger,
                    symbol: "exclamationmark.shield"
                )
            )
            appendDeletedEvent(prefix: "debt", name: debt.name, deletedAt: debt.deletedAt, typeLabel: "Debt", color: AppTheme.Colors.danger, symbol: "archivebox", into: &events)
        }

        for payment in snapshot.recurringPayments {
            let cardName = payment.creditCardId.flatMap { cardsById[$0]?.name }
            let potName = payment.potId.flatMap { potsById[$0]?.name }
            let groupName = payment.billGroupId.flatMap { billGroupsById[$0]?.name }
            let linkDetail = [groupName, cardName, potName]
                .compactMap { $0 }
                .joined(separator: " • ")
            events.append(
                ActivityTimelineEvent(
                    id: "bill-created-\(payment.id)",
                    sortKey: payment.createdAt,
                    title: "Bill added",
                    detail: linkDetail.isEmpty ? payment.name : "\(payment.name) • \(linkDetail)",
                    typeLabel: "Bill",
                    secondaryLabel: prettyLabel(payment.frequency.rawValue),
                    amountPence: payment.amountPence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.warning,
                    symbol: "calendar.badge.clock"
                )
            )
            appendDeletedEvent(prefix: "bill", name: payment.name, deletedAt: payment.deletedAt, typeLabel: "Bill", color: AppTheme.Colors.warning, symbol: "archivebox", into: &events)
        }

        for period in snapshot.payPeriods {
            events.append(
                ActivityTimelineEvent(
                    id: "pay-period-\(period.id)",
                    sortKey: period.createdAt,
                    title: "Pay period created",
                    detail: "\(timelineDateLabel(period.startDate)) to \(timelineDateLabel(period.endDate)).",
                    typeLabel: "Income",
                    secondaryLabel: prettyLabel(period.status.rawValue),
                    amountPence: period.incomePence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "calendar"
                )
            )
        }

        for paycheck in snapshot.paychecks {
            let period = payPeriodsById[paycheck.payPeriodId]
            events.append(
                ActivityTimelineEvent(
                    id: "paycheck-\(paycheck.id)",
                    sortKey: paycheck.createdAt,
                    title: "Income recorded",
                    detail: period.map { "Payday \(timelineDateLabel($0.payday))" } ?? "Paycheck recorded.",
                    typeLabel: "Income",
                    secondaryLabel: "\(String(format: "%.1f", paycheck.hoursWorked)) hours",
                    amountPence: paycheck.actualAmountPence ?? paycheck.calculatedAmountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.neonMoneyUp,
                    symbol: "sterlingsign.circle"
                )
            )
        }

        for income in snapshot.oneOffIncomes where income.deletedAt == nil {
            events.append(
                ActivityTimelineEvent(
                    id: "one-off-income-\(income.id)",
                    sortKey: income.createdAt,
                    title: "One-off income recorded",
                    detail: income.note.isEmpty ? income.name : "\(income.name) • \(income.note)",
                    typeLabel: "Income",
                    secondaryLabel: timelineDateLabel(income.date),
                    amountPence: income.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.neonMoneyUp,
                    symbol: "plus.circle"
                )
            )
        }

        for allocation in snapshot.potAllocations {
            let potName = allocation.potId.isEmpty ? "Pot" : (potsById[allocation.potId]?.name ?? "Pot")
            events.append(
                ActivityTimelineEvent(
                    id: "allocation-\(allocation.id)",
                    sortKey: allocation.createdAt,
                    title: "Pot funded",
                    detail: potName,
                    typeLabel: "Pot",
                    secondaryLabel: allocation.source.map { prettyLabel($0.rawValue) },
                    amountPence: allocation.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "arrow.down.to.line.compact"
                )
            )
        }

        for transaction in snapshot.transactions {
            let isSpending = transaction.type == .spending
            let route = transaction.creditCardId.flatMap { cardsById[$0]?.name }
                ?? transaction.potId.flatMap { potsById[$0]?.name }
                ?? transaction.paymentMethod?.displayName
                ?? "Manual"
            events.append(
                ActivityTimelineEvent(
                    id: "transaction-\(transaction.id)",
                    sortKey: transaction.date,
                    title: transaction.note.isEmpty ? (isSpending ? "Spending recorded" : "Money movement recorded") : transaction.note,
                    detail: route,
                    typeLabel: isSpending ? "Spend" : prettyLabel(transaction.type.rawValue),
                    secondaryLabel: transaction.paymentMethod?.displayName,
                    amountPence: transaction.type == .spending ? transaction.netAmountPence : transaction.amountPence,
                    amountStyle: isSpending ? .negative : .positive,
                    color: isSpending ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp,
                    symbol: isSpending ? "receipt" : "arrow.left.arrow.right"
                )
            )
        }

        for payment in snapshot.creditCardRepayments {
            events.append(
                ActivityTimelineEvent(
                    id: "card-repayment-\(payment.id)",
                    sortKey: payment.date,
                    title: "Card payment",
                    detail: cardsById[payment.creditCardId]?.name ?? "Credit card",
                    typeLabel: "Credit",
                    secondaryLabel: payment.source.map { prettyLabel($0.rawValue) } ?? "Manual",
                    amountPence: payment.netAmountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "creditcard.and.123"
                )
            )
        }

        for cardPot in snapshot.creditCardPots {
            events.append(
                ActivityTimelineEvent(
                    id: "card-pot-\(cardPot.id)",
                    sortKey: cardPot.createdAt,
                    title: "Card pot created",
                    detail: "\(cardPot.name) for \(cardsById[cardPot.creditCardId]?.name ?? "Credit card").",
                    typeLabel: "Credit",
                    secondaryLabel: prettyLabel(cardPot.status.rawValue),
                    amountPence: cardPot.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.primaryOrange,
                    symbol: "wallet.pass"
                )
            )
        }

        for payment in snapshot.customPayments {
            events.append(
                ActivityTimelineEvent(
                    id: "custom-payment-\(payment.id)",
                    sortKey: payment.createdAt,
                    title: "Custom payment added",
                    detail: payment.name,
                    typeLabel: "Payment",
                    secondaryLabel: timelineDateLabel(payment.dueDate),
                    amountPence: payment.amountPence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.warning,
                    symbol: "calendar.badge.plus"
                )
            )
        }

        for reserve in snapshot.debtReserves {
            events.append(
                ActivityTimelineEvent(
                    id: "debt-reserve-\(reserve.id)",
                    sortKey: reserve.createdAt,
                    title: "Debt reserve created",
                    detail: debtsById[reserve.debtId]?.name ?? "Debt",
                    typeLabel: "Debt",
                    secondaryLabel: prettyLabel(reserve.status.rawValue),
                    amountPence: reserve.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.primaryOrange,
                    symbol: "shield.lefthalf.filled"
                )
            )
        }

        for payment in snapshot.debtPayments {
            events.append(
                ActivityTimelineEvent(
                    id: "debt-payment-\(payment.id)",
                    sortKey: payment.date,
                    title: "Debt payment",
                    detail: debtsById[payment.debtId]?.name ?? "Debt",
                    typeLabel: "Debt",
                    secondaryLabel: prettyLabel(payment.paymentType.rawValue),
                    amountPence: payment.netAmountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "checkmark.shield"
                )
            )
        }

        for brief in snapshot.dailyBriefs {
            events.append(
                ActivityTimelineEvent(
                    id: "daily-brief-\(brief.id)",
                    sortKey: brief.createdAt,
                    title: "Daily brief saved",
                    detail: brief.content.isEmpty ? "Planner summary captured." : brief.content,
                    typeLabel: "Brief",
                    secondaryLabel: timelineDateLabel(brief.date),
                    amountPence: nil,
                    amountStyle: .neutral,
                    color: AppTheme.Colors.secondaryText,
                    symbol: "sparkles"
                )
            )
        }

        return events
            .sorted {
                if $0.sortKey == $1.sortKey {
                    return $0.id < $1.id
                }
                return $0.sortKey < $1.sortKey
            }
    }

    private static func appendDeletedEvent(prefix: String, name: String, deletedAt: String?, typeLabel: String, color: Color, symbol: String, into events: inout [ActivityTimelineEvent]) {
        guard let deletedAt else { return }
        events.append(
            ActivityTimelineEvent(
                id: "\(prefix)-deleted-\(name)-\(deletedAt)",
                sortKey: deletedAt,
                title: "\(name) archived",
                detail: "This item was removed from the active account view.",
                typeLabel: typeLabel,
                secondaryLabel: "Archived",
                amountPence: nil,
                amountStyle: .neutral,
                color: color,
                symbol: symbol
            )
        )
    }

    private static func prettyLabel(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private struct ActivityTimelineEvent: Identifiable {
    enum AmountStyle {
        case positive
        case negative
        case neutral
    }

    var id: String
    var sortKey: String
    var title: String
    var detail: String
    var typeLabel: String
    var secondaryLabel: String?
    var amountPence: Int?
    var amountStyle: AmountStyle
    var color: Color
    var symbol: String

    var dateLabel: String {
        timelineDateLabel(sortKey)
    }

    var cardScrollID: String {
        "timeline-card-\(id)"
    }

    var branchScrollID: String {
        "timeline-branch-\(id)"
    }

    var amountLabel: String? {
        guard let amountPence else { return nil }
        switch amountStyle {
        case .positive:
            return "+\(MoneyParser.formatPence(amountPence))"
        case .negative:
            return "-\(MoneyParser.formatPence(amountPence))"
        case .neutral:
            return MoneyParser.formatPence(amountPence)
        }
    }

    var amountColor: Color {
        switch amountStyle {
        case .positive:
            return AppTheme.Colors.neonMoneyUp
        case .negative:
            return AppTheme.Colors.neonMoneyDown
        case .neutral:
            return AppTheme.Colors.primaryText
        }
    }
}

private func timelineDateLabel(_ isoDate: String) -> String {
    FinanceEngine.parseDate(isoDate.prefixDateLabel).formatted(.dateTime.day().month(.abbreviated).year())
}

struct ActivitySpendingDetailView: View {
    @ObservedObject var store: PlannerStore
    @State private var editMode: EditMode = .inactive
    @State private var isAddSpendingPresented = false

    var body: some View {
        PaydayView(
            store: store,
            navigationMode: .inline,
            toolbarMode: .editDoneAndAdd(
                isEditing: editMode.isEditing,
                canEdit: hasDeletableSpending,
                editAction: toggleEditMode,
                addAction: { isAddSpendingPresented = true }
            )
        )
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $isAddSpendingPresented) {
            SpendingSheetView(store: store)
        }
    }

    private var hasDeletableSpending: Bool {
        store.snapshot.transactions.contains {
            $0.type == .spending && $0.deletedAt == nil
        }
    }

    private func toggleEditMode() {
        withAnimation(appToolbarMorphAnimation) {
            editMode = editMode.isEditing ? .inactive : .active
        }
    }
}

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case spending
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .spending: "Spending"
        case .income: "Income"
        }
    }
}

private enum ActivityEntrySource: Equatable {
    case transaction(String)
    case transfer(String)
    case paycheck(String)
    case oneOffIncome(String)
    case payPeriod(String)
}

private struct ActivitySourceBadge {
    var label: String
    var color: Color
}

private struct ActivityEntry: Identifiable {
    var id: String
    var kind: ActivityFilter
    var title: String
    var detail: String
    var amount: String
    var typeLabel: String
    var color: Color
    var sortDate: String
    var detailRows: [ActivityDetailRow]
    var recordRows: [ActivityDetailRow]
    var source: ActivityEntrySource
    var auditAction: PlannerAuditAction? = nil
    var sourceBadge: ActivitySourceBadge? = nil
}

private struct ActivityDetailRow: Identifiable {
    var label: String
    var value: String
    var valueColor: Color = AppTheme.Colors.primaryText

    var id: String { label }
}

private struct ActivityEntryRow: View {
    var entry: ActivityEntry

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Circle()
                .fill(entry.color)
                .frame(width: 10, height: 10)
                .shadow(color: entry.color.opacity(0.45), radius: 6, y: 2)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    if let auditAction = entry.auditAction {
                        HistoryAuditStatusPill(action: auditAction)
                    }
                    if let sourceBadge = entry.sourceBadge {
                        ActivitySourcePill(source: sourceBadge)
                    }
                }
                Text(entry.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.amount)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(entry.color)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel("Open details for \(entry.title)")
    }
}

private struct ActivitySourcePill: View {
    var source: ActivitySourceBadge

    var body: some View {
        Text(source.label.uppercased())
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(source.color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(source.color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(source.color.opacity(0.2), lineWidth: 1))
            .accessibilityLabel("Paid from \(source.label)")
    }
}

private struct ActivityEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var entry: ActivityEntry
    @State private var isDeleteConfirmationPresented = false
    @State private var isEditPresented = false

    var body: some View {
        ScreenScaffold(
            title: "Activity detail",
            subtitle: currentEntry.title,
            navigationMode: .inline,
            toolbarMode: .actions(toolbarActions),
            titleDisplayMode: .inline
        ) {
            activityHero

            SectionTitle("Details")
            ActivityDetailRowsCard(rows: currentEntry.detailRows)

            if !currentEntry.recordRows.isEmpty {
                SectionTitle("Record")
                ActivityDetailRowsCard(rows: currentEntry.recordRows)
            }
        }
        .navigationDestination(isPresented: $isEditPresented) {
            editDestination
        }
        .alert(deleteConfirmationTitle, isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    private var activityHero: some View {
        let entry = currentEntry
        return AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 10, height: 10)
                                .shadow(color: entry.color.opacity(0.55), radius: 8, y: 2)

                            Text(entry.typeLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.cardEyebrow)
                                .textCase(.uppercase)

                            if let auditAction = entry.auditAction {
                                HistoryAuditStatusPill(action: auditAction)
                            }
                            if let sourceBadge = entry.sourceBadge {
                                ActivitySourcePill(source: sourceBadge)
                            }
                        }

                        Text(entry.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(entry.amount)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(entry.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: 150, alignment: .trailing)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    ActivityHeroInfoPill(label: "Date", value: heroDate, color: entry.color)
                    ActivityHeroInfoPill(label: "Source", value: heroSource, color: AppTheme.Colors.primaryOrange)
                }
            }
        }
    }

    private var detailParts: [String] {
        currentEntry.detail.components(separatedBy: " · ")
    }

    private var heroDate: String {
        detailParts.first ?? currentEntry.detail
    }

    private var heroSource: String {
        if let sourceBadge = currentEntry.sourceBadge {
            return sourceBadge.label
        }
        guard detailParts.count > 1 else { return currentEntry.typeLabel }
        return detailParts.dropFirst().joined(separator: " · ")
    }

    private var currentEntry: ActivityEntry {
        ActivityView.makeActivityEntries(snapshot: store.snapshot)
            .first(where: { $0.source == entry.source }) ?? entry
    }

    private var toolbarActions: [AppToolbarAction] {
        [
            AppToolbarAction(
                id: "activity-detail-delete",
                symbol: "trash",
                accessibilityLabel: "Delete activity"
            ) {
                isDeleteConfirmationPresented = true
            },
            AppToolbarAction(
                id: "activity-detail-edit",
                symbol: "pencil",
                title: "Edit",
                accessibilityLabel: "Edit activity"
            ) {
                isEditPresented = true
            }
        ]
    }

    @ViewBuilder
    private var editDestination: some View {
        switch entry.source {
        case .transaction(let id):
            if let transaction = store.snapshot.transactions.first(where: { $0.id == id && $0.deletedAt == nil }) {
                SpendingTransactionDetailView(store: store, transaction: transaction)
            } else {
                missingRecordView
            }
        case .transfer(let id):
            if let transaction = store.snapshot.transactions.first(where: { $0.id == id && $0.deletedAt == nil }) {
                PotBankTransferView(store: store, transfer: transaction)
            } else {
                missingRecordView
            }
        case .paycheck(let id):
            if let paycheck = store.snapshot.paychecks.first(where: { $0.id == id && $0.deletedAt == nil }) {
                PaycheckDetailView(store: store, paycheck: paycheck, presentation: .push)
            } else {
                missingRecordView
            }
        case .oneOffIncome(let id):
            if let income = store.snapshot.oneOffIncomes.first(where: { $0.id == id && $0.deletedAt == nil }) {
                OneOffIncomeDetailView(store: store, income: income)
            } else {
                missingRecordView
            }
        case .payPeriod(let id):
            if let paycheck = store.snapshot.paychecks.first(where: { $0.payPeriodId == id && $0.deletedAt == nil }) {
                PaycheckDetailView(store: store, paycheck: paycheck, presentation: .push)
            } else {
                missingRecordView
            }
        }
    }

    private var missingRecordView: some View {
        ScreenScaffold(
            title: "Activity",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppCard {
                EmptyStateView(
                    title: "Activity no longer available",
                    message: "This record has already been deleted.",
                    systemImage: "trash"
                )
            }
        }
    }

    private var deleteConfirmationTitle: String {
        "Permanently delete this activity?"
    }

    private var deleteConfirmationMessage: String {
        switch entry.source {
        case .transaction:
            "Are you sure? This payment will be permanently removed and all linked balances will be updated."
        case .transfer:
            "Are you sure? This transfer will be removed and both balances will be restored."
        case .paycheck:
            "Are you sure? This paycheck, its pay period, and linked allocations will be permanently removed."
        case .oneOffIncome:
            "Are you sure? This income will be permanently removed from your totals."
        case .payPeriod:
            "Are you sure? This pay period and its linked paycheck and allocations will be permanently removed."
        }
    }

    private func deleteEntry() {
        switch entry.source {
        case .transaction(let id):
            store.permanentlyDeleteActivityTransaction(id: id)
        case .transfer(let id):
            _ = store.deletePotBankTransfer(id: id)
        case .paycheck(let id):
            store.deletePaycheck(id: id)
        case .oneOffIncome(let id):
            _ = store.permanentlyDeleteOneOffIncome(id: id)
        case .payPeriod(let id):
            store.deletePayPeriod(id: id)
        }
        dismiss()
    }
}

private struct ActivityHeroInfoPill: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ActivityDetailRowsCard: View {
    var rows: [ActivityDetailRow]

    var body: some View {
        AppCard {
            ForEach(rows.indices, id: \.self) { index in
                MetricRow(
                    label: rows[index].label,
                    value: rows[index].value,
                    valueColor: rows[index].valueColor
                )

                if index < rows.count - 1 {
                    AppDivider()
                }
            }
        }
    }
}

struct ActivityYearlyNetChartPoint: Identifiable, Equatable {
    var month: Int
    var monthLabel: String
    var cumulativeNetPence: Int
    var incomePence: Int
    var spentPence: Int
    var isCurrentMonth: Bool
    var isFuture: Bool

    var id: Int { month }

    var netPence: Int {
        incomePence - spentPence
    }
}

struct ActivityYearlyNetChartData: Equatable {
    var year: Int
    var currentMonth: Int
    var totalIncomePence: Int
    var totalSpentPence: Int
    var points: [ActivityYearlyNetChartPoint]

    var id: String {
        "\(year)-\(currentMonth)-\(totalIncomePence)-\(totalSpentPence)"
    }

    var hasData: Bool {
        totalIncomePence != 0 || totalSpentPence != 0
    }

    var currentNetPence: Int {
        totalIncomePence - totalSpentPence
    }

    var activePoints: [ActivityYearlyNetChartPoint] {
        points.filter { !$0.isFuture }
    }

    var graphMinPence: Int {
        min(0, activePoints.map(\.cumulativeNetPence).min() ?? 0)
    }

    var graphMaxPence: Int {
        let maxValue = max(0, activePoints.map(\.cumulativeNetPence).max() ?? 0)
        return maxValue == graphMinPence ? maxValue + 1 : maxValue
    }

    static func make(snapshot: PlannerSnapshot, todayIso: String) -> ActivityYearlyNetChartData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let today = FinanceEngine.parseDate(todayIso)
        let todayComponents = calendar.dateComponents([.year, .month], from: today)
        let year = todayComponents.year ?? 0
        let currentMonth = min(max(todayComponents.month ?? 1, 1), 12)

        // Cloud/local merges can contain the same record ID more than once. Keep the
        // latest array entry instead of trapping while constructing the lookup.
        let payPeriodsById = snapshot.payPeriods.reduce(into: [String: PayPeriod]()) { result, period in
            result[period.id] = period
        }
        let paychecksByPeriodId = snapshot.paychecks.reduce(into: [String: Paycheck]()) { result, paycheck in
            guard paycheck.deletedAt == nil else { return }
            result[paycheck.payPeriodId] = paycheck
        }

        let periodIncomeEvents = payPeriodsById.values.compactMap { period -> ActivityYearAmount? in
            guard period.deletedAt == nil else { return nil }
            let paycheck = paychecksByPeriodId[period.id]
            let sourceId = paycheck?.id ?? period.id
            let override = incomeOverride(
                snapshot: snapshot,
                kind: .paycheck,
                sourceId: sourceId,
                scheduledDate: period.payday
            )
            let amount = override?.amountPenceOverride
                ?? paycheck?.actualAmountPence
                ?? paycheck?.calculatedAmountPence
                ?? period.incomePence
            return resolvedIncomeAmount(
                scheduledDate: period.payday,
                amountPence: amount,
                override: override,
                calendar: calendar,
                year: year,
                todayIso: todayIso
            )
        }

        let oneOffIncomeEvents = snapshot.oneOffIncomes.compactMap { income -> ActivityYearAmount? in
            guard income.deletedAt == nil else { return nil }
            let override = incomeOverride(
                snapshot: snapshot,
                kind: .oneOffIncome,
                sourceId: income.id,
                scheduledDate: income.date
            )
            return resolvedIncomeAmount(
                scheduledDate: income.date,
                amountPence: override?.amountPenceOverride ?? income.amountPence,
                override: override,
                calendar: calendar,
                year: year,
                todayIso: todayIso
            )
        }

        let incomeEvents = periodIncomeEvents + oneOffIncomeEvents
        let spendingEvents = snapshot.transactions.compactMap { transaction -> ActivityYearAmount? in
            guard transaction.deletedAt == nil,
                  !transaction.isRefunded,
                  transaction.type == .spending,
                  transaction.date <= todayIso,
                  let month = monthInYear(transaction.date, calendar: calendar, year: year)
            else {
                return nil
            }
            return ActivityYearAmount(month: month, amountPence: transaction.netAmountPence)
        }

        let incomeByMonth = groupedAmounts(incomeEvents)
        let spendByMonth = groupedAmounts(spendingEvents)

        var cumulativeIncome = 0
        var cumulativeSpend = 0
        var points: [ActivityYearlyNetChartPoint] = []

        for month in 1...12 {
            let monthlyIncome = month <= currentMonth ? incomeByMonth[month, default: 0] : 0
            let monthlySpend = month <= currentMonth ? spendByMonth[month, default: 0] : 0

            if month <= currentMonth {
                cumulativeIncome += monthlyIncome
                cumulativeSpend += monthlySpend
            }

            points.append(
                ActivityYearlyNetChartPoint(
                    month: month,
                    monthLabel: monthLabel(for: month, year: year, calendar: calendar),
                    cumulativeNetPence: cumulativeIncome - cumulativeSpend,
                    incomePence: monthlyIncome,
                    spentPence: monthlySpend,
                    isCurrentMonth: month == currentMonth,
                    isFuture: month > currentMonth
                )
            )
        }

        return ActivityYearlyNetChartData(
            year: year,
            currentMonth: currentMonth,
            totalIncomePence: cumulativeIncome,
            totalSpentPence: cumulativeSpend,
            points: points
        )
    }

    private static func groupedAmounts(_ amounts: [ActivityYearAmount]) -> [Int: Int] {
        amounts.reduce(into: [:]) { result, amount in
            result[amount.month, default: 0] += amount.amountPence
        }
    }

    private static func monthInYear(_ isoDate: String, calendar: Calendar, year: Int) -> Int? {
        guard FinanceEngine.isIsoDate(isoDate.prefixDateLabel) else { return nil }
        let date = FinanceEngine.parseDate(isoDate.prefixDateLabel)
        let components = calendar.dateComponents([.year, .month], from: date)
        guard components.year == year,
              let month = components.month
        else {
            return nil
        }
        return month
    }

    private static func monthLabel(for month: Int, year: Int, calendar: Calendar) -> String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: components) else {
            return "Month \(month)"
        }
        return date.formatted(.dateTime.month(.wide))
    }

    private static func incomeOverride(
        snapshot: PlannerSnapshot,
        kind: IncomeOccurrenceSourceKind,
        sourceId: String,
        scheduledDate: String
    ) -> IncomeOccurrenceOverride? {
        snapshot.incomeOccurrenceOverrides.first {
            $0.deletedAt == nil &&
            $0.sourceKind == kind &&
            $0.sourceId == sourceId &&
            $0.scheduledDate == scheduledDate
        }
    }

    private static func resolvedIncomeAmount(
        scheduledDate: String,
        amountPence: Int,
        override: IncomeOccurrenceOverride?,
        calendar: Calendar,
        year: Int,
        todayIso: String
    ) -> ActivityYearAmount? {
        guard override?.state != .awaiting, override?.state != .cancelled else { return nil }
        let effectiveDate: String
        if override?.state == .confirmed,
           let actualDate = override?.actualDate,
           FinanceEngine.isIsoDate(actualDate) {
            effectiveDate = actualDate
        } else {
            effectiveDate = scheduledDate
        }
        guard effectiveDate <= todayIso,
              let month = monthInYear(effectiveDate, calendar: calendar, year: year)
        else { return nil }
        return ActivityYearAmount(month: month, amountPence: max(0, amountPence))
    }
}

private struct ActivityYearAmount {
    var month: Int
    var amountPence: Int
}

enum ActivityYearlyNetChartLayoutPolicy {
    static let lineStyle = "yearToDateCumulativeNet"
    static let futurePresentation = "unusedAxisSpace"
    static let currentMonthMarkerFollowsActualLine = true
    static let monthCount = 12
    static let presentation = "compactLine"
    static let showsProgressRing = false
    static let showsAreaFill = false
    static let chartHeight: CGFloat = 140
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

private struct ActivityYearlyNetCard: View {
    var data: ActivityYearlyNetChartData

    var body: some View {
        AppCard(glow: data.hasData) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Overall income this year")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.cardEyebrow)
                        .textCase(.uppercase)
                    Text(signedMoney(data.currentNetPence))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(data.currentNetPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(data.hasData ? "Total income minus total spending in \(data.year) so far" : "No income or spending recorded in \(data.year)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                ActivityYearNetLineGraph(data: data)
                    .frame(height: ActivityYearlyNetChartLayoutPolicy.chartHeight)

                ActivityYearMetricStrip(data: data)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overall income this year \(signedMoney(data.currentNetPence))")
    }
}

private struct ActivityYearMetricStrip: View {
    var data: ActivityYearlyNetChartData

    var body: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            ActivityChartMetric(label: "Total income", value: MoneyParser.formatPence(data.totalIncomePence), color: AppTheme.Colors.success)
            ActivityChartMetric(label: "Total spent", value: MoneyParser.formatPence(data.totalSpentPence), color: AppTheme.Colors.danger)
            ActivityChartMetric(label: "Net", value: signedMoney(data.currentNetPence), color: data.currentNetPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.Spacing.sm)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(height: 1)
        }
    }
}

private struct ActivityYearlyNetDetailView: View {
    var data: ActivityYearlyNetChartData

    var body: some View {
        ScreenScaffold(
            title: "Yearly cash flow",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            detailHero

            SectionTitle("Yearly line")
            AppCard(glow: data.hasData) {
                ActivityYearNetLineGraph(data: data)
                    .frame(height: 190)
            }

            SectionTitle("Breakdown")
            ActivityDetailRowsCard(rows: breakdownRows)

            SectionTitle("Monthly movement")
            AppCard {
                let rows = data.activePoints
                ForEach(rows.indices, id: \.self) { index in
                    ActivityYearlyNetMonthRow(point: rows[index])

                    if index < rows.count - 1 {
                        AppDivider()
                    }
                }
            }
        }
    }

    private var detailHero: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(data.year)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.cardEyebrow)
                        .textCase(.uppercase)

                    Text(signedMoney(data.currentNetPence))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(data.currentNetPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text("Total income minus total spending from the start of the year to now.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                ActivityYearMetricStrip(data: data)
            }
        }
    }

    private var breakdownRows: [ActivityDetailRow] {
        [
            ActivityDetailRow(label: "Total income", value: MoneyParser.formatPence(data.totalIncomePence), valueColor: AppTheme.Colors.success),
            ActivityDetailRow(label: "Total spending", value: MoneyParser.formatPence(data.totalSpentPence), valueColor: AppTheme.Colors.danger),
            ActivityDetailRow(label: "Overall income", value: signedMoney(data.currentNetPence), valueColor: data.currentNetPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange),
            ActivityDetailRow(label: "Year progress", value: "\(data.currentMonth) of 12 months")
        ]
    }
}

private struct ActivityYearlyNetMonthRow: View {
    var point: ActivityYearlyNetChartPoint

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(point.monthLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(point.isCurrentMonth ? "Current month" : "Month \(point.month)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(signedMoney(point.netPence))
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(point.netPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                    Text("Net month")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                ActivityChartMetricPill(label: "In", value: MoneyParser.formatPence(point.incomePence), color: AppTheme.Colors.success)
                ActivityChartMetricPill(label: "Out", value: MoneyParser.formatPence(point.spentPence), color: AppTheme.Colors.danger)
                ActivityChartMetricPill(label: "Year net", value: signedMoney(point.cumulativeNetPence), color: point.cumulativeNetPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ActivityYearNetLineGraph: View {
    var data: ActivityYearlyNetChartData

    private var trendColor: Color {
        data.currentNetPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange
    }

    var body: some View {
        GeometryReader { proxy in
            let minValue = data.graphMinPence
            let maxValue = data.graphMaxPence
            let activePoints = data.activePoints
            let lineColor = trendColor

            ZStack(alignment: .topLeading) {
                graphGrid

                ActivityYearNetLineShape(
                    points: activePoints,
                    minValue: minValue,
                    maxValue: maxValue
                )
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )

                ForEach(activePoints) { point in
                    Circle()
                        .fill(lineColor)
                        .frame(width: point.isCurrentMonth ? 9 : 6, height: point.isCurrentMonth ? 9 : 6)
                        .overlay {
                            if point.isCurrentMonth {
                                Circle()
                                    .stroke(AppTheme.Colors.primaryText.opacity(0.72), lineWidth: 1.5)
                            }
                        }
                        .position(pointPosition(
                            month: point.month,
                            cumulativeNetPence: point.cumulativeNetPence,
                            size: proxy.size,
                            minValue: minValue,
                            maxValue: maxValue
                        ))
                        .accessibilityHidden(true)
                }

                HStack {
                    Text("Jan")
                    Spacer()
                    Text("Jun")
                    Spacer()
                    Text("Dec")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: 18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Year to date cumulative income minus spending")
        .accessibilityValue(signedMoney(data.currentNetPence))
    }

    private var graphGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                AppTheme.Colors.border.opacity(0.32)
                    .frame(height: 1)
                Spacer()
            }
            AppTheme.Colors.border.opacity(0.42)
                .frame(height: 1)
        }
        .padding(.bottom, 8)
    }

    private func pointPosition(month: Int, cumulativeNetPence: Int, size: CGSize, minValue: Int, maxValue: Int) -> CGPoint {
        let drawingHeight = max(size.height - 26, 1)
        let clampedMonth = min(max(month, 1), 12)
        let x = CGFloat(clampedMonth - 1) / 11 * max(size.width, 1)
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(cumulativeNetPence - minValue) / range
        let y = drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(8, min(drawingHeight, y)))
    }
}

private struct ActivityYearNetLineShape: Shape {
    var points: [ActivityYearlyNetChartPoint]
    var minValue: Int
    var maxValue: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        for (index, point) in points.enumerated() {
            let position = pointPosition(month: point.month, cumulativeNetPence: point.cumulativeNetPence, rect: rect)
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }

        if points.count == 1 {
            let position = pointPosition(month: points[0].month, cumulativeNetPence: points[0].cumulativeNetPence, rect: rect)
            path.addLine(to: CGPoint(x: min(rect.maxX, position.x + 0.5), y: position.y))
        }

        return path
    }

    private func pointPosition(month: Int, cumulativeNetPence: Int, rect: CGRect) -> CGPoint {
        let drawingHeight = max(rect.height - 26, 1)
        let clampedMonth = min(max(month, 1), 12)
        let x = rect.minX + CGFloat(clampedMonth - 1) / 11 * rect.width
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(cumulativeNetPence - minValue) / range
        let y = rect.minY + drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(rect.minY + 8, min(rect.minY + drawingHeight, y)))
    }
}

private struct ActivityChartMetric: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct ActivityChartMetricPill: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CreditView: View {
    @ObservedObject var store: PlannerStore
    var rootTabResetRevision: Int?
    var presentationCache: PlannerTabPresentationCache?
    var presentationContext: PlannerTabPresentationContext?
    @State private var selectedCard: CreditCard?
    @State private var directDebitsExpanded = true
    @State private var nextStatementsExpanded = true

    var body: some View {
        let displayData = creditDisplayData

        ScreenScaffold(
            title: "Credit",
            subtitle: "Cards, debts, and payments due.",
            navigationMode: .tabRoot,
            toolbarMode: .none,
            rootTabResetRevision: rootTabResetRevision
        ) {
            creditSummary(summary: displayData.summary, dueItems: displayData.dueItems)
            activeCardRows(cardModels: displayData.cardModels)
            paymentDueSummary(
                directDebits: displayData.directDebitItems,
                nextStatements: displayData.nextStatementItems
            )
            creditRoutes
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(store: store, card: card)
        }
    }

    private func creditSummary(summary: CreditSummaryData, dueItems: [CreditDueItem]) -> some View {
        NavigationLink {
            CreditOverviewDetailView(summary: summary, dueItems: dueItems)
        } label: {
            CreditSummaryCard(summary: summary, showsDisclosure: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open credit overview")
    }

    private var creditDisplayData: CreditDisplayData {
        let context = presentationContext ?? PlannerTabPresentationContext(
            snapshot: store.snapshot,
            activePlannerAccountId: store.activePlannerAccountId,
            snapshotRevision: store.snapshotRevision,
            todayIso: store.todayIso,
            selectedPayPeriod: store.selectedPayPeriod
        )

        guard let presentationCache else {
            return Self.makePresentation(context: context)
        }

        return presentationCache.value(for: context.key(for: .credit)) {
            Self.makePresentation(context: context)
        }
    }

    static func warmPresentation(cache: PlannerTabPresentationCache, context: PlannerTabPresentationContext) {
        let _: CreditDisplayData = cache.value(for: context.key(for: .credit)) {
            makePresentation(context: context)
        }
    }

    private static func makePresentation(context: PlannerTabPresentationContext) -> CreditDisplayData {
        let snapshot = context.snapshot
        let activeCards = snapshot.creditCards.filter { !$0.archived }
        let totalCredit = PlannerDerivedData.totalCreditLimitPence(cards: snapshot.creditCards)
        let cardModels = creditCardPreviewModels(
            cards: activeCards,
            snapshot: snapshot,
            payPeriod: context.selectedPayPeriod,
            asOfDate: context.todayIso
        )
        let cardOwed = cardModels.reduce(0) { $0 + $1.balancePence }
        let debtSummary = FinanceEngine.getDebtSummary(
            debts: snapshot.debts,
            payments: snapshot.debtPayments,
            reserves: snapshot.debtReserves,
            pots: snapshot.pots,
            today: context.todayIso
        )
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: context.todayIso)
        let unpaidStatements = statements.reduce(0) { $0 + $1.unpaidAmountPence }
        let statementDueItems = statements
            .filter { $0.status != .paid }
            .map {
                CreditDueItem(
                    id: "statement-\($0.id)",
                    title: "\($0.cardName) direct debit",
                    date: $0.directDebitDate,
                    amountPence: $0.unpaidAmountPence,
                    isOverdue: $0.status == .overdue,
                    cardId: $0.cardId,
                    scheduledStatementDate: $0.scheduledStatementDate
                )
            }
        let nextStatementItems = activeCards.compactMap { card -> CreditNextStatementItem? in
            guard let statementDate = PlannerDerivedData.creditCardNextStatementDate(
                card: card,
                snapshot: snapshot,
                asOfDate: context.todayIso
            ) else {
                return nil
            }

            let history = CreditCardBalanceHistoryData.make(card: card, snapshot: snapshot, asOfDate: context.todayIso)
            return CreditNextStatementItem(
                cardId: card.id,
                scheduledStatementDate: statementDate,
                cardName: card.name,
                statementDate: statementDate,
                amountPence: history.currentSection.balancePence,
                movementCount: history.currentSection.entries.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.statementDate == rhs.statementDate {
                lhs.cardName.localizedStandardCompare(rhs.cardName) == .orderedAscending
            } else {
                lhs.statementDate < rhs.statementDate
            }
        }
        let debtsById = Dictionary(uniqueKeysWithValues: snapshot.debts.map { ($0.id, $0) })
        let debtDueItems = PlannerDerivedData.debtScheduleItems(snapshot: snapshot, payPeriod: nil)
            .filter { $0.status != .paid && $0.status != .cancelled }
            .map { item in
                CreditDueItem(
                    id: "debt-\(item.id)",
                    title: debtsById[item.debtId]?.name ?? "Debt payment",
                    date: item.dueDate,
                    amountPence: item.plannedAmountPence,
                    isOverdue: item.dueDate < context.todayIso,
                    cardId: nil,
                    scheduledStatementDate: nil
                )
            }

        return CreditDisplayData(
            summary: CreditSummaryData(
                totalCreditPence: totalCredit,
                cardOwedPence: cardOwed,
                debtBalancePence: debtSummary.totalCurrentBalancePence,
                debtPaidPence: debtSummary.totalPaidPence,
                overdueDebtCount: debtSummary.overdueDebtCount,
                unpaidStatementsPence: unpaidStatements,
                unpaidStatementCount: statements.filter { $0.status != .paid }.count,
                activeCardCount: activeCards.count,
                activeDebtCount: snapshot.debts.filter { $0.deletedAt == nil && $0.status.isActiveLike }.count
            ),
            dueItems: (statementDueItems + debtDueItems).sorted { $0.date < $1.date },
            directDebitItems: statementDueItems.sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                } else {
                    lhs.date < rhs.date
                }
            },
            nextStatementItems: nextStatementItems,
            cardModels: cardModels
        )
    }

    private func paymentDueSummary(
        directDebits: [CreditDueItem],
        nextStatements: [CreditNextStatementItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Due soon")

            CreditDirectDebitsCard(
                items: directDebits,
                previewLimit: CreditLayoutPolicy.dueSoonPreviewItemLimit,
                showsDisclosure: true,
                isExpanded: $directDebitsExpanded,
                moreDestination: { AnyView(CreditScheduleDetailView(store: store, schedule: .directDebits)) }
            )

            CreditNextStatementsCard(
                items: nextStatements,
                previewLimit: CreditLayoutPolicy.dueSoonPreviewItemLimit,
                showsDisclosure: true,
                isExpanded: $nextStatementsExpanded,
                moreDestination: { AnyView(CreditScheduleDetailView(store: store, schedule: .statements)) }
            )
        }
        .padding(.top, CreditLayoutPolicy.dueSoonTopAdjustment)
    }

    @ViewBuilder
    private func activeCardRows(cardModels: [CreditCardPreviewModel]) -> some View {
        if !cardModels.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionTitle("Cards")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        ForEach(cardModels) { model in
                            Button {
                                selectedCard = model.card
                            } label: {
                                FloatingCreditCardPreview(model: model)
                                .equatable()
                                .frame(width: CreditLayoutPolicy.cardRowWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }
                .padding(.horizontal, -AppTheme.Spacing.lg)
            }
        }
    }

    private var creditRoutes: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(CreditRoute.allCases, id: \.rawValue) { route in
                creditRoute(route)
            }
        }
    }

    @ViewBuilder
    private func creditRoute(_ route: CreditRoute) -> some View {
        switch route {
        case .cards:
            NavigationLink {
                CardsView(store: store, navigationMode: .inline)
            } label: {
                creditRouteCard(route)
            }
            .buttonStyle(.plain)
        case .debts:
            NavigationLink {
                DebtsView(store: store)
            } label: {
                creditRouteCard(route)
            }
            .buttonStyle(.plain)
        }
    }

    private func creditRouteCard(_ route: CreditRoute) -> some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: route.symbol)
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(route.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(route.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }
}

private struct CreditDisplayData {
    var summary: CreditSummaryData
    var dueItems: [CreditDueItem]
    var directDebitItems: [CreditDueItem]
    var nextStatementItems: [CreditNextStatementItem]
    var cardModels: [CreditCardPreviewModel]
}

private struct CreditSummaryData {
    var totalCreditPence: Int
    var cardOwedPence: Int
    var debtBalancePence: Int
    var debtPaidPence: Int
    var overdueDebtCount: Int
    var unpaidStatementsPence: Int
    var unpaidStatementCount: Int
    var activeCardCount: Int
    var activeDebtCount: Int

    var totalOwedPence: Int {
        cardOwedPence + debtBalancePence
    }

    var hasOwedBalance: Bool {
        totalOwedPence > 0 || unpaidStatementsPence > 0
    }
}

private struct CreditSummaryCard: View {
    var summary: CreditSummaryData
    var showsDisclosure: Bool

    var body: some View {
        AppCard(glow: true) {
            CreditMetricGrid(
                items: [
                    .init(label: "Total credit", value: MoneyParser.formatPence(summary.totalCreditPence)),
                    .init(label: "Cards owed", value: MoneyParser.formatPence(summary.cardOwedPence)),
                    .init(label: "Debt balance", value: MoneyParser.formatPence(summary.debtBalancePence)),
                    .init(
                        label: "Unpaid statements",
                        value: MoneyParser.formatPence(summary.unpaidStatementsPence),
                        valueColor: summary.unpaidStatementsPence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success
                    )
                ]
            )

            if showsDisclosure {
                HStack(spacing: 8) {
                    Text("View credit overview")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct CreditOverviewDetailView: View {
    var summary: CreditSummaryData
    var dueItems: [CreditDueItem]

    var body: some View {
        ScreenScaffold(
            title: "Credit overview",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            CreditSummaryCard(summary: summary, showsDisclosure: false)

            SectionTitle("Breakdown")
            AppCard {
                CreditMetricGrid(
                    items: [
                        .init(label: "Active cards", value: "\(summary.activeCardCount)"),
                        .init(label: "Active debts", value: "\(summary.activeDebtCount)"),
                        .init(label: "Paid toward debts", value: MoneyParser.formatPence(summary.debtPaidPence), valueColor: AppTheme.Colors.success),
                        .init(label: "Overdue debts", value: "\(summary.overdueDebtCount)", valueColor: summary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success),
                        .init(label: "Open statements", value: "\(summary.unpaidStatementCount)")
                    ]
                )
            }

            SectionTitle("Due soon")
            AppCard {
                if dueItems.isEmpty {
                    EmptyStateView(title: "Nothing due soon", message: "Card statements and debt payments will appear here when scheduled.", systemImage: "checkmark.circle")
                } else {
                    CreditMetricGrid(
                        items: dueItems.prefix(10).map { item in
                            .init(
                                id: item.id,
                                label: item.title,
                                detail: shortDate(item.date),
                                value: MoneyParser.formatPence(item.amountPence),
                                valueColor: item.isOverdue ? AppTheme.Colors.danger : AppTheme.Colors.warning
                            )
                        }
                    )
                }
            }
        }
    }
}

struct CreditDueItem: Identifiable {
    var id: String
    var title: String
    var date: String
    var amountPence: Int
    var isOverdue: Bool
    var cardId: String?
    var scheduledStatementDate: String?
}

struct CreditNextStatementItem: Identifiable {
    var cardId: String
    var scheduledStatementDate: String
    var cardName: String
    var statementDate: String
    var amountPence: Int
    var movementCount: Int

    var id: String { "\(cardId)-\(scheduledStatementDate)" }
}

enum CreditScheduleDetail: Equatable {
    case directDebits
    case statements
}

struct CreditScheduleDetailView: View {
    @ObservedObject var store: PlannerStore
    var schedule: CreditScheduleDetail
    @State private var showsPreviousStatements = !CreditLayoutPolicy.previousStatementsStartCollapsed

    var body: some View {
        ScreenScaffold(
            title: title,
            subtitle: subtitle,
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            switch schedule {
            case .directDebits:
                CreditDirectDebitsCard(items: directDebitItems, destination: { item in
                    CreditStatementLedgerDetailView(
                        store: store,
                        identity: item.statementIdentity ?? .init(cardId: "", scheduledStatementDate: ""),
                        mode: .directDebit
                    )
                })
            case .statements:
                CreditNextStatementsCard(items: currentStatementItems, destination: { item in
                    CreditStatementLedgerDetailView(
                        store: store,
                        identity: .init(cardId: item.cardId, scheduledStatementDate: item.scheduledStatementDate),
                        mode: .currentStatement
                    )
                })

                DisclosureGroup(isExpanded: $showsPreviousStatements) {
                    VStack(spacing: 0) {
                        if previousStatements.isEmpty {
                            Text("No previous statements yet")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        } else {
                            ForEach(Array(previousStatements.enumerated()), id: \.element.id) { index, statement in
                                NavigationLink {
                                    CreditStatementLedgerDetailView(
                                        store: store,
                                        identity: .init(cardId: statement.cardId, scheduledStatementDate: statement.scheduledStatementDate),
                                        mode: .previousStatement
                                    )
                                } label: {
                                    CreditStatementScheduleRow(
                                        title: statement.cardName,
                                        subtitle: "\(shortDate(statement.statementDate)) · \(statementStatusLabel(statement.status))",
                                        amountPence: statement.statementAmountPence
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens the locked statement and every editable movement")
                                if index < previousStatements.count - 1 { AppDivider() }
                            }
                        }
                    }
                    .padding(.top, AppTheme.Spacing.sm)
                } label: {
                    CreditScheduleHeader(title: "Previous statements", showsDisclosure: true, isExpanded: showsPreviousStatements)
                }
                .tint(AppTheme.Colors.primaryOrange)
                .accessibilityIdentifier("previous-statements-disclosure")
            }
        }
    }

    private var directDebitItems: [CreditDueItem] {
        PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: store.todayIso)
            .filter { $0.status != .paid }
            .sorted { $0.directDebitDate < $1.directDebitDate }
            .map {
                CreditDueItem(
                    id: "statement-\($0.id)",
                    title: "\($0.cardName) direct debit",
                    date: $0.directDebitDate,
                    amountPence: $0.unpaidAmountPence,
                    isOverdue: $0.status == .overdue,
                    cardId: $0.cardId,
                    scheduledStatementDate: $0.scheduledStatementDate
                )
            }
    }

    private var currentStatementItems: [CreditNextStatementItem] {
        store.snapshot.creditCards
            .filter { !$0.archived && $0.deletedAt == nil }
            .compactMap { card in
                guard let date = PlannerDerivedData.creditCardNextStatementDate(card: card, snapshot: store.snapshot, asOfDate: store.todayIso) else { return nil }
                let current = CreditCardBalanceHistoryData.make(card: card, snapshot: store.snapshot, asOfDate: store.todayIso).currentSection
                return CreditNextStatementItem(
                    cardId: card.id,
                    scheduledStatementDate: date,
                    cardName: card.name,
                    statementDate: date,
                    amountPence: current.balancePence,
                    movementCount: current.entries.count
                )
            }
            .sorted { $0.statementDate < $1.statementDate }
    }

    private var previousStatements: [CreditCardStatementSummary] {
        PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: store.todayIso)
            .filter { $0.statementDate <= store.todayIso }
            .sorted { $0.statementDate > $1.statementDate }
    }

    private var title: String {
        switch schedule {
        case .directDebits: "Direct debits"
        case .statements: "Statements"
        }
    }

    private var subtitle: String {
        switch schedule {
        case .directDebits: "Every open collection and the movements that make up its total."
        case .statements: "Open cycles and locked previous statements."
        }
    }
}

struct CreditStatementIdentity: Hashable, Identifiable {
    var cardId: String
    var scheduledStatementDate: String
    var id: String { "\(cardId)-\(scheduledStatementDate)" }
}

private extension CreditDueItem {
    var statementIdentity: CreditStatementIdentity? {
        guard let cardId, let scheduledStatementDate else { return nil }
        return CreditStatementIdentity(cardId: cardId, scheduledStatementDate: scheduledStatementDate)
    }
}

private struct CreditScheduleHeader: View {
    var title: String
    var showsDisclosure = false
    var isExpanded = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Spacer(minLength: AppTheme.Spacing.sm)
            if showsDisclosure {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: CreditLayoutPolicy.scheduleHeaderMinimumTapTarget,
                           height: CreditLayoutPolicy.scheduleHeaderMinimumTapTarget)
                    .accessibilityHidden(true)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: CreditLayoutPolicy.scheduleHeaderMinimumTapTarget,
            alignment: .leading
        )
        .contentShape(Rectangle())
    }
}

private struct CreditDirectDebitsCard: View {
    var items: [CreditDueItem]
    var previewLimit: Int?
    var showsDisclosure: Bool
    var isExpanded: Binding<Bool>?
    var moreDestination: (() -> AnyView)?
    var destination: ((CreditDueItem) -> CreditStatementLedgerDetailView)?

    init(
        items: [CreditDueItem],
        previewLimit: Int? = nil,
        showsDisclosure: Bool = false,
        isExpanded: Binding<Bool>? = nil,
        moreDestination: (() -> AnyView)? = nil,
        destination: ((CreditDueItem) -> CreditStatementLedgerDetailView)? = nil
    ) {
        self.items = items
        self.previewLimit = previewLimit
        self.showsDisclosure = showsDisclosure
        self.isExpanded = isExpanded
        self.moreDestination = moreDestination
        self.destination = destination
    }

    var body: some View {
        AppCard {
            Button {
                isExpanded?.wrappedValue.toggle()
            } label: {
                CreditScheduleHeader(title: "Direct debits", showsDisclosure: showsDisclosure, isExpanded: expanded)
            }
            .buttonStyle(.plain)
            .disabled(isExpanded == nil)
            .accessibilityIdentifier(CreditLayoutPolicy.directDebitsDisclosureId)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")

            if expanded && items.isEmpty {
                EmptyStateView(
                    title: "No direct debits due",
                    message: "Open card statement payments will appear here.",
                    systemImage: "checkmark.circle"
                )
                    .padding(.top, CreditLayoutPolicy.scheduleContentTopAdjustment)
            } else if expanded {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                ForEach(visibleItems) { item in
                    if let destination {
                        NavigationLink { destination(item) } label: { CreditDirectDebitRow(item: item, showsDisclosure: true) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the collection reconciliation and editable movements")
                    } else {
                        CreditDirectDebitRow(item: item, showsDisclosure: false)
                    }

                    if item.id != visibleItems.last?.id {
                        AppDivider()
                    }
                }

                remainingItemsLabel
                }
                .padding(.top, CreditLayoutPolicy.scheduleContentTopAdjustment)
                .accessibilityIdentifier(CreditLayoutPolicy.directDebitsContentId)
            }
        }
    }

    private var expanded: Bool {
        isExpanded?.wrappedValue ?? true
    }

    private var visibleItems: [CreditDueItem] {
        guard let previewLimit else { return items }
        return Array(items.prefix(previewLimit))
    }

    @ViewBuilder
    private var remainingItemsLabel: some View {
        let remainingCount = items.count - visibleItems.count
        if remainingCount > 0 {
            if let moreDestination {
                NavigationLink { moreDestination() } label: {
                    Text("View \(remainingCount) more")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
                .buttonStyle(.plain)
            } else {
                Text("View \(remainingCount) more")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
            }
        }
    }
}

private struct CreditDirectDebitRow: View {
    var item: CreditDueItem
    var showsDisclosure: Bool

    var body: some View {
        CreditStatementScheduleRow(
            title: item.title,
            subtitle: "\(item.isOverdue ? "Overdue" : CreditLayoutPolicy.directDebitFutureStatus) · \(shortDate(item.date))",
            amountPence: item.amountPence,
            statusColor: item.isOverdue ? AppTheme.Colors.danger : AppTheme.Colors.secondaryText,
            showsDisclosure: showsDisclosure
        )
    }
}

private struct CreditNextStatementsCard: View {
    var items: [CreditNextStatementItem]
    var previewLimit: Int?
    var showsDisclosure: Bool
    var isExpanded: Binding<Bool>?
    var moreDestination: (() -> AnyView)?
    var destination: ((CreditNextStatementItem) -> CreditStatementLedgerDetailView)?

    init(
        items: [CreditNextStatementItem],
        previewLimit: Int? = nil,
        showsDisclosure: Bool = false,
        isExpanded: Binding<Bool>? = nil,
        moreDestination: (() -> AnyView)? = nil,
        destination: ((CreditNextStatementItem) -> CreditStatementLedgerDetailView)? = nil
    ) {
        self.items = items
        self.previewLimit = previewLimit
        self.showsDisclosure = showsDisclosure
        self.isExpanded = isExpanded
        self.moreDestination = moreDestination
        self.destination = destination
    }

    var body: some View {
        AppCard {
            Button {
                isExpanded?.wrappedValue.toggle()
            } label: {
                CreditScheduleHeader(title: "Next statements", showsDisclosure: showsDisclosure, isExpanded: expanded)
            }
            .buttonStyle(.plain)
            .disabled(isExpanded == nil)
            .accessibilityIdentifier(CreditLayoutPolicy.nextStatementsDisclosureId)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")

            if expanded && items.isEmpty {
                EmptyStateView(
                    title: "No statements scheduled",
                    message: "Next statement dates will appear after they are set on your cards.",
                    systemImage: "doc.text"
                )
                    .padding(.top, CreditLayoutPolicy.scheduleContentTopAdjustment)
            } else if expanded {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                ForEach(visibleItems) { item in
                    if let destination {
                        NavigationLink { destination(item) } label: {
                            CreditStatementScheduleRow(
                                title: item.cardName,
                                subtitle: "Closes \(shortDate(item.statementDate)) · \(item.movementCount) movements",
                                amountPence: item.amountPence,
                                showsDisclosure: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens every movement contributing to the current statement")
                    } else {
                        CreditStatementScheduleRow(
                            title: item.cardName,
                            subtitle: "Closes \(shortDate(item.statementDate)) · \(item.movementCount) movements",
                            amountPence: item.amountPence
                        )
                    }

                    if item.id != visibleItems.last?.id {
                        AppDivider()
                    }
                }

                remainingItemsLabel
                }
                .padding(.top, CreditLayoutPolicy.scheduleContentTopAdjustment)
                .accessibilityIdentifier(CreditLayoutPolicy.nextStatementsContentId)
            }
        }
    }

    private var expanded: Bool {
        isExpanded?.wrappedValue ?? true
    }

    private var visibleItems: [CreditNextStatementItem] {
        guard let previewLimit else { return items }
        return Array(items.prefix(previewLimit))
    }

    @ViewBuilder
    private var remainingItemsLabel: some View {
        let remainingCount = items.count - visibleItems.count
        if remainingCount > 0 {
            if let moreDestination {
                NavigationLink { moreDestination() } label: {
                    Text("View \(remainingCount) more")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
                .buttonStyle(.plain)
            } else {
                Text("View \(remainingCount) more")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
            }
        }
    }
}

private struct CreditStatementScheduleRow: View {
    var title: String
    var subtitle: String
    var amountPence: Int
    var statusColor: Color = AppTheme.Colors.secondaryText
    var showsDisclosure = false

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.Colors.primaryText)
                Text(subtitle).font(.caption).foregroundStyle(statusColor).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: AppTheme.Spacing.sm)
            Text(MoneyParser.formatPence(amountPence))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: CreditLayoutPolicy.ledgerRowMinimumTapTarget,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

enum CreditStatementLedgerMode: Equatable {
    case directDebit
    case currentStatement
    case previousStatement
}

struct CreditStatementLedgerDetailView: View {
    @ObservedObject var store: PlannerStore
    var identity: CreditStatementIdentity
    var mode: CreditStatementLedgerMode
    @State private var editTarget: CreditCardBalanceHistoryEditTarget?
    @State private var isCycleAdjustmentPresented = false

    var body: some View {
        ScreenScaffold(
            title: title,
            subtitle: subtitle,
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            if card != nil, let section {
                AppCard {
                    CreditMetricGrid(items: summaryMetrics)
                    Button {
                        isCycleAdjustmentPresented = true
                    } label: {
                        Label("Adjust cycle date or status", systemImage: "calendar.badge.clock")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.Colors.primaryOrange)
                }

                if let statementSummary {
                    SectionTitle("Reconciliation")
                    AppCard {
                        MetricRow(label: "Tracked movements", value: MoneyParser.formatPence(statementSummary.calculatedAmountPence))
                        AppDivider()
                        MetricRow(
                            label: statementSummary.reconciliationAdjustmentPence >= 0 ? "Unitemised adjustment" : "Refunds and adjustments",
                            value: MoneyParser.formatPence(abs(statementSummary.reconciliationAdjustmentPence)),
                            valueColor: statementSummary.reconciliationAdjustmentPence < 0 ? AppTheme.Colors.success : AppTheme.Colors.warning
                        )
                        AppDivider()
                        MetricRow(label: "Paid", value: MoneyParser.formatPence(statementSummary.paidAmountPence), valueColor: AppTheme.Colors.success)
                        AppDivider()
                        MetricRow(label: "Outstanding", value: MoneyParser.formatPence(statementSummary.unpaidAmountPence), valueColor: statementSummary.unpaidAmountPence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success)
                    }
                }

                SectionTitle(mode == .currentStatement ? "Contributing movements" : "Statement movements")
                AppCard {
                    if section.entries.isEmpty {
                        EmptyStateView(title: "No movements yet", message: "Movements appear here as they are recorded.", systemImage: "list.bullet.rectangle")
                    } else {
                        ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                            if let target = entry.editTarget {
                                Button { editTarget = target } label: {
                                    CreditCardBalanceHistoryEntryRow(entry: entry, showsEditIndicator: true, auditAction: nil)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens this movement to edit, refund, or delete")
                            } else {
                                CreditCardBalanceHistoryEntryRow(entry: entry, showsEditIndicator: false, auditAction: nil)
                            }
                            if index < section.entries.count - 1 { AppDivider() }
                        }
                    }
                }
            } else {
                AppCard {
                    EmptyStateView(title: "Statement unavailable", message: "The card or statement was deleted.", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .sheet(item: $editTarget) { CreditCardBalanceHistoryEditorSheet(store: store, target: $0) }
        .sheet(isPresented: $isCycleAdjustmentPresented) {
            if let card {
                CreditCardCycleAdjustmentSheet(
                    store: store,
                    card: card,
                    scheduledStatementDate: identity.scheduledStatementDate
                )
            }
        }
        .accessibilityIdentifier("credit-statement-ledger-\(identity.id)")
    }

    private var card: CreditCard? {
        store.snapshot.creditCards.first { $0.id == identity.cardId && $0.deletedAt == nil }
    }

    private var history: CreditCardBalanceHistoryData? {
        card.map { CreditCardBalanceHistoryData.make(card: $0, snapshot: store.snapshot, asOfDate: store.todayIso) }
    }

    private var section: CreditCardBalanceHistorySection? {
        switch mode {
        case .currentStatement:
            history?.currentSection
        case .directDebit, .previousStatement:
            history?.statementSections.first { statementSection in
                statementSection.id == "statement-\(identity.id)" ||
                    statementSection.statementDate == statementSummary?.statementDate
            }
        }
    }

    private var statementSummary: CreditCardStatementSummary? {
        PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: store.todayIso)
            .first { $0.cardId == identity.cardId && $0.scheduledStatementDate == identity.scheduledStatementDate }
    }

    private var title: String {
        switch mode {
        case .directDebit: "Direct debit"
        case .currentStatement: "Current statement"
        case .previousStatement: "Previous statement"
        }
    }

    private var subtitle: String {
        guard let card else { return "" }
        return "\(card.name) · \(shortDate(identity.scheduledStatementDate))"
    }

    private var summaryMetrics: [CreditMetricGrid.Item] {
        guard let section else { return [] }
        var result = [CreditMetricGrid.Item(label: mode == .currentStatement ? "Total so far" : "Locked total", value: MoneyParser.formatPence(section.balancePence), valueColor: AppTheme.Colors.primaryOrange)]
        if let statementSummary {
            result.append(.init(label: "Payment status", value: statementStatusLabel(statementSummary.status)))
            result.append(.init(label: "Collection date", value: shortDate(statementSummary.directDebitDate)))
        } else {
            result.append(.init(label: "Statement date", value: shortDate(identity.scheduledStatementDate)))
        }
        result.append(.init(label: "Movements", value: "\(section.entries.count)"))
        return result
    }
}

private func statementStatusLabel(_ status: CreditCardStatementStatus) -> String {
    switch status {
    case .upcoming: "Upcoming"
    case .paid: "Paid"
    case .overdue: "Overdue"
    case .awaitingConfirmation: "Awaiting confirmation"
    }
}

struct StatementsLayoutPolicy {
    static let toolbarActionId = "edit-toolbar-action"

    static func toolbarMode(editAction: @escaping () -> Void = {}) -> AppToolbarMode {
        .actions([AppToolbarAction.edit(action: editAction)])
    }
}

struct StatementsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = StatementsLayoutPolicy.toolbarMode()
    @State private var selectedStatementID: String?

    private var statements: [CreditCardStatementSummary] {
        PlannerDerivedData.creditCardStatementSummaries(
            snapshot: store.snapshot,
            asOfDate: store.todayIso
        )
    }

    var body: some View {
        ScreenScaffold(
            title: "Credit Statements",
            subtitle: "",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            if statements.isEmpty {
                AppCard {
                    EmptyStateView(title: "No statements yet", message: "Statements appear after a card statement date has passed.", systemImage: "doc.text")
                }
            } else {
                ForEach(statements) { statement in
                    Button {
                        selectedStatementID = statement.id
                    } label: {
                        StatementSummaryCard(statement: statement)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(statement.cardName) statement from \(shortDate(statement.statementDate))")
                    .accessibilityHint("Shows statement totals, payment status, and every transaction")
                }
            }
        }
        .accessibilityIdentifier("statements-screen")
        .navigationDestination(item: $selectedStatementID) { statementID in
            if let statement = statements.first(where: { $0.id == statementID }) {
                StatementDetailView(statement: statement)
            } else {
                ContentUnavailableView("Statement unavailable", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    private func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct StatementSummaryCard: View {
    var statement: CreditCardStatementSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AppCard(glow: statement.status == .overdue) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(statement.cardName) Statement")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text("Statement date: \(shortDate(statement.statementDate))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            statusBadge
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                        }
                    }
                } else {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(statement.cardName) Statement")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Colors.primaryText)
                            Text("Statement date: \(shortDate(statement.statementDate))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        Spacer()
                        statusBadge

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                }

                CreditMetricGrid(items: statementMetrics)
            }
        }
        .accessibilityIdentifier("statement-card-\(statement.cardId)-\(statement.statementDate)")
    }

    private var statusBadge: some View {
        Text(statusLabel)
            .font(.caption.weight(.bold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statementMetrics: [CreditMetricGrid.Item] {
        var items = [
            CreditMetricGrid.Item(label: "Statement total", value: MoneyParser.formatPence(statement.statementAmountPence), valueColor: AppTheme.Colors.primaryOrange),
            CreditMetricGrid.Item(label: "Due date", value: shortDate(statement.directDebitDate))
        ]
        if statement.paidAmountPence > 0 {
            items.append(.init(label: "Paid", value: MoneyParser.formatPence(statement.paidAmountPence), valueColor: AppTheme.Colors.success))
        }
        if statement.unpaidAmountPence > 0 {
            items.append(.init(label: "Remaining", value: MoneyParser.formatPence(statement.unpaidAmountPence), valueColor: statement.status == .overdue ? AppTheme.Colors.danger : AppTheme.Colors.warning))
        }
        items.append(.init(label: "Tracked transactions", value: "\(statement.transactions.count)", valueColor: AppTheme.Colors.secondaryText))
        return items
    }

    private var statusLabel: String {
        switch statement.status {
        case .upcoming:
            return "Upcoming"
        case .paid:
            return "Paid"
        case .overdue:
            return "Overdue"
        case .awaitingConfirmation:
            return "Awaiting confirmation"
        }
    }

    private var statusColor: Color {
        switch statement.status {
        case .upcoming:
            return AppTheme.Colors.warning
        case .paid:
            return AppTheme.Colors.success
        case .overdue:
            return AppTheme.Colors.danger
        case .awaitingConfirmation:
            return AppTheme.Colors.warning
        }
    }

    private func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
    }
}

private extension String {
    var accessibilityIdentifierSlug: String {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

struct DateSimulationCard: View {
    @ObservedObject var store: PlannerStore
    @State private var manualDate = Date()

    var body: some View {
        SettingsPanel(
            title: "Planner date",
            subtitle: "Use today automatically or preview another date.",
            systemImage: "calendar.badge.clock",
            tint: store.snapshot.settings.appDateMode == .manual ? AppTheme.Colors.primaryOrange : AppTheme.Colors.success
        ) {
            MetricRow(label: "Today", value: FinanceEngine.formatShortDateLabel(store.todayIso), valueColor: store.snapshot.settings.appDateMode == .manual ? AppTheme.Colors.primaryOrange : AppTheme.Colors.success)
            Picker("Date mode", selection: dateModeBinding) {
                ForEach(AppDateMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if store.snapshot.settings.appDateMode == .manual {
                DatePicker("Manual today", selection: manualDateBinding, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(AppTheme.Colors.primaryOrange)
                    .foregroundStyle(AppTheme.Colors.primaryText)
            }
        }
        .onAppear {
            manualDate = store.snapshot.settings.manualTodayIso?.isoDate ?? store.todayIso.isoDate
        }
    }

    private var dateModeBinding: Binding<AppDateMode> {
        Binding {
            store.snapshot.settings.appDateMode
        } set: { mode in
            var settings = store.snapshot.settings
            settings.appDateMode = mode
            switch mode {
            case .automatic:
                settings.manualTodayIso = nil
            case .manual:
                let selectedDate = settings.manualTodayIso?.isoDate ?? manualDate
                manualDate = selectedDate
                settings.manualTodayIso = selectedDate.isoDateString
            }
            store.updateSettings(settings)
        }
    }

    private var manualDateBinding: Binding<Date> {
        Binding {
            manualDate
        } set: { selectedDate in
            manualDate = selectedDate
            var settings = store.snapshot.settings
            settings.appDateMode = .manual
            settings.manualTodayIso = selectedDate.isoDateString
            store.updateSettings(settings)
        }
    }
}
