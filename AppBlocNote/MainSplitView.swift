import SwiftUI

struct MainSplitView: View {
    @StateObject var notesManager = NotesManager()
    
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    
    @State private var editingCategoryId: UUID? = nil
    @State private var editingName: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationSplitView {
            List(selection: $notesManager.selectedCategory) {
                
                // ==================================================
                // 📌 SECTION SPÉCIALE : TOUS LES ÉPINGLÉS (Si présente)
                // ==================================================
                // (Je garde la structure de ta liste actuelle)
                
                Section(header: Text("Mes Dossiers")) {
                    ForEach(notesManager.categories, id: \.self) { category in
                        if editingCategoryId == category.id {
                            // MODE ÉDITION
                            HStack {
                                Image(systemName: "folder").foregroundColor(.blue)
                                TextField("Nom du dossier", text: $editingName)
                                    .textFieldStyle(.plain)
                                    .focused($isInputFocused)
                                    .onSubmit { validerRenommage(category: category) }
                                Button(action: { validerRenommage(category: category) }) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }.buttonStyle(.plain)
                            }
                            .onAppear { isInputFocused = true }
                        } else {
                            // MODE LECTURE
                            NavigationLink(value: category) {
                                HStack {
                                    Image(systemName: category.is_pinned ? "pin.fill" : "folder")
                                        .foregroundColor(category.is_pinned ? .indigo : .blue)
                                    Text(category.name)
                                        .foregroundColor(category.is_red ? .red : .primary)
                                        .fontWeight(category.is_red ? .bold : .regular)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button { Task { await notesManager.toggleCategoryPin(category: category) } } label: { Label("Épingler", systemImage: category.is_pinned ? "pin.slash" : "pin") }.tint(.indigo)
                                Button { Task { await notesManager.toggleCategoryRed(category: category) } } label: { Label("Rouge", systemImage: "paintbrush.fill") }.tint(.red)
                            }
                            .swipeActions(edge: .trailing) {
                                Button { lancerEdition(category: category) } label: { Label("Renommer", systemImage: "pencil") }.tint(.orange)
                            }
                            .onTapGesture(count: 2) { lancerEdition(category: category) }
                            .contextMenu {
                                Button("Renommer") { lancerEdition(category: category) }
                                Button(category.is_pinned ? "Désépingler" : "Épingler") { Task { await notesManager.toggleCategoryPin(category: category) } }
                                Button(category.is_red ? "Enlever rouge" : "Mettre en rouge") { Task { await notesManager.toggleCategoryRed(category: category) } }
                            }
                        }
                    }
                    .onMove(perform: notesManager.deplacerCategorie)
                }
            }
            .navigationTitle("Catégories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCategory = true }) {
                        Label("Ajouter", systemImage: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                VStack(spacing: 20) {
                    Text("Nouveau dossier").font(.headline)
                    TextField("Nom du dossier", text: $newCategoryName).textFieldStyle(.roundedBorder).padding()
                    HStack {
                        Button("Annuler") { showingAddCategory = false }
                        Button("Créer") {
                            Task {
                                await notesManager.ajouterCategorie(nom: newCategoryName)
                                newCategoryName = ""
                                showingAddCategory = false
                            }
                        }
                        .disabled(newCategoryName.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding().presentationDetents([.fraction(0.3)])
            }
            // --- BOUTONS BAS DE PAGE (SUPABASE + GEMINI) ---
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    
                    // 1. BOUTON SUPABASE
                    Link(destination: URL(string: "https://supabase.com/dashboard/project/lomgelwpxlzynuogxsri/editor/40424")!) {
                        HStack {
                            Image(systemName: "database.fill")
                            Text("SUPABASE")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.green)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                    
                    Divider()
                    
                    // 2. BOUTON GEMINI
                    Link(destination: URL(string: "https://gemini.google.com/app/52bf4dc58f08a43d")!) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("HELP GEMINI")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.indigo)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                }
            }
            
        } detail: {
            if !notesManager.categories.isEmpty {
                TabView(selection: $notesManager.selectedCategory) {
                    ForEach(notesManager.categories, id: \.self) { category in
                        BlocNotesView(notesManager: notesManager)
                            .tag(Optional(category))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                #if os(iOS)
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                #endif
                .id(notesManager.categories.count)
            } else {
                Text("Aucun dossier. Créez-en un !").foregroundStyle(.secondary)
            }
        }
        .onAppear { Task { await notesManager.chargerCategories() } }
        
        // --- NOUVEAU : GESTION DE L'OUVERTURE DES TAGS ---
        .sheet(item: Binding(
            get: { notesManager.selectedTagToOpen.map { TagWrapper(name: $0) } },
            set: { notesManager.selectedTagToOpen = $0?.name }
        )) { wrapper in
            TagResultsView(tagName: wrapper.name, manager: notesManager)
        }
    }
    
    func lancerEdition(category: NoteCategory) {
        editingName = category.name
        editingCategoryId = category.id
    }
    
    func validerRenommage(category: NoteCategory) {
        guard !editingName.isEmpty else { return }
        let oldName = category.name
        let newName = editingName
        let catId = category.id
        editingCategoryId = nil
        if oldName != newName {
            Task { await notesManager.renommerCategorie(id: catId, nouveauNom: newName) }
        }
    }
}

// --- PETITE STRUCTURE POUR LE SHEET ---
struct TagWrapper: Identifiable {
    let id = UUID()
    let name: String
}
