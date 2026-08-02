import Foundation
import SwiftUI

enum PotsSection: Equatable {
    case summary
    case controls
    case potList
}

enum PotsOverviewDetailSection: Equatable {
    case graph
    case timeline
}

enum PotsDetailPresentation: Equatable {
    case navigationPush
}

enum PotsLayoutPolicy {
    static let sections: [PotsSection] = [.summary, .controls, .potList]
    static let summaryPresentation: PotsDetailPresentation = .navigationPush
    static let summaryShowsTopCardSymbol = false
    static let overviewDetailSections: [PotsOverviewDetailSection] = [.graph, .timeline]
    static let graphStyle = "themeAdaptiveLine"
    static let timelineStyle = "themeAdaptivePotTimeline"
    static let timelinePresentation = "collapsibleDropdown"
    static let timelineDefaultsExpandedWhenEmpty = true
    static let overviewDetailSubtitle = ""
    static let overviewDetailUsesInlineTitle = true
    static let potOverviewShowsAllocateAction = true
    static let potOverviewShowsRecordSpendingAction = false
}

enum PotHistoryLayoutPolicy {
    static let toolbarActionId = AppEditDoneToolbarPolicy.editToolbarActionId
    static let editTitle = AppEditDoneToolbarPolicy.editTitle
    static let doneTitle = AppEditDoneToolbarPolicy.doneTitle
    static let usesNativeToolbarContentSwap = true
    static let showsPlaceholderOptions = false
    static let showsTopDividerAboveModePicker = false
    static let editRequiresDeletableRows = true
    static let deleteControlStyle = "destructiveBadge"
    static let deleteRequiresConfirmation = true
}

enum PotFormLayoutPolicy {
    static let usesBillsStyleCard = true
    static let hidesNavigationDivider = true
    static let linkedPickerStyle = "selectionFieldBox"
    static let colorHexes = [
        "#FF7A1A",
        "#22C55E",
        "#38BDF8",
        "#A855F7",
        "#F43F5E",
        "#FACC15",
        "#14B8A6",
        "#64748B"
    ]
}

private struct PotTabPresentationRow: Identifiable {
    var pot: Pot
    var linkedLabel: String?
    var progress: PotProgress
    var pendingFundingContext: PotPendingFundingContext

    var id: String { pot.id }
}

private struct PotsTabPresentation {
    var activePots: [Pot]
    var totalSavedPence: Int
    var rows: [PotTabPresentationRow]
}

struct PotsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    var rootTabResetRevision: Int?
    var presentationCache: PlannerTabPresentationCache?
    var presentationContext: PlannerTabPresentationContext?
    @State private var query = ""
    @State private var selectedType: PotType?
    @State private var selectedPot: Pot?

    private var filteredRows: [PotTabPresentationRow] {
        tabPresentation.rows.filter { row in
            let pot = row.pot
            let matchesQuery = query.isEmpty
                || pot.name.localizedCaseInsensitiveContains(query)
                || (pot.category ?? "").localizedCaseInsensitiveContains(query)
            let matchesType = selectedType == nil || pot.type == selectedType
            return matchesQuery && matchesType
        }
    }

    var body: some View {
        ScreenScaffold(
            title: "Pots",
            subtitle: "Buckets for bills, spending, savings, investments, and buffers.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode,
            rootTabResetRevision: rootTabResetRevision
        ) {
            summaryCard
            if !tabPresentation.activePots.isEmpty {
                controls
            }
            potList
        }
        .sheet(item: $selectedPot) { pot in
            PotDetailView(store: store, pot: pot)
        }
    }

    private var summaryCard: some View {
        NavigationLink {
            PotOverviewDetailView(store: store)
        } label: {
            PotsSummaryCardContent(
                totalSavedPence: tabPresentation.totalSavedPence,
                activePotCount: tabPresentation.activePots.count
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open pots graph")
    }

    private var controls: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            TextField("Search pots", text: $query)
                .textFieldStyle(AppTextFieldStyle())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    FilterChip(title: "All", isSelected: selectedType == nil) { selectedType = nil }
                    ForEach(PotType.allCases) { type in
                        FilterChip(title: type.rawValue.capitalized, isSelected: selectedType == type) { selectedType = type }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 3)
            }
            .scrollClipDisabled()
        }
    }

    private var potList: some View {
        LazyVStack(spacing: AppTheme.Spacing.md) {
            if filteredRows.isEmpty {
                AppCard {
                    if tabPresentation.activePots.isEmpty {
                        EmptyStateView(title: "Create your first pot", message: "Use Add in the toolbar to set up savings, bills, buffers, or goals.", systemImage: "wallet.pass")
                    } else {
                        EmptyStateView(title: "No pots match", message: "Adjust the search or clear the selected filter.", systemImage: "magnifyingglass")
                    }
                }
            } else {
                ForEach(filteredRows) { row in
                    Button {
                        selectedPot = row.pot
                    } label: {
                        PotRow(
                            pot: row.pot,
                            linkedLabel: row.linkedLabel,
                            progress: row.progress,
                            pendingFundingContext: row.pendingFundingContext,
                            today: presentationContext?.todayIso ?? store.todayIso
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tabPresentation: PotsTabPresentation {
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

        return presentationCache.value(for: context.key(for: .pots)) {
            Self.makePresentation(context: context)
        }
    }

    static func warmPresentation(cache: PlannerTabPresentationCache, context: PlannerTabPresentationContext) {
        let _: PotsTabPresentation = cache.value(for: context.key(for: .pots)) {
            makePresentation(context: context)
        }
    }

    private static func makePresentation(context: PlannerTabPresentationContext) -> PotsTabPresentation {
        let activePots = context.snapshot.pots.filter { !$0.archived }
        let pendingFundingContexts = potPendingFundingContexts(
            snapshot: context.snapshot,
            payPeriod: context.selectedPayPeriod,
            today: context.todayIso
        )

        return PotsTabPresentation(
            activePots: activePots,
            totalSavedPence: activePots.reduce(0) { $0 + $1.balancePence },
            rows: activePots.map { pot in
                PotTabPresentationRow(
                    pot: pot,
                    linkedLabel: linkedTargetLabel(for: pot, in: context.snapshot),
                    progress: PlannerDerivedData.potProgress(
                        pot: pot,
                        snapshot: context.snapshot,
                        today: context.todayIso
                    ),
                    pendingFundingContext: pendingFundingContexts[pot.id, default: .none]
                )
            }
        )
    }
}

private struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? AppTheme.Colors.controlText : AppTheme.Colors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(AppTheme.Gradients.primary) : AnyShapeStyle(AppTheme.Colors.elevatedSurface))
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct PotsSummaryCardContent: View {
    var totalSavedPence: Int
    var activePotCount: Int

    var body: some View {
        AppCard(glow: true) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    MetricRow(
                        label: "Total saved",
                        value: MoneyParser.formatPence(totalSavedPence),
                        valueColor: AppTheme.Colors.primaryOrange
                    )
                    MetricRow(label: "Active pots", value: "\(activePotCount)")
                }
            }

            HStack(spacing: 8) {
                Text("View pot growth")
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

private struct PotOverviewDetailView: View {
    @ObservedObject var store: PlannerStore

    private var graphData: PotBalanceTrendData {
        PotBalanceTrendData.make(snapshot: store.snapshot, todayIso: store.todayIso)
    }

    private var timelineEvents: [PotTimelineEvent] {
        PotTimelineEvent.make(snapshot: store.snapshot)
    }

    var body: some View {
        ScreenScaffold(
            title: "Pot value",
            subtitle: PotsLayoutPolicy.overviewDetailSubtitle,
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            ForEach(PotsLayoutPolicy.overviewDetailSections, id: \.self) { section in
                switch section {
                case .graph:
                    PotBalanceTrendCard(data: graphData)
                case .timeline:
                    PotTimelineCard(events: timelineEvents)
                }
            }
        }
    }
}

private struct PotBalanceTrendData: Equatable {
    var startDate: String
    var endDate: String
    var startPence: Int
    var currentPence: Int
    var movementPence: Int
    var points: [PotBalanceTrendPoint]

    var id: String {
        "\(startDate)-\(endDate)-\(startPence)-\(currentPence)-\(movementPence)-\(points.count)"
    }

    var hasMovement: Bool {
        movementPence != 0 || points.contains { $0.balancePence != startPence }
    }

    var graphMinPence: Int {
        min(0, points.map(\.balancePence).min() ?? 0)
    }

    var graphMaxPence: Int {
        let maxValue = max(0, points.map(\.balancePence).max() ?? 0)
        return maxValue == graphMinPence ? maxValue + 1 : maxValue
    }

    var changePence: Int {
        currentPence - startPence
    }

    var trendColor: Color {
        changePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange
    }

    static func make(snapshot: PlannerSnapshot, todayIso: String) -> PotBalanceTrendData {
        let activePots = snapshot.pots.filter { !$0.archived && $0.deletedAt == nil }
        let currentPence = activePots.reduce(0) { $0 + $1.balancePence }
        let moneyEvents = PotTimelineEvent.moneyEvents(snapshot: snapshot).sorted(by: potTimelineAscending)
        let movementPence = moneyEvents.reduce(0) { $0 + ($1.amountPence ?? 0) }
        let startPence = currentPence - movementPence
        let firstKnownDate = (
            moneyEvents.map(\.date) + activePots.map { potDatePrefix($0.createdAt) } + [todayIso]
        )
        .filter { !$0.isEmpty }
        .min() ?? todayIso

        var runningBalance = startPence
        var points = [
            PotBalanceTrendPoint(
                index: 0,
                date: firstKnownDate,
                balancePence: startPence,
                label: "Start"
            )
        ]

        for (index, event) in moneyEvents.enumerated() {
            runningBalance += event.amountPence ?? 0
            points.append(
                PotBalanceTrendPoint(
                    index: index + 1,
                    date: event.date,
                    balancePence: runningBalance,
                    label: event.title
                )
            )
        }

        if points.count == 1 || points.last?.balancePence != currentPence {
            points.append(
                PotBalanceTrendPoint(
                    index: points.count,
                    date: todayIso,
                    balancePence: currentPence,
                    label: "Current value"
                )
            )
        }

        return PotBalanceTrendData(
            startDate: firstKnownDate,
            endDate: todayIso,
            startPence: startPence,
            currentPence: currentPence,
            movementPence: movementPence,
            points: points
        )
    }
}

private struct PotBalanceTrendPoint: Identifiable, Equatable {
    var index: Int
    var date: String
    var balancePence: Int
    var label: String

    var id: Int { index }
}

private struct PotBalanceTrendCard: View {
    var data: PotBalanceTrendData

    var body: some View {
        AppCard(glow: data.hasMovement) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Pot value")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.cardEyebrow)
                            .textCase(.uppercase)
                        Text(MoneyParser.formatPence(data.currentPence))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(data.trendColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(data.hasMovement ? "Tracked from \(shortDayMonth(data.startDate))" : "No pot movement recorded yet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer(minLength: AppTheme.Spacing.sm)

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(data.changePence >= 0 ? "Up" : "Down")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(AppTheme.Colors.controlText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(data.trendColor, in: Capsule())
                        Text(signedMoney(data.changePence))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(data.trendColor)
                    }
                }

                PotBalanceLineGraph(data: data)
                    .frame(height: 170)

                PotOverviewMetricStrip(data: data)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pot value \(MoneyParser.formatPence(data.currentPence))")
    }

    private func signedMoney(_ amountPence: Int) -> String {
        amountPence < 0
            ? "-\(MoneyParser.formatPence(abs(amountPence)))"
            : "+\(MoneyParser.formatPence(amountPence))"
    }
}

private struct PotBalanceLineGraph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var data: PotBalanceTrendData
    @State private var drawProgress = 0.0
    @State private var revealOpacity = 1.0

    var body: some View {
        GeometryReader { proxy in
            let minValue = data.graphMinPence
            let maxValue = data.graphMaxPence
            let lineColor = data.trendColor

            ZStack(alignment: .topLeading) {
                graphGrid

                PotBalanceAreaShape(points: data.points, minValue: minValue, maxValue: maxValue)
                    .fill(
                        LinearGradient(
                            colors: [
                                lineColor.opacity(data.hasMovement ? 0.24 : 0.08),
                                lineColor.opacity(data.hasMovement ? 0.09 : 0.03),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(reduceMotion ? revealOpacity : drawProgress)

                PotBalanceLineShape(points: data.points, minValue: minValue, maxValue: maxValue)
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: graphShadowColor, radius: data.hasMovement ? 6 : 3, y: 3)
                    .opacity(revealOpacity)

                if let finalPoint = data.points.last {
                    PotBalancePulseMarker(color: lineColor)
                        .position(pointPosition(index: data.points.count - 1, balancePence: finalPoint.balancePence, size: proxy.size, minValue: minValue, maxValue: maxValue))
                        .opacity(drawProgress > 0.92 ? 1 : 0)
                        .opacity(revealOpacity)
                }

                HStack {
                    Text(shortDayMonth(data.startDate))
                    Spacer()
                    Text(shortDayMonth(data.endDate))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: 18)
            }
            .onAppear {
                startAnimation()
            }
            .onChange(of: data.id) { _, _ in
                startAnimation()
            }
        }
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

    private var graphShadowColor: Color {
        data.changePence < 0
            ? AppTheme.Colors.danger.opacity(0.24)
            : AppTheme.Colors.accentGlow.opacity(0.48)
    }

    private func pointPosition(index: Int, balancePence: Int, size: CGSize, minValue: Int, maxValue: Int) -> CGPoint {
        let drawingHeight = max(size.height - 26, 1)
        let x = CGFloat(index) / CGFloat(max(data.points.count - 1, 1)) * max(size.width, 1)
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(balancePence - minValue) / range
        let y = drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(8, min(drawingHeight, y)))
    }

    private func startAnimation() {
        guard !reduceMotion else {
            drawProgress = 1
            revealOpacity = 0
            withAnimation(.easeOut(duration: 0.2)) {
                revealOpacity = 1
            }
            return
        }
        revealOpacity = 1
        drawProgress = 0
        withAnimation(.easeOut(duration: 0.7)) {
            drawProgress = 1
        }
    }
}

private struct PotOverviewMetricStrip: View {
    var data: PotBalanceTrendData

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.Spacing.sm) {
                metrics
            }
            VStack(spacing: AppTheme.Spacing.sm) {
                metrics
            }
        }
    }

    @ViewBuilder
    private var metrics: some View {
        PotOverviewMetricPill(label: "Started", value: MoneyParser.formatPence(data.startPence), color: AppTheme.Colors.primaryOrange)
        PotOverviewMetricPill(label: "Moved", value: signedMoney(data.movementPence), color: data.trendColor)
        PotOverviewMetricPill(label: "Now", value: MoneyParser.formatPence(data.currentPence), color: AppTheme.Colors.primaryOrange)
    }

    private func signedMoney(_ amountPence: Int) -> String {
        amountPence < 0
            ? "-\(MoneyParser.formatPence(abs(amountPence)))"
            : "+\(MoneyParser.formatPence(amountPence))"
    }
}

private struct PotBalanceLineShape: Shape {
    var points: [PotBalanceTrendPoint]
    var minValue: Int
    var maxValue: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        for (index, point) in points.enumerated() {
            let position = pointPosition(index: index, balancePence: point.balancePence, rect: rect)
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }

        if points.count == 1 {
            let position = pointPosition(index: 0, balancePence: points[0].balancePence, rect: rect)
            path.addLine(to: CGPoint(x: min(rect.maxX, position.x + 0.5), y: position.y))
        }

        return path
    }

    private func pointPosition(index: Int, balancePence: Int, rect: CGRect) -> CGPoint {
        let drawingHeight = max(rect.height - 26, 1)
        let x = rect.minX + CGFloat(index) / CGFloat(max(points.count - 1, 1)) * rect.width
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(balancePence - minValue) / range
        let y = rect.minY + drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(rect.minY + 8, min(rect.minY + drawingHeight, y)))
    }
}

private struct PotBalanceAreaShape: Shape {
    var points: [PotBalanceTrendPoint]
    var minValue: Int
    var maxValue: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        for (index, point) in points.enumerated() {
            let position = pointPosition(index: index, balancePence: point.balancePence, rect: rect)
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }

        let lastX = pointPosition(index: points.count - 1, balancePence: points.last?.balancePence ?? 0, rect: rect).x
        let firstX = pointPosition(index: 0, balancePence: points[0].balancePence, rect: rect).x
        path.addLine(to: CGPoint(x: lastX, y: rect.maxY - 18))
        path.addLine(to: CGPoint(x: firstX, y: rect.maxY - 18))
        path.closeSubpath()
        return path
    }

    private func pointPosition(index: Int, balancePence: Int, rect: CGRect) -> CGPoint {
        let drawingHeight = max(rect.height - 26, 1)
        let x = rect.minX + CGFloat(index) / CGFloat(max(points.count - 1, 1)) * rect.width
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(balancePence - minValue) / range
        let y = rect.minY + drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(rect.minY + 8, min(rect.minY + drawingHeight, y)))
    }
}

private struct PotBalancePulseMarker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var color: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: pulse ? 38 : 22, height: pulse ? 38 : 22)
                .opacity(pulse ? 0.15 : 0.8)

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(AppTheme.Colors.primaryText.opacity(0.72), lineWidth: 2))
                .shadow(color: color.opacity(0.72), radius: 10, y: 4)
        }
        .onAppear {
            startPulse()
        }
    }

    private func startPulse() {
        guard !reduceMotion else {
            pulse = false
            return
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private struct PotOverviewMetricPill: View {
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
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct PotTimelineEvent: Identifiable, Equatable {
    var id: String
    var date: String
    var title: String
    var detail: String
    var amountPence: Int?
    var kind: PotTimelineEventKind
    var potColor: String
    var sortIndex: Int

    static func make(snapshot: PlannerSnapshot) -> [PotTimelineEvent] {
        let creationEvents = snapshot.pots
            .filter { $0.deletedAt == nil }
            .enumerated()
            .map { index, pot in
                PotTimelineEvent(
                    id: "created-\(pot.id)",
                    date: potDatePrefix(pot.createdAt),
                    title: "Created \(pot.name)",
                    detail: "\(pot.type.rawValue.capitalized) pot",
                    amountPence: nil,
                    kind: .created,
                    potColor: pot.color,
                    sortIndex: index
                )
            }

        return (creationEvents + moneyEvents(snapshot: snapshot))
            .sorted(by: potTimelineAscending)
    }

    static func moneyEvents(snapshot: PlannerSnapshot) -> [PotTimelineEvent] {
        // Cloud/local merges can contain repeated IDs. Keep the latest entry so the
        // overview remains renderable while the source data is repaired elsewhere.
        let potsById = snapshot.pots.reduce(into: [String: Pot]()) { result, pot in
            result[pot.id] = pot
        }
        let periodsById = snapshot.payPeriods.reduce(into: [String: PayPeriod]()) { result, period in
            result[period.id] = period
        }
        let recurringById = snapshot.recurringPayments.reduce(into: [String: RecurringPayment]()) { result, payment in
            result[payment.id] = payment
        }

        let allocationEvents = snapshot.potAllocations
            .filter { $0.deletedAt == nil }
            .enumerated()
            .compactMap { index, allocation -> PotTimelineEvent? in
                guard let pot = potsById[allocation.potId] else { return nil }
                let date = periodsById[allocation.payPeriodId]?.payday ?? potDatePrefix(allocation.createdAt)
                return PotTimelineEvent(
                    id: "allocation-\(allocation.id)",
                    date: date,
                    title: "Added to \(pot.name)",
                    detail: allocationSourceLabel(allocation.source),
                    amountPence: allocation.amountPence,
                    kind: .topUp,
                    potColor: pot.color,
                    sortIndex: 10_000 + index
                )
            }

        let transactionEvents = snapshot.transactions
            .filter { $0.deletedAt == nil && $0.potId != nil }
            .enumerated()
            .compactMap { index, transaction -> PotTimelineEvent? in
                guard let potId = transaction.potId,
                      let pot = potsById[potId],
                      transaction.type == .allocation || transaction.type == .spending
                else {
                    return nil
                }

                let signedAmount = transaction.type == .spending ? -transaction.amountPence : transaction.amountPence
                let recurringName = transaction.recurringPaymentId.flatMap { recurringById[$0]?.name }
                let title = transaction.type == .spending ? "Paid from \(pot.name)" : "Added to \(pot.name)"
                let fallbackDetail = transaction.type == .spending ? "Recorded payment" : "Pot top-up"
                let detail = recurringName ?? (transaction.note.potTrimmed.isEmpty ? fallbackDetail : transaction.note)

                return PotTimelineEvent(
                    id: "transaction-\(transaction.id)",
                    date: transaction.date,
                    title: title,
                    detail: detail,
                    amountPence: signedAmount,
                    kind: transaction.type == .spending ? .payment : .topUp,
                    potColor: pot.color,
                    sortIndex: 20_000 + index
                )
            }

        return allocationEvents + transactionEvents
    }
}

private enum PotTimelineEventKind: Equatable {
    case created
    case topUp
    case payment

    var color: Color {
        switch self {
        case .created:
            return AppTheme.Colors.primaryOrange
        case .topUp:
            return AppTheme.Colors.success
        case .payment:
            return AppTheme.Colors.danger
        }
    }
}

private struct PotTimelineCard: View {
    var events: [PotTimelineEvent]
    @State private var isExpanded: Bool

    init(events: [PotTimelineEvent]) {
        self.events = events
        _isExpanded = State(initialValue: events.isEmpty)
    }

    var body: some View {
        AppCard {
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timeline")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)

                        Text(events.isEmpty ? "No events yet" : "\(events.count) events")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.black))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.Colors.accent.opacity(0.12), in: Circle())
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if events.isEmpty {
                    EmptyStateView(
                        title: "No pot timeline yet",
                        message: "Pot creation, top ups, and pot payments will appear here.",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                            PotTimelineRow(
                                event: event,
                                isFirst: index == 0,
                                isLast: index == events.count - 1
                            )
                        }
                    }
                }
            }
        }
        .animation(AppTheme.Animation.standard, value: isExpanded)
    }
}

private struct PotTimelineRow: View {
    var event: PotTimelineEvent
    var isFirst: Bool
    var isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            timelineBranch

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Text(event.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(2)

                    Spacer(minLength: AppTheme.Spacing.sm)

                    if let amountPence = event.amountPence {
                        Text(signedMoney(amountPence))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(event.kind.color)
                            .lineLimit(1)
                    }
                }

                Text(event.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)

                Text(friendlyDate(event.date))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .padding(.vertical, AppTheme.Spacing.sm)
        }
    }

    private var timelineBranch: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? .clear : AppTheme.Colors.border.opacity(0.68))
                .frame(width: 2, height: 11)

            Circle()
                .fill(event.kind.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color(hex: event.potColor).opacity(0.45), lineWidth: 4)
                )
                .shadow(color: event.kind.color.opacity(0.2), radius: 4, y: 2)

            Rectangle()
                .fill(isLast ? .clear : AppTheme.Colors.border.opacity(0.68))
                .frame(width: 2)
        }
        .frame(width: 24)
    }

    private func signedMoney(_ amountPence: Int) -> String {
        amountPence < 0
            ? "-\(MoneyParser.formatPence(abs(amountPence)))"
            : "+\(MoneyParser.formatPence(amountPence))"
    }

    private func friendlyDate(_ value: String) -> String {
        FinanceEngine.parseDate(value).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct PotPendingFundingContext {
    static let none = PotPendingFundingContext()

    var hasPendingChecklistFunding = false
    var hasProcessedDueItems = false
}

private struct PotRow: View {
    var pot: Pot
    var linkedLabel: String?
    var progress: PotProgress
    var pendingFundingContext: PotPendingFundingContext
    var today: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Circle()
                        .fill(Color(hex: pot.color))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(pot.color.uppercased() == "#FFFFFF" ? AppTheme.Colors.border : .clear, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pot.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text(rowDetail)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(MoneyParser.formatPence(pot.balancePence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }

                PotProgressBlock(
                    progress: progress,
                    pendingFundingContext: pendingFundingContext,
                    balancePence: pot.balancePence,
                    today: today
                )
            }
        }
    }

    private var rowDetail: String {
        if let linkedLabel {
            return "\(pot.type.rawValue.capitalized) · \(linkedLabel)"
        }
        return "\(pot.type.rawValue.capitalized) · \(pot.category ?? "Uncategorised")"
    }
}

private struct PotProgressBlock: View {
    var progress: PotProgress
    var pendingFundingContext: PotPendingFundingContext
    var balancePence: Int
    var today: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if progress.targetPence > 0 {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Text("\(progress.percent)%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.success)
                    Spacer(minLength: AppTheme.Spacing.sm)
                    Text(progress.targetLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                ProgressView(value: cappedProgressValue, total: 100)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.Colors.success)

                Text(potFundingStatusLabel(progress: progress))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(progress.shortfallPence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success)
                    .lineLimit(1)

                pendingFundingContextLine

                if !progress.linkedCardPayments.isEmpty {
                    LinkedCardPaymentsBlock(payments: progress.linkedCardPayments)
                } else {
                    if let dueLabel = potDueLabel(progress: progress, today: today) {
                        Text(dueLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.warning)
                            .lineLimit(1)
                    }

                    if let laterLabel = potLaterLabel(progress: progress) {
                        Text(laterLabel)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .lineLimit(1)
                    }
                }
            } else {
                HStack {
                    Text("No target")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Spacer()
                    Text("Balance only")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }

                pendingFundingContextLine
            }

            if !progress.sourceLabels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(progress.sourceLabels.prefix(2)), id: \.self) { label in
                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.elevatedSurface)
                            .clipShape(Capsule())
                    }
                    if progress.sourceLabels.count > 2 {
                        Text("+\(progress.sourceLabels.count - 2)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.elevatedSurface)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var cappedProgressValue: Double {
        Double(min(max(progress.percent, 0), 100))
    }

    @ViewBuilder
    private var pendingFundingContextLine: some View {
        if let text = pendingFundingContextText {
            Text(text)
                .font(.caption2)
                .foregroundStyle(pendingFundingContextColor)
                .lineLimit(2)
        }
    }

    private var pendingFundingContextText: String? {
        guard pendingFundingContext.hasPendingChecklistFunding else { return nil }

        if balancePence < 0 {
            return "Temporary until funding is ticked."
        }

        if pendingFundingContext.hasProcessedDueItems {
            return "Due items processed, funding not completed yet."
        }

        return "Pending checklist funding."
    }

    private var pendingFundingContextColor: Color {
        balancePence < 0 || pendingFundingContext.hasProcessedDueItems ? AppTheme.Colors.warning : AppTheme.Colors.tertiaryText
    }
}

private struct LinkedCardPaymentsBlock: View {
    var payments: [LinkedCardPaymentDue]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let cardName = payments.first?.cardName {
                Text("Upcoming \(cardName) payments")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            ForEach(Array(payments.enumerated()), id: \.offset) { _, payment in
                HStack(spacing: 6) {
                    Text(shortDayMonth(payment.dueIso))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("- \(MoneyParser.formatPence(payment.amountPence)) due")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                    Spacer(minLength: 0)
                }
                .lineLimit(1)
            }
        }
    }
}

struct PotFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var type: PotType = .spending
    @State private var balance = ""
    @State private var target = ""
    @State private var color = AppTheme.selectedPalette.accentHex.uppercased()
    @State private var linkType: PotLinkType = .none
    @State private var linkedEntityId = ""
    @State private var fundingBankAccountId = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                AppCard(glow: true) {
                    SectionTitle("Add pot")
                    PotSetupFields(
                        store: store,
                        name: $name,
                        type: $type,
                        balance: $balance,
                        target: $target,
                        color: $color,
                        linkType: $linkType,
                        linkedEntityId: $linkedEntityId,
                        fundingBankAccountId: $fundingBankAccountId
                    )

                    PrimaryButton(title: "Add pot", systemImage: "plus", isDisabled: isSaveDisabled) {
                        store.addPot(
                            name: name,
                            type: type,
                            category: type.defaultCategory,
                            targetPence: target.potNilIfBlank.map { MoneyParser.parsePoundsToPence($0) },
                            color: color,
                            balancePence: MoneyParser.parsePoundsToPence(balance),
                            linkedCreditCardId: linkType == .creditCard ? linkedEntityId.potNilIfBlank : nil,
                            linkedDebtId: linkType == .debt ? linkedEntityId.potNilIfBlank : nil,
                            fundingBankAccountId: fundingBankAccountId.potNilIfBlank
                        )
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Add pot")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .onAppear {
            if fundingBankAccountId.isEmpty {
                fundingBankAccountId = store.primaryBankAccount?.id ?? store.activeBankAccounts.first?.id ?? ""
            }
        }
    }

    private var isSaveDisabled: Bool {
        name.potTrimmed.isEmpty || !isValidLinkSelection(linkType: linkType, linkedEntityId: linkedEntityId, store: store)
    }
}

struct PotHistorySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var selectedMode: PotHistoryMode = .allHistory
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Picker("History", selection: $selectedMode) {
                        ForEach(PotHistoryMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.Colors.primaryOrange)

                    if rows.isEmpty {
                        AppCard {
                            EmptyStateView(
                                title: selectedMode.emptyTitle,
                                message: selectedMode.emptyMessage,
                                systemImage: "receipt"
                            )
                        }
                    } else {
                        VStack(spacing: AppTheme.Spacing.md) {
                            ForEach(rows) { row in
                                PotHistoryRowView(
                                    row: row,
                                    onDelete: deleteAction(for: row)
                                )
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Pots history")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AppEditDoneToolbarButton(isEditing: editMode.isEditing, canEdit: hasEditableRows) {
                        toggleEditMode()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .environment(\.editMode, $editMode)
        .onChange(of: selectedMode) { _, _ in
            exitEditModeIfNeeded()
        }
        .onChange(of: editableRowIds) { _, _ in
            exitEditModeIfNeeded()
        }
    }

    private var rows: [PotHistoryRow] {
        switch selectedMode {
        case .topUps:
            topUpRows
        case .payments:
            paymentRows
        case .allHistory:
            (topUpRows + paymentRows).sorted(by: sortRows)
        }
    }

    private func toggleEditMode() {
        guard editMode.isEditing || hasEditableRows else { return }
        withAnimation(appToolbarMorphAnimation) {
            editMode = editMode.isEditing ? .inactive : .active
        }
    }

    private var hasEditableRows: Bool {
        rows.contains { $0.isDeletable }
    }

    private var editableRowIds: [String] {
        rows.filter { $0.isDeletable }.map(\.id)
    }

    private func exitEditModeIfNeeded() {
        guard editMode.isEditing, !hasEditableRows else { return }
        withAnimation(appToolbarMorphAnimation) {
            editMode = .inactive
        }
    }

    private func deleteAction(for row: PotHistoryRow) -> (() -> Void)? {
        guard editMode.isEditing, row.isDeletable else { return nil }
        return {
            delete(row)
        }
    }

    private func delete(_ row: PotHistoryRow) {
        switch row.source {
        case .allocation(let id, _):
            _ = store.deleteManualPotAllocation(id: id)
        case .transaction(let id):
            store.deletePotHistoryTransaction(id: id)
        }
    }

    private var topUpRows: [PotHistoryRow] {
        let allocationRows = store.snapshot.potAllocations
            .filter { $0.deletedAt == nil }
            .compactMap { allocation -> PotHistoryRow? in
                guard let pot = pot(for: allocation.potId) else { return nil }
                let period = store.snapshot.payPeriods.first { $0.id == allocation.payPeriodId }
                return PotHistoryRow(
                    id: allocation.id,
                    potName: pot.name,
                    date: period?.payday ?? String(allocation.createdAt.prefix(10)),
                    detail: allocationSourceLabel(allocation.source),
                    amountPence: allocation.amountPence,
                    kind: .topUp,
                    source: .allocation(
                        id: allocation.id,
                        canDelete: (allocation.source ?? .manual) == .manual &&
                            allocation.fundingPotId == nil &&
                            allocation.recurringPaymentId == nil &&
                            allocation.debtId == nil
                    )
                )
            }

        let transactionRows = store.snapshot.transactions
            .filter { $0.deletedAt == nil && $0.type == .allocation && $0.potId != nil }
            .compactMap { transaction -> PotHistoryRow? in
                guard let potId = transaction.potId, let pot = pot(for: potId) else { return nil }
                return PotHistoryRow(
                    id: transaction.id,
                    potName: pot.name,
                    date: transaction.date,
                    detail: transaction.note.potTrimmed.isEmpty ? "Pot top-up" : transaction.note,
                    amountPence: transaction.amountPence,
                    kind: .topUp,
                    source: .transaction(transaction.id)
                )
            }

        return (allocationRows + transactionRows).sorted(by: sortRows)
    }

    private var paymentRows: [PotHistoryRow] {
        store.snapshot.transactions
            .filter { $0.deletedAt == nil && $0.type == .spending && $0.potId != nil }
            .compactMap { transaction -> PotHistoryRow? in
                guard let potId = transaction.potId, let pot = pot(for: potId) else { return nil }
                return PotHistoryRow(
                    id: transaction.id,
                    potName: pot.name,
                    date: transaction.date,
                    detail: transaction.note.potTrimmed.isEmpty ? "Recorded payment" : transaction.note,
                    amountPence: transaction.amountPence,
                    kind: .payment,
                    source: .transaction(transaction.id)
                )
            }
            .sorted(by: sortRows)
    }

    private func pot(for id: String) -> Pot? {
        store.snapshot.pots.first { $0.id == id }
    }

    private func allocationSourceLabel(_ source: PotAllocationSource?) -> String {
        switch source ?? .manual {
        case .manual:
            return "Manual top-up"
        case .recurring:
            return "Recurring top-up"
        case .recurringBillFunding:
            return "Bill funding"
        case .cardBillFunding:
            return "Card bill funding"
        case .cardSpendFunding:
            return "Card spend funding"
        case .cardOpeningBalanceFunding:
            return "Card opening balance funding"
        case .cardPaymentFunding:
            return "Card payment funding"
        case .debtFunding:
            return "Debt funding"
        case .potAuto:
            return "Auto top-up"
        }
    }

    private func sortRows(_ lhs: PotHistoryRow, _ rhs: PotHistoryRow) -> Bool {
        if lhs.date == rhs.date {
            return lhs.id > rhs.id
        }
        return lhs.date > rhs.date
    }
}

private enum PotHistoryMode: String, CaseIterable, Identifiable {
    case topUps
    case payments
    case allHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topUps:
            return "Top ups"
        case .payments:
            return "Payments"
        case .allHistory:
            return "All history"
        }
    }

    var emptyTitle: String {
        switch self {
        case .topUps:
            return "No top ups yet"
        case .payments:
            return "No payments yet"
        case .allHistory:
            return "No pot history yet"
        }
    }

    var emptyMessage: String {
        switch self {
        case .topUps:
            return "Top up a pot to see it here."
        case .payments:
            return "Record pot spending to see payments here."
        case .allHistory:
            return "Top ups and payments will appear here."
        }
    }
}

private enum PotHistoryKind {
    case topUp
    case payment

    var title: String {
        switch self {
        case .topUp:
            return "Top up"
        case .payment:
            return "Payment"
        }
    }

    var symbol: String {
        switch self {
        case .topUp:
            return "arrow.down.circle"
        case .payment:
            return "arrow.up.circle"
        }
    }

    var color: Color {
        switch self {
        case .topUp:
            return AppTheme.Colors.success
        case .payment:
            return AppTheme.Colors.warning
        }
    }
}

private enum PotHistoryRowSource {
    case allocation(id: String, canDelete: Bool)
    case transaction(String)

    var isDeletable: Bool {
        switch self {
        case .allocation(_, let canDelete):
            canDelete
        case .transaction:
            true
        }
    }
}

private struct PotHistoryRow: Identifiable {
    let id: String
    let potName: String
    let date: String
    let detail: String
    let amountPence: Int
    let kind: PotHistoryKind
    let source: PotHistoryRowSource

    var isDeletable: Bool {
        source.isDeletable
    }
}

private struct PotHistoryRowView: View {
    var row: PotHistoryRow
    var onDelete: (() -> Void)?

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.potName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("\(friendlyDate(row.date)) · \(row.detail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(amountText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(row.kind.color)
                    Pill(text: row.kind.title, systemImage: row.kind.symbol, color: row.kind.color)
                }

                if let onDelete {
                    DestructiveBadgeButton(
                        accessibilityLabel: "Delete \(row.detail)",
                        confirmationTitle: "Delete this pot history entry?",
                        confirmationMessage: "Are you sure? This entry will be permanently removed and the pot balance will be updated.",
                        action: onDelete
                    )
                }
            }
        }
    }

    private var amountText: String {
        "\(row.kind == .payment ? "-" : "+")\(MoneyParser.formatPence(row.amountPence))"
    }

    private func friendlyDate(_ value: String) -> String {
        FinanceEngine.parseDate(value).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct PotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var pot: Pot
    @State private var allocation = ""
    @State private var isEditingSetup = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    PotRow(
                        pot: latestPot,
                        linkedLabel: linkedTargetLabel(for: latestPot, in: store.snapshot),
                        progress: PlannerDerivedData.potProgress(pot: latestPot, snapshot: store.snapshot, today: store.todayIso),
                        pendingFundingContext: potPendingFundingContexts(
                            snapshot: store.snapshot,
                            payPeriod: store.selectedPayPeriod,
                            today: store.todayIso
                        )[latestPot.id, default: .none],
                        today: store.todayIso
                    )
                    AppCard {
                        SectionTitle("Move money")
                        MoneyField(title: "Add allocation", text: $allocation)
                        SecondaryButton(title: "Allocate to pot", systemImage: "plus") {
                            let amountPence = MoneyParser.parsePoundsToPence(allocation)
                            guard amountPence > 0 else { return }
                            if store.addPotAllocation(potId: pot.id, amountPence: amountPence) {
                                allocation = ""
                            }
                        }
                    }
                    SecondaryButton(title: "Delete pot", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Pot Overview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .navigationDestination(isPresented: $isEditingSetup) {
                PotEditView(store: store, pot: latestPot)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(id: "pot-setup-edit", placement: .topBarTrailing) {
                    Button {
                        isEditingSetup = true
                    } label: {
                        Text("Edit")
                    }
                    .accessibilityLabel("Edit pot setup")
                }
            }
            .alert("Delete pot?", isPresented: $isDeleteConfirmationPresented) {
                Button("Delete pot", role: .destructive) {
                    store.deletePot(id: pot.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pots with existing history are hidden instead so old records stay intact.")
            }
        }
    }

    private var latestPot: Pot {
        store.snapshot.pots.first(where: { $0.id == pot.id }) ?? pot
    }
}

private struct PotEditView: View {
    @ObservedObject var store: PlannerStore
    var pot: Pot
    @State private var name: String
    @State private var type: PotType
    @State private var balance: String
    @State private var target: String
    @State private var color: String
    @State private var linkType: PotLinkType
    @State private var linkedEntityId: String
    @State private var fundingBankAccountId: String

    init(store: PlannerStore, pot: Pot) {
        self.store = store
        self.pot = pot
        _name = State(initialValue: pot.name)
        _type = State(initialValue: pot.type)
        _balance = State(initialValue: moneyInputText(for: pot.balancePence))
        _target = State(initialValue: moneyInputText(for: pot.targetPence))
        _color = State(initialValue: pot.color)
        _fundingBankAccountId = State(initialValue: pot.fundingBankAccountId ?? "")
        if let linkedCreditCardId = pot.linkedCreditCardId {
            _linkType = State(initialValue: .creditCard)
            _linkedEntityId = State(initialValue: linkedCreditCardId)
        } else if let linkedDebtId = pot.linkedDebtId {
            _linkType = State(initialValue: .debt)
            _linkedEntityId = State(initialValue: linkedDebtId)
        } else {
            _linkType = State(initialValue: .none)
            _linkedEntityId = State(initialValue: "")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                PotSetupFields(
                    store: store,
                    name: $name,
                    type: $type,
                    balance: $balance,
                    target: $target,
                    color: $color,
                    linkType: $linkType,
                    linkedEntityId: $linkedEntityId,
                    fundingBankAccountId: $fundingBankAccountId
                )

                PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: isSaveDisabled) {
                    saveChanges()
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle("Edit Pot")
        .navigationBarTitleDisplayMode(.inline)
        .navigationTopDividerHidden()
    }

    private var isSaveDisabled: Bool {
        name.potTrimmed.isEmpty || !isValidLinkSelection(linkType: linkType, linkedEntityId: linkedEntityId, store: store)
    }

    private func saveChanges() {
        guard var updated = store.snapshot.pots.first(where: { $0.id == pot.id }) else { return }
        updated.name = name.potTrimmed
        updated.type = type
        updated.category = type.defaultCategory
        updated.balancePence = max(0, MoneyParser.parsePoundsToPence(balance))
        updated.targetPence = target.potNilIfBlank.map { max(0, MoneyParser.parsePoundsToPence($0)) }
        updated.color = color
        updated.linkedCreditCardId = linkType == .creditCard ? linkedEntityId.potNilIfBlank : nil
        updated.linkedDebtId = linkType == .debt ? linkedEntityId.potNilIfBlank : nil
        updated.fundingBankAccountId = fundingBankAccountId.potNilIfBlank
        store.updatePot(updated)
    }
}

private struct PotSetupFields: View {
    @ObservedObject var store: PlannerStore
    @Binding var name: String
    @Binding var type: PotType
    @Binding var balance: String
    @Binding var target: String
    @Binding var color: String
    @Binding var linkType: PotLinkType
    @Binding var linkedEntityId: String
    @Binding var fundingBankAccountId: String

    private var potColors: [String] {
        PotFormLayoutPolicy.colorHexes
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            TextField("Name", text: $name)
                .textFieldStyle(AppTextFieldStyle())

            Picker("Type", selection: $type) {
                ForEach(PotType.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)

            MoneyField(title: "Current balance", text: $balance)
            MoneyField(title: "Target (optional)", text: $target)
            linkControls
            fundingAccountControl
            colorSwatches
        }
        .onAppear {
            if !potColors.contains(color.uppercased()) {
                color = potColors.first ?? color
            }
            normalizeLinkedSelection()
        }
    }

    private var linkControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Link this pot to")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Picker("Link this pot to", selection: linkTypeBinding) {
                ForEach(PotLinkType.allCases) { linkType in
                    Text(linkType.title).tag(linkType)
                }
            }
            .pickerStyle(.segmented)

            switch linkType {
            case .none:
                EmptyView()
            case .creditCard:
                if selectableCards.isEmpty {
                    linkEmptyState("No active credit cards")
                } else {
                    SelectionField(title: "Credit card", value: selectedCreditCardName, placeholder: "No card", systemImage: "creditcard") {
                        ForEach(selectableCards) { card in
                            Button(card.name) { linkedEntityId = card.id }
                        }
                    }
                }
            case .debt:
                if selectableDebts.isEmpty {
                    linkEmptyState("No active debts")
                } else {
                    SelectionField(title: "Debt", value: selectedDebtName, placeholder: "No debt", systemImage: "exclamationmark.shield") {
                        ForEach(selectableDebts) { debt in
                            Button(debt.name) { linkedEntityId = debt.id }
                        }
                    }
                }
            }
        }
    }

    private var colorSwatches: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ForEach(potColors, id: \.self) { swatch in
                Button {
                    color = swatch
                } label: {
                    Circle()
                        .fill(Color(hex: swatch))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(color == swatch ? AppTheme.Colors.primaryText : AppTheme.Colors.border, lineWidth: color == swatch ? 2 : 1)
                        )
                        .overlay {
                            if color == swatch {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(swatch.uppercased() == "#FFFFFF" ? AppTheme.Colors.primaryText : AppTheme.Colors.controlText)
                            }
                        }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Pot color")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var fundingAccountControl: some View {
        SelectionField(
            title: "Funded from",
            value: selectedFundingAccountName,
            placeholder: "No bank account",
            systemImage: "building.columns"
        ) {
            Button("No bank account") { fundingBankAccountId = "" }
            ForEach(store.activeBankAccounts) { account in
                Button(account.name) { fundingBankAccountId = account.id }
            }
        }
    }

    private var linkTypeBinding: Binding<PotLinkType> {
        Binding {
            linkType
        } set: { newValue in
            linkType = newValue
            linkedEntityId = defaultLinkId(for: newValue)
        }
    }

    private var selectableCards: [CreditCard] {
        linkableCreditCards(in: store.snapshot, currentId: linkedEntityId)
    }

    private var selectableDebts: [Debt] {
        linkableDebts(in: store.snapshot, currentId: linkedEntityId)
    }

    private var selectedCreditCardName: String {
        selectableCards.first { $0.id == linkedEntityId }?.name ?? ""
    }

    private var selectedDebtName: String {
        selectableDebts.first { $0.id == linkedEntityId }?.name ?? ""
    }

    private var selectedFundingAccountName: String {
        store.activeBankAccounts.first { $0.id == fundingBankAccountId }?.name ?? ""
    }

    private func normalizeLinkedSelection() {
        guard linkType != .none else {
            linkedEntityId = ""
            return
        }
        if !isValidLinkSelection(linkType: linkType, linkedEntityId: linkedEntityId, store: store) {
            linkedEntityId = defaultLinkId(for: linkType)
        }
    }

    private func defaultLinkId(for linkType: PotLinkType) -> String {
        switch linkType {
        case .none:
            return ""
        case .creditCard:
            return selectableCards.first?.id ?? ""
        case .debt:
            return selectableDebts.first?.id ?? ""
        }
    }

    private func linkEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

private enum PotLinkType: String, CaseIterable, Identifiable {
    case none
    case creditCard
    case debt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "No link"
        case .creditCard:
            return "Credit card"
        case .debt:
            return "Debt"
        }
    }
}

private func linkedTargetLabel(for pot: Pot, in snapshot: PlannerSnapshot) -> String? {
    if let cardId = pot.linkedCreditCardId,
       let card = snapshot.creditCards.first(where: { $0.id == cardId }) {
        return "Linked to \(card.name)"
    }
    if let debtId = pot.linkedDebtId,
       let debt = snapshot.debts.first(where: { $0.id == debtId }) {
        return "Linked to \(debt.name)"
    }
    return nil
}

private func potPendingFundingContexts(snapshot: PlannerSnapshot, payPeriod: PayPeriod?, today: String) -> [String: PotPendingFundingContext] {
    guard let payPeriod else { return [:] }

    var contexts: [String: PotPendingFundingContext] = [:]

    func markPending(potId: String, hasProcessedDueItems: Bool = false) {
        var context = contexts[potId, default: .none]
        context.hasPendingChecklistFunding = true
        context.hasProcessedDueItems = context.hasProcessedDueItems || hasProcessedDueItems
        contexts[potId] = context
    }

    for item in PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        let hasProcessedDueItems = item.cardId == nil && hasProcessedDirectRecurringBill(item: item, snapshot: snapshot, today: today)
        markPending(potId: item.potId, hasProcessedDueItems: hasProcessedDueItems)
    }

    for item in PlannerDerivedData.cardSpendFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        markPending(potId: item.potId)
    }

    for item in PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        markPending(potId: item.potId)
    }

    for item in PlannerDerivedData.debtFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        markPending(potId: item.potId)
    }

    return contexts
}

private func hasProcessedDirectRecurringBill(item: RecurringBillFundingChecklistItem, snapshot: PlannerSnapshot, today: String) -> Bool {
    snapshot.transactions.contains {
        $0.deletedAt == nil &&
        $0.type == .spending &&
        $0.paymentMethod == .pot &&
        $0.creditCardId == nil &&
        $0.recurringPaymentId == item.paymentId &&
        $0.date == item.dueDate &&
        $0.date <= today &&
        $0.potId == item.potId
    }
}

private func potDueLabel(progress: PotProgress, today: String) -> String? {
    guard progress.targetPence > 0 else { return nil }

    guard let obligation = progress.nextObligation else {
        return progress.shortfallPence > 0 ? "Top up \(MoneyParser.formatPence(progress.shortfallPence))" : nil
    }

    let days = daysUntil(obligation.dueIso, from: today)
    let dueText = days <= 0 ? "Due now" : "Due in \(days) day\(days == 1 ? "" : "s")"
    return "Next payment: \(MoneyParser.formatPence(obligation.amountPence)) \(dueText.lowercased())"
}

private func potFundingStatusLabel(progress: PotProgress) -> String {
    progress.shortfallPence > 0 ? "\(MoneyParser.formatPence(progress.shortfallPence)) to fund" : "Fully funded"
}

private func potLaterLabel(progress: PotProgress) -> String? {
    guard let obligation = progress.laterObligation else { return nil }
    return "Later: \(MoneyParser.formatPence(obligation.amountPence)) on \(shortDayMonth(obligation.dueIso))"
}

private func daysUntil(_ dueIso: String, from today: String) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let start = FinanceEngine.parseDate(today)
    let end = FinanceEngine.parseDate(dueIso)
    return calendar.dateComponents([.day], from: start, to: end).day ?? 0
}

private func shortDayMonth(_ isoDate: String) -> String {
    FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
}

private func potDatePrefix(_ value: String) -> String {
    String(value.prefix(10))
}

private func potTimelineAscending(_ lhs: PotTimelineEvent, _ rhs: PotTimelineEvent) -> Bool {
    if lhs.date == rhs.date {
        return lhs.sortIndex < rhs.sortIndex
    }

    return lhs.date < rhs.date
}

private func allocationSourceLabel(_ source: PotAllocationSource?) -> String {
    switch source ?? .manual {
    case .manual:
        return "Manual top-up"
    case .recurring:
        return "Recurring top-up"
    case .recurringBillFunding:
        return "Bill funding"
    case .cardBillFunding:
        return "Card bill funding"
    case .cardSpendFunding:
        return "Card spend funding"
    case .cardOpeningBalanceFunding:
        return "Card opening balance funding"
    case .cardPaymentFunding:
        return "Card payment funding"
    case .debtFunding:
        return "Debt funding"
    case .potAuto:
        return "Auto top-up"
    }
}

private func linkableCreditCards(in snapshot: PlannerSnapshot, currentId: String) -> [CreditCard] {
    snapshot.creditCards.filter { !$0.archived || $0.id == currentId }
}

private func linkableDebts(in snapshot: PlannerSnapshot, currentId: String) -> [Debt] {
    snapshot.debts.filter { ($0.status != .archived && $0.currentBalancePence > 0) || $0.id == currentId }
}

@MainActor
private func isValidLinkSelection(linkType: PotLinkType, linkedEntityId: String, store: PlannerStore) -> Bool {
    switch linkType {
    case .none:
        return true
    case .creditCard:
        return linkableCreditCards(in: store.snapshot, currentId: linkedEntityId).contains { $0.id == linkedEntityId }
    case .debt:
        return linkableDebts(in: store.snapshot, currentId: linkedEntityId).contains { $0.id == linkedEntityId }
    }
}

private func moneyInputText(for amountPence: Int?) -> String {
    guard let amountPence, amountPence > 0 else { return "" }
    return String(format: "%.2f", Double(amountPence) / 100)
}

private extension PotType {
    var defaultCategory: String {
        switch self {
        case .spending:
            return "Spending"
        case .reserved:
            return "Bills"
        case .saving, .investment, .buffer:
            return "Savings"
        }
    }
}

private extension String {
    var potTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var potNilIfBlank: String? {
        let trimmed = potTrimmed
        return trimmed.isEmpty ? nil : trimmed
    }
}
