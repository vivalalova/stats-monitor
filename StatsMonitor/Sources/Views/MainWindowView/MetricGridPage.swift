import SwiftUI

struct MetricGridPage<Cards: View, Footer: View>: View {
    let columns: [GridItem]
    let gridSpacing: CGFloat
    let sectionSpacing: CGFloat
    private let cards: Cards
    private let footer: Footer

    init(
        columns: [GridItem],
        gridSpacing: CGFloat,
        sectionSpacing: CGFloat = 8,
        @ViewBuilder cards: () -> Cards,
        @ViewBuilder footer: () -> Footer
    ) {
        self.columns = columns
        self.gridSpacing = gridSpacing
        self.sectionSpacing = sectionSpacing
        self.cards = cards()
        self.footer = footer()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    cards
                }

                footer
            }
            .padding(sectionSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
