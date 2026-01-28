import SwiftUI
import UIKit

class RichTextEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: RichTextEditor
    weak var currentTextView: UITextView?
    var lastText: String = ""
    var lastFontSize: Double = 0

    init(_ parent: RichTextEditor) {
        self.parent = parent
    }

    // --- 1. RECEPTION ET ANALYSE ---
    func updateTextContent(textView: UITextView, html: String, fontSize: Double) {
        
        // ✅ FIX : Protection anti-boucle modifiée - permet l'init des blocs vides
        if html == lastText && !html.isEmpty { return }
        
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
        
        // ✅ FIX ESPACE : On ne supprime QUE les retours à la ligne, PAS les espaces !
        cleanContent = cleanContent.trimmingCharacters(in: .newlines)

        // ✅ FIX : Si contenu vide, initialiser typingAttributes et sortir
        if cleanContent.isEmpty {
            textView.text = ""
            textView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                .foregroundColor: UIColor.label
            ]
            return
        }

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
            
            /* ✅ FIX : Retrait de div et br du display: block */
            ul, ol { display: block !important; margin-top: 10px; margin-bottom: 10px; padding-left: 20px; }
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
                
                // ✅ FIX : Réappliquer typingAttributes après avoir mis le contenu
                textView.typingAttributes = [
                    .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                    .foregroundColor: UIColor.label
                ]
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
        
        // ✅ FIX : Mettre à jour typingAttributes aussi
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: UIColor.label
        ]
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
        
        // LOG VISUEL : Est-ce que l'espace est là ?
        if let txt = textView.text, let last = txt.last {
            if last == " " {
                print("   ✅ [VISUEL] Espace PRÉSENT (OK)")
            } else {
                // Ignore si c'est un retour ligne
                if last != "\n" {
                    print("   ❌ [VISUEL] Espace ABSENT (Dernier char: '\(last)')")
                }
            }
        }

        if let attr = textView.attributedText {
            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               var fullHtml = String(data: data, encoding: .utf8) {
                
                // FIX ESPACE INSÉCABLE AVANT SAUVEGARDE
                fullHtml = fullHtml.replacingOccurrences(of: "&nbsp;", with: " ")
                
                if parent.text != fullHtml {
                    print("   💾 [SAVE] Sauvegarde (longueur: \(fullHtml.count))")
                    lastText = fullHtml
                    parent.text = fullHtml
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

