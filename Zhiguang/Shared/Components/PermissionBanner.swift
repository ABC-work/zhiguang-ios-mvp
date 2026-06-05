import SwiftUI

struct PermissionBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
                .font(.caption)
            Text("当前仅获取部分相册，照片筛选结果可能不完整")
                .font(.caption)
                .foregroundColor(.yellow)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.15))
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: 2)
                .foregroundColor(.yellow)
        }
    }
}

#Preview {
    PermissionBanner()
        .preferredColorScheme(.dark)
}
