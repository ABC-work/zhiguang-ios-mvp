// Zhiguang/Features/ManualUpload/ManualUploadViewModel.swift
import Foundation
import UIKit
import PhotosUI

@MainActor
final class ManualUploadViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var uploadedImages: [(id: UUID, image: CGImage)] = []
    @Published var isProcessing = false

    func processSelected() async {
        isProcessing = true
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let cgImage = uiImage.cgImage {
                let entry = (id: UUID(), image: cgImage)
                uploadedImages.append(entry)
            }
        }
        selectedItems = []
        isProcessing = false
    }
}
