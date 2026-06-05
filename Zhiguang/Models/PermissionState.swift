import Foundation

enum PermissionState: String, Codable {
    case notDetermined
    case full
    case limited
    case denied
}
