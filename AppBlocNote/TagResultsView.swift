import SwiftUI

struct TagResultsView: View {
    let tagName: String
    @ObservedObject var manager: NotesManager

    @State private var matchingBlocks: [NoteBlock] = []
    @State private var isLoading = true

    // Hauteurs dynamiques pour les éditeurs (juste pour l'affichage)
    @State private var heights: [UUID: CGFloat] = [:]

    // ✅ Permet de fermer (pop) la page
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if isLoading {
                ProgressView("Recherche de \(tagName)...")
            } else if matchingBlocks.isEmpty {
                Text("Aucun bloc trouvé avec ce tag.")
                    .foregroundColor(.secondary)
            } else {
                ForEach($matchingBlocks) { $block in
                    VStack(alignment: .leading) {
                        RichTextEditor(
                            text: $block.content,
                            dynamicHeight: binding(for: block.id),
                            fontSize: 16.0
                        )
                        .frame(minHeight: heights[block.id ?? UUID()] ?? 80)
                        .disabled(true) // Lecture seule dans la vue recherche
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(tagName) // "#slide" par exemple
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ✅ Bouton Fermer (X) en haut à droite
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                }
                .accessibilityLabel("Fermer")
            }
        }
        .onAppear {
            searchTags()
        }
    }

    // Helper pour la hauteur dynamique
    func binding(for id: UUID?) -> Binding<CGFloat> {
        guard let id = id else { return .constant(80) }
        return Binding(
            get: { heights[id] ?? 80 },
            set: { heights[id] = $0 }
        )
    }

    func searchTags() {
        Task {
            let results = await manager.fetchBlocksWithTag(tag: tagName)
            await MainActor.run {
                self.matchingBlocks = results
                self.isLoading = false
            }
        }
    }
}

