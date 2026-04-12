import SwiftUI
import ModelRigKit

struct CheerDashboardSwiftUIView: View {
    enum Axis: String, CaseIterable, Identifiable {
        case x = "X Axis"
        case y = "Y Axis"
        case z = "Z Axis"

        var id: String { rawValue }
    }

    @State private var selectedPreset: BodyPreset = .averageNeutral
    @State private var selectedTransformMode: TransformMode = .position
    @State private var selectedAxis: Axis = .x
    @State private var jointAngle: Double = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CheerDashboardBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerPanel
                    topCards
                    jointControlsPanel
                }
                .padding(16)
            }

            Button("Focus") {}
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(CheerColors.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(Capsule().fill(CheerColors.white.opacity(0.20)))
                .padding(16)
        }
        .background(CheerColors.midnight)
    }

    private var headerPanel: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHEERCOM STUDIO")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(CheerColors.midnight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(CheerColors.accentAmber))

                        Text("Refine posture, balance, and saved routines.")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(CheerColors.textPrimary)

                        Text("Tune joints, transform the model, and keep diagnostics one tap away on every device.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(CheerColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    capsuleButton("Diagnostics", systemImage: "stethoscope", fill: CheerColors.white.opacity(0.12))
                        .frame(width: 214)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Body Preset")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(CheerColors.textSecondary)

                    segmentedRow(
                        BodyPreset.allCases,
                        selection: $selectedPreset,
                        activeFill: CheerColors.accentBlue.opacity(0.45)
                    )
                }
            }
        }
    }

    private var topCards: some View {
        GeometryReader { geometry in
            let horizontal = geometry.size.width > 760

            Group {
                if horizontal {
                    HStack(spacing: 16) {
                        balanceOverviewCard
                        transformCard
                    }
                } else {
                    VStack(spacing: 16) {
                        balanceOverviewCard
                        transformCard
                    }
                }
            }
        }
        .frame(height: 280)
    }

    private var balanceOverviewCard: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Balance Overview")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(CheerColors.textPrimary)

                        Text("Live center-of-mass tracking")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(CheerColors.textSecondary)
                    }

                    Spacer()

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(CheerColors.accentMint.opacity(0.16))
                            .frame(width: 318, height: 24)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x6FE8A5), Color(hex: 0x9AEBB6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 210, height: 18)
                            .overlay(alignment: .leading) {
                                Text("Live")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(CheerColors.midnight)
                                    .padding(.leading, 10)
                            }
                            .padding(3)
                    }
                }

                HStack(spacing: 10) {
                    metricTile(axis: "X AXIS", value: "0.00 cm")
                    metricTile(axis: "Y AXIS", value: "0.00 cm")
                    metricTile(axis: "Z AXIS", value: "0.00 cm")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Support Margin")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(CheerColors.textSecondary)

                    Text("18.4 cm")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(CheerColors.textPrimary)

                    Text("Stable posture")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(CheerColors.accentMint)

                    Text("Balance window looks healthy.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: 0xDCE5EF))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(CheerColors.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(CheerColors.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var transformCard: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transform")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(CheerColors.textPrimary)

                    Text("\(transformSummary)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(CheerColors.textSecondary)
                }

                segmentedRow(
                    [TransformMode.position, .rotation, .scale],
                    selection: $selectedTransformMode,
                    label: {
                        switch $0 {
                        case .position: "Move"
                        case .rotation: "Rotate"
                        case .scale: "Scale"
                        }
                    },
                    activeFill: CheerColors.accentBlue.opacity(0.45)
                )

                VStack(spacing: 10) {
                    HStack {
                        Spacer()
                        dpadButton("arrow.up")
                            .frame(width: 164)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        dpadButton("arrow.left")
                        Text("Step 5.0")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(CheerColors.textPrimary)
                            .frame(width: 132, height: 28)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x25364D)))
                        dpadButton("arrow.right")
                    }

                    HStack {
                        Spacer()
                        dpadButton("arrow.down")
                            .frame(width: 164)
                        Spacer()
                    }
                }
            }
        }
    }

    private var jointControlsPanel: some View {
        glassPanel {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    capsuleButton("Choose Joint", systemImage: "slider.horizontal.3", fill: CheerColors.accentBlue.opacity(0.85))
                        .frame(width: 206)

                    capsuleButton("Reset Joint", systemImage: "arrow.counterclockwise", fill: Color(hex: 0x29405E))
                        .frame(width: 136)

                    Text(selectedAxis.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(CheerColors.textSecondary)
                        .frame(width: 108, height: 38)
                        .background(Capsule().fill(CheerColors.white.opacity(0.08)))

                    Spacer()
                }

                segmentedRow(Axis.allCases, selection: $selectedAxis, activeFill: CheerColors.accentBlue.opacity(0.45))

                HStack {
                    Text("Joint Angle")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(CheerColors.textSecondary)

                    Spacer()

                    Text("\(jointAngle, specifier: "%.1f")°")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(CheerColors.textPrimary)
                        .frame(width: 78, height: 28)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(CheerColors.white.opacity(0.08)))
                }

                HStack(spacing: 10) {
                    stepButton("-") { jointAngle = max(-180, jointAngle - 1) }

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(CheerColors.white.opacity(0.10))
                            .frame(height: 10)

                        GeometryReader { geo in
                            let fraction = (jointAngle + 180) / 360
                            let usableWidth = max(geo.size.width - 24, 0)
                            let thumbX = usableWidth * fraction

                            Capsule()
                                .fill(CheerColors.accentBlue)
                                .frame(width: max(24, thumbX + 12), height: 10)

                            Circle()
                                .fill(CheerColors.textPrimary)
                                .frame(width: 24, height: 24)
                                .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
                                .offset(x: thumbX, y: -7)
                        }
                    }
                    .frame(height: 24)

                    stepButton("+") { jointAngle = min(180, jointAngle + 1) }
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        actionButton("Library", systemImage: "square.grid.2x2", fill: CheerColors.accentBlue.opacity(0.85), foreground: CheerColors.textPrimary)
                        actionButton("Reset Pose", systemImage: "arrow.counterclockwise", fill: Color(hex: 0xE4877C), foreground: Color(hex: 0xFFF7F6))
                    }

                    HStack(spacing: 10) {
                        actionButton("Fit View", systemImage: "viewfinder", fill: Color(hex: 0x233959), foreground: Color(hex: 0xEAF1F8))
                        actionButton("Visuals", systemImage: "sparkles", fill: Color(hex: 0x8FD1A3), foreground: CheerColors.midnight)
                    }
                }
                .frame(maxWidth: 260)
            }
        }
    }

    private func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(hex: 0x162234).opacity(0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(CheerColors.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 30, y: 18)
    }

    private func metricTile(axis: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(axis)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(CheerColors.textSecondary)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(CheerColors.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CheerColors.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(CheerColors.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func dpadButton(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(CheerColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(CheerColors.white.opacity(0.08)))
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(CheerColors.textPrimary)
                .frame(width: 50, height: 34)
                .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(CheerColors.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func capsuleButton(_ title: String, systemImage: String, fill: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(CheerColors.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(Capsule().fill(fill))
    }

    private func actionButton(_ title: String, systemImage: String, fill: Color, foreground: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, minHeight: 34)
        .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(fill))
    }

    private func segmentedRow<T: Hashable>(
        _ items: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String = { String(describing: $0) },
        activeFill: Color
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection.wrappedValue == item
                Button {
                    selection.wrappedValue = item
                } label: {
                    Text(label(item))
                        .font(.system(size: 15, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? CheerColors.textPrimary : CheerColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? activeFill : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: 0x64748B).opacity(0.28))
        )
    }

    private var transformSummary: String {
        switch selectedTransformMode {
        case .position:
            return "Position • 5.0"
        case .rotation:
            return "Rotation • 5.0"
        case .scale:
            return "Scale • 5.0"
        }
    }
}

private struct CheerDashboardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CheerColors.midnight, CheerColors.nightfall, CheerColors.storm],
                startPoint: UnitPoint(x: 0.15, y: 0.0),
                endPoint: UnitPoint(x: 0.85, y: 1.0)
            )

            Circle()
                .fill(CheerColors.accentBlue.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 240, y: -320)

            Circle()
                .fill(CheerColors.accentTeal.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 36)
                .offset(x: -260, y: -120)

            Circle()
                .fill(CheerColors.accentRose.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 48)
                .offset(x: -100, y: 360)
        }
        .ignoresSafeArea()
    }
}

private enum CheerColors {
    static let midnight = Color(hex: 0x07111F)
    static let nightfall = Color(hex: 0x10233D)
    static let storm = Color(hex: 0x17314A)
    static let accentBlue = Color(hex: 0x56C2FF)
    static let accentTeal = Color(hex: 0x4FE0C2)
    static let accentAmber = Color(hex: 0xFFC85C)
    static let accentRose = Color(hex: 0xFF7E79)
    static let accentMint = Color(hex: 0x7EF3AF)
    static let textPrimary = Color(hex: 0xF6FAFF)
    static let textSecondary = Color(hex: 0xA9BCD0)
    static let white = Color.white
}

private extension Color {
    init(hex: Int) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct CheerDashboardSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        CheerDashboardSwiftUIView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
