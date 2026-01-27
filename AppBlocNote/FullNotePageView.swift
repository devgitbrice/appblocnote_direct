import SwiftUI

struct FullNotePageView: View {
    @ObservedObject var manager: NotesManager
    @State var selectedNoteId: UUID
    
    // États lecture
    @State private var audioSwipeEnabled = false
    @State private var autoAudioSwipeEnabled = false
    @State private var dynamicHeight: CGFloat = 100
    
    // Auto-correction
    @State private var isAutoCorrectActive = false
    @State private var correctionTask: Task<Void, Never>? = nil
    
    // État Copie
    @State private var isCopied = false
    
    // Taille persistante
    @AppStorage("fullScreenFontSize") private var fontSize: Double = 18

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            
            TabView(selection: $selectedNoteId) {
                ForEach($manager.blocks) { $block in
                    if let id = block.id {
                        VStack(alignment: .leading) {
                            ScrollView {
                                RichTextEditor(
                                    text: $block.content,
                                    dynamicHeight: $dynamicHeight,
                                    fontSize: fontSize
                                )
                                .frame(minHeight: 300)
                                .padding()
                                .onChange(of: block.content) { newValue in
                                    // 1. Sauvegarde
                                    manager.sauvegarderContenu(id: id, content: newValue)
                                    
                                    // 2. Auto-correction
                                    if isAutoCorrectActive {
                                        correctionTask?.cancel()
                                        correctionTask = Task {
                                            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                                            if !Task.isCancelled {
                                                manager.declencherCorrectionAuto(pour: id, contenuActuel: newValue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .tag(id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            Divider()
            
            bottomControlBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 8) {
                    
                    // 1. BOUTONS TAILLE
                    Button(action: { if fontSize > 10 { fontSize -= 2 } }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    
                    TextField("Size", value: $fontSize, formatter: NumberFormatter())
                        .frame(width: 40)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.center)
                    
                    Button(action: { if fontSize < 100 { fontSize += 2 } }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    
                    Divider()
                    
                    // 2. BOUTON COPIER
                    Button(action: {
                        copierContenu()
                    }) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .foregroundColor(isCopied ? .green : .blue)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .help("Copier le texte")
                    
                    Divider()
                    
                    // 3. BOUTON AUTO-CORRECT
                    Button(action: {
                        isAutoCorrectActive.toggle()
                    }) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(isAutoCorrectActive ? .purple : .gray)
                            .padding(4)
                            .background(isAutoCorrectActive ? Color.purple.opacity(0.1) : Color.clear)
                            .clipShape(Circle())
                    }
                    .help("Correction auto")
                }
                .padding(.trailing, 10)
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
            }
        }
        .onChange(of: selectedNoteId) { newId in
            checkAutoPlay(newId: newId)
        }
        // --- NAVIGATION CLAVIER ---
        .background(
            VStack {
                Button(action: navigueVersPrecedent) { Text("") }
                    .keyboardShortcut(.leftArrow, modifiers: [.option, .command])
                
                Button(action: navigueVersSuivant) { Text("") }
                    .keyboardShortcut(.rightArrow, modifiers: [.option, .command])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
    }
    
    // --- FONCTIONS ---
    
    func copierContenu() {
        if let note = manager.blocks.first(where: { $0.id == selectedNoteId }) {
            
            // --- CORRECTION ICI : NETTOYAGE DU HTML ---
            var texteBrut = note.content
            
            if let data = note.content.data(using: .utf8) {
                if let attributedString = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                    documentAttributes: nil
                ) {
                    texteBrut = attributedString.string
                }
            }
            
            UIPasteboard.general.string = texteBrut
            
            withAnimation { isCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { isCopied = false }
            }
        }
    }
    
    // --- VUES DÉCOUPÉES ---
    
    var bottomControlBar: some View {
        HStack(spacing: 15) {
            Button(action: { togglePlayCurrent() }) {
                VStack(spacing: 2) {
                    Image(systemName: manager.playingBlockId == selectedNoteId ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                    Text("Lecture").font(.caption2)
                }
                .foregroundColor(manager.playingBlockId == selectedNoteId ? .red : .blue)
            }
            Spacer()
            Button(action: {
                audioSwipeEnabled.toggle()
                if audioSwipeEnabled { autoAudioSwipeEnabled = false }
            }) {
                VStack(spacing: 2) {
                    Image(systemName: audioSwipeEnabled ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                        .font(.system(size: 24))
                    Text("AudioSwipe").font(.caption2)
                }
                .foregroundColor(audioSwipeEnabled ? .indigo : .gray)
            }
            Button(action: {
                autoAudioSwipeEnabled.toggle()
                if autoAudioSwipeEnabled {
                    audioSwipeEnabled = false
                    lancerLectureEtChaine()
                } else {
                    manager.stopAudio()
                }
            }) {
                VStack(spacing: 2) {
                    Image(systemName: autoAudioSwipeEnabled ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                        .font(.system(size: 24))
                    Text("AutoChain").font(.caption2)
                }
                .foregroundColor(autoAudioSwipeEnabled ? .green : .gray)
            }
            Spacer()
            Button(action: { supprimerEtAvancer() }) {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.system(size: 24))
                    Text("Supprimer").font(.caption2)
                }
                .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // --- LOGIQUE NAVIGATION ---
    
    func navigueVersSuivant() {
        guard let index = manager.blocks.firstIndex(where: { $0.id == selectedNoteId }) else { return }
        let nextIndex = index + 1
        if nextIndex < manager.blocks.count, let nextId = manager.blocks[nextIndex].id {
            withAnimation { selectedNoteId = nextId }
        }
    }
    
    func navigueVersPrecedent() {
        guard let index = manager.blocks.firstIndex(where: { $0.id == selectedNoteId }) else { return }
        let prevIndex = index - 1
        if prevIndex >= 0, let prevId = manager.blocks[prevIndex].id {
            withAnimation { selectedNoteId = prevId }
        }
    }
    
    // --- LOGIQUE AUTOMATISATION ---
    
    func checkAutoPlay(newId: UUID) {
        if audioSwipeEnabled || autoAudioSwipeEnabled {
            manager.stopAudio()
            if let note = manager.blocks.first(where: { $0.id == newId }) {
                manager.lireNote(id: newId, content: note.content) { onFinDeLecture() }
            }
        } else {
            manager.stopAudio()
        }
    }
    
    func supprimerEtAvancer() {
        guard let currentIndex = manager.blocks.firstIndex(where: { $0.id == selectedNoteId }) else { return }
        let idASupprimer = selectedNoteId
        var nextIdToSelect: UUID? = nil
        
        if currentIndex + 1 < manager.blocks.count {
            nextIdToSelect = manager.blocks[currentIndex + 1].id
        } else if currentIndex - 1 >= 0 {
            nextIdToSelect = manager.blocks[currentIndex - 1].id
        }
        
        if let nextId = nextIdToSelect {
            withAnimation { selectedNoteId = nextId }
        } else {
            presentationMode.wrappedValue.dismiss()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            manager.supprimerNote(id: idASupprimer)
        }
    }
    
    func togglePlayCurrent() {
        if manager.playingBlockId == selectedNoteId { manager.stopAudio() }
        else if let note = manager.blocks.first(where: { $0.id == selectedNoteId }) {
            manager.lireNote(id: selectedNoteId, content: note.content) { onFinDeLecture() }
        }
    }
    
    func lancerLectureEtChaine() {
        if let note = manager.blocks.first(where: { $0.id == selectedNoteId }) {
            manager.lireNote(id: selectedNoteId, content: note.content) { onFinDeLecture() }
        }
    }
    
    func onFinDeLecture() {
        if autoAudioSwipeEnabled { passerAuSuivant() }
        else { DispatchQueue.main.async { manager.playingBlockId = nil } }
    }
    
    func passerAuSuivant() {
        if let index = manager.blocks.firstIndex(where: { $0.id == selectedNoteId }) {
            let nextIndex = index + 1
            if nextIndex < manager.blocks.count, let nextId = manager.blocks[nextIndex].id {
                withAnimation { selectedNoteId = nextId }
            } else {
                autoAudioSwipeEnabled = false
                manager.stopAudio()
            }
        }
    }
}
