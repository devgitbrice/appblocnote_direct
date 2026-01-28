import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var fontSize: Double
    var onTagClick: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear

        // Configuration du texte
        textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        textView.textColor = UIColor.label

        // CORRECTION: On laisse autoresizingMask (true par défaut) gérer le layout SwiftUI
        // On ne force pas le translatesAutoresizingMaskIntoConstraints à false

        // Configuration du textContainer
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0

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
        // CORRECTION: Suppression de la gestion manuelle des contraintes ici.
        // SwiftUI s'en charge.

        // Mise à jour du texte (Uniquement si changé pour éviter les boucles)
        if context.coordinator.lastText != text {
            context.coordinator.updateTextContent(textView: uiView, html: text, fontSize: fontSize)
            context.coordinator.lastText = text
        }

        // Mise à jour de la police (Uniquement si changée)
        if context.coordinator.lastFontSize != fontSize {
            context.coordinator.updateFontSize(textView: uiView, fontSize: fontSize)
            context.coordinator.lastFontSize = fontSize
        }

        // Recalcul hauteur
        DispatchQueue.main.async {
            let width = uiView.bounds.width > 0 ? uiView.bounds.width : UIScreen.main.bounds.width
            let size = uiView.sizeThatFits(CGSize(width: width, height: .infinity))
            let newHeight = size.height + 20 // Marge de sécurité
            if abs(self.dynamicHeight - newHeight) > 2 {
                self.dynamicHeight = newHeight
            }
        }
    }

    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(self)
    }
}