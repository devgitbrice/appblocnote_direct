import SwiftUI
import UIKit

class RichTextEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: RichTextEditor
    weak var currentTextView: UITextView?
    var lastText: String = ""
    var lastFontSize: Double = 0

    // FIX: Flag pour éviter les boucles de mise à jour
    var isUpdatingFromTextView = false

    init(_ parent: RichTextEditor) {
        self.parent = parent
    }

    // --- 1. RECEPTION ET ANALYSE ---
    func updateTextContent(textView: UITextView, html: String, fontSize: Double) {

        // FIX CRITIQUE: Ne JAMAIS écraser le contenu pendant que l'utilisateur tape
        // C'est LA cause du bug de l'espace qui disparaît
        if textView.isFirstResponder {
            return
        }

        // FIX: Si c'est une mise à jour qui vient du textView lui-même, on ignore
        if isUpdatingFromTextView {
            return
        }

        // PROTECTION ANTI-BOUCLE (comparaison de contenu)
        if html == lastText { return }

        print("\n⬇️ [UPDATE] HTML Reçu (len: \(html.count))")

        // 1. NETTOYAGE & RÉPARATION ESPACES
        var cleanContent = html.replacingOccurrences(of: "&nbsp;", with: " ")
        cleanContent = cleanContent.replacingOccurrences(of: "\u{00A0}", with: " ")
        
        // Extraction Body
        if let bodyStart = cleanContent.range(of: "<body"), let bodyEnd = cleanContent.range(of: "</body>") {
            let content = String(cleanContent[bodyStart.lowerBound..<bodyEnd.lowerBound])
            if let firstTag = content.firstIndex(of: ">") {
                cleanContent = String(content[content.index(after: firstTag)...])
            }
        } else {
            cleanContent = cleanContent.replacingOccurrences(of: "<!DOCTYPE html>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "<html>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "<body>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "</body>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "</html>", with: "")
        }
        
        cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. CSS CORRECTIF (AVEC INLINE-BLOCK)
        let cssStyle = """
        <style>
            body { 
                font-family: -apple-system; 
                font-size: \(fontSize)px; 
                
                /* CONTRAINTES DE LARGEUR */
                width: 100%; 
                max-width: 100%;
                overflow-x: hidden; /* Coupe ce qui dépasse */
                box-sizing: border-box;
                
                word-wrap: break-word; 
                overflow-wrap: break-word; 
                white-space: pre-wrap; /* CRITIQUE pour les espaces */
                color: #000000;
                margin: 0; padding: 0;
            }
            
            /* LE FIX DE L'ESPACE : inline-block au lieu de inline */
            p { 
                display: inline-block; 
                margin-right: 4px; 
            }
            
            ul, ol, li, div, br { display: block !important; }
            ul, ol { margin-top: 10px; margin-bottom: 10px; padding-left: 20px; }
            li { display: list-item !important; margin-bottom: 4px; }
        </style>
        """
        
        let fullHtml = "<!DOCTYPE html><html><head>\(cssStyle)</head><body>\(cleanContent)</body></html>"
        
        if let data = fullHtml.data(using: .utf8) {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                let mutable = NSMutableAttributedString(attributedString: attr)
                let range = NSRange(location: 0, length: mutable.length)
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
                
                textView.attributedText = mutable
            } else {
                textView.text = cleanContent
            }
        }
    }

    func updateFontSize(textView: UITextView, fontSize: Double) {
        guard let currentAttr = textView.attributedText else { return }
        let mutable = NSMutableAttributedString(attributedString: currentAttr)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
        textView.attributedText = mutable
    }

    // --- 3. INTERCEPTION CLAVIER (LOGS) ---
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == " " {
            print("\n⌨️ [CLAVIER] Barre Espace Appuyée")
        }
        return true
    }

    // --- 4. VERIFICATION APRES FRAPPE ---
    func textViewDidChange(_ textView: UITextView) {

        if let attr = textView.attributedText {
            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               var fullHtml = String(data: data, encoding: .utf8) {

                // FIX ESPACE INSÉCABLE AVANT SAUVEGARDE
                fullHtml = fullHtml.replacingOccurrences(of: "&nbsp;", with: " ")
                // FIX: Aussi remplacer le caractère Unicode non-breaking space
                fullHtml = fullHtml.replacingOccurrences(of: "\u{00A0}", with: " ")

                if parent.text != fullHtml {
                    // FIX: Activer le flag AVANT de mettre à jour le binding
                    // pour éviter que updateTextContent soit rappelé en boucle
                    isUpdatingFromTextView = true
                    lastText = fullHtml
                    parent.text = fullHtml
                    // FIX: Désactiver le flag après la mise à jour
                    // On utilise async pour s'assurer que SwiftUI a fini son cycle
                    DispatchQueue.main.async {
                        self.isUpdatingFromTextView = false
                    }
                }
            }
        }

        // Maintien visuel
        textView.font = UIFont.systemFont(ofSize: CGFloat(parent.fontSize))
        textView.textColor = UIColor.label

        // Hauteur bornée
        let fixedWidth = UIScreen.main.bounds.width - 40
        let size = textView.sizeThatFits(CGSize(width: fixedWidth, height: .infinity))
        let newHeight = size.height + 20
        if abs(parent.dynamicHeight - newHeight) > 2 {
            parent.dynamicHeight = newHeight
        }
    }
    
    // --- 5. QUAND L'UTILISATEUR QUITTE LE CHAMP ---
    func textViewDidEndEditing(_ textView: UITextView) {
        // FIX: Quand l'utilisateur quitte le champ, on s'assure que le binding
        // contient le contenu actuel du textView (pas une version modifiée par
        // la correction auto pendant la frappe)
        if let attr = textView.attributedText {
            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               var fullHtml = String(data: data, encoding: .utf8) {

                fullHtml = fullHtml.replacingOccurrences(of: "&nbsp;", with: " ")
                fullHtml = fullHtml.replacingOccurrences(of: "\u{00A0}", with: " ")

                // Synchronise le binding avec le contenu réel du textView
                isUpdatingFromTextView = true
                lastText = fullHtml
                parent.text = fullHtml
                DispatchQueue.main.async {
                    self.isUpdatingFromTextView = false
                }
            }
        }
    }

    // --- AUTRES ---
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "tag" {
            let tag = URL.absoluteString.replacingOccurrences(of: "tag://", with: "").removingPercentEncoding ?? ""
            parent.onTagClick?(tag)
            return false
        }
        if URL.scheme == "search" { return false }
        UIApplication.shared.open(URL)
        return false
    }

    @objc func toggleBulletList() { currentTextView?.insertText("\n• ") }
    @objc func toggleNumberList() { currentTextView?.insertText("\n1. ") }
    @objc func dismissKeyboard() { currentTextView?.resignFirstResponder() }
}
