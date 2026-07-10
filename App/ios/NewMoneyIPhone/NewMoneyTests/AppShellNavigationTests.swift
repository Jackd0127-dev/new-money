import XCTest
@testable import NewMoneyIPhone

final class AppShellNavigationTests: XCTestCase {
    func testSplashPlaysOnlyOncePerProcessLaunch() {
        XCTAssertTrue(MUNOSplashPresentationPolicy.playsOncePerProcessLaunch)
        XCTAssertFalse(MUNOSplashPresentationPolicy.replaysOnForeground)
        XCTAssertFalse(MUNOSplashPresentationPolicy.usesScenePhaseReplayRevision)
        XCTAssertEqual(MUNOSplashPresentationPolicy.fadeOutDuration, 0.28, accuracy: 0.001)
    }

    func testPrimaryTabOrderMatchesMainNavigationRestructure() {
        XCTAssertEqual(AppTab.allCases.map(\.title), ["Home", "Bills", "Activity", "Pots", "Credit"])
        XCTAssertEqual(AppTab.allCases.map(\.symbol), ["house", "calendar.badge.clock", "list.bullet.rectangle.portrait", "wallet.pass", "creditcard.trianglebadge.exclamationmark"])
    }

    func testHomeNavigationTitleUsesActiveAccountName() {
        XCTAssertEqual(AppNavigationTitlePolicy.title(for: .home, activeAccountName: "Personal"), "Personal")
        XCTAssertEqual(AppNavigationTitlePolicy.title(for: .home, activeAccountName: "  Bills  "), "Bills")
        XCTAssertEqual(AppNavigationTitlePolicy.title(for: .home, activeAccountName: nil), "Home")
        XCTAssertEqual(AppNavigationTitlePolicy.title(for: .bills, activeAccountName: "Personal"), "Bills")
    }

    func testTabRootScreensResetToTopOnSelectionButPreserveAfterNavigationPop() {
        XCTAssertTrue(RootTabScrollPolicy.resetsTabRootOnSelection)
        XCTAssertTrue(RootTabScrollPolicy.resetsOnlyWhenSelectionRevisionChanges)
        XCTAssertTrue(RootTabScrollPolicy.preservesPositionAfterNavigationPop)
        XCTAssertTrue(RootTabScrollPolicy.disablesSelectionScrollAnimation)
        XCTAssertFalse(RootTabScrollPolicy.rebuildsSelectedTabScrollViewOnSelection)
        XCTAssertTrue(RootTabScrollPolicy.keepsInactiveTabIdentityStableDuringSwitch)
        XCTAssertTrue(RootTabScrollPolicy.usesScrollReaderForTabReset)
        XCTAssertTrue(RootTabScrollPolicy.updatesResetTargetBeforeSelectedTab)
        XCTAssertTrue(RootTabScrollPolicy.preventsPreviousTabResetDuringSwitch)
        XCTAssertEqual(RootTabScrollPolicy.topAnchorID, "root-tab-scroll-top")
    }

    func testMainTabsPushScreensAboveTabBarAndKeepToolbarItems() {
        XCTAssertFalse(AppTabNavigationStackPolicy.isolatesNavigationStackPerTab)
        XCTAssertTrue(AppTabNavigationStackPolicy.wrapsTabShellInRootNavigationStack)
        XCTAssertTrue(AppTabNavigationStackPolicy.pushedScreensCoverAppleTabBar)
        XCTAssertTrue(AppTabNavigationStackPolicy.appliesTitleInsideRootTabShell)
        XCTAssertTrue(AppTabNavigationStackPolicy.appliesToolbarInsideRootTabShell)
        XCTAssertTrue(AppTabNavigationStackPolicy.keepsTabRootScrollReset)
    }

    func testActivityUsesToolbarTitleInsteadOfLargeTitle() {
        XCTAssertEqual(AppNavigationTitleDisplayPolicy.style(for: .activity), .inline)
        XCTAssertEqual(AppNavigationTitleDisplayPolicy.style(for: .home), .large)
        XCTAssertEqual(AppNavigationTitleDisplayPolicy.style(for: .bills), .large)
        XCTAssertEqual(AppNavigationTitleDisplayPolicy.style(for: .pots), .large)
        XCTAssertEqual(AppNavigationTitleDisplayPolicy.style(for: .credit), .large)
    }

    func testUniversalAddMenuIncludesSupportedAddFlows() {
        XCTAssertEqual(AppAddAction.allCases.map(\.title), ["Add Spend", "Add Bill", "Add Pot", "Add Card"])
        XCTAssertEqual(AppAddAction.allCases.map(\.symbol), ["receipt", "calendar.badge.plus", "wallet.pass", "creditcard"])
        XCTAssertFalse(AppAddAction.allCases.map(\.title).contains("Add Income"))
        XCTAssertFalse(AppAddAction.allCases.map(\.title).contains("Add Card Payment"))
        XCTAssertFalse(AppAddAction.allCases.map(\.title).contains("Add Debt"))
    }

    func testAddMenuActionsAreScopedToCurrentTab() {
        XCTAssertFalse(AppAddMenuPolicy.showsNavigationDivider)
        XCTAssertTrue(AppAddMenuPolicy.opensSingleActionDirectly)
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .home), [.spend])
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .activity), [])
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .bills), [.bill])
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .pots), [.pot])
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .credit), [.card])
        XCTAssertFalse(AppAddMenuPolicy.actions(for: .credit).map(\.title).contains("Add Debt"))
    }

    func testSingleActionTabsBypassAddMenu() {
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .home).count, 1)
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .bills).count, 1)
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .pots).count, 1)
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .credit).count, 1)
        XCTAssertEqual(AppAddMenuPolicy.actions(for: .activity).count, 0)
    }

    func testToolbarActionsHideRequestedTabExtras() {
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .home), ["plan-calendar-toolbar-action", "add-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .bills), ["add-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .activity), ["activity-infinity-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .pots), ["pot-history-toolbar-action", "add-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .credit), ["add-menu-toolbar-action"])
        XCTAssertTrue(AppToolbarPolicy.actionIds(for: .home).contains("plan-calendar-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .bills).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .activity).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .activity).contains("add-menu-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .activity).contains("spending-history-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .pots).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .credit).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .credit).contains("card-payments-toolbar-action"))
    }

    func testHomeShowsProfileMenuInLeadingToolbarOnly() {
        XCTAssertEqual(AppToolbarPolicy.leadingActionIds(for: .home), ["profile-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.leadingActionIds(for: .bills), [])
        XCTAssertEqual(AppToolbarPolicy.leadingActionIds(for: .activity), [])
        XCTAssertEqual(AppToolbarPolicy.leadingActionIds(for: .pots), [])
        XCTAssertEqual(AppToolbarPolicy.leadingActionIds(for: .credit), [])
    }

    func testProfileMenuIncludesSettingsRoute() {
        XCTAssertEqual(ProfileMenuAction.allCases.map(\.title), ["Add Income", "Appearance", "History", "Credit Statements"])
        XCTAssertEqual(ProfileMenuAction.allCases.map(\.symbol), ["sterlingsign.circle", "paintpalette", "clock.arrow.circlepath", "doc.text.magnifyingglass"])
        XCTAssertTrue(ProfileMenuPresentationPolicy.includesAddIncomeAction)
    }

    func testProfileMenuUsesRootNavigationLinkAndSettingsLink() {
        XCTAssertEqual(ProfileMenuPresentationPolicy.profileStyle, .rootNavigationLink)
        XCTAssertEqual(ProfileMenuPresentationPolicy.settingsStyle, .navigationLink)
        XCTAssertTrue(ProfileMenuPresentationPolicy.centersProfileIdentity)
        XCTAssertTrue(ProfileMenuPresentationPolicy.syncsActiveAccountName)
        XCTAssertTrue(ProfileMenuPresentationPolicy.syncsActiveAccountAvatar)
        XCTAssertTrue(ProfileMenuPresentationPolicy.showsSignOutAction)
        XCTAssertTrue(ProfileMenuPresentationPolicy.signOutUsesAuthGateSession)
        XCTAssertEqual(ProfileMenuPresentationPolicy.logOutActionTitle, "Log Out")
        XCTAssertTrue(ProfileMenuPresentationPolicy.confirmsLogOut)
        XCTAssertTrue(ProfileMenuPresentationPolicy.showsResetDataAction)
        XCTAssertEqual(ProfileMenuPresentationPolicy.resetDataActionTitle, "Reset Data")
        XCTAssertEqual(ProfileMenuPresentationPolicy.resetDataConfirmationCount, 2)
        XCTAssertTrue(ProfileMenuPresentationPolicy.resetDataKeepsAuthAccount)
        XCTAssertTrue(ProfileMenuPresentationPolicy.resetDataDeletesCloudPlannerData)
        XCTAssertTrue(ProfileMenuPresentationPolicy.opensAppearanceDirectly)
        XCTAssertTrue(ProfileMenuPresentationPolicy.usesSystemFullScreenSafeArea)
        XCTAssertTrue(ProfileMenuPresentationPolicy.usesInlineNavigationTitle)
        XCTAssertFalse(ProfileMenuPresentationPolicy.showsProfileSubtitle)
        XCTAssertEqual(ProfileMenuPresentationPolicy.editActionTitle, "Edit")
        XCTAssertTrue(ProfileMenuPresentationPolicy.editActionOpensAccounts)
        XCTAssertFalse(ProfileMenuPresentationPolicy.animatesFromBottom)
        XCTAssertFalse(ProfileMenuPresentationPolicy.avoidsSystemNavigationBar)
    }

    func testAccountsSheetUsesCarouselCreateButtonAndHiddenManagement() {
        XCTAssertEqual(AccountsLayoutPolicy.sections, [.carousel, .profileOverview, .profilePulse, .profilePills])
        XCTAssertEqual(AccountsLayoutPolicy.createActionPlacement, "topBarTrailing")
        XCTAssertEqual(AccountsLayoutPolicy.presentationDetent, "large")
        XCTAssertFalse(AccountsLayoutPolicy.showsNavigationDivider)
        XCTAssertFalse(AccountsLayoutPolicy.avatarPreviewShowsNavigationDivider)
        XCTAssertEqual(AccountsLayoutPolicy.managementPresentation, .contextMenu)
        XCTAssertLessThan(AccountsLayoutPolicy.carouselSnapThreshold, 0.15)
        XCTAssertLessThanOrEqual(AccountsLayoutPolicy.carouselMinimumDragDistance, 6)
        XCTAssertLessThanOrEqual(AccountsLayoutPolicy.carouselMinimumSwipeDistance, 16)
        XCTAssertLessThanOrEqual(AccountsLayoutPolicy.carouselMaximumSwipeDistance, 32)
        XCTAssertLessThan(AccountsLayoutPolicy.carouselVerticalToleranceRatio, 0.6)
        XCTAssertEqual(AccountsLayoutPolicy.editMenuPresentation, "nativeSwiftUIMenu")
        XCTAssertEqual(AccountsLayoutPolicy.avatarSourcePresentation, "nativeSwiftUIMenu")
        XCTAssertEqual(AccountsLayoutPolicy.carouselInteraction, "directionalSwipeAutoAdvance")
        XCTAssertEqual(AccountsLayoutPolicy.profileGraphMetric, "savedSpentTotals")
        XCTAssertFalse(AccountsLayoutPolicy.profileGraphShowsMetricPills)
        XCTAssertEqual(AccountsLayoutPolicy.profilePulseCardCornerRadius, AppTheme.Radius.md)
        XCTAssertFalse(AccountsLayoutPolicy.showsBottomAccountList)
    }

    func testAssistantUsesNativeEditMenuAndInstructionsRoute() {
        XCTAssertEqual(AssistantMenuPresentationPolicy.toolbarTitle, "Edit")
        XCTAssertEqual(AssistantMenuPresentationPolicy.presentation, "nativeSwiftUIMenu")
        XCTAssertEqual(AssistantMenuPresentationPolicy.actions, ["Customise assistant", "Rename"])
        XCTAssertEqual(AssistantMenuPresentationPolicy.customiseAssistantRoute, "instructionsScreen")
        XCTAssertEqual(AssistantMenuPresentationPolicy.renamePresentation, "textFieldAlert")
        XCTAssertFalse(AssistantMenuPresentationPolicy.instructionsUsesPlaceholderToolbar)
    }

    func testEditToolbarActionUsesTextButton() {
        let action = AppToolbarAction.edit()

        XCTAssertEqual(action.id, "edit-toolbar-action")
        XCTAssertEqual(action.title, "Edit")
        XCTAssertEqual(action.accessibilityLabel, "Edit")
    }

    func testEditDoneToolbarPolicyUsesNativeContentSwap() {
        XCTAssertEqual(AppEditDoneToolbarPolicy.editToolbarActionId, "edit-toolbar-action")
        XCTAssertEqual(AppEditDoneToolbarPolicy.editTitle, "Edit")
        XCTAssertEqual(AppEditDoneToolbarPolicy.doneTitle, "Done")
        XCTAssertTrue(AppEditDoneToolbarPolicy.usesNativeToolbarContentSwap)
        XCTAssertEqual(AppEditDoneToolbarPolicy.springResponse, 0.28, accuracy: 0.001)
        XCTAssertEqual(AppEditDoneToolbarPolicy.springDampingFraction, 0.86, accuracy: 0.001)
    }

    @MainActor
    func testEditDoneToolbarUsesPlanDayStyleDistinctContentBranches() {
        let bodyType = String(
            describing: type(
                of: AppEditDoneToolbarButton(isEditing: false, action: {}).body
            )
        )

        XCTAssertTrue(bodyType.contains("AppEditToolbarBranchButton"))
        XCTAssertTrue(bodyType.contains("AppDoneToolbarBranchButton"))
    }

    func testCreditRoutesHideCardPaymentsAndStatements() {
        XCTAssertEqual(CreditRoute.allCases.map(\.title), ["Cards", "Debts"])
        XCTAssertFalse(CreditRoute.allCases.map(\.title).contains("Card payments"))
        XCTAssertFalse(CreditRoute.allCases.map(\.title).contains("Statements"))
    }

    func testSettingsRoutesIncludeCreditStatements() {
        XCTAssertEqual(SettingsRoute.allCases.map(\.title), ["History", "Credit Statements"])
    }

    func testCreditSecondaryScreenToolbarActionsMatchRequestedButtons() {
        XCTAssertEqual(CardsLayoutPolicy.toolbarActionId, "add")
        XCTAssertEqual(CardsLayoutPolicy.detailToolbarActionId, "card-detail-add-payment")
        XCTAssertEqual(CardsLayoutPolicy.detailToolbarTitle, "Payment")
        XCTAssertEqual(CardsLayoutPolicy.detailToolbarStyle, "textButton")
        XCTAssertEqual(CardsLayoutPolicy.repaymentFlowPlacement, "cardDetailToolbar")
        XCTAssertEqual(DebtsLayoutPolicy.toolbarActionId, "add")
        XCTAssertEqual(DebtsLayoutPolicy.addFlowPlacement, "debtsSectionToolbar")
        XCTAssertEqual(StatementsLayoutPolicy.toolbarActionId, "edit-toolbar-action")
    }

    func testAddCardFormUsesCompactCenteredLayoutWithoutPlaceholderToolbar() {
        XCTAssertEqual(CardFormLayoutPolicy.dayFieldOrder, ["directDebitDay", "statementDay"])
        XCTAssertEqual(CardFormLayoutPolicy.dayFieldPresentation, "compactSideBySideMenuBoxes")
        XCTAssertEqual(CardFormLayoutPolicy.dayFieldTitleLineLimit, 1)
        XCTAssertEqual(CardFormLayoutPolicy.dayFieldMinimumHeight, 64, accuracy: 0.001)
        XCTAssertEqual(CardFormLayoutPolicy.colorSwatchAlignment, "center")
        XCTAssertFalse(CardFormLayoutPolicy.showsPlaceholderToolbar)
        XCTAssertTrue(CardFormLayoutPolicy.hidesNavigationDivider)
        XCTAssertTrue(CardFormLayoutPolicy.usesBillsStyleCard)
        XCTAssertEqual(CardFormLayoutPolicy.designSelectionPresentation, "navigationPushGroupedDesignBrowser")
        XCTAssertEqual(CardFormLayoutPolicy.designGridColumnCount, 2)
        XCTAssertTrue(CardFormLayoutPolicy.preservesDesignAspectRatio)
    }

    func testNamedScreensHideTopNavigationDivider() {
        XCTAssertEqual(ScreenTopDividerPolicy.hiddenScreens, [
            "Add card",
            "Create paycheck plan",
            "Assistant",
            "Card",
            "Card payments",
            "Add debt",
            "Pot Overview",
            "Edit Pot"
        ])
        XCTAssertTrue(ScreenTopDividerPolicy.keepsToolbarBackgroundHidden)
        XCTAssertTrue(ScreenTopDividerPolicy.usesNavigationBarAppearanceInstaller)
    }

    func testPlusAddFormsUseCleanBoxedLayouts() {
        XCTAssertEqual(SpendingFormLayoutPolicy.accountPickerStyle, "selectionFieldBox")
        XCTAssertTrue(AddBillFormLayoutPolicy.hidesNavigationDivider)
        XCTAssertEqual(AddBillFormLayoutPolicy.allowedFrequencies, [.weekly, .biweekly, .monthly, .yearly])
        XCTAssertFalse(AddBillFormLayoutPolicy.allowedFrequencies.contains(.once))
        XCTAssertFalse(AddBillFormLayoutPolicy.allowedFrequencies.contains(.quarterly))
        XCTAssertTrue(PotFormLayoutPolicy.usesBillsStyleCard)
        XCTAssertTrue(PotFormLayoutPolicy.hidesNavigationDivider)
        XCTAssertEqual(PotFormLayoutPolicy.linkedPickerStyle, "selectionFieldBox")
        XCTAssertEqual(PotFormLayoutPolicy.colorHexes.count, 8)
        XCTAssertEqual(Set(PotFormLayoutPolicy.colorHexes).count, 8)
        XCTAssertEqual(CardFormLayoutPolicy.directDebitDayTitle, "Direct debit")
        XCTAssertEqual(CardFormLayoutPolicy.statementDayTitle, "Statement")
        XCTAssertLessThanOrEqual(CardFormLayoutPolicy.dayFieldTitleMinimumScaleFactor, CGFloat(0.55))
    }

    func testCreditSecondaryScreensHideInlineAddAndAllocationCards() {
        XCTAssertEqual(CardsLayoutPolicy.sections, [.summary, .activeCards])
        XCTAssertFalse(CardsLayoutPolicy.sections.contains(.paymentAllocation))
        XCTAssertEqual(CardsLayoutPolicy.detailTopPresentation, "floatingNoOuterCard")
        XCTAssertEqual(CardsLayoutPolicy.rowPresentation, "floatingNoOuterCard")
        XCTAssertEqual(CardsLayoutPolicy.activeCardCollapsedPresentation, "overlappedStack")
        XCTAssertEqual(CardsLayoutPolicy.activeCardExpandedPresentation, "floatingTwoColumnGrid")
        XCTAssertEqual(CardsLayoutPolicy.activeCardExpandedColumnCount, 2)
        XCTAssertTrue(CardsLayoutPolicy.activeCardExpandedUsesLazyGrid)
        XCTAssertTrue(CardsLayoutPolicy.activeCardViewAllPillEnabled)
        XCTAssertEqual(CardsLayoutPolicy.activeCardStackAnimation, "matchedGeometrySpring")
        XCTAssertEqual(DebtsLayoutPolicy.sections, [.summary, .activeDebts])
        XCTAssertFalse(DebtsLayoutPolicy.sections.map(\.rawValue).contains("addDebt"))
    }

    func testBillsTabSupportsGroupsAndLinkedBillContext() {
        XCTAssertEqual(BillsLayoutPolicy.sections, [.overview, .fundingChecklist, .groups, .billGroups, .upcoming])
        XCTAssertEqual(BillsLayoutPolicy.overviewPresentation, .navigationPush)
        XCTAssertEqual(BillsLayoutPolicy.groupCreationPlacement, "groupsHeader")
        XCTAssertTrue(BillsLayoutPolicy.showsCreditCardAndPotLinksOnBills)
        XCTAssertEqual(BillsLayoutPolicy.billGroupingPersistence, "recurringPayment.billGroupId")
        XCTAssertFalse(BillsLayoutPolicy.groupFilterScrollClipsContent)
        XCTAssertGreaterThan(BillsLayoutPolicy.groupFilterHorizontalContentPadding, 0)
        XCTAssertTrue(BillsLayoutPolicy.overviewHeroUsesGlow)
        XCTAssertFalse(BillsLayoutPolicy.detailShowsDuplicateUpcomingEmptyState)
        XCTAssertEqual(BillsLayoutPolicy.fundingChecklistPlacement, "belowOverview")
        XCTAssertTrue(BillsLayoutPolicy.fundingChecklistAlwaysVisible)
        XCTAssertTrue(BillsLayoutPolicy.fundingChecklistUsesExistingDerivedItems)
        XCTAssertEqual(BillsLayoutPolicy.yourBillsPresentation, "collapsibleDropdown")
        XCTAssertEqual(BillsLayoutPolicy.takingSoonPresentation, "collapsibleDropdown")
        XCTAssertTrue(BillsLayoutPolicy.yourBillsAppearsAboveTakingSoon)
        XCTAssertTrue(BillsLayoutPolicy.billRowsOpenEditScreen)
        XCTAssertEqual(BillsLayoutPolicy.editBillTitle, "Edit Bill")
        XCTAssertTrue(BillsLayoutPolicy.editUsesExistingRecurringPaymentUpdate)
    }

    func testPotsSummaryOpensGraphTimelineDetail() {
        XCTAssertEqual(PotsLayoutPolicy.sections, [.summary, .controls, .potList])
        XCTAssertEqual(PotsLayoutPolicy.summaryPresentation, .navigationPush)
        XCTAssertFalse(PotsLayoutPolicy.summaryShowsTopCardSymbol)
        XCTAssertEqual(PotsLayoutPolicy.overviewDetailSections, [.graph, .timeline])
        XCTAssertEqual(PotsLayoutPolicy.graphStyle, "animatedNeonLine")
        XCTAssertEqual(PotsLayoutPolicy.timelineStyle, "branchedPotTimeline")
        XCTAssertEqual(PotsLayoutPolicy.timelinePresentation, "collapsibleDropdown")
        XCTAssertTrue(PotsLayoutPolicy.timelineDefaultsExpandedWhenEmpty)
        XCTAssertEqual(PotsLayoutPolicy.overviewDetailSubtitle, "")
        XCTAssertTrue(PotsLayoutPolicy.overviewDetailUsesInlineTitle)
    }

    func testActivityMonthlyChartUsesProjectedAndDayAnchoredLines() {
        XCTAssertEqual(ActivityMonthlyBalanceChartLayoutPolicy.estimatedLineStyle, "fullMonthProjectedLine")
        XCTAssertEqual(ActivityMonthlyBalanceChartLayoutPolicy.actualLineStyle, "dayAnchoredNeonLine")
        XCTAssertTrue(ActivityMonthlyBalanceChartLayoutPolicy.todayMarkerFollowsActualLine)
    }

    func testCreditSummaryOpensInlineOverviewDetail() {
        XCTAssertEqual(CreditLayoutPolicy.summaryPresentation, .navigationPush)
        XCTAssertTrue(CreditLayoutPolicy.summaryDetailUsesInlineTitle)
        XCTAssertEqual(CreditLayoutPolicy.cardsPlacement, "belowSummaryAboveDueSoon")
        XCTAssertEqual(CreditLayoutPolicy.cardsPresentation, "lazyHStack")
        XCTAssertFalse(CreditLayoutPolicy.cardsUseCardsViewRow)
        XCTAssertTrue(CreditLayoutPolicy.cardsUseFloatingPreview)
        XCTAssertFalse(CreditLayoutPolicy.cardsShowOuterRowBox)
        XCTAssertTrue(CreditLayoutPolicy.removesPhysicalCardStrip)
        XCTAssertTrue(CreditLayoutPolicy.cardRowsUseHorizontalScroll)
        XCTAssertEqual(CreditLayoutPolicy.cardRowWidth, CreditCardVisualLayoutPolicy.rowCardMaxWidth, accuracy: 0.001)
        XCTAssertEqual(CreditLayoutPolicy.cardRowCornerRadius, AppTheme.Radius.md, accuracy: 0.001)
        XCTAssertLessThan(CreditLayoutPolicy.cardRowCornerRadius, AppTheme.Radius.lg)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.cardAspectRatio, 1.58, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.cardCornerRadius, 12, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.canonicalRenderer, "PremiumCardView")
        XCTAssertTrue(CreditCardVisualLayoutPolicy.usesSingleCardRenderer)
        XCTAssertTrue(CreditCardVisualLayoutPolicy.miniPreviewWrapsCanonicalRenderer)
        XCTAssertTrue(CreditCardVisualLayoutPolicy.designGridUsesCanonicalRenderer)
        XCTAssertTrue(CreditCardVisualLayoutPolicy.creditTabUsesStaticFloatingCards)
        XCTAssertFalse(CreditCardVisualLayoutPolicy.designSelectionShowsThumbnail)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.designBrowserLayout, "lazyVStackTwoColumnRows")
        XCTAssertFalse(CreditCardVisualLayoutPolicy.designBrowserShowsOuterTiles)
        XCTAssertFalse(CreditCardVisualLayoutPolicy.designBrowserShowsNames)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.previewCornerRadius(for: 50), CreditCardVisualLayoutPolicy.cardCornerRadius, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.previewCornerRadius(for: 240), CreditCardVisualLayoutPolicy.cardCornerRadius, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.rowCardMaxWidth, 260, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.rowPreviewWidth, CreditCardVisualLayoutPolicy.rowCardMaxWidth, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.rowPreviewHeight, CreditCardVisualLayoutPolicy.rowCardMaxWidth / CreditCardVisualLayoutPolicy.cardAspectRatio, accuracy: 0.001)
        XCTAssertGreaterThan(CreditCardVisualLayoutPolicy.rowPreviewWidth, 200)
        XCTAssertGreaterThan(CreditCardVisualLayoutPolicy.rowPreviewHeight, 120)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.designSelectionPreviewWidth, 112, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.previewArtworkDetail, .preview)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.fullArtworkDetail, .full)
        XCTAssertNotEqual(CreditCardVisualLayoutPolicy.previewArtworkDetail, CreditCardVisualLayoutPolicy.fullArtworkDetail)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.contentInset(for: 240), 18, accuracy: 0.001)
        XCTAssertEqual(CreditCardVisualLayoutPolicy.contentInset(for: 50), 5, accuracy: 0.001)
    }

    func testCardDesignBrowserUsesSelectableLazyOrderAndKeepsLegacyResolution() {
        XCTAssertEqual(CreditCardDesignCatalog.displayCategories.map(\.rawValue), ["Minimal", "Calm", "Metal", "Bold", "Premium", "Artwork", "Neon"])

        let hiddenNames = Set([
            "Royal Plum",
            "Neon Night",
            "Forest Matte",
            "Skyline Blue",
            "Deep Space",
            "Clean Navy",
            "Petrol Shift",
            "Emerald Circuit",
            "Blueprint",
            "Solar Flare"
        ])
        let selectableNames = Set(CreditCardDesignCatalog.selectableDesigns.map(\.name))

        XCTAssertTrue(hiddenNames.isDisjoint(with: selectableNames))
        XCTAssertTrue(CreditCardDesignCatalog.selectableStorageValues().allSatisfy { value in
            CreditCardDesignCatalog.selectableDesigns.contains {
                $0.storageHex.caseInsensitiveCompare(value) == .orderedSame
            }
        })
        XCTAssertEqual(CreditCardDesignCatalog.design(forStoredValue: "royal-plum").name, "Royal Plum")
        XCTAssertEqual(CreditCardDesignCatalog.design(forStoredValue: "#7C3AED").name, "Royal Plum")
    }

    func testPotsHistoryUsesEditToolbarWithoutTopDivider() {
        XCTAssertEqual(PotHistoryLayoutPolicy.toolbarActionId, "edit-toolbar-action")
        XCTAssertEqual(PotHistoryLayoutPolicy.editTitle, "Edit")
        XCTAssertEqual(PotHistoryLayoutPolicy.doneTitle, "Done")
        XCTAssertTrue(PotHistoryLayoutPolicy.usesNativeToolbarContentSwap)
        XCTAssertFalse(PotHistoryLayoutPolicy.showsPlaceholderOptions)
        XCTAssertFalse(PotHistoryLayoutPolicy.showsTopDividerAboveModePicker)
    }

    func testProfileHistoryScreenHasNoPlaceholderToolbar() {
        XCTAssertEqual(HistoryLayoutPolicy.toolbarMode, "none")
        XCTAssertFalse(HistoryLayoutPolicy.showsPlaceholderOptions)
    }

    func testActivityRecentRowsUseCleanDotMarkersAndReadableDates() {
        XCTAssertEqual(ActivityLayoutPolicy.recentActivityMarkerStyle, "coloredDot")
        XCTAssertEqual(ActivityLayoutPolicy.recentActivityDateFormat, "EEE, d MMM yyyy")
        XCTAssertEqual(ActivityLayoutPolicy.recentActivityDetailPresentation, .navigationPush)
        XCTAssertTrue(ActivityLayoutPolicy.recentActivityDetailUsesInlineTitle)
        XCTAssertFalse(ActivityLayoutPolicy.recentActivityShowsGeneratedPayPeriodSummaries)
        XCTAssertFalse(ActivityLayoutPolicy.recentActivityShowsGeneratedAutomaticPaychecks)
        XCTAssertFalse(ActivityLayoutPolicy.recentActivityShowsZeroValuePaychecks)
        XCTAssertEqual(ActivityLayoutPolicy.paycheckActivityDateSource, "payday")
        XCTAssertEqual(ActivityLayoutPolicy.monthBalanceChartMetric, "currentMonthIncomeMinusSpending")
        XCTAssertEqual(ActivityLayoutPolicy.monthBalanceDetailPresentation, .navigationPush)
        XCTAssertTrue(ActivityLayoutPolicy.monthBalanceDetailUsesInlineTitle)
        XCTAssertFalse(ActivityLayoutPolicy.showsDetailRecordId)
        XCTAssertEqual(ActivityLayoutPolicy.incomeDetailToolbarMode, "editDone")
        XCTAssertEqual(ActivityLayoutPolicy.spendingDetailToolbarMode, "editDone")
        XCTAssertTrue(ActivityLayoutPolicy.incomeDetailUsesNativeToolbarMorph)
        XCTAssertTrue(ActivityLayoutPolicy.spendingDetailUsesNativeToolbarMorph)

        let period = PayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            nextPayday: "2026-08-01",
            payFrequency: .monthly,
            incomePence: 340663,
            status: .active,
            createdAt: "2026-07-09T12:00:00.000Z",
            updatedAt: "2026-07-09T12:00:00.000Z",
            deletedAt: nil
        )
        let paycheck = Paycheck(
            id: "paycheck-july",
            payPeriodId: period.id,
            hoursWorked: 0,
            hourlyRatePence: 0,
            calculatedAmountPence: 340663,
            actualAmountPence: 340663,
            createdAt: "2026-07-09T12:00:00.000Z",
            updatedAt: "2026-07-09T12:00:00.000Z",
            deletedAt: nil
        )
        XCTAssertEqual(ActivityLayoutPolicy.paycheckActivityDate(paycheck: paycheck, payPeriod: period), "2026-07-01")
    }

    func testActivityInfinityButtonIsPlaceholderOnly() {
        XCTAssertEqual(ActivityTimelineLayoutPolicy.toolbarActionId, "activity-infinity-toolbar-action")
        XCTAssertEqual(ActivityTimelineLayoutPolicy.toolbarSymbol, "infinity")
        XCTAssertEqual(ActivityTimelineLayoutPolicy.presentation, "placeholder")
        XCTAssertTrue(ActivityTimelineLayoutPolicy.isPlaceholderOnly)
        XCTAssertFalse(ActivityTimelineLayoutPolicy.opensTimeline)
    }
}

final class DashboardSpendingChartTests: XCTestCase {
    func testHomeLayoutMovesSpendingSnapshotIntoMoneyLeftDetails() {
        XCTAssertEqual(
            DashboardHomeLayoutPolicy.homeSections,
            [
                .hero,
                .accounts,
                .monthlySpendChart,
                .upcomingBeforePayday,
                .alerts,
                .fundingChecklist
            ]
        )
        XCTAssertFalse(DashboardHomeLayoutPolicy.homeSections.contains(.paydayPlanning))
        XCTAssertFalse(DashboardHomeLayoutPolicy.homeSections.contains(.spendingSnapshot))
        XCTAssertFalse(DashboardHomeLayoutPolicy.homeSections.contains(.recentActivity))
        XCTAssertTrue(DashboardHomeLayoutPolicy.moneyLeftDetailSections.contains(.spendingSnapshot))
        XCTAssertEqual(DashboardHomeLayoutPolicy.moneyLeftDetailPresentation, .navigationPush)
    }

    func testMonthlySpendingChartUsesCurrentMonthSpendingThroughTodayOnly() {
        let transactions = [
            makeTransaction(id: "coffee", amountPence: 450, type: .spending, date: "2026-07-01"),
            makeTransaction(id: "groceries", amountPence: 2550, type: .spending, date: "2026-07-03"),
            makeTransaction(id: "future", amountPence: 9999, type: .spending, date: "2026-07-20"),
            makeTransaction(id: "last-month", amountPence: 8000, type: .spending, date: "2026-06-30"),
            makeTransaction(id: "allocation", amountPence: 1200, type: .allocation, date: "2026-07-03")
        ]

        let chartData = DashboardMonthlySpendChartData.make(transactions: transactions, todayIso: "2026-07-03")

        XCTAssertEqual(chartData.totalPence, 3000)
        XCTAssertEqual(chartData.daysElapsed, 3)
        XCTAssertEqual(chartData.daysInMonth, 31)
        XCTAssertEqual(chartData.points[0].amountPence, 450)
        XCTAssertEqual(chartData.points[1].amountPence, 0)
        XCTAssertEqual(chartData.points[2].amountPence, 2550)
        XCTAssertTrue(chartData.points[19].isFuture)
    }

    func testMonthlyOutgoingsChartIncludesBillsAndFuturePlannedOutgoings() {
        var snapshot = DefaultData.emptySnapshot
        snapshot.transactions = [
            makeTransaction(id: "coffee", amountPence: 450, type: .spending, date: "2026-07-03")
        ]
        snapshot.recurringPayments = [
            makeRecurringPayment(
                id: "icloud",
                name: "iCloud+",
                amountPence: 899,
                dueDay: 10,
                potId: nil
            )
        ]
        snapshot.payPeriods = [
            PayPeriod(
                id: "period-july",
                startDate: "2026-07-01",
                endDate: "2026-07-31",
                payday: "2026-07-01",
                nextPayday: "2026-08-01",
                payFrequency: .monthly,
                incomePence: 100000,
                status: .active,
                createdAt: "2026-07-01T00:00:00.000Z",
                updatedAt: "2026-07-01T00:00:00.000Z",
                deletedAt: nil
            )
        ]
        snapshot.potAllocations = [
            PotAllocation(
                id: "allocation-icloud",
                payPeriodId: "period-july",
                potId: "pot-bills",
                fundingPotId: nil,
                amountPence: 16240,
                source: .recurringBillFunding,
                recurringPaymentId: "icloud",
                recurringDueDate: "2026-07-10",
                debtId: nil,
                debtDueDate: nil,
                createdAt: "2026-07-01T00:00:00.000Z",
                updatedAt: "2026-07-01T00:00:00.000Z",
                deletedAt: nil
            )
        ]

        let manualData = DashboardMonthlySpendChartData.make(
            transactions: snapshot.transactions,
            todayIso: "2026-07-09"
        )
        let outgoingsData = DashboardMonthlySpendChartData.makeAllOutgoings(
            snapshot: snapshot,
            todayIso: "2026-07-09"
        )

        XCTAssertEqual(DashboardMonthlySpendChartMode.manualSpends.title, "Manual spends")
        XCTAssertEqual(DashboardMonthlySpendChartMode.manualSpends.next, .allOutgoings)
        XCTAssertEqual(manualData.totalPence, 450)
        XCTAssertEqual(outgoingsData.totalPence, 1349)
        XCTAssertEqual(outgoingsData.points[0].amountPence, 0)
        XCTAssertEqual(outgoingsData.points[2].amountPence, 450)
        XCTAssertEqual(outgoingsData.points[9].amountPence, 899)
        XCTAssertTrue(outgoingsData.points[9].isFuture)
    }

    private func makeTransaction(
        id: String,
        amountPence: Int,
        type: TransactionType,
        date: String
    ) -> Transaction {
        Transaction(
            id: id,
            potId: nil,
            payPeriodId: nil,
            amountPence: amountPence,
            type: type,
            paymentMethod: .pot,
            creditCardId: nil,
            recurringPaymentId: nil,
            date: date,
            note: id,
            createdAt: date,
            updatedAt: date,
            deletedAt: nil
        )
    }

    private func makeRecurringPayment(
        id: String,
        name: String,
        amountPence: Int,
        dueDay: Int?,
        potId: String?
    ) -> RecurringPayment {
        RecurringPayment(
            id: id,
            name: name,
            amountPence: amountPence,
            dueDay: dueDay,
            dueDate: nil,
            frequency: .monthly,
            potId: potId,
            creditCardId: nil,
            priority: .essential,
            active: true,
            createdAt: "2026-07-01T00:00:00.000Z",
            updatedAt: "2026-07-01T00:00:00.000Z",
            deletedAt: nil
        )
    }
}

final class PlanLayoutTests: XCTestCase {
    func testPlanUsesCompactSwipeCalendarAndMinimalCards() {
        XCTAssertEqual(PlanLayoutPolicy.sections, [.calendar, .upcomingBills, .recurringPayments])
        XCTAssertFalse(PlanLayoutPolicy.sections.contains(.incomeSchedule))
        XCTAssertFalse(PlanLayoutPolicy.calendarElements.contains(.monthHeaderCard))
        XCTAssertTrue(PlanLayoutPolicy.calendarElements.contains(.swipeMonthGrid))
        XCTAssertFalse(PlanLayoutPolicy.showsCalendarSectionTitle)
        XCTAssertEqual(PlanLayoutPolicy.monthSwipeTransition, .horizontalSlide)
        XCTAssertLessThanOrEqual(PlanLayoutPolicy.dayCellHeight, 44)
        XCTAssertEqual(PlanLayoutPolicy.emptySelectedDayMessage, "No money events are scheduled for this day.")
        XCTAssertEqual(PlanLayoutPolicy.emptyUpcomingBillsSubtitle, "Upcoming bills will appear here.")
        XCTAssertEqual(PlanLayoutPolicy.emptyRecurringPaymentsSubtitle, "Recurring payments will appear here.")
        XCTAssertEqual(PlanLayoutPolicy.subtitle, "")
        XCTAssertTrue(PlanLayoutPolicy.repeatedSelectedDayTapOpensDayDetail)
    }

    func testPlanDayDetailToolbarUsesNextDayWithoutPlaceholderOptions() {
        XCTAssertEqual(PlanLayoutPolicy.dayDetailInitialLeadingAction, "close")
        XCTAssertEqual(PlanLayoutPolicy.dayDetailAdvancedLeadingAction, "previousDay")
        XCTAssertEqual(PlanLayoutPolicy.dayDetailTrailingAction, "nextDay")
        XCTAssertEqual(PlanLayoutPolicy.dayDetailPreviousSymbol, "arrow.left")
        XCTAssertEqual(PlanLayoutPolicy.dayDetailNextSymbol, "arrow.right")
        XCTAssertTrue(PlanLayoutPolicy.dayDetailLeadingUsesLiquidGlassMorph)
        XCTAssertTrue(PlanLayoutPolicy.dayDetailTrailingUsesAccentColor)
        XCTAssertFalse(PlanLayoutPolicy.dayDetailUsesPlaceholderOptions)
        XCTAssertFalse(PlanLayoutPolicy.dayDetailShowsNavigationDivider)
        XCTAssertTrue(PlanLayoutPolicy.dayDetailIncludesMoneyFlowGraph)
    }
}

final class ActivityLayoutTests: XCTestCase {
    func testActivityLayoutShowsRecentActivityBeforeIncomeAndSpending() {
        XCTAssertEqual(ActivityLayoutPolicy.sections, [.recentActivity, .monthBalance, .income, .spending])
        XCTAssertEqual(ActivityLayoutPolicy.monthBalanceChartMetric, "currentMonthIncomeMinusSpending")
        XCTAssertEqual(ActivityLayoutPolicy.monthBalanceDetailPresentation, .navigationPush)
        XCTAssertTrue(ActivityLayoutPolicy.monthBalanceDetailUsesInlineTitle)
    }
}

final class AppThemePresetTests: XCTestCase {
    func testThemeRefreshPoliciesCoverCachedShellAndSharedSurfaces() {
        XCTAssertTrue(AppThemeRefreshPolicy.rebuildsTabContentOnThemeChange)
        XCTAssertTrue(AppThemeRefreshPolicy.sharedSurfacesObserveThemeStorage)
        XCTAssertTrue(AppThemeRefreshPolicy.screenBackgroundAvoidsGlobalAccentOverlay)
    }

    func testCurrentThemeIsFirstPreset() {
        XCTAssertEqual(AppThemePreset.allCases.first, .classic)
        XCTAssertEqual(AppThemePreset.classic.palette.accentHex, "#E85002")
        XCTAssertEqual(AppThemePreset.classic.palette.backgroundHex, "#000000")
        XCTAssertEqual(AppThemePreset.classic.palette.textHex, "#F9F9F9")
    }

    func testThemePresetIdsAreStableAndUnique() {
        XCTAssertEqual(
            AppThemePreset.allCases.map(\.rawValue),
            [
                "classic",
                "goldObsidian",
                "warmLight",
                "sagePaper",
                "navyEmerald",
                "darkBlueMintGold",
                "charcoalTeal",
                "slateCoral",
                "midnightEmerald"
            ]
        )
        XCTAssertEqual(Set(AppThemePreset.allCases.map(\.rawValue)).count, AppThemePreset.allCases.count)
    }

    func testListedThemePalettesMapToExpectedHexValues() {
        let expected: [(AppThemePreset, String, String, String)] = [
            (.goldObsidian, "#E6B450", "#0B0E14", "#BFBDB6"),
            (.warmLight, "#CC7D5E", "#F9F9F7", "#2D2D2B"),
            (.sagePaper, "#3D755D", "#F5F3ED", "#2F312D"),
            (.navyEmerald, "#1A237E", "#FFFFFF", "#263238"),
            (.darkBlueMintGold, "#0D47A1", "#F5F5F5", "#263238"),
            (.charcoalTeal, "#212121", "#FAFAFA", "#424242"),
            (.slateCoral, "#607D8B", "#FFFFFF", "#333333"),
            (.midnightEmerald, "#003366", "#E8E8E8", "#263238")
        ]

        for (preset, accent, background, text) in expected {
            XCTAssertEqual(preset.palette.accentHex, accent)
            XCTAssertEqual(preset.palette.backgroundHex, background)
            XCTAssertEqual(preset.palette.textHex, text)
        }
    }

    func testInvalidStoredThemeFallsBackToClassic() {
        XCTAssertEqual(AppThemePreset.resolved(from: "missing-theme"), .classic)
        XCTAssertEqual(AppThemePreset.resolved(from: nil), .classic)
    }

    func testAccentReadableTextAdaptsToBrightAccent() {
        XCTAssertEqual(AppThemePreset.classic.palette.accentReadableTextHex, "#FFFFFF")
        XCTAssertEqual(AppThemePreset.goldObsidian.palette.accentReadableTextHex, "#111111")
        XCTAssertEqual(AppThemePreset.navyEmerald.palette.accentReadableTextHex, "#FFFFFF")
    }

    func testCardEyebrowUsesReadablePresetTextOnLightThemes() {
        XCTAssertEqual(AppThemePreset.classic.palette.cardEyebrowHex, "#D9C3AB")
        XCTAssertEqual(AppThemePreset.warmLight.palette.cardEyebrowHex, "#69665F")
        XCTAssertEqual(AppThemePreset.sagePaper.palette.cardEyebrowHex, "#66695F")
        XCTAssertEqual(AppThemePreset.navyEmerald.palette.cardEyebrowHex, "#60717A")
    }

    func testSelectableColorHexesFollowSelectedTheme() {
        let defaults = UserDefaults.standard
        let previousTheme = defaults.string(forKey: AppTheme.selectedPresetStorageKey)
        defer {
            if let previousTheme {
                defaults.set(previousTheme, forKey: AppTheme.selectedPresetStorageKey)
            } else {
                defaults.removeObject(forKey: AppTheme.selectedPresetStorageKey)
            }
        }

        defaults.set(AppThemePreset.sagePaper.rawValue, forKey: AppTheme.selectedPresetStorageKey)
        XCTAssertEqual(Array(AppTheme.selectableColorHexes(includeWhite: true).prefix(3)), ["#3D755D", "#5C9479", "#2D5E49"])
        XCTAssertTrue(AppTheme.selectableColorHexes(includeWhite: true).contains("#FFFFFF"))

        defaults.set(AppThemePreset.classic.rawValue, forKey: AppTheme.selectedPresetStorageKey)
        XCTAssertEqual(AppTheme.selectableColorHexes().first, "#E85002")
    }
}
