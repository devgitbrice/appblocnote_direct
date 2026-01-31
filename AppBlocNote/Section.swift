import Foundation

struct Section: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var user_id: UUID
    var created_at: Date?
    var order_index: Int
    var icon: String  // SF Symbol name

    init(id: UUID = UUID(), name: String, user_id: UUID, order_index: Int = 0, icon: String = "folder.fill") {
        self.id = id
        self.name = name
        self.user_id = user_id
        self.created_at = Date()
        self.order_index = order_index
        self.icon = icon
    }

    // Section par défaut "HOME"
    static func defaultHome(userId: UUID) -> Section {
        Section(id: UUID(), name: "HOME", user_id: userId, order_index: 0, icon: "house.fill")
    }
}
