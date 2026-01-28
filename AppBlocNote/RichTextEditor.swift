import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var fontSize: Double
    var onTagClick: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        // Utilisation de notre sous-classe personnalisée
        let textView = DynamicTextView()

        textView.isEditable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // Configuration critique du conteneur
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        textView.textContainer.widthTracksTextView = true // Doit être true

        textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        textView.textColor = UIColor.label
        textView.dataDetectorTypes = []

        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let done = UIBarButtonItem(title: "OK", style: .done, target: context.coordinator, action: #selector(RichTextEditorCoordinator.dismissKeyboard))
        toolBar.items = [.flexibleSpace(), done]
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
            context.coordinator.lastFontSize = fontSize
        }

        // Calcul de hauteur
        DispatchQueue.main.async {
            let size = uiView.sizeThatFits(CGSize(width: uiView.bounds.width, height: .infinity))
            let newHeight = size.height + 20
            if abs(self.dynamicHeight - newHeight) > 2 {
                self.dynamicHeight = newHeight
            }
        }
    }

    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(self)
    }
}

// --- SOUS-CLASSE POUR FORCER LE LAYOUT ---
class DynamicTextView: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        // FORCE le conteneur de texte à prendre toute la largeur de la vue
        // C'est souvent ce qui manque quand le texte reste vertical
        if textContainer.size.width != bounds.width {
            textContainer.size.width = bounds.width
        }
    }
}