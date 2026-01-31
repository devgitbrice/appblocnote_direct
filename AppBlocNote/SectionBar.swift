import SwiftUI

struct SectionBar: View {
    @ObservedObject var notesManager: NotesManager
    @State private var showingAddSection = false
    @State private var newSectionName = ""
    @State private var selectedIcon = "folder.fill"

    // Icônes disponibles pour les sections
    let availableIcons = [
        "house.fill", "briefcase.fill", "book.fill", "heart.fill",
        "star.fill", "folder.fill", "tray.fill", "archivebox.fill",
        "doc.fill", "note.text", "bookmark.fill", "tag.fill",
        "graduationcap.fill", "lightbulb.fill", "gearshape.fill", "person.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(notesManager.sections, id: \.self) { section in
                        SectionTabButton(
                            section: section,
                            isSelected: notesManager.selectedSection?.id == section.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    notesManager.selectedSection = section
                                }
                            },
                            onDelete: section.name != "HOME" ? {
                                Task { await notesManager.supprimerSection(id: section.id) }
                            } : nil
                        )
                    }

                    // Bouton pour ajouter une section
                    Button(action: { showingAddSection = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.secondarySystemBackground))

            Divider()
        }
        .sheet(isPresented: $showingAddSection) {
            AddSectionSheet(
                newSectionName: $newSectionName,
                selectedIcon: $selectedIcon,
                availableIcons: availableIcons,
                onCancel: {
                    showingAddSection = false
                    newSectionName = ""
                },
                onCreate: {
                    Task {
                        await notesManager.ajouterSection(nom: newSectionName, icon: selectedIcon)
                        newSectionName = ""
                        selectedIcon = "folder.fill"
                        showingAddSection = false
                    }
                }
            )
        }
    }
}

struct SectionTabButton: View {
    let section: Section
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                Text(section.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            }
        }
    }
}

struct AddSectionSheet: View {
    @Binding var newSectionName: String
    @Binding var selectedIcon: String
    let availableIcons: [String]
    let onCancel: () -> Void
    let onCreate: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Nom de la section", text: $newSectionName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Text("Choisir une icône")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: { selectedIcon = icon }) {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 50, height: 50)
                                .background(selectedIcon == icon ? Color.blue : Color(UIColor.tertiarySystemBackground))
                                .foregroundColor(selectedIcon == icon ? .white : .primary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Nouvelle Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer", action: onCreate)
                        .disabled(newSectionName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
