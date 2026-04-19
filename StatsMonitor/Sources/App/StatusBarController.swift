import AppKit
import SwiftUI

@MainActor
enum StatusBarButtonPresentation {
    struct State {
        let layout: StatusBarLayout
        let itemLength: CGFloat
    }

    static func state(monitor: SystemMonitor, settings: AppSettings) -> State {
        let segments = StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
        let layout = StatusBarLabelRenderer.layout(for: segments)
        return State(layout: layout, itemLength: layout.itemWidth)
    }

    static func apply(_ state: State, to button: NSStatusBarButton) {
        button.title = ""
        button.attributedTitle = NSAttributedString()
        button.image = nil
        button.isBordered = false
        let contentView = contentView(for: button)
        contentView.frame = button.bounds
        contentView.autoresizingMask = [.width, .height]
        contentView.layout = state.layout
    }

    static func makeStandaloneButton(monitor: SystemMonitor, settings: AppSettings) -> NSStatusBarButton {
        let state = state(monitor: monitor, settings: settings)
        let button = NSStatusBarButton(frame: CGRect(
            x: 0,
            y: 0,
            width: state.itemLength,
            height: MenuBarTextLayout.statusItemHeight
        ))
        apply(state, to: button)
        button.layoutSubtreeIfNeeded()
        return button
    }

    private static func contentView(for button: NSStatusBarButton) -> StatusBarLabelView {
        if let contentView = button.subviews.compactMap({ $0 as? StatusBarLabelView }).first {
            return contentView
        }

        let contentView = StatusBarLabelView(frame: button.bounds)
        button.addSubview(contentView)
        return contentView
    }
}

@MainActor
final class StatusBarController: NSObject {
    static let clickActionMask: NSEvent.EventTypeMask = [.leftMouseDown]

    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let monitor: SystemMonitor
    private let popover: NSPopover
    private let popoverContentController: NSHostingController<AnyView>
    private var currentPanel: PanelID?

    private var statusButton: NSStatusBarButton? {
        statusItem.button
    }

    init(settings: AppSettings, monitor: SystemMonitor) {
        self.settings = settings
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popoverContentController = NSHostingController(rootView: AnyView(EmptyView()))
        super.init()
        Self.configurePopoverBehavior(for: popover)
        popover.delegate = self
        popover.contentViewController = popoverContentController
        setupButton()
        observeForLength()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusButton else { return }
        refreshButtonPresentation(for: button)
        Self.configureClickBehavior(for: button)
        button.setAccessibilityLabel("StatsMonitor")
        button.target = self
        button.action = #selector(handleClick(_:))
    }
 
    static func configureClickBehavior(for button: NSStatusBarButton) {
        button.sendAction(on: clickActionMask)
    }

    static func configurePopoverBehavior(for popover: NSPopover) {
        popover.behavior = .transient
        popover.animates = false
    }

    // MARK: - Length

    private func refreshButtonPresentation(for button: NSStatusBarButton? = nil) {
        guard let button = button ?? statusButton else { return }
        let presentationState = StatusBarButtonPresentation.state(monitor: monitor, settings: settings)
        if presentationState.itemLength > 0 {
            statusItem.length = presentationState.itemLength
        }
        StatusBarButtonPresentation.apply(presentationState, to: button)
    }

    /// 觀察所有影響 label 寬度的值（指標數值 + show 設定），任一改變就重算 length
    private func observeForLength() {
        withObservationTracking {
            _ = currentSegments
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshButtonPresentation()
                self?.observeForLength()
            }
        }
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let point = Self.normalizeClickPoint(
            sender.convert(event.locationInWindow, from: nil),
            in: sender.bounds,
            isFlipped: sender.isFlipped
        )
        toggle(panel: panel(at: point, in: sender.bounds), relativeTo: sender)
    }

    static func normalizeClickPoint(_ point: CGPoint, in bounds: CGRect, isFlipped: Bool) -> CGPoint {
        guard isFlipped else { return point }

        return CGPoint(
            x: point.x,
            y: max(0, min(bounds.height, bounds.height - point.y))
        )
    }

    private func panel(at point: CGPoint, in bounds: CGRect) -> PanelID {
        StatusBarLabelRenderer.panel(at: point, in: currentSegments, bounds: bounds) ?? .cpu
    }

    // MARK: - Popover

    private func toggle(panel: PanelID, relativeTo button: NSView) {
        if popover.isShown, currentPanel == panel {
            popover.performClose(nil)
            return
        }

        updatePopoverContent(for: panel)
        if popover.isShown {
            popover.performClose(nil)
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        currentPanel = panel
    }

    private func updatePopoverContent(for panel: PanelID) {
        popoverContentController.rootView = AnyView(
            DetailPopoverContentFactory.makeContent(
                for: panel,
                settings: settings,
                monitor: monitor
            )
        )
    }

    private var currentSegments: [MenuBarItem] {
        StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
    }
}

// MARK: - NSPopoverDelegate

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        currentPanel = nil
    }
}
