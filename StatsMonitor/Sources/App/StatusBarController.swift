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
    static let panelSpacing: CGFloat = 4

    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let monitor: SystemMonitor
    private let detailPanel: NSPanel
    private let hostingController: NSHostingController<AnyView>
    private var currentPanel: PanelID?
    private var dismissMonitors: [Any] = []

    private var statusButton: NSStatusBarButton? {
        statusItem.button
    }

    init(settings: AppSettings, monitor: SystemMonitor) {
        self.settings = settings
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hostingController = NSHostingController(rootView: AnyView(EmptyView()))
        detailPanel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 280, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        Self.configureDetailPanel(detailPanel)
        detailPanel.contentViewController = hostingController
        detailPanel.contentView?.wantsLayer = true
        detailPanel.delegate = self
        setupButton()
        observeForLength()
    }

    deinit {
        MainActor.assumeIsolated {
            removeDismissMonitors()
        }
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

    static func configureDetailPanel(_ panel: NSPanel) {
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
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

    // MARK: - Panel presentation

    private func toggle(panel: PanelID, relativeTo button: NSView) {
        if detailPanel.isVisible, currentPanel == panel {
            closePanel()
            return
        }

        updatePanelContent(for: panel)
        sizePanelToFitContent()
        positionPanel(relativeTo: button)
        detailPanel.orderFrontRegardless()
        installDismissMonitors()
        NSApp.activate(ignoringOtherApps: true)
        currentPanel = panel
    }

    private func closePanel() {
        removeDismissMonitors()
        detailPanel.orderOut(nil)
        currentPanel = nil
    }

    private func updatePanelContent(for panel: PanelID) {
        hostingController.rootView = AnyView(
            DetailPopoverContentFactory.makeContent(
                for: panel,
                settings: settings,
                monitor: monitor
            )
        )
    }

    private func sizePanelToFitContent() {
        hostingController.view.layoutSubtreeIfNeeded()
        let fitting = hostingController.view.fittingSize
        detailPanel.setContentSize(fitting)
    }

    private func positionPanel(relativeTo button: NSView) {
        guard let buttonWindow = button.window else { return }
        let buttonRectOnScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelSize = detailPanel.frame.size
        var origin = CGPoint(
            x: buttonRectOnScreen.midX - panelSize.width / 2,
            y: buttonRectOnScreen.minY - panelSize.height - Self.panelSpacing
        )
        if let screenFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = max(screenFrame.minX + 4, min(origin.x, screenFrame.maxX - panelSize.width - 4))
            origin.y = max(screenFrame.minY + 4, origin.y)
        }
        detailPanel.setFrameOrigin(origin)
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
        let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.detailPanel {
                self.closePanel()
            }
            return event
        }
        if let globalMonitor { dismissMonitors.append(globalMonitor) }
        if let localMonitor { dismissMonitors.append(localMonitor) }
    }

    private func removeDismissMonitors() {
        for token in dismissMonitors {
            NSEvent.removeMonitor(token)
        }
        dismissMonitors.removeAll()
    }

    private var currentSegments: [MenuBarItem] {
        StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
    }
}

// MARK: - NSWindowDelegate

extension StatusBarController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === detailPanel else { return }
        closePanel()
    }
}
