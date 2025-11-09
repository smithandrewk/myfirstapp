//
//  DesignSystem.swift
//  myfirstapp
//
//  Modern design system with reusable styles and components
//

import SwiftUI

// MARK: - Design Tokens

extension Color {
    // Custom color palette
    static let dsAccent = Color.blue
    static let dsSuccess = Color.green
    static let dsWarning = Color.orange
    static let dsError = Color.red

    // Semantic colors
    static let dsPrimary = Color.primary
    static let dsSecondary = Color.secondary
    static let dsTertiary = Color(.systemGray3)

    // Background colors
    static let dsBackground = Color(.systemBackground)
    static let dsBackgroundSecondary = Color(.secondarySystemBackground)
    static let dsBackgroundTertiary = Color(.tertiarySystemBackground)

    // Card colors
    static let dsCardBackground = Color(.systemBackground)
    static let dsCardBorder = Color(.separator).opacity(0.3)
}

extension Font {
    // Typography scale
    static let dsTitle = Font.title2.weight(.bold)
    static let dsHeadline = Font.headline.weight(.semibold)
    static let dsBody = Font.body
    static let dsCallout = Font.callout.weight(.medium)
    static let dsCaption = Font.caption.weight(.medium)
    static let dsSmall = Font.system(size: 11).weight(.medium)
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 999
}

// MARK: - Shadows

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let subtle = ShadowStyle(
        color: .black.opacity(0.05),
        radius: 4,
        x: 0,
        y: 2
    )

    static let medium = ShadowStyle(
        color: .black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 4
    )

    static let strong = ShadowStyle(
        color: .black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 8
    )

    static let glow = ShadowStyle(
        color: .blue.opacity(0.3),
        radius: 12,
        x: 0,
        y: 0
    )
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Modifiers

struct CardModifier: ViewModifier {
    var padding: CGFloat = Spacing.md
    var shadow: ShadowStyle = .medium

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.dsCardBackground)
            .cornerRadius(CornerRadius.lg)
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.lg

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PressableModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(padding: CGFloat = Spacing.md, shadow: ShadowStyle = .medium) -> some View {
        modifier(CardModifier(padding: padding, shadow: shadow))
    }

    func glassStyle(cornerRadius: CGFloat = CornerRadius.lg) -> some View {
        modifier(GlassModifier(cornerRadius: cornerRadius))
    }

    func pressableScale() -> some View {
        modifier(PressableModifier())
    }
}

// MARK: - Reusable Components

struct ModernCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.md
    var shadow: ShadowStyle = .medium

    init(padding: CGFloat = Spacing.md, shadow: ShadowStyle = .medium, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.shadow = shadow
        self.content = content()
    }

    var body: some View {
        content
            .cardStyle(padding: padding, shadow: shadow)
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.md
    var cornerRadius: CGFloat = CornerRadius.lg

    init(padding: CGFloat = Spacing.md, cornerRadius: CGFloat = CornerRadius.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassStyle(cornerRadius: cornerRadius)
    }
}

struct StatusBadge: View {
    let text: String
    let icon: String
    let color: Color
    var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if isAnimating {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: icon)
                    .font(.caption)
            }

            Text(text)
                .font(.dsCallout)
        }
        .foregroundColor(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = .dsSecondary

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [iconColor.opacity(0.8), iconColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.dsHeadline)
                    .foregroundColor(.dsPrimary)

                Text(subtitle)
                    .font(.dsCaption)
                    .foregroundColor(.dsSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
    }
}

struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var colors: [Color] = [.blue, .purple]

    init(_ title: String, icon: String? = nil, colors: [Color] = [.blue, .purple], action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.colors = colors
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.dsCallout)
            }
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(CornerRadius.md)
            .shadow(
                color: colors.first?.opacity(0.3) ?? .clear,
                radius: 8,
                y: 4
            )
        }
        .pressableScale()
    }
}

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var color: Color = .dsAccent

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: color.opacity(0.4), radius: 12, y: 6)
        }
        .pressableScale()
    }
}

struct ModernDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.dsCardBorder)
            .frame(height: 1)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            // Cards
            ModernCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Modern Card")
                        .font(.dsHeadline)
                    Text("This is a modern card with subtle shadows")
                        .font(.dsBody)
                        .foregroundColor(.dsSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Glass Card")
                        .font(.dsHeadline)
                    Text("Frosted glass effect with blur")
                        .font(.dsBody)
                        .foregroundColor(.dsSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Status Badges
            HStack(spacing: Spacing.sm) {
                StatusBadge(text: "Active", icon: "checkmark.circle.fill", color: .dsSuccess)
                StatusBadge(text: "Loading", icon: "arrow.clockwise", color: .dsAccent, isAnimating: true)
                StatusBadge(text: "Warning", icon: "exclamationmark.triangle.fill", color: .dsWarning)
            }

            // Empty State
            EmptyStateView(
                icon: "tray",
                title: "No Data Yet",
                subtitle: "Start collecting to see your data here",
                iconColor: .blue
            )

            // Buttons
            VStack(spacing: Spacing.sm) {
                GradientButton("Get Started", icon: "arrow.right") {}
                GradientButton("Warning Action", colors: [.orange, .red]) {}
            }

            // FAB
            HStack {
                Spacer()
                FloatingActionButton(icon: "plus", action: {})
            }
        }
        .padding()
    }
    .background(Color.dsBackgroundSecondary)
}
