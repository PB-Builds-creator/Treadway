import SwiftUI

/// Centralized spacing, typography, and radii. Restrained and consistent — the
/// design language deliberately avoids heavy cards, neon, and excessive rounding.
enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
    }
    enum Symbol {
        static let hitTarget: CGFloat = 44   // accessible minimum tap target
    }
}

extension Font {
    static let cairnTitle = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let cairnSection = Font.system(.subheadline, weight: .semibold)
    static let cairnRow = Font.system(.body)
}

/// A hairline separator that respects the platform's separator color.
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// A section header for grouped lists — quiet, uppercased, spaced.
struct GroupHeader: View {
    let title: String
    var trailing: String?
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.xs)
    }
}

/// A thin progress ring used for daily completion and hydration. Status is conveyed
/// by both the arc AND the numeric label (never color alone — accessibility).
struct ProgressRing: View {
    var fraction: Double
    var lineWidth: CGFloat = 8
    var label: String?
    var caption: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(fraction, 1)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: fraction)
            VStack(spacing: 2) {
                if let label {
                    Text(label).font(.title3).fontWeight(.semibold).monospacedDigit()
                }
                if let caption {
                    Text(caption).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption ?? "Progress")
        .accessibilityValue(label ?? "\(Int(fraction * 100)) percent")
    }
}

/// A thin linear progress bar (used inline in the hydration row and week view).
struct ThinProgressBar: View {
    var fraction: Double
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule().fill(Color.accentColor)
                    .frame(width: geo.size.width * max(0, min(fraction, 1)))
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Consistent empty-state presentation.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 320)
        .padding(DS.Spacing.xl)
    }
}
