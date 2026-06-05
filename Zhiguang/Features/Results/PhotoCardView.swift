// Zhiguang/Features/Results/PhotoCardView.swift
import SwiftUI

struct PhotoCardView: View {
    let assetId: String
    let thumbnail: CGImage?
    let isRejected: Bool
    let onRemove: () -> Void
    let onRestore: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            Group {
                if let img = thumbnail {
                    Image(img, scale: 1, label: Text(""))
                        .resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                        .overlay(ProgressView())
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isRejected ? 0.3 : 1)
            .grayscale(isRejected ? 1 : 0)

            // Action button
            if isRejected {
                Button(action: onRestore) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .padding(4)
            } else {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.4), in: Circle())
                }
                .padding(4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRejected)
    }
}
