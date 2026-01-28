import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var fontSize: Double
    var onTagClick: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        // Utilisation de la classe technique qui force le layout
        let textView = ForceLayoutTextView()

        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear

        // Gestion de la largeur pour éviter l'écrasement
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Marges et Padding
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        
        textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        textView.textColor = UIColor.label
        textView.dataDetectorTypes = []

        // Toolbar
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

        // Calcul hauteur
        DispatchQueue.main.async {
            let fitSize = uiView.sizeThatFits(CGSize(width: uiView.bounds.width, height: .infinity))
            let newHeight = fitSize.height + 20
            if abs(self.dynamicHeight - newHeight) > 2 {
                self.dynamicHeight = newHeight
            }
        }
    }

    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(self)
    }
}

// Classe indispensable pour garantir que le texte prend toute la largeur
class ForceLayoutTextView: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let availableWidth = bounds.width - (textContainerInset.left + textContainerInset.right)
        if textContainer.size.width != availableWidth && availableWidth > 0 {
            textContainer.size.width = availableWidth
            layoutManager.textContainerChangedGeometry(textContainer)
        }
    }
}
