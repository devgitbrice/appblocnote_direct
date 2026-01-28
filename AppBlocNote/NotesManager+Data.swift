import Foundation
import Supabase
import SwiftUI

extension NotesManager {
    
    // ==========================================
    // 1. GESTION DES CATÉGORIES
    // ==========================================
    
    func chargerCategories() async {
        do {
            let cats: [NoteCategory] = try await client
                .from("site_notes_categories")
                .select()
                .order("is_pinned", ascending: false)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            self.categories = cats
            
            if selectedCategory == nil, let premier = cats.first {
                self.selectedCategory = premier
            }
        } catch {
            print("❌ Erreur chargement catégories: \(error)")
        }
    }
    
    func ajouterCategorie(nom: String) async {
        guard let userId = client.auth.currentUser?.id else { return }
        let maxIndex = categories.map { $0.order_index }.max() ?? 0
        let newCat = NoteCategory(name: nom, user_id: userId, order_index: maxIndex + 1)
        
        do {
            try await client.from("site_notes_categories").insert(newCat).execute()
            await chargerCategories()
            self.selectedCategory = categories.last
        } catch {
            print("❌ Erreur ajout catégorie: \(error)")
        }
    }
    
    func renommerCategorie(id: UUID, nouveauNom: String) async {
        if let index = categories.firstIndex(where: { $0.id == id }) {
            categories[index].name = nouveauNom
            if selectedCategory?.id == id { selectedCategory?.name = nouveauNom }
        }
        do {
            try await client.from("site_notes_categories").update(["name": nouveauNom]).eq("id", value: id).execute()
        } catch { print("❌ Erreur renommage: \(error)") }
    }
    
    func deplacerCategorie(from source: IndexSet, to destination: Int) {
        var updatedCategories = categories
        updatedCategories.move(fromOffsets: source, toOffset: destination)
        self.categories = updatedCategories
        Task {
            for (index, category) in updatedCategories.enumerated() {
                try? await client.from("site_notes_categories").update(["order_index": index]).eq("id", value: category.id).execute()
            }
        }
    }
    
    func toggleCategoryPin(category: NoteCategory) async {
        let newState = !category.is_pinned
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            withAnimation {
                categories[index].is_pinned = newState
                categories.sort {
                    if $0.is_pinned != $1.is_pinned { return $0.is_pinned }
                    return $0.order_index < $1.order_index
                }
            }
        }
        try? await client.from("site_notes_categories").update(["is_pinned": newState]).eq("id", value: category.id).execute()
    }
    
    func toggleCategoryRed(category: NoteCategory) async {
        let newState = !category.is_red
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index].is_red = newState
        }
        try? await client.from("site_notes_categories").update(["is_red": newState]).eq("id", value: category.id).execute()
    }

    // ==========================================
    // 2. GESTION DES NOTES
    // ==========================================
    
    func chargerNotes(pour categoryId: UUID) {
        Task {
            do {
                let notes: [NoteBlock] = try await client
                    .from("site_notes_blocks")
                    .select()
                    .eq("category_id", value: categoryId)
                    .order("is_pinned", ascending: false)
                    .order("order_index", ascending: true)
                    .execute()
                    .value
                self.blocks = notes
            } catch { print("❌ Erreur notes: \(error)") }
        }
    }
    
    func chargerToutesLesNotesEpingles() {
        Task {
            do {
                let notes: [NoteBlock] = try await client
                    .from("site_notes_blocks")
                    .select()
                    .eq("is_pinned", value: true)
                    .order("updated_at", ascending: false)
                    .execute()
                    .value
                
                await MainActor.run {
                    self.blocks = notes
                    if let currentUser = client.auth.currentUser {
                        self.selectedCategory = NoteCategory(id: UUID(), name: "📌 Épinglés (Tous)", user_id: currentUser.id, order_index: -1)
                    }
                }
            } catch { print("❌ Erreur chargement épinglés: \(error)") }
        }
    }
    
    // --- 🚨 FONCTION DE TEST DIAGNOSTIC 🚨 ---
    func ajouterNote() {
        if selectedCategory?.name == "📌 Épinglés (Tous)" {
            print("⚠️ Impossible d'ajouter une note ici. Va dans un vrai dossier.")
            return
        }
        
        guard let catId = selectedCategory?.id else { return }
        
        let minIndex = blocks.map { $0.order_index }.min() ?? 0
        let newIndex = minIndex - 1
        let newId = UUID()
        let newNote = NoteBlock(id: newId, content: "", order_index: newIndex)
        
        // 1. AJOUT OPTIMISTE (UI)
        withAnimation { blocks.insert(newNote, at: 0) }
        
        Task {
            guard let userId = client.auth.currentUser?.id else {
                print("❌ ERREUR CRITIQUE : Pas d'utilisateur connecté !")
                return
            }
            
            let payload = NoteInsertPayload(
                id: newId,
                content: newNote.content,
                order_index: newIndex,
                category_id: catId,
                user_id: userId
            )
            
            do {
                // 2. TENTATIVE D'ENVOI SUPABASE (LOGS)
                print("📡 [TEST MAC] Tentative d'envoi de la note ID : \(newId)")
                try await client.from("site_notes_blocks").insert(payload).execute()
                print("✅ [TEST MAC] SUCCÈS : Note enregistrée dans Supabase !")
            } catch {
                // 3. CAS D'ERREUR
                print("❌❌❌ ERREUR FATALE SUR MAC ❌❌❌")
                print("L'erreur est : \(error)")
                print("Description : \(error.localizedDescription)")
                
                await MainActor.run {
                    if let idx = blocks.firstIndex(where: { $0.id == newId }) {
                        withAnimation { blocks.remove(at: idx) }
                    }
                }
            }
        }
    }
    
    func sauvegarderContenu(id: UUID, content: String) {
        Task {
            let payload = NoteUpdateContentPayload(content: content)
            try? await client.from("site_notes_blocks").update(payload).eq("id", value: id).execute()
        }
    }
    
    func supprimerNote(id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            withAnimation { blocks.remove(at: index) }
        }
        Task { try? await client.from("site_notes_blocks").delete().eq("id", value: id).execute() }
    }
    
    func togglePin(id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            let isGlobalPinnedView = selectedCategory?.name == "📌 Épinglés (Tous)"
            blocks[index].is_pinned.toggle()
            let newState = blocks[index].is_pinned
            
            if isGlobalPinnedView && !newState {
                withAnimation { blocks.remove(at: index) }
            } else {
                withAnimation { blocks.sort { ($0.is_pinned && !$1.is_pinned) || ($0.is_pinned == $1.is_pinned && $0.order_index < $1.order_index) } }
            }
            Task {
                let payload = NoteUpdatePinPayload(is_pinned: newState)
                try? await client.from("site_notes_blocks").update(payload).eq("id", value: id).execute()
            }
        }
    }
    
    func toggleFavorite(id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].is_favorite.toggle()
            let newState = blocks[index].is_favorite
            Task {
                let payload = NoteUpdateFavoritePayload(is_favorite: newState)
                try? await client.from("site_notes_blocks").update(payload).eq("id", value: id).execute()
            }
        }
    }
}
