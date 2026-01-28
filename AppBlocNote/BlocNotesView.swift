import SwiftUI
import Supabase

struct BlocNotesView: View {
    @ObservedObject var notesManager: NotesManager
    @State private var activeMicId: UUID? = nil
    
    // --- TAILLE DE POLICE ---
    @AppStorage("listFontSize") private var fontSize: Double = 14
    
    // --- VARIABLES DE TEST ---
    @State private var testMessage: String = "En attente du clic..."
    @State private var testColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ==========================================
            // ZONE DE DIAGNOSTIC CRITIQUE
            // ==========================================
            VStack(spacing: 8) {
                Text(testMessage)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(testColor)
                
                HStack {
                    Button("1. ETAT SESSION") {
                        Task { await verifierSession() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button("2. FORCE LOGIN") {
                        // Simule une déconnexion pour forcer la vue Login à réapparaître
                        Task {
                            try? await SupabaseSingleton.shared.client.auth.signOut()
                            testMessage = "Déconnecté. Relance l'app pour te loguer."
                            testColor = .orange
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.bottom, 5)
            }
            .background(Color.black.opacity(0.9))
            
            // ==========================================
            // EN-TÊTE
            // ==========================================
            HStack(alignment: .center, spacing: 12) {
                Text(notesManager.selectedCategory?.name ?? "Dossier")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Contrôleur de taille
                HStack(spacing: 0) {
                    Button(action: { if fontSize > 8 { fontSize -= 1 } }) {
                        Image(systemName: "minus").frame(width: 30, height: 30).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider().frame(height: 20)
                    Text("\(Int(fontSize))").frame(width: 35)
                    Divider().frame(height: 20)
                    Button(action: { if fontSize < 40 { fontSize += 1 } }) {
                        Image(systemName: "plus").frame(width: 30, height: 30).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
                
                // Refresh
                Button(action: {
                    Task { if let cat = notesManager.selectedCategory { await notesManager.chargerNotes(pour: cat.id) } }
                }) {
                    Image(systemName: "arrow.clockwise").font(.title2).foregroundColor(.blue).padding(8).background(Color.blue.opacity(0.1)).clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // LISTE
            if notesManager.blocks.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "note.text").font(.system(size: 50)).foregroundColor(.gray.opacity(0.3))
                    Text("Aucune note ici").foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach($notesManager.blocks) { $block in
                                NoteRow(note: $block, manager: notesManager, activeMicId: $activeMicId, fontSize: fontSize)
                                    .frame(maxWidth: .infinity)
                                    .id(block.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            HStack {
                Spacer()
                Button(action: { notesManager.ajouterNote() }) {
                    Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white).frame(width: 50, height: 50).background(Color.blue).clipShape(Circle()).shadow(radius: 4)
                }
                .padding(.trailing, 20).padding(.top, 10)
            }
        }
    }
    
    // --- FONCTION Mouchard ---
    func verifierSession() async {
        let client = SupabaseSingleton.shared.client
        
        // 1. Check Session
        let session = try? await client.auth.session
        let user = client.auth.currentUser
        
        if session == nil {
            testMessage = "⛔️ SESSION = NIL (Vide)\nLe Mac a oublié la connexion."
            testColor = .red
        } else if user == nil {
            testMessage = "⚠️ SESSION OK MAIS USER NIL\nProblème bizarre de synchro."
            testColor = .orange
        } else {
            testMessage = "✅ TOUT EST VERT !\nUser: \(user?.email ?? "?")\nUID: \(user?.id.uuidString.prefix(5) ?? "nil")..."
            testColor = .green
        }
    }
}
