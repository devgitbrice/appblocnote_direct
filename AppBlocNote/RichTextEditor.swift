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

        // CORRECTION 1 : On force la largeur flexible explicite
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // CORRECTION 2 : Le conteneur de texte doit impérativement suivre la vue
        textView.textContainer.widthTracksTextView = true
        
        textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        textView.textColor = UIColor.label

        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        textView.textContainer.lineFragmentPadding = 0
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
        // Mise à jour du texte
        if context.coordinator.lastText != text {
            context.coordinator.updateTextContent(textView: uiView, html: text, fontSize: fontSize)
            context.coordinator.lastText = text
        }

        // Mise à jour de la police
        if context.coordinator.lastFontSize != fontSize {
            context.coordinator.updateFontSize(textView: uiView, fontSize: fontSize)
            context.coordinator.lastFontSize = fontSize
        }

        // CORRECTION 3 : Calcul de hauteur sécurisé
        DispatchQueue.main.async {
            // Si la vue fait moins de 50px de large, c'est un bug -> on utilise la largeur d'écran
            let screenWidth = UIScreen.main.bounds.width
            let viewWidth = uiView.bounds.width
            
            // On prend la largeur réelle, sinon une largeur par défaut confortable
            let safeWidth = viewWidth > 50 ? viewWidth : (screenWidth - 40)
            
            let sizeToFit = CGSize(width: safeWidth, height: .infinity)
            let size = uiView.sizeThatFits(sizeToFit)
            
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