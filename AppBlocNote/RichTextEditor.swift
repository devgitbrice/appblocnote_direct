import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var fontSize: Double
    var onTagClick: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = ForceLayoutTextView()
        
        // Connexion
        context.coordinator.currentTextView = textView
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false // CRITIQUE : Empêche le scroll interne
        textView.backgroundColor = .clear

        // Contraintes pour empêcher l'élargissement infini
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        
        textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        textView.textColor = UIColor.label
        textView.dataDetectorTypes = []
        
        // ✅ FIX : Définir typingAttributes pour le nouveau texte tapé
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: UIColor.label
        ]

        // Toolbar
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let bullet = UIBarButtonItem(image: UIImage(systemName: "list.bullet"), style: .plain, target: context.coordinator, action: #selector(RichTextEditorCoordinator.toggleBulletList))
        let number = UIBarButtonItem(image: UIImage(systemName: "list.number"), style: .plain, target: context.coordinator, action: #selector(RichTextEditorCoordinator.toggleNumberList))
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "OK", style: .done, target: context.coordinator, action: #selector(RichTextEditorCoordinator.dismissKeyboard))
        toolBar.items = [bullet, number, space, done]
        textView.inputAccessoryView = toolBar

        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if context.coordinator.lastText != text {
            context.coordinator.updateTextContent(textView: uiView, html: text, fontSize: fontSize)
            context.coordinator.lastText = text
        }
        if context.coordinator.lastFontSize != fontSize {
            context.coordinator.updateFontSize(textView: uiView, fontSize: fontSize)
            
            // ✅ FIX : Mettre à jour typingAttributes quand la taille change
            uiView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                .foregroundColor: UIColor.label
            ]
            
            context.coordinator.lastFontSize = fontSize
        }

        DispatchQueue.main.async {
            // FIX LARGEUR : On calcule la hauteur basée sur la largeur de l'ÉCRAN, pas du texte
            let fixedWidth = UIScreen.main.bounds.width - 40 // Marge de sécurité
            let fitSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: .infinity))
            
            let newHeight = fitSize.height + 20
            
            // LOG LARGEUR
            if uiView.contentSize.width > fixedWidth + 50 {
                print("🚨 [LAYOUT] DÉBORDEMENT DÉTECTÉ ! Content: \(uiView.contentSize.width) vs Screen: \(fixedWidth)")
            }

            if abs(self.dynamicHeight - newHeight) > 2 {
                self.dynamicHeight = newHeight
            }
        }
    }

    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(self)
    }
}

// Classe qui force le layout à respecter les bornes
class ForceLayoutTextView: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if bounds.width > 0 {
            let maxAvailableWidth = bounds.width - (textContainerInset.left + textContainerInset.right)
            if textContainer.size.width != maxAvailableWidth {
                textContainer.size.width = maxAvailableWidth
                layoutManager.textContainerChangedGeometry(textContainer)
            }
        }
    }
}

