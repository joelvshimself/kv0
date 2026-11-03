import SwiftUI

/// Round Liquid Glass button for the top corner. Falls back to Nova's frosted pill
/// treatment on systems without Liquid Glass.
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Nova.bone)
                .frame(width: 44, height: 44)
                .modifier(GlassCircle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct GlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(Circle().fill(.ultraThinMaterial.opacity(0.5)))
                .background(Circle().fill(Nova.surface.opacity(0.85)))
                .overlay(Circle().strokeBorder(Nova.hairline, lineWidth: 1))
        }
    }
}
