import SwiftUI

enum AssistantPresentationMode: Equatable {
    case modal
    case pushed
}

enum AssistantMenuPresentationPolicy {
    static let toolbarTitle = "Edit"
    static let presentation = "nativeSwiftUIMenu"
    static let actions = ["Customise assistant", "Rename"]
    static let customiseAssistantRoute = "preferencesScreen"
    static let renamePresentation = "textFieldAlert"
    static let instructionsUsesPlaceholderToolbar = false
    static let focusedMessageBottomClearance: CGFloat = 132
    static let bottomScrollAnchorID = "assistant-bottom-scroll-anchor"
    static let returnsToStandardBottomWhenKeyboardCloses = true
    static let everyPromptReceivesLocalReply = true
}

struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var presentationMode: AssistantPresentationMode = .modal
    @State private var prompt = ""
    @State private var isRenameAssistantPresented = false
    @State private var assistantNameDraft = ""
    @State private var activeAssistantSheet: AssistantSettingsSheet?
    @State private var scrollRequestRevision = 0
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(role: "Assistant", text: "I answer locally from your saved planner. Ask about money left, income, payday, bills, cards, or debts. I cannot make changes or contact an online AI provider.")
    ]
    @FocusState private var isPromptFocused: Bool

    private var assistantName: String {
        store.snapshot.settings.assistantName?.nilIfBlank ?? "Assistant"
    }

    @ViewBuilder
    var body: some View {
        switch presentationMode {
        case .modal:
            NavigationStack {
                assistantContent
            }
        case .pushed:
            assistantContent
        }
    }

    private var assistantContent: some View {
        ScrollViewReader { proxy in
            GeometryReader { _ in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                AppCard(glow: true) {
                                    MetricRow(label: "Spendable", value: MoneyParser.formatPence(FinanceEngine.getSpendablePence(pots: store.snapshot.pots)), valueColor: AppTheme.Colors.primaryOrange)
                                    MetricRow(label: "Active cards", value: "\(store.activeCards.count)")
                                    MetricRow(label: "Active debts", value: "\(store.activeDebts.count)")
                                }

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
                                }
                            }

                            Color.clear
                                .frame(height: isPromptFocused ? AssistantMenuPresentationPolicy.focusedMessageBottomClearance : 0)
                                .id(AssistantMenuPresentationPolicy.bottomScrollAnchorID)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.lg)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        scrollToBottom(with: proxy, animated: false)
                    }
                    .onChange(of: messages.count) { _, _ in
                        requestScrollToBottom()
                    }
                    .onChange(of: isPromptFocused) { _, _ in
                        requestScrollToBottom()
                    }
                    .task(id: scrollRequestRevision) {
                        await Task.yield()
                        scrollToBottom(with: proxy)
                        try? await Task.sleep(for: .milliseconds(320))
                        guard !Task.isCancelled else { return }
                        scrollToBottom(with: proxy)
                    }

                    assistantComposer
                        .zIndex(1)
                }
                .premiumScreenBackground()
                .navigationTitle(assistantName)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTopDividerHidden()
                .toolbar {
                    if presentationMode == .modal {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu(AssistantMenuPresentationPolicy.toolbarTitle) {
                            Button(AssistantMenuPresentationPolicy.actions[0]) {
                                activeAssistantSheet = .customise
                            }

                            Button(AssistantMenuPresentationPolicy.actions[1]) {
                                assistantNameDraft = assistantName
                                isRenameAssistantPresented = true
                            }
                        }
                    }
                }
                .alert("Rename assistant", isPresented: $isRenameAssistantPresented) {
                    TextField("Assistant name", text: $assistantNameDraft)

                    Button("Cancel", role: .cancel) {}
                    Button("Save") {
                        saveAssistantName()
                    }
                } message: {
                    Text("Choose the name shown in assistant replies.")
                }
                .sheet(item: $activeAssistantSheet) { sheet in
                    switch sheet {
                    case .customise:
                        AssistantCustomiseView(store: store)
                    }
                }
            }
        }
    }

    private var assistantComposer: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            promptField

            Button("Send message", systemImage: "paperplane.fill", action: sendLocalReply)
                .labelStyle(.iconOnly)
                .foregroundStyle(AppTheme.Colors.controlText)
                .frame(width: 48, height: 48)
                .background(AppTheme.Gradients.primary)
                .clipShape(Circle())
                .shadow(color: AppTheme.Colors.glowOrange.opacity(0.6), radius: 12, y: 4)
                .buttonStyle(ScaleButtonStyle())
                .disabled(prompt.isBlank)
        }
        .padding(AppTheme.Spacing.lg)
    }

    private var promptField: some View {
        TextField("Ask Assistant", text: $prompt)
            .foregroundStyle(AppTheme.Colors.primaryText)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 48)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.primaryText.opacity(0.14), lineWidth: 1)
            )
            .focused($isPromptFocused)
            .submitLabel(.send)
            .onSubmit(sendLocalReply)
    }

    private func requestScrollToBottom() {
        scrollRequestRevision += 1
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(AppTheme.Animation.standard) {
                proxy.scrollTo(AssistantMenuPresentationPolicy.bottomScrollAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(AssistantMenuPresentationPolicy.bottomScrollAnchorID, anchor: .bottom)
        }
    }

    private func sendLocalReply() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(AssistantMessage(role: "You", text: text))
        prompt = ""
        let reply = AssistantLocalResponseBuilder.response(
            to: text,
            snapshot: store.snapshot,
            selectedPayPeriod: store.selectedPayPeriod
        )
        messages.append(AssistantMessage(role: assistantName, text: reply))
    }

    private func saveAssistantName() {
        let previousName = assistantName
        let newName = assistantNameDraft.nilIfBlank ?? "Assistant"
        var settings = store.snapshot.settings
        settings.assistantName = newName
        store.updateSettings(settings)
        messages = messages.map { message in
            guard message.role == previousName || message.role == "Assistant" else { return message }
            var renamedMessage = message
            renamedMessage.role = newName
            return renamedMessage
        }
    }
}

private enum AssistantSettingsSheet: String, Identifiable {
    case customise

    var id: String { rawValue }
}

private struct AssistantCustomiseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var assistantName = ""
    @State private var responseStyle: AssistantResponseStyle = .straightToThePoint

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    AppCard(glow: true) {
                        SectionTitle("Customise assistant")
                        TextField("Assistant name", text: $assistantName)
                            .textFieldStyle(AppTextFieldStyle())
                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(AssistantResponseStyle.allCases) { style in
                                Button {
                                    responseStyle = style
                                } label: {
                                    HStack {
                                        Text(style.label)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                        Spacer()
                                        if responseStyle == style {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppTheme.Colors.primaryOrange)
                                        }
                                    }
                                    .padding(AppTheme.Spacing.md)
                                    .background(responseStyle == style ? AppTheme.Colors.primaryOrange.opacity(0.12) : AppTheme.Colors.elevatedSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                                            .stroke(responseStyle == style ? AppTheme.Colors.primaryOrange.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        PrimaryButton(title: "Save assistant", systemImage: "checkmark") {
                            var settings = store.snapshot.settings
                            settings.assistantName = assistantName.nilIfBlank ?? "Assistant"
                            settings.assistantResponseStyle = responseStyle
                            store.updateSettings(settings)
                            dismiss()
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Customise")
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
            .onAppear {
                assistantName = store.snapshot.settings.assistantName?.nilIfBlank ?? "Assistant"
                responseStyle = store.snapshot.settings.assistantResponseStyle ?? .straightToThePoint
            }
        }
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
