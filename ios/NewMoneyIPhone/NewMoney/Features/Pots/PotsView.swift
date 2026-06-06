import SwiftUI

struct PotsView: View {
    @ObservedObject var store: PlannerStore
    @State private var query = ""
    @State private var selectedType: PotType?
    @State private var isAddPresented = false
    @State private var selectedPot: Pot?

    private var filteredPots: [Pot] {
        store.activePots.filter { pot in
            let matchesQuery = query.isEmpty || pot.name.localizedCaseInsensitiveContains(query) || (pot.category ?? "").localizedCaseInsensitiveContains(query)
            let matchesType = selectedType == nil || pot.type == selectedType
            return matchesQuery && matchesType
        }
    }

    var body: some View {
        ScreenScaffold(
            title: "Pots",
            subtitle: "Buckets for bills, spending, savings, investments, and buffers."
        ) {
            summaryCard
            controls
            potList
        }
        .sheet(isPresented: $isAddPresented) {
            PotFormView(store: store)
        }
        .sheet(item: $selectedPot) { pot in
            PotDetailView(store: store, pot: pot)
        }
    }

    private var summaryCard: some View {
        AppCard(glow: true) {
            MetricRow(label: "Total pot balance", value: MoneyParser.formatPence(store.activePots.reduce(0) { $0 + $1.balancePence }), valueColor: AppTheme.Colors.primaryOrange)
            MetricRow(label: "Spendable", value: MoneyParser.formatPence(FinanceEngine.getSpendablePence(pots: store.snapshot.pots)))
            MetricRow(label: "Active pots", value: "\(store.activePots.count)")
        }
    }

    private var controls: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                TextField("Search pots", text: $query)
                    .textFieldStyle(AppTextFieldStyle())
                AddButton(title: "Add") {
                    isAddPresented = true
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    FilterChip(title: "All", isSelected: selectedType == nil) { selectedType = nil }
                    ForEach(PotType.allCases) { type in
                        FilterChip(title: type.rawValue.capitalized, isSelected: selectedType == type) { selectedType = type }
                    }
                }
            }
        }
    }

    private var potList: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if filteredPots.isEmpty {
                AppCard {
                    EmptyStateView(title: "No pots match", message: "Adjust the search or add a new pot.", systemImage: "magnifyingglass")
                }
            } else {
                ForEach(filteredPots) { pot in
                    Button {
                        selectedPot = pot
                    } label: {
                        PotRow(pot: pot)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(AppTheme.Gradients.primary) : AnyShapeStyle(AppTheme.Colors.elevatedSurface))
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct PotRow: View {
    var pot: Pot

    var body: some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Circle()
                    .fill(Color(hex: pot.color))
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 6) {
                    Text(pot.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("\(pot.type.rawValue.capitalized) · \(pot.category ?? "Uncategorised")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(MoneyParser.formatPence(pot.balancePence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                    if let target = pot.targetPence, target > 0 {
                        Text("\(Int((Double(pot.balancePence) / Double(target) * 100).rounded()))% target")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                }
            }
        }
    }
}

private struct PotFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var type: PotType = .spending
    @State private var category = ""
    @State private var target = ""
    @State private var color = "#E85002"

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.md) {
                TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
                Picker("Type", selection: $type) {
                    ForEach(PotType.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                TextField("Category", text: $category).textFieldStyle(AppTextFieldStyle())
                MoneyField(title: "Target (optional)", text: $target)
                TextField("Colour hex", text: $color).textFieldStyle(AppTextFieldStyle())
                PrimaryButton(title: "Add pot", systemImage: "plus", isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                    store.addPot(name: name, type: type, category: category, targetPence: target.isEmpty ? nil : MoneyParser.parsePoundsToPence(target), color: color)
                    dismiss()
                }
                Spacer()
            }
            .padding(AppTheme.Spacing.lg)
            .premiumScreenBackground()
            .navigationTitle("Add pot")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

private struct PotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var pot: Pot
    @State private var allocation = ""
    @State private var spend = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    PotRow(pot: latestPot)
                    AppCard {
                        SectionTitle("Move money")
                        MoneyField(title: "Add allocation", text: $allocation)
                        SecondaryButton(title: "Allocate to pot", systemImage: "plus") {
                            store.addPotAllocation(potId: pot.id, amountPence: MoneyParser.parsePoundsToPence(allocation))
                            allocation = ""
                        }
                        AppDivider()
                        MoneyField(title: "Spend amount", text: $spend)
                        TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                        SecondaryButton(title: "Record spending", systemImage: "cart") {
                            store.recordTransaction(potId: pot.id, creditCardId: nil, paymentMethod: .pot, amountPence: MoneyParser.parsePoundsToPence(spend), type: .spending, date: Date().isoDateString, note: note)
                            spend = ""
                            note = ""
                        }
                    }
                    SecondaryButton(title: "Archive pot", systemImage: "archivebox", role: .destructive) {
                        store.archivePot(id: pot.id)
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(pot.name)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private var latestPot: Pot {
        store.snapshot.pots.first(where: { $0.id == pot.id }) ?? pot
    }
}
