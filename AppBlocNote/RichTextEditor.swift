import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var fontSize: Double
    var availableWidth: CGFloat = 0  // 🔧 FIX: Largeur disponible depuis GeometryReader
    var onTagClick: ((String) -> Void)? = nil
    
    func makeUIView(context: Context) -> UITextView {
        // On laisse SwiftUI gérer la taille - ne pas forcer une largeur fixe
        let textView = UITextView()
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        
        // --- CORRECTION CRUCIALE POUR LE TEXTE VERTICAL ---
        // 1. On dit à la vue de s'étirer dans son parent
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // 2. NE PAS utiliser widthTracksTextView - on gère manuellement dans updateUIView
        textView.textContainer.widthTracksTextView = false
        // 3. On force le mode de rupture de ligne standard
        textView.textContainer.lineBreakMode = .byWordWrapping
        // 4. Grande largeur par défaut (sera ajustée dans updateUIView)
        textView.textContainer.size = CGSize(width: UIScreen.main.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        
        // Configuration Layout stricte
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Désactivation des détecteurs Apple pour gérer nos propres liens
        textView.dataDetectorTypes = []
        
        // Toolbar
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "OK", style: .done, target: context.coordinator, action: #selector(RichTextEditorCoordinator.dismissKeyboard))
        toolBar.items = [space, done]
        textView.inputAccessoryView = toolBar
        
        textView.delegate = context.coordinator
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 🔧 FIX TEXTE VERTICAL: Utiliser la largeur fournie par GeometryReader
        let width = availableWidth > 0 ? availableWidth : uiView.frame.width
        if width > 0 {
            uiView.frame.size.width = width
            uiView.textContainer.size.width = width
            // Stocker la largeur dans le coordinateur pour textViewDidChange
            context.coordinator.currentWidth = width
        }
        uiView.layoutIfNeeded()

        // Mise à jour du texte (Uniquement si changé pour éviter les boucles)
        if context.coordinator.lastText != text {
            // Notez le label 'html:' qui correspond bien à la définition du coordinateur
            context.coordinator.updateTextContent(textView: uiView, html: text, fontSize: fontSize)
            context.coordinator.lastText = text
        }
        
        // Mise à jour de la police (Uniquement si changée)
        if context.coordinator.lastFontSize != fontSize {
            context.coordinator.updateFontSize(textView: uiView, fontSize: fontSize)
            context.coordinator.lastFontSize = fontSize
        }
        
        // Recalcul hauteur avec la largeur disponible
        context.coordinator.recalculateHeight(view: uiView, dynamicHeight: $dynamicHeight, availableWidth: width)
    }
    
    // On utilise notre classe renommée
    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(self)
    }
}
