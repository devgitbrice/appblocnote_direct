import SwiftUI
import Combine
import AVFoundation
import Supabase
import UIKit

// --- STRUCTURES DE DONNÉES ---

struct NoteInsertPayload: Encodable {
    let id: UUID        // ✅ Correction ID présente
    let content: String
    let order_index: Int
    let category_id: UUID
    let user_id: UUID
}

struct NoteUpdateContentPayload: Encodable {
    let content: String
}

struct NoteUpdateFavoritePayload: Encodable {
    let is_favorite: Bool
}

struct NoteUpdatePinPayload: Encodable {
    let is_pinned: Bool
}

// --- CLASSE PRINCIPALE ---
@MainActor
class NotesManager: ObservableObject {
    
    // --- DONNÉES ---
    @Published var categories: [NoteCategory] = []
    @Published var blocks: [NoteBlock] = []
    
    @Published var selectedCategory: NoteCategory? {
        didSet {
            if let cat = selectedCategory {
                chargerNotes(pour: cat.id)
            } else {
                blocks = []
            }
        }
    }
    
    // --- SERVICES ---
    @Published var dictationService = DictationService()
    var audioPlayer = AudioPlayer()
    var cancellables = Set<AnyCancellable>()
    
    let client = SupabaseSingleton.shared.client
    
    // --- ÉTATS UI ---
    @Published var playingBlockId: UUID? = nil
    @Published var isAutoPlayActive = false
    @Published var afficherFavorisSeulement = false
    @Published var isAutoCorrectActive = true
    
    // --- NOUVEAU : NAVIGATION TAGS ---
    @Published var selectedTagToOpen: String? = nil // Déclenche l'ouverture de la page Tag
    
    var isRecording: Bool { dictationService.isRecording }
    var isTranscribing: Bool { dictationService.isTranscribing }
    
    var blocksAffiches: [NoteBlock] {
        if afficherFavorisSeulement { return blocks.filter { $0.is_favorite } }
        return blocks
    }
    
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        dictationService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
    
    // ==========================================
    // GESTION DICTÉE
    // ==========================================
    
    func startRecording() {
        dictationService.startRecording()
    }
    
    func stopRecordingAndTranscribe(for noteId: UUID) {
        dictationService.stopAndTranscribe { [weak self] text in
            guard let self = self, let text = text, let index = self.blocks.firstIndex(where: { $0.id == noteId }) else { return }
            
            let oldContent = self.blocks[index].content
            let separateur = oldContent.isEmpty ? "" : " "
            let newContent = oldContent + separateur + text
            
            self.blocks[index].content = newContent
            
            if let id = self.blocks[index].id {
                self.sauvegarderContenu(id: id, content: newContent)
                
                // Rétablissement de la correction auto
                self.declencherCorrectionAuto(pour: id, contenuActuel: newContent)
            }
        }
    }
    
    // ==========================================
    // GESTION DES TAGS (RECHERCHE)
    // ==========================================
    
    func fetchBlocksWithTag(tag: String) async -> [NoteBlock] {
        do {
            // Recherche insensible à la casse (%tag%) dans Supabase
            // Cela trouvera "content" qui contient le mot clé
            let results: [NoteBlock] = try await client
                .from("site_notes_blocks")
                .select()
                .ilike("content", value: "%\(tag)%")
                .order("created_at", ascending: false)
                .execute()
                .value
            return results
        } catch {
            print("❌ Erreur recherche tag: \(error)")
            return []
        }
    }
    
    func openTag(_ tag: String) {
        // On s'assure qu'il y a le # pour l'affichage du titre
        let formattedTag = tag.starts(with: "#") ? tag : "#\(tag)"
        self.selectedTagToOpen = formattedTag
    }
}
