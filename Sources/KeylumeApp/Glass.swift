import SwiftUI

// Liquid Glass on macOS 26+, frosted material on macOS 14–15.
// Glass is used only for the functional layer (panels, toolbar controls);
// the keyboard and other content stay solid.

extension View {
    /// A floating control panel. Regular glass variant, since panels hold text.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 22) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.12)))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        }
    }

    /// A small interactive chip. A selected chip gets an accent-tinted label, not a coloured background.
    @ViewBuilder
    func glassChip(selected: Bool) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(selected ? .regular.tint(.accentColor.opacity(0.25)) : .regular, in: .capsule)
        } else {
            self.background(selected ? AnyShapeStyle(Color.accentColor.opacity(0.2)) : AnyShapeStyle(.thinMaterial),
                            in: Capsule())
        }
    }

    /// The one primary action per screen: tinted (prominent) glass.
    @ViewBuilder
    func primaryGlassButton() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func secondaryGlassButton() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

/// Groups glass chips so their shapes blend together on macOS 26+.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
