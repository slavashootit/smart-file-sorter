import SwiftUI

public struct SlidingSegment<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String, icon: Image)]
    @Namespace private var ns

    public init(selection: Binding<T>, options: [(value: T, label: String, icon: Image)]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    withAnimation(DT.Animation.spring) {
                        selection = option.value
                    }
                }) {
                    HStack(spacing: 6) {
                        option.icon
                            .font(.system(size: 12))
                        Text(option.label)
                            .font(DT.Font.body(12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if selection == option.value {
                                RoundedRectangle(cornerRadius: DT.Radius.md)
                                    .fill(DT.Color.glass)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DT.Radius.md)
                                            .strokeBorder(DT.Color.borderStrong, lineWidth: 0.5)
                                    )
                                    .matchedGeometryEffect(id: "seg_indicator", in: ns)
                            }
                        }
                    )
                    .foregroundColor(
                        selection == option.value
                            ? DT.Color.textPrimary
                            : DT.Color.textSecondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .liquidGlass(radius: DT.Radius.lg)
    }
}
