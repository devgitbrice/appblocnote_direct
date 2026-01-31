import SwiftUI

struct MainSplitView: View {
    @StateObject var notesManager = NotesManager()

    @State private var showingAddCategory = false
    @State private var newCategoryName = ""

    @State private var editingCategoryId: UUID? = nil
    @State private var editingName: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SectionBar(notesManager: notesManager)

            NavigationSplitView {
                sidebarContent
            } detail: {
                detailContent
            }
            .onAppear {
                Task {
                    await notesManager.chargerSections()
                    await notesManager.chargerCategories()
                }
            }
        }
        .sheet(item: Binding(
            get: { notesManager.selectedTagToOpen.map { TagWrapper(name: $0) } },
            set: { notesManager.selectedTagToOpen = $0?.name }
        )) { wrapper in
            TagResultsView(tagName: wrapper.name, manager: notesManager)
        }
    }

    // MARK: - Sidebar Content
    @ViewBuilder
    private var sidebarContent: some View {
        List(selection: $notesManager.selectedCategory) {
            Section(header: Text("Mes Dossiers")) {
                ForEach(notesManager.categoriesForSelectedSection, id: \.self) { category in
                    categoryRow(for: category)
                }
                .onMove(perform: deplacerCategorieDansSection)
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
            addCategorySheet
        }
        .safeAreaInset(edge: .bottom) {
            bottomLinks
        }
    }

    // MARK: - Category Row
    @ViewBuilder
    private func categoryRow(for category: NoteCategory) -> some View {
        if editingCategoryId == category.id {
            editingRow(for: category)
        } else {
            readingRow(for: category)
        }
    }

    @ViewBuilder
    private func editingRow(for category: NoteCategory) -> some View {
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
    }

    @ViewBuilder
    private func readingRow(for category: NoteCategory) -> some View {
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
            Button { Task { await notesManager.toggleCategoryPin(category: category) } } label: {
                Label("Épingler", systemImage: category.is_pinned ? "pin.slash" : "pin")
            }.tint(.indigo)
            Button { Task { await notesManager.toggleCategoryRed(category: category) } } label: {
                Label("Rouge", systemImage: "paintbrush.fill")
            }.tint(.red)
        }
        .swipeActions(edge: .trailing) {
            Button { lancerEdition(category: category) } label: {
                Label("Renommer", systemImage: "pencil")
            }.tint(.orange)
        }
        .onTapGesture(count: 2) { lancerEdition(category: category) }
        .contextMenu { contextMenuContent(for: category) }
    }

    @ViewBuilder
    private func contextMenuContent(for category: NoteCategory) -> some View {
        Button("Renommer") { lancerEdition(category: category) }
        Button(category.is_pinned ? "Désépingler" : "Épingler") {
            Task { await notesManager.toggleCategoryPin(category: category) }
        }
        Button(category.is_red ? "Enlever rouge" : "Mettre en rouge") {
            Task { await notesManager.toggleCategoryRed(category: category) }
        }

        Divider()

        Menu("Déplacer vers...") {
            ForEach(sectionsForMove(excluding: category.section_id), id: \.self) { section in
                Button {
                    Task {
                        await notesManager.deplacerCategorieVersSection(
                            categoryId: category.id,
                            newSectionId: section.id
                        )
                    }
                } label: {
                    Label(section.name, systemImage: section.icon)
                }
            }
        }
    }

    private func sectionsForMove(excluding sectionId: UUID?) -> [Section] {
        notesManager.sections.filter { $0.id != sectionId }
    }

    // MARK: - Detail Content
    @ViewBuilder
    private var detailContent: some View {
        if !notesManager.categoriesForSelectedSection.isEmpty {
            TabView(selection: $notesManager.selectedCategory) {
                ForEach(notesManager.categoriesForSelectedSection, id: \.self) { category in
                    BlocNotesView(notesManager: notesManager)
                        .tag(Optional(category))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #if os(iOS)
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            #endif
            .id(notesManager.categoriesForSelectedSection.count)
        } else {
            Text("Aucun dossier dans cette section. Créez-en un !").foregroundStyle(.secondary)
        }
    }

    // MARK: - Add Category Sheet
    private var addCategorySheet: some View {
        VStack(spacing: 20) {
            Text("Nouveau dossier").font(.headline)
            TextField("Nom du dossier", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)
                .padding()
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
        .padding()
        .presentationDetents([.fraction(0.3)])
    }

    // MARK: - Bottom Links
    private var bottomLinks: some View {
        VStack(spacing: 0) {
            Divider()
            Link(destination: URL(string: "https://supabase.com/dashboard/project/lomgelwpxlzynuogxsri/editor/40424")!) {
                HStack {
                    Image(systemName: "database.fill")
                    Text("SUPABASE").fontWeight(.bold)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.green)
                .background(Color(UIColor.secondarySystemBackground))
            }
            Divider()
            Link(destination: URL(string: "https://gemini.google.com/app/52bf4dc58f08a43d")!) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("HELP GEMINI").fontWeight(.bold)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.indigo)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
    }

    // MARK: - Functions
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

    func deplacerCategorieDansSection(from source: IndexSet, to destination: Int) {
        var filteredCategories = notesManager.categoriesForSelectedSection
        filteredCategories.move(fromOffsets: source, toOffset: destination)

        let orderedIds = filteredCategories.map { $0.id }
        Task {
            await notesManager.reordonnerCategories(ids: orderedIds)
        }
    }
}

struct TagWrapper: Identifiable {
    let id = UUID()
    let name: String
}
