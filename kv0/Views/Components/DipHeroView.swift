import SwiftUI

struct DipHeroView: View {
    let snapshot: DaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.heroText)
                .font(Typeface.hero)
                .kerning(-4)
                .foregroundStyle(Ink.sumi)
                .contentTransition(.numericText(value: snapshot.heroValue))
                .padding(.bottom, -14)
            Text(snapshot.heroLabel)
                .font(Typeface.body)
                .foregroundStyle(Ink.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }
}
