import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
                Text(title).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [Color(hex: "6C63FF"), Color(hex: "A78BFA")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        assert(hex.count == 6, "Color(hex:) expects a 6-character hex string, got: \(hex)")
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
