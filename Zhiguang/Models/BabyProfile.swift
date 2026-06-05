import Foundation

struct BabyProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var nickname: String
    var birthday: Date?
    var gender: Gender?

    enum Gender: String, Codable, CaseIterable {
        case boy = "男宝"
        case girl = "女宝"
    }

    init(id: UUID = UUID(), nickname: String, birthday: Date? = nil, gender: Gender? = nil) {
        self.id = id
        self.nickname = nickname
        self.birthday = birthday
        self.gender = gender
    }
}
