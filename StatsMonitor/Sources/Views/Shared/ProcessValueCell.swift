import SwiftUI

/// 行程表的欄寬。Top Processes 與 Top Energy Impact 兩表共用同一份 ——
/// 各自寫字面值會漂移（曾出現 Memory 欄一邊 72、一邊 80）。
enum ProcessColumnWidth {
    static let cpu: CGFloat = 60
    static let gpu: CGFloat = 60
    static let memory: CGFloat = 72
    static let disk: CGFloat = 72
    static let network: CGFloat = 80
    static let impact: CGFloat = 74
}

/// 行程列的數值欄：右對齊數字；`barFraction > 0` 時墊一條與該欄最大值成比例的淡色底條。
/// 無資料（formatter 回破折號）以 tertiary 淡化，跟真的是 0 的列一眼分得開。
struct ProcessValueCell: View {
    let text: String
    let width: CGFloat
    let hasValue: Bool
    /// 0 ＝不畫比例條（沒有欄位最大值可比的欄位就留預設）。
    var barFraction: Double = 0

    /// 比例條顏色淡到不搶數字。
    private static let barOpacity: Double = 0.18

    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(hasValue ? AnyShapeStyle(HierarchicalShapeStyle.primary)
                                      : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
            .frame(width: width, alignment: .trailing)
            .background(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.accentColor.opacity(Self.barOpacity))
                    .frame(width: width * barFraction)
            }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .trailing, spacing: 8) {
        ProcessValueCell(text: "48.2%", width: ProcessColumnWidth.cpu, hasValue: true, barFraction: 1)
        ProcessValueCell(text: "16.2%", width: ProcessColumnWidth.cpu, hasValue: true, barFraction: 0.34)
        ProcessValueCell(text: "—", width: ProcessColumnWidth.cpu, hasValue: false)
    }
    .font(.system(size: 12))
    .monospacedDigit()
    .padding()
}
