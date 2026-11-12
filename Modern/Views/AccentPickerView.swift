import SwiftUI

struct AccentPickerView: View {
    @Binding var selection: JoyConAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Joy-Con-Akzent").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(JoyConAccent.allCases) { accent in
                    Button { selection = accent } label: {
                        VStack(spacing: 5) {
                            Circle().fill(accent.color).frame(width: 27, height: 27)
                                .overlay {
                                    if selection == accent {
                                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(accent.onColor)
                                    }
                                }
                            Text(accent.name).font(.system(size: 10)).foregroundStyle(.primary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(.primary.opacity(selection == accent ? 0.07 : 0),
                                    in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(accent.name)
                        .accessibilityAddTraits(selection == accent ? .isSelected : [])
                }
            }
        }.padding(14).frame(width: 240)
    }
}
