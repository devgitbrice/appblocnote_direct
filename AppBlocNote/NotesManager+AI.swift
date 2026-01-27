import Foundation
import UIKit // Pour NSAttributedString
import AVFoundation

extension NotesManager {
    
    // ==========================================
    // 1. CORRECTION AUTOMATIQUE (GPT-4o-mini)
    // ==========================================
    
    func declencherCorrectionAuto(pour id: UUID, contenuActuel: String) {
        guard isAutoCorrectActive else { return }
        print("✨ Début de la correction manuelle...")
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // --- PROMPT STRICT ---
        let promptSystem = "Tu es un correcteur strict. Tu reçois du texte qui contient du HTML. TA TÂCHE : 1. Corrige l'orthographe et la grammaire. 2. NE TOUCHE PAS aux balises HTML (div, span, b, i). 3. RENVOIE UNIQUEMENT le texte corrigé. INTERDIT de dire 'Voici le texte' ou d'ajouter des commentaires."
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": promptSystem],
                ["role": "user", "content": contenuActuel]
            ],
            "temperature": 0.3
        ]
        
        do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch { return }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let contenuCorrige = message["content"] as? String {
                
                Task { @MainActor in
                    // On applique la correction seulement si ça a changé
                    if contenuActuel != contenuCorrige {
                        print("✅ Correction appliquée !")
                        if let index = self.blocks.firstIndex(where: { $0.id == id }) {
                            self.blocks[index].content = contenuCorrige
                            self.sauvegarderContenu(id: id, content: contenuCorrige)
                        }
                    }
                }
            }
        }.resume()
    }
    
    // ==========================================
    // 2. LECTURE AUDIO (OpenAI TTS)
    // ==========================================
    
    // Fonction interne pour nettoyer le HTML avant la lecture
    internal func cleanHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return html
    }

    func lireNote(id: UUID, content: String, onFinish: (() -> Void)? = nil) {
        if playingBlockId != nil && playingBlockId != id { audioPlayer.stop() }
        playingBlockId = id
        
        let textToRead = cleanHTML(content)
        
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["model": "tts-1", "input": textToRead, "voice": "alloy"]
        do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch { return }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                Task { @MainActor in
                    self.audioPlayer.play(data: data) {
                        if let onFinishAction = onFinish {
                            onFinishAction()
                        } else if self.isAutoPlayActive {
                            self.lireSuivant(apres: id)
                        } else {
                            self.playingBlockId = nil
                        }
                    }
                }
            } else {
                Task { @MainActor in self.stopAudio() }
            }
        }.resume()
    }
    
    func stopAudio() {
        audioPlayer.stop()
        playingBlockId = nil
        isAutoPlayActive = false
    }
    
    func toggleAutoPlay() {
        if isAutoPlayActive {
            stopAudio()
        } else {
            isAutoPlayActive = true
            if let premier = blocksAffiches.first, let id = premier.id {
                lireNote(id: id, content: premier.content)
            } else {
                isAutoPlayActive = false
            }
        }
    }
    
    internal func lireSuivant(apres idPrecedent: UUID) {
        let source = blocksAffiches
        if let index = source.firstIndex(where: { $0.id == idPrecedent }) {
            if index + 1 < source.count {
                let suivant = source[index + 1]
                if let id = suivant.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if self.isAutoPlayActive {
                            self.lireNote(id: id, content: suivant.content)
                        }
                    }
                    return
                }
            }
        }
        stopAudio()
    }
}
