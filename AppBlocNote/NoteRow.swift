import SwiftUI

struct NoteRow: View {
    // Liaison avec les données de la note
    @Binding var note: NoteBlock
    
    // Accès au manager pour les actions
    @ObservedObject var manager: NotesManager
    
    // État local pour l'animation du micro
    @State private var localMicActive = false
    
    // Savoir quel bloc est en train d'être lu
    @Binding var activeMicId: UUID?
    
    // La taille de la police
    var fontSize: Double
    
    // Hauteur dynamique du texte
    @State private var rowHeight: CGFloat = 80
    
    // Tâche pour l'auto-correction
    @State private var correctionTask: Task<Void, Never>? = nil

    // État pour l'animation du bouton copier
    @State private var isCopied = false

    // Formatteur de date
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 1. En-tête (Boutons)
            headerView
            
            // 2. Éditeur
            editorView
            
            Divider()
                .padding(.horizontal, 12)
                .opacity(0.5)
            
            // 3. Bas (Audio/Micro)
            bottomView
            
            // 4. Date
            if let date = note.created_at {
                HStack {
                    Spacer()
                    Text("Créé le \(dateFormatter.string(from: date))")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .padding(.bottom, 8)
            }
        }
        // Fond Rouge si épinglé
        .background(
            note.is_pinned ? Color.red.opacity(0.15) : Color(UIColor.tertiarySystemBackground)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(manager.playingBlockId == note.id ? Color.green : Color.clear, lineWidth: 2)
        )
    }
    
    // ==========================================
    // SOUS-VUES
    // ==========================================
    
    var headerView: some View {
        HStack {
            // Bouton Favori
            Button(action: { if let id = note.id { manager.toggleFavorite(id: id) } }) {
                Image(systemName: note.is_favorite ? "heart.fill" : "heart")
                    .foregroundColor(note.is_favorite ? .red : .gray)
                    .padding(8)
            }
            
            // Bouton Épingle
            Button(action: { if let id = note.id { manager.togglePin(id: id) } }) {
                Image(systemName: note.is_pinned ? "pin.fill" : "pin")
                    .foregroundColor(note.is_pinned ? .indigo : .gray)
                    .rotationEffect(.degrees(45))
                    .padding(8)
            }

            // Bouton Magique (Auto-Correct)
            Button(action: {
                if let id = note.id {
                    manager.declencherCorrectionAuto(pour: id, contenuActuel: note.content)
                }
            }) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(8)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Bouton Copier
            Button(action: {
                // 1. On récupère le contenu brut
                var texteBrut = note.content
                
                // 2. On essaie de convertir le HTML en texte simple
                if let data = note.content.data(using: .utf8) {
                    if let attributedString = try? NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                        documentAttributes: nil
                    ) {
                        texteBrut = attributedString.string
                    }
                }
                
                // 3. On copie le texte propre
                UIPasteboard.general.string = texteBrut
                
                withAnimation { isCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { isCopied = false }
                }
            }) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isCopied ? .green : .gray)
                    .padding(8)
                    .background(isCopied ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Bouton Full View
            if let id = note.id {
                NavigationLink(destination: FullNotePageView(manager: manager, selectedNoteId: id)) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            // Indicateur lecture
            if manager.playingBlockId == note.id {
                HStack(spacing: 4) {
                    Circle().frame(width: 6, height: 6).foregroundColor(.green)
                    Text("Lecture").font(.caption2).foregroundColor(.green)
                }
                .padding(.trailing, 8)
            }
            
            // Bouton Supprimer
            Button(action: { if let id = note.id { manager.supprimerNote(id: id) } }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.5))
                    .padding(8)
            }
        }
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    var editorView: some View {
        // 🔧 FIX: Utiliser GeometryReader pour capturer la largeur réelle
        GeometryReader { geometry in
            RichTextEditor(
                text: $note.content,
                dynamicHeight: $rowHeight,
                fontSize: fontSize,
                availableWidth: geometry.size.width,
                onTagClick: { tag in
                    manager.openTag(tag)
                }
            )
        }
        .frame(height: max(60, rowHeight))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: note.content) { newValue in
            if let id = note.id {
                manager.sauvegarderContenu(id: id, content: newValue)
                if manager.isAutoCorrectActive {
                    correctionTask?.cancel()
                    correctionTask = Task {
                        try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                        if !Task.isCancelled {
                            manager.declencherCorrectionAuto(pour: id, contenuActuel: newValue)
                        }
                    }
                }
            }
        }
    }
    
    var bottomView: some View {
        HStack {
            Button(action: {
                if let id = note.id {
                    if manager.playingBlockId == id { manager.stopAudio() }
                    else { manager.lireNote(id: id, content: note.content) }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: manager.playingBlockId == note.id ? "stop.fill" : "play.fill")
                    Text(manager.playingBlockId == note.id ? "Stop" : "Écouter")
                        .font(.caption).fontWeight(.bold)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(manager.playingBlockId == note.id ? Color.red.opacity(0.1) : Color.indigo.opacity(0.1))
                .foregroundColor(manager.playingBlockId == note.id ? .red : .indigo)
                .cornerRadius(20)
            }
            
            Spacer()
            
            ZStack {
                if localMicActive {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: localMicActive)
                }
                
                Image(systemName: localMicActive ? "mic.fill" : "mic")
                    .font(.title2)
                    .foregroundColor(localMicActive ? .white : .indigo)
                    .frame(width: 44, height: 44)
                    .background(localMicActive ? Color.red : Color.indigo.opacity(0.1))
                    .clipShape(Circle())
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !localMicActive {
                            localMicActive = true
                            manager.startRecording()
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        if let id = note.id { manager.stopRecordingAndTranscribe(for: id) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { localMicActive = false }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
            )
        }
        .padding(12)
    }
}
