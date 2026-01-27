import Foundation

struct NoteBlock: Identifiable, Codable {
    // L'identifiant unique (UUID)
    var id: UUID?
    
    // Le contenu HTML de la note
    var content: String
    
    // Les options de tri et d'affichage
    var is_favorite: Bool
    var is_pinned: Bool
    var order_index: Int
    
    // AJOUT : La date de création (optionnelle car gérée par la base)
    var created_at: Date?
    
    // Initialiseur mis à jour
    init(id: UUID? = nil, content: String, is_favorite: Bool = false, is_pinned: Bool = false, order_index: Int = 0, created_at: Date? = Date()) {
        self.id = id
        self.content = content
        self.is_favorite = is_favorite
        self.is_pinned = is_pinned
        self.order_index = order_index
        self.created_at = created_at
    }
}
