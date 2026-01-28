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
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear

        // CONFIGURATION CRITIQUE
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

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

        DispatchQueue.main.async {
            // --- LOGS DE DIAGNOSTIC ---
            let w = uiView.frame.width
            let screen = UIScreen.main.bounds.width
            print("🔍 DEBUG: Frame Width: \(w) | Screen: \(screen)")

            // Si largeur < 50, on force une largeur théorique pour le calcul de hauteur
            let safeWidth = w > 50 ? w : (screen - 60) 
            let size = uiView.sizeThatFits(CGSize(width: safeWidth, height: .infinity))
            let newHeight = size.height + 20
            
            print("🔍 DEBUG: Hauteur calculée: \(newHeight) (sur largeur: \(safeWidth))")

            if abs(self.dynamicHeight - newHeight) > 2 {
                self.dynamicHeight = newHeight
            }
        }
    }

    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(self)
    }
}