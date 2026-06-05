import SwiftUI

struct PhotoCardView: View {
    let assetId: String
    let thumbnail: CGImage?
    let isRejected: Bool
    let onRemove: () -> Void
    let onRestore: () -> Void
    var body: some View { Text("PhotoCardView placeholder") }
}
