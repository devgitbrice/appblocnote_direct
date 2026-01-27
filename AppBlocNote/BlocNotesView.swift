import SwiftUI
import Supabase

struct BlocNotesView: View {
    @ObservedObject var notesManager: NotesManager
    @State private var activeMicId: UUID? = nil
    
    // --- TAILLE DE POLICE (Sauvegardée automatiquement) ---
    @AppStorage("listFontSize") private var fontSize: Double = 14
    
    // --- VARIABLES DE TEST ---
    @State private var testMessage: String = "En attente du test..."
    @State private var testColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ==========================================
            // ZONE DE TEST (Temporaire)
            // ==========================================
            VStack(spacing: 5) {
                Text(testMessage)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(testColor)
                
                Button("CLIQUE ICI POUR TESTER LA CONNEXION") {
                    Task { await testerConnexion() }
                }
                .font(.footnote.bold())
                .padding(.bottom, 5)
            }
            .background(Color.black.opacity(0.8))
            
            // ==========================================
            // 🏷️ EN-TÊTE : TITRE + 🔠 TAILLE + 🔄 REFRESH + 🚪 LOGOUT
            // ==========================================
            HStack(alignment: .center, spacing: 12) {
                // 1. Titre du dossier
                Text(notesManager.selectedCategory?.name ?? "Dossier sans nom")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                // 2. Contrôleur de taille de police
                HStack(spacing: 0) {
                    Button(action: {
                        if fontSize > 8 { fontSize -= 1 }
                    }) {
                        Image(systemName: "minus")
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 20)
                    
                    TextField("11", value: $fontSize, formatter: NumberFormatter())
                        .multilineTextAlignment(.center)
                        .frame(width: 35)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    
                    Divider().frame(height: 20)
                    
                    Button(action: {
                        if fontSize < 40 { fontSize += 1 }
                    }) {
                        Image(systemName: "plus")
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                
                // 3. Bouton Actualiser
                Button(action: {
                    print("🔄 Actualisation manuelle demandée")
                    Task {
                        if let category = notesManager.selectedCategory {
                            await notesManager.chargerNotes(pour: category.id)
                        }
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Recharger la page (⌘R)")

                // 4. BOUTON DÉCONNEXION
                Button(action: {
                    Task {
                        try? await SupabaseSingleton.shared.client.auth.signOut()
                        print("👋 Déconnexion demandée")
                        testMessage = "👋 Déconnecté ! Relance l'app."
                        testColor = .red
                    }
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title2)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .help("Se déconnecter")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            // ==========================================
            
            // LISTE DES NOTES
            if notesManager.blocks.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Aucune note dans ce dossier")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Color.clear.frame(height: 10)
                            
                            ForEach($notesManager.blocks) { $block in
                                NoteRow(
                                    note: $block,
                                    manager: notesManager,
                                    activeMicId: $activeMicId,
                                    fontSize: fontSize
                                )
                                .frame(maxWidth: .infinity) // <--- CORRECTION IPAD : FORCE LA LARGEUR MAXIMALE
                                .id(block.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        // BOUTON FLOTTANT (+)
        .overlay(alignment: .top) {
            HStack {
                Spacer()
                Button(action: {
                    notesManager.ajouterNote()
                }) {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.top, 10)
            }
        }
    }
    
    // FONCTION DE TEST DIAGNOSTIC
    func testerConnexion() async {
        if let user = SupabaseSingleton.shared.client.auth.currentUser {
            testMessage = "👤 Connecté : \(user.email ?? "Sans email")"
            testColor = .orange
        } else {
            testMessage = "⛔️ NON CONNECTÉ (Relance l'app !)"
            testColor = .red
            return
        }
        
        do {
            let userId = SupabaseSingleton.shared.client.auth.currentUser!.id
            let testCat = NoteCategory(name: "TEST", user_id: userId, order_index: 999)
            try await SupabaseSingleton.shared.client.from("site_notes_categories").insert(testCat).execute()
            testMessage = "✅ CONNEXION ET ÉCRITURE RÉUSSIES !"
            testColor = .green
        } catch {
            testMessage = "❌ ERREUR : \(error.localizedDescription)"
            testColor = .purple
        }
    }
}
