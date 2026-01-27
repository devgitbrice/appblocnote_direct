import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var fontSize: Double
    var onTagClick: ((String) -> Void)? = nil
    
    func makeUIView(context: Context) -> UITextView {
        // CORRECTION VERTICALE : On force une largeur explicite au départ
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        
        // --- CORRECTION CRUCIALE POUR LE TEXTE VERTICAL ---
        // 1. On dit à la vue de s'étirer dans son parent
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // 2. On dit au conteneur de texte de suivre la largeur de la vue (C'EST ÇA QUI MANQUAIT)
        textView.textContainer.widthTracksTextView = true
        // 3. On force le mode de rupture de ligne standard
        textView.textContainer.lineBreakMode = .byWordWrapping
        
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
        
        // Recalcul hauteur
        context.coordinator.recalculateHeight(view: uiView, dynamicHeight: $dynamicHeight)
    }
    
    // On utilise notre classe renommée
    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(self)
    }
}
