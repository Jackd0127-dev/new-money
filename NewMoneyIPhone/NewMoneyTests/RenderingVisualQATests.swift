import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

/// Real screen captures for reviewing the rendering changes. All planner data
/// belongs to an in-memory fixture; this never mounts authentication or sync UI.
final class RenderingVisualQATests: XCTestCase {
    @MainActor
    func testRevisedScreensAtNarrowPhoneWidth() async throws {
        try await captureScreens(width: 320, dynamicTypeSize: .large, variant: "narrow")
    }

    @MainActor
    func testRevisedScreensAtAccessibilityTextSize() async throws {
        try await captureScreens(width: 390, dynamicTypeSize: .accessibility3, variant: "accessibility3")
    }

    @MainActor
    func testRevisedScreensInLightTheme() async throws {
        try await captureScreens(width: 390, dynamicTypeSize: .large, variant: "light", theme: .warmLight)
    }

    private enum Screen: String, CaseIterable {
        case plan
        case calendar
        case history
        case assistant

        var title: String { rawValue.capitalized }

        var fieldPlaceholder: String? {
            switch self {
            case .history: "Search payments, statements, bills..."
            case .assistant: "Ask Assistant"
            case .plan, .calendar: nil
            }
        }
    }

    @MainActor
    private func captureScreens(width: CGFloat, dynamicTypeSize: DynamicTypeSize, variant: String, theme: AppThemePreset = .classic) async throws {
        let themeKey = AppTheme.selectedPresetStorageKey
        let previousTheme = UserDefaults.standard.object(forKey: themeKey)
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
        defer {
            if let previousTheme { UserDefaults.standard.set(previousTheme, forKey: themeKey) }
            else { UserDefaults.standard.removeObject(forKey: themeKey) }
        }
        let basicStore = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))
        let emptyStore = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.emptySnapshot))
        await basicStore.load()
        await emptyStore.load()
        XCTAssertNil(basicStore.errorMessage)
        XCTAssertNil(emptyStore.errorMessage)

        for screen in Screen.allCases {
            let store = screen == .assistant ? emptyStore : basicStore
            let snapshotBeforeRendering = store.snapshot
            try await capture(
                screen: screen,
                store: store,
                width: width,
                dynamicTypeSize: dynamicTypeSize,
                name: "rendering-\(screen.rawValue)-\(variant)"
            )
            XCTAssertEqual(store.snapshot, snapshotBeforeRendering, "Rendering \(screen.title) must not change financial data")
        }
    }

    @MainActor
    @ViewBuilder
    private func screenView(_ screen: Screen, store: PlannerStore) -> some View {
        switch screen {
        case .plan:
            NavigationStack {
                PlanView(store: store, navigationMode: .inline, toolbarMode: .none)
            }
        case .calendar:
            NavigationStack {
                CalendarPlannerView(store: store, navigationMode: .inline, toolbarMode: .none)
            }
        case .history:
            NavigationStack {
                HistoryView(store: store)
            }
        case .assistant:
            AssistantView(store: store)
        }
    }

    @MainActor
    private func capture(
        screen: Screen,
        store: PlannerStore,
        width: CGFloat,
        dynamicTypeSize: DynamicTypeSize,
        name: String
    ) async throws {
        let frame = CGRect(x: 0, y: 0, width: width, height: 844)
        let previousKeyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        let host = UIHostingController(
            rootView: screenView(screen, store: store)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .environment(\.locale, Locale(identifier: "en_GB"))
                .preferredColorScheme(AppTheme.selectedColorScheme)
        )
        let window = UIWindow(frame: frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = frame
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }

        // Let navigation and the assistant's bounded scroll task finish before
        // checking the hierarchy or capturing its final on-screen state.
        try await Task.sleep(for: .milliseconds(450))
        host.view.layoutIfNeeded()

        let descendants = descendants(of: host.view)
        let navigationTitles = descendants.compactMap { ($0 as? UINavigationBar)?.topItem?.title }
        XCTAssertTrue(navigationTitles.contains(screen.title), "\(name) did not mount its expected navigation destination: \(navigationTitles)")

        let pageScrollViews = descendants.compactMap { $0 as? UIScrollView }
            .filter { !$0.isHidden && $0.bounds.width >= width * 0.75 && $0.contentSize.height > 0 }
        XCTAssertFalse(pageScrollViews.isEmpty, "\(name) did not render its scrollable screen content")
        for scrollView in pageScrollViews {
            XCTAssertLessThanOrEqual(
                scrollView.contentSize.width,
                scrollView.bounds.width + 1,
                "\(name) has unintended horizontal content overflow at \(dynamicTypeSize)"
            )
        }

        if let placeholder = screen.fieldPlaceholder {
            let field = descendants.compactMap { $0 as? UITextField }.first { $0.placeholder == placeholder }
            XCTAssertNotNil(field, "\(name) is missing its search/composer field")
            if let field {
                let fieldFrame = field.convert(field.bounds, to: host.view)
                XCTAssertGreaterThan(fieldFrame.width, 0)
                XCTAssertGreaterThanOrEqual(fieldFrame.minX, -1, "\(name) clips the field's leading edge")
                XCTAssertLessThanOrEqual(fieldFrame.maxX, width + 1, "\(name) clips the field's trailing edge")
                XCTAssertTrue(frame.intersects(fieldFrame), "\(name) leaves its search/composer field off-screen")
            }
        }

        var rendered = false
        let image = UIGraphicsImageRenderer(size: frame.size).image { _ in
            rendered = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(rendered, "\(name) could not capture the mounted screen")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func descendants(of view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }
}
