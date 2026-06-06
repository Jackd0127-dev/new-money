import SwiftUI

struct SpendingView: View {
    @ObservedObject var store: PlannerStore
    @State private var paymentMethod: PaymentMethod = .pot
    @State private var selectedPotId = ""
    @State private var selectedCardId = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()

    var body: some View {
        ScreenScaffold(title: "Spending", subtitle: "Record pot or credit-card spend with period links.") {
            AppCard(glow: true) {
                Picker("Route", selection: $paymentMethod) {
                    Text("Pot").tag(PaymentMethod.pot)
                    Text("Card").tag(PaymentMethod.creditCard)
                }
                .pickerStyle(.segmented)

                if paymentMethod == .pot {
                    Picker("Pot", selection: $selectedPotId) {
                        ForEach(store.activePots) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                } else {
                    Picker("Card", selection: $selectedCardId) {
                        ForEach(store.activeCards) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                }

                MoneyField(title: "Amount", text: $amount)
                TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .tint(AppTheme.Colors.primaryOrange)
                PrimaryButton(title: "Record spending", systemImage: "cart", isDisabled: !canSubmit) {
                    store.recordTransaction(
                        potId: paymentMethod == .pot ? selectedPotId : nil,
                        creditCardId: paymentMethod == .creditCard ? selectedCardId : nil,
                        paymentMethod: paymentMethod,
                        amountPence: MoneyParser.parsePoundsToPence(amount),
                        type: .spending,
                        date: date.isoDateString,
                        note: note
                    )
                    amount = ""
                    note = ""
                }
            }

            SectionTitle("Transactions")
            if store.snapshot.transactions.isEmpty {
                AppCard { EmptyStateView(title: "No spending recorded", message: "Transactions will show here and in History.", systemImage: "cart") }
            } else {
                ForEach(store.snapshot.transactions.sorted { $0.date > $1.date }) { transaction in
                    AppCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(transaction.note.isEmpty ? "Spending" : transaction.note)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text(transaction.date)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            Spacer()
                            Text("-\(MoneyParser.formatPence(transaction.amountPence))")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.orangeHighlight)
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedPotId = store.activePots.first?.id ?? ""
            selectedCardId = store.activeCards.first?.id ?? ""
        }
    }

    private var canSubmit: Bool {
        MoneyParser.parsePoundsToPence(amount) > 0 && (paymentMethod == .pot ? !selectedPotId.isEmpty : !selectedCardId.isEmpty)
    }
}

struct BillsView: View {
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var amount = ""
    @State private var dueDay = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var priority: RecurringPriority = .essential
    @State private var potId = ""
    @State private var cardId = ""
    @State private var routeToCard = false

    var body: some View {
        ScreenScaffold(title: "Bills", subtitle: "Recurring payment templates and upcoming bill agenda.") {
            AppCard(glow: true) {
                SectionTitle("Add recurring payment")
                TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
                MoneyField(title: "Amount", text: $amount)
                TextField("Due day", text: $dueDay).keyboardType(.numberPad).textFieldStyle(AppTextFieldStyle())
                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Priority", selection: $priority) {
                    ForEach(RecurringPriority.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Linked to card", isOn: $routeToCard)
                    .tint(AppTheme.Colors.primaryOrange)
                if routeToCard {
                    Picker("Card", selection: $cardId) {
                        Text("No card").tag("")
                        ForEach(store.activeCards) { Text($0.name).tag($0.id) }
                    }
                } else {
                    Picker("Pot", selection: $potId) {
                        Text("No pot").tag("")
                        ForEach(store.activePots) { Text($0.name).tag($0.id) }
                    }
                }
                PrimaryButton(title: "Add bill", systemImage: "plus", isDisabled: name.isBlank || MoneyParser.parsePoundsToPence(amount) <= 0) {
                    store.addRecurringPayment(
                        name: name,
                        amountPence: MoneyParser.parsePoundsToPence(amount),
                        dueDay: Int(dueDay),
                        frequency: frequency,
                        potId: routeToCard ? nil : potId.nilIfBlank,
                        creditCardId: routeToCard ? cardId.nilIfBlank : nil,
                        priority: priority
                    )
                    name = ""
                    amount = ""
                }
            }

            upcomingAgenda
            billList
        }
        .onAppear {
            potId = store.activePots.first?.id ?? ""
            cardId = store.activeCards.first?.id ?? ""
        }
    }

    private var upcomingAgenda: some View {
        let endDate = FinanceEngine.addIsoDays(date: store.todayIso, days: 30)
        let upcoming = PlannerDerivedData.recurringOccurrences(payments: store.snapshot.recurringPayments, startDate: store.todayIso, endDate: endDate)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Next 30 days")
            AppCard {
                if upcoming.isEmpty {
                    EmptyStateView(title: "No upcoming bills", message: "Recurring payments with due dates appear here.", systemImage: "calendar")
                } else {
                    ForEach(upcoming.prefix(8)) { occurrence in
                        MetricRow(label: "\(occurrence.dueDate) · \(occurrence.payment.name)", value: MoneyParser.formatPence(occurrence.amountPence), valueColor: AppTheme.Colors.warning)
                    }
                }
            }
        }
    }

    private var billList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Bills list")
            if store.snapshot.recurringPayments.isEmpty {
                AppCard { EmptyStateView(title: "No recurring payments", message: "Add rent, subscriptions, utilities, and card-linked bills.", systemImage: "calendar.badge.plus") }
            } else {
                ForEach(store.snapshot.recurringPayments) { payment in
                    AppCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(payment.name)
                                    .font(.headline)
                                    .foregroundStyle(payment.active ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
                                Text("\(payment.frequency.rawValue.capitalized) · day \(payment.dueDay ?? 0) · \(payment.priority.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(MoneyParser.formatPence(payment.amountPence))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                                Button("Archive") {
                                    store.archiveRecurringPayment(id: payment.id)
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.danger)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DebtsView: View {
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var lender = ""
    @State private var original = ""
    @State private var balance = ""
    @State private var minimum = ""
    @State private var dueDate = Date()
    @State private var apr = ""
    @State private var note = ""
    @State private var selectedDebt: Debt?

    var body: some View {
        ScreenScaffold(title: "Debts", subtitle: "Balances, reserves, minimums, and payoff progress.") {
            debtSummary
            addDebtCard
            SectionTitle("Active debts")
            if store.activeDebts.isEmpty {
                AppCard { EmptyStateView(title: "No active debts", message: "Add debts to track minimums, reserves, and payments.", systemImage: "checkmark.shield") }
            } else {
                ForEach(store.activeDebts) { debt in
                    Button {
                        selectedDebt = debt
                    } label: {
                        debtRow(debt)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedDebt) { debt in
            DebtDetailView(store: store, debt: debt)
        }
    }

    private var debtSummary: some View {
        let summary = FinanceEngine.getDebtSummary(debts: store.snapshot.debts, payments: store.snapshot.debtPayments, reserves: store.snapshot.debtReserves, pots: store.snapshot.pots, today: store.todayIso)
        return AppCard(glow: true) {
            MetricRow(label: "Current balance", value: MoneyParser.formatPence(summary.totalCurrentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(label: "Paid", value: MoneyParser.formatPence(summary.totalPaidPence))
            MetricRow(label: "Progress", value: "\(Int(summary.progressPercent.rounded()))%")
            MetricRow(label: "Overdue", value: "\(summary.overdueDebtCount)", valueColor: summary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
        }
    }

    private var addDebtCard: some View {
        AppCard {
            SectionTitle("Add debt")
            TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
            TextField("Lender", text: $lender).textFieldStyle(AppTextFieldStyle())
            MoneyField(title: "Original amount", text: $original)
            MoneyField(title: "Current balance", text: $balance)
            MoneyField(title: "Minimum payment", text: $minimum)
            DatePicker("Due date", selection: $dueDate, displayedComponents: .date).tint(AppTheme.Colors.primaryOrange)
            TextField("APR", text: $apr).keyboardType(.decimalPad).textFieldStyle(AppTextFieldStyle())
            TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
            PrimaryButton(title: "Add debt", systemImage: "plus", isDisabled: name.isBlank || MoneyParser.parsePoundsToPence(balance) <= 0) {
                store.addDebt(
                    name: name,
                    lender: lender,
                    originalAmountPence: MoneyParser.parsePoundsToPence(original),
                    currentBalancePence: MoneyParser.parsePoundsToPence(balance),
                    minimumPaymentPence: MoneyParser.parsePoundsToPence(minimum),
                    dueDate: dueDate.isoDateString,
                    apr: Double(apr),
                    note: note
                )
                name = ""
                lender = ""
                original = ""
                balance = ""
                minimum = ""
                note = ""
            }
        }
    }

    private func debtRow(_ debt: Debt) -> some View {
        AppCard(glow: debt.dueDate < store.todayIso) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(debt.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("\(debt.lender) · due \(debt.dueDate)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(MoneyParser.formatPence(debt.currentBalancePence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                    Text("Min \(MoneyParser.formatPence(debt.minimumPaymentPence))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
        }
    }
}

private struct DebtDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var debt: Debt
    @State private var payment = ""
    @State private var reserve = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    AppCard(glow: true) {
                        MetricRow(label: "Balance", value: MoneyParser.formatPence(currentDebt.currentBalancePence), valueColor: AppTheme.Colors.primaryOrange)
                        MetricRow(label: "Minimum", value: MoneyParser.formatPence(currentDebt.minimumPaymentPence))
                        MetricRow(label: "Due date", value: currentDebt.dueDate)
                    }
                    AppCard {
                        SectionTitle("Payment")
                        MoneyField(title: "Payment amount", text: $payment)
                        TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                        SecondaryButton(title: "Record payment", systemImage: "checkmark.circle") {
                            store.recordDebtPayment(debtId: debt.id, amountPence: MoneyParser.parsePoundsToPence(payment), date: Date().isoDateString, note: note)
                            payment = ""
                            note = ""
                        }
                        AppDivider()
                        MoneyField(title: "Reserve amount", text: $reserve)
                        SecondaryButton(title: "Plan reserve", systemImage: "plus.circle") {
                            store.addDebtReserve(debtId: debt.id, amountPence: MoneyParser.parsePoundsToPence(reserve), note: "Manual reserve")
                            reserve = ""
                        }
                    }
                    SecondaryButton(title: "Archive debt", systemImage: "archivebox", role: .destructive) {
                        store.archiveDebt(id: debt.id)
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(debt.name)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private var currentDebt: Debt {
        store.snapshot.debts.first(where: { $0.id == debt.id }) ?? debt
    }
}

struct CalendarPlannerView: View {
    @ObservedObject var store: PlannerStore
    @State private var month = Date()

    var body: some View {
        ScreenScaffold(title: "Calendar", subtitle: "Money events by month.") {
            AppCard(glow: true) {
                HStack {
                    Button {
                        month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(month, format: .dateTime.month(.wide).year())
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Spacer()
                    Button {
                        month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundStyle(AppTheme.Colors.primaryOrange)
            }

            if events.isEmpty {
                AppCard { EmptyStateView(title: "No events this month", message: "Paydays, bills, card payments, spending, and debts appear here.", systemImage: "calendar") }
            } else {
                ForEach(groupedDates, id: \.self) { date in
                    AppCard {
                        Text(date)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        ForEach(eventsByDate[date] ?? []) { event in
                            MetricRow(label: event.title, value: event.amountPence.map { MoneyParser.formatPence($0) } ?? event.detail, valueColor: color(for: event.type))
                        }
                    }
                }
            }
        }
    }

    private var monthStart: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = calendar.dateComponents([.year, .month], from: month)
        return FinanceEngine.toIsoDate(calendar.date(from: components) ?? month)
    }

    private var monthEnd: String {
        let start = monthStart.isoDate
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return FinanceEngine.toIsoDate(FinanceEngine.addDays(next, days: -1))
    }

    private var events: [CalendarEvent] {
        PlannerDerivedData.calendarEvents(snapshot: store.snapshot, startDate: monthStart, endDate: monthEnd)
    }

    private var eventsByDate: [String: [CalendarEvent]] {
        Dictionary(grouping: events, by: \.date)
    }

    private var groupedDates: [String] {
        eventsByDate.keys.sorted()
    }

    private func color(for type: CalendarEventType) -> Color {
        switch type {
        case .payday: AppTheme.Colors.success
        case .recurring, .savedPayment, .debtDue: AppTheme.Colors.warning
        case .cardPayment, .spending: AppTheme.Colors.orangeHighlight
        case .debtReserve, .debtPayment, .allocation: AppTheme.Colors.primaryOrange
        }
    }
}

struct HistoryView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(title: "History", subtitle: "Closed and active paycheck plans with allocations.") {
            AppCard(glow: true) {
                MetricRow(label: "Paychecks", value: "\(store.snapshot.paychecks.count)")
                MetricRow(label: "Total income", value: MoneyParser.formatPence(store.snapshot.payPeriods.reduce(0) { $0 + $1.incomePence }), valueColor: AppTheme.Colors.success)
                MetricRow(label: "Total allocated", value: MoneyParser.formatPence(store.snapshot.potAllocations.reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.primaryOrange)
            }

            if store.snapshot.payPeriods.isEmpty {
                AppCard { EmptyStateView(title: "No history", message: "Paycheck plans and allocation breakdowns appear here.", systemImage: "clock") }
            } else {
                ForEach(store.snapshot.payPeriods.sorted { $0.payday > $1.payday }) { period in
                    AppCard {
                        MetricRow(label: "Payday", value: period.payday)
                        MetricRow(label: "Income", value: MoneyParser.formatPence(period.incomePence), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Allocated", value: MoneyParser.formatPence(allocations(for: period).reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.primaryOrange)
                        ForEach(allocations(for: period)) { allocation in
                            MetricRow(label: store.snapshot.pots.first(where: { $0.id == allocation.potId })?.name ?? "Pot", value: MoneyParser.formatPence(allocation.amountPence))
                        }
                    }
                }
            }
        }
    }

    private func allocations(for period: PayPeriod) -> [PotAllocation] {
        store.snapshot.potAllocations.filter { $0.payPeriodId == period.id }
    }
}

struct SettingsView: View {
    @ObservedObject var store: PlannerStore
    @State private var hourlyRate = ""
    @State private var hours = ""
    @State private var manualDate = Date()
    @State private var showResetAlert = false

    var body: some View {
        ScreenScaffold(title: "Settings", subtitle: "Planner defaults, account placeholders, and local data controls.") {
            AppCard(glow: true) {
                SectionTitle("Pay defaults")
                Picker("Pay frequency", selection: bindingPayFrequency) {
                    ForEach(PayFrequency.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                MoneyField(title: "Hourly rate", text: $hourlyRate)
                TextField("Default hours", text: $hours).keyboardType(.decimalPad).textFieldStyle(AppTextFieldStyle())
                SecondaryButton(title: "Save pay defaults", systemImage: "checkmark") {
                    var settings = store.snapshot.settings
                    settings.hourlyRatePence = MoneyParser.parsePoundsToPence(hourlyRate)
                    settings.defaultHoursWorked = Double(hours) ?? settings.defaultHoursWorked
                    store.updateSettings(settings)
                }
            }

            AppCard {
                SectionTitle("Date mode")
                Picker("Mode", selection: bindingDateMode) {
                    ForEach(AppDateMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                if store.snapshot.settings.appDateMode == .manual {
                    DatePicker("Manual today", selection: $manualDate, displayedComponents: .date)
                        .tint(AppTheme.Colors.primaryOrange)
                    SecondaryButton(title: "Use selected date", systemImage: "calendar") {
                        var settings = store.snapshot.settings
                        settings.manualTodayIso = manualDate.isoDateString
                        store.updateSettings(settings)
                    }
                }
            }

            AppCard {
                SectionTitle("AI")
                Picker("Provider", selection: bindingAIProvider) {
                    ForEach(AIProvider.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                TextEditor(text: bindingAIInstructions)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            }

            accountCard

            SecondaryButton(title: "Reset local planner", systemImage: "trash", role: .destructive) {
                showResetAlert = true
            }
        }
        .onAppear {
            hourlyRate = String(format: "%.2f", Double(store.snapshot.settings.hourlyRatePence) / 100)
            hours = String(format: "%.0f", store.snapshot.settings.defaultHoursWorked)
            manualDate = store.snapshot.settings.manualTodayIso?.isoDate ?? Date()
        }
        .alert("Reset local planner?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { store.resetLocalData() }
        } message: {
            Text("This clears the local iPhone snapshot. The existing web app code and ignored web dist files are untouched.")
        }
    }

    private var accountCard: some View {
        AppCard {
            SectionTitle("Account")
            MetricRow(label: "Native Firebase", value: "Not configured", valueColor: AppTheme.Colors.warning)
            MetricRow(label: "Cloud sync", value: "Placeholder service")
            Text("TODO: add Firebase iOS Auth, GoogleService-Info.plist, Google/Apple provider setup, and Firestore snapshot sync for users/{uid}/planner/snapshot.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var bindingPayFrequency: Binding<PayFrequency> {
        Binding {
            store.snapshot.settings.payFrequency
        } set: {
            var settings = store.snapshot.settings
            settings.payFrequency = $0
            settings.defaultPayPeriodDays = FinanceEngine.frequencyToDays($0)
            store.updateSettings(settings)
        }
    }

    private var bindingDateMode: Binding<AppDateMode> {
        Binding {
            store.snapshot.settings.appDateMode
        } set: {
            var settings = store.snapshot.settings
            settings.appDateMode = $0
            store.updateSettings(settings)
        }
    }

    private var bindingAIProvider: Binding<AIProvider> {
        Binding {
            store.snapshot.settings.aiProvider
        } set: {
            var settings = store.snapshot.settings
            settings.aiProvider = $0
            store.updateSettings(settings)
        }
    }

    private var bindingAIInstructions: Binding<String> {
        Binding {
            store.snapshot.settings.aiInstructions
        } set: {
            var settings = store.snapshot.settings
            settings.aiInstructions = $0
            store.updateSettings(settings)
        }
    }
}

struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var prompt = ""
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(role: "Assistant", text: "I can summarise your local planner. Authenticated AI chat needs the native Firebase/backend TODOs in Settings.")
    ]
    @FocusState private var isPromptFocused: Bool
    private let assistantCoordinateSpace = "assistantScrollSpace"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                AppCard(glow: true) {
                                    MetricRow(label: "Spendable", value: MoneyParser.formatPence(FinanceEngine.getSpendablePence(pots: store.snapshot.pots)), valueColor: AppTheme.Colors.primaryOrange)
                                    MetricRow(label: "Active cards", value: "\(store.activeCards.count)")
                                    MetricRow(label: "Active debts", value: "\(store.activeDebts.count)")
                                }
                                .assistantBottomContentBlur(viewportHeight: geometry.size.height, coordinateSpaceName: assistantCoordinateSpace)

                                ForEach(messages) { message in
                                    HStack {
                                        if message.role == "You" { Spacer() }
                                        Text(message.text)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                            .padding(AppTheme.Spacing.md)
                                            .background(message.role == "You" ? AppTheme.Colors.primaryOrange.opacity(0.32) : AppTheme.Colors.elevatedSurface)
                                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                                        if message.role != "You" { Spacer() }
                                    }
                                    .assistantBottomContentBlur(viewportHeight: geometry.size.height, coordinateSpaceName: assistantCoordinateSpace)
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.top, AppTheme.Spacing.lg)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear {
                            scrollToBottom(with: proxy, animated: false)
                        }
                        .onChange(of: messages.count) { _, _ in
                            scrollToBottom(with: proxy)
                        }
                        .onChange(of: isPromptFocused) { _, isFocused in
                            if isFocused {
                                scrollToBottomAfterLayoutSettles(with: proxy)
                            }
                        }

                        assistantComposer(proxy: proxy)
                            .zIndex(1)
                    }
                    .coordinateSpace(name: assistantCoordinateSpace)
                    .premiumScreenBackground()
                    .navigationTitle("Assistant")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }
                }
            }
        }
    }

    private func assistantComposer(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            promptField(proxy: proxy)

            Button {
                sendLocalReply()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.Gradients.primary)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.Colors.glowOrange.opacity(0.6), radius: 12, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(prompt.isBlank)
        }
        .padding(AppTheme.Spacing.lg)
    }

    private func promptField(proxy: ScrollViewProxy) -> some View {
        TextField("Ask Assistant", text: $prompt)
            .foregroundStyle(AppTheme.Colors.primaryText)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 48)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.primaryText.opacity(0.14), lineWidth: 1)
            )
            .focused($isPromptFocused)
            .simultaneousGesture(
                TapGesture().onEnded {
                    scrollToBottomAfterLayoutSettles(with: proxy)
                }
            )
    }

    private func scrollToBottomAfterLayoutSettles(with proxy: ScrollViewProxy) {
        scrollToBottom(with: proxy)
        DispatchQueue.main.async {
            scrollToBottom(with: proxy)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            scrollToBottom(with: proxy)
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessageID = messages.last?.id else { return }
        if animated {
            withAnimation(AppTheme.Animation.standard) {
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }

    private func sendLocalReply() {
        let text = prompt
        messages.append(AssistantMessage(role: "You", text: text))
        prompt = ""
        let period = store.selectedPayPeriod
        let reply = "Local summary: \(MoneyParser.formatPence(period?.incomePence ?? 0)) income in the current plan, \(MoneyParser.formatPence(FinanceEngine.getSpendablePence(pots: store.snapshot.pots))) spendable, and \(store.snapshot.recurringPayments.filter(\.active).count) active bills. Authenticated AI actions are waiting on native Firebase ID tokens."
        messages.append(AssistantMessage(role: "Assistant", text: reply))
    }
}

private struct AssistantBottomContentBlurModifier: ViewModifier {
    let viewportHeight: CGFloat
    let coordinateSpaceName: String

    private let blurZoneHeight: CGFloat = 132
    private let blurRampHeight: CGFloat = 72
    private let maxBlurRadius: CGFloat = 2.4

    func body(content: Content) -> some View {
        content.visualEffect { effect, geometry in
            let frame = geometry.frame(in: .named(coordinateSpaceName))
            let zoneStart = viewportHeight - blurZoneHeight
            let distanceIntoZone = max(frame.maxY - zoneStart, 0)
            let progress = min(distanceIntoZone / blurRampHeight, 1)

            return effect.blur(radius: progress * maxBlurRadius)
        }
    }
}

private extension View {
    func assistantBottomContentBlur(viewportHeight: CGFloat, coordinateSpaceName: String) -> some View {
        modifier(AssistantBottomContentBlurModifier(viewportHeight: viewportHeight, coordinateSpaceName: coordinateSpaceName))
    }
}

private struct AssistantMessage: Identifiable {
    let id = UUID()
    var role: String
    var text: String
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfBlank: String? {
        isBlank ? nil : self
    }
}
