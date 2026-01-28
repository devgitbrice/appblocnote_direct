import SwiftUI
import Combine
import AVFoundation
import Supabase
import UIKit

// --- STRUCTURES DE DONNÉES ---

struct NoteInsertPayload: Encodable {
    let id: UUID
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
    
    @Published var selectedTagToOpen: String? = nil
    
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
    // GESTION DICTÉE (CORRIGÉE)
    // ==========================================
    
    func startRecording() {
        dictationService.startRecording()
    }
    
    func stopRecordingAndTranscribe(for noteId: UUID) {
        dictationService.stopAndTranscribe { [weak self] text in
            guard let self = self, let text = text, let index = self.blocks.firstIndex(where: { $0.id == noteId }) else { return }
            
            let oldContent = self.blocks[index].content
            var newContent = ""
            
            // CORRECTION IMPORTANTE : Insertion propre dans le HTML
            if let bodyEndRange = oldContent.range(of: "</body>", options: .backwards) {
                // Si c'est du HTML, on insère avant la fermeture du body
                let textToInsert = " " + text
                newContent = oldContent.replacingCharacters(in: bodyEndRange, with: textToInsert + "</body>")
            } else {
                // Sinon (texte brut), on ajoute à la fin
                let separateur = oldContent.isEmpty ? "" : " "
                newContent = oldContent + separateur + text
            }
            
            self.blocks[index].content = newContent
            
            if let id = self.blocks[index].id {
                self.sauvegarderContenu(id: id, content: newContent)
                
                // Rétablissement de la correction auto
                self.declencherCorrectionAuto(pour: id, contenuActuel: newContent)
            }
        }
    }
    
    // ==========================================
    // GESTION DES TAGS
    // ==========================================
    
    func fetchBlocksWithTag(tag: String) async -> [NoteBlock] {
        do {
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
        let formattedTag = tag.starts(with: "#") ? tag : "#\(tag)"
        self.selectedTagToOpen = formattedTag
    }
}
