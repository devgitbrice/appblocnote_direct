import Foundation

struct NoteCategory: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var user_id: UUID
    var created_at: Date?
    var is_pinned: Bool
    var is_red: Bool
    // NOUVEAU : L'index pour le tri
    var order_index: Int
    
    init(id: UUID = UUID(), name: String, user_id: UUID, is_pinned: Bool = false, is_red: Bool = false, order_index: Int = 0) {
        self.id = id
        self.name = name
        self.user_id = user_id
        self.created_at = Date()
        self.is_pinned = is_pinned
        self.is_red = is_red
        self.order_index = order_index
    }
}
