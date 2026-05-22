import SwiftUI
import Charts

// MARK: - AnimatedNumber
public struct AnimatedNumber: View {
    let value: Int
    let font: SwiftUI.Font
    let color: Color
    @State private var displayValue: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Int, font: SwiftUI.Font = DT.Font.mono(22), color: Color = DT.Color.textPrimary) {
        self.value = value
        self.font = font
        self.color = color
    }

    public var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear { displayValue = value }
            .onChange(of: value) { newVal in
                if reduceMotion {
                    displayValue = newVal
                } else {
                    withAnimation(DT.Animation.spring) {
                        displayValue = newVal
                    }
                }
            }
    }
}

// MARK: - BentoStat
public struct BentoStat: View {
    let label: String
    let value: Int
    let formattedValue: String?
    let delta: String?
    let trend: [Double]
    let tint: Color

    public init(
        label: String,
        value: Int,
        formattedValue: String? = nil,
        delta: String? = nil,
        trend: [Double] = [],
        tint: Color = DT.Color.accent
    ) {
        self.label = label
        self.value = value
        self.formattedValue = formattedValue
        self.delta = delta
        self.trend = trend
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DT.Color.textTertiary)
                    .tracking(0.6)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let formatted = formattedValue {
                    Text(formatted)
                        .font(DT.Font.mono(22))
                        .foregroundColor(DT.Color.textPrimary)
                } else {
                    AnimatedNumber(value: value)
                }
                if let delta = delta {
                    Text(delta)
                        .font(DT.Font.mono(11))
                        .foregroundColor(tint)
                }
            }

            if !trend.isEmpty {
                Chart {
                    ForEach(Array(trend.enumerated()), id: \.offset) { i, val in
                        LineMark(
                            x: .value("i", i),
                            y: .value("v", val)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(tint)
                    }
                    ForEach(Array(trend.enumerated()), id: \.offset) { i, val in
                        AreaMark(
                            x: .value("i", i),
                            y: .value("v", val)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.3), tint.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot.background(.clear)
                }
                .frame(height: 28)
                .opacity(0.8)
            }
        }
        .padding(14)
        .liquidGlass(radius: DT.Radius.lg)
    }
}
