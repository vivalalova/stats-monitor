import SwiftUI

enum MainWindowMetricGridLayout {
    static let spacing: CGFloat = 8
    private static let horizontalPadding: CGFloat = 16
    private static let minimumCardWidthFloor: CGFloat = 120

    static func columns(for dashboardColumns: Int) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimumCardWidth(for: dashboardColumns)), spacing: spacing)]
    }

    static func minimumCardWidth(for dashboardColumns: Int) -> CGFloat {
        let clampedColumns = max(
            DashboardGridSizing.columnRange.lowerBound,
            min(dashboardColumns, DashboardGridSizing.columnRange.upperBound)
        )
        let detailWidth = SettingsWindowLayout.defaultWidth - SettingsWindowLayout.sidebarWidth - horizontalPadding
        let totalSpacing = spacing * CGFloat(clampedColumns - 1)
        let cardWidth = floor((detailWidth - totalSpacing) / CGFloat(clampedColumns))
        return max(cardWidth, minimumCardWidthFloor)
    }
}
