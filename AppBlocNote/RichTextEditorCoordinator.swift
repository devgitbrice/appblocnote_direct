import SwiftUI
import UIKit

class RichTextEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: RichTextEditor
    weak var currentTextView: UITextView?
    var lastText: String = ""
    var lastFontSize: Double = 0

    // ✅ FIX ESPACE: Flag pour bloquer updateTextContent après une frappe
    var isUserTyping: Bool = false

    init(_ parent: RichTextEditor) {
        self.parent = parent
    }

    // --- 1. RECEPTION ET ANALYSE ---
    func updateTextContent(textView: UITextView, html: String, fontSize: Double) {

        // ✅ FIX ESPACE: Si l'utilisateur vient de taper, on ignore l'update
        if isUserTyping {
            print("🔵 [SKIP] isUserTyping=true - on ignore updateTextContent")
            isUserTyping = false
            lastText = html
            return
        }

        // Protection anti-boucle
        if html == lastText && !html.isEmpty { return }

        var cleanContent = html

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

        cleanContent = cleanContent.trimmingCharacters(in: .newlines)

        if cleanContent.isEmpty {
            textView.text = ""
            textView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                .foregroundColor: UIColor.label
            ]
            return
        }

        let cssStyle = """
        <style>
            body {
                font-family: -apple-system;
                font-size: \(fontSize)px;
                width: 100%;
                max-width: 100%;
                overflow-x: hidden;
                box-sizing: border-box;
                word-wrap: break-word;
                overflow-wrap: break-word;
                white-space: pre-wrap;
                color: #000000;
                margin: 0; padding: 0;
            }
            p {
                display: inline-block;
                margin-right: 4px;
            }
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

                textView.typingAttributes = [
                    .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                    .foregroundColor: UIColor.label
                ]
            } else {
                textView.text = cleanContent
            }
        }

        lastText = html
    }

    func updateFontSize(textView: UITextView, fontSize: Double) {
        guard let currentAttr = textView.attributedText else { return }
        let mutable = NSMutableAttributedString(attributedString: currentAttr)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
        textView.attributedText = mutable

        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: UIColor.label
        ]
    }

    // --- 3. INTERCEPTION CLAVIER ---
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }

    // --- 4. VERIFICATION APRES FRAPPE ---
    func textViewDidChange(_ textView: UITextView) {

        // ✅ FIX ESPACE: Marquer qu'on vient de taper
        isUserTyping = true

        if let attr = textView.attributedText {
            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               let fullHtml = String(data: data, encoding: .utf8) {

                if parent.text != fullHtml {
                    lastText = fullHtml
                    parent.text = fullHtml
                }
            }
        }

        // Maintien visuel
        textView.font = UIFont.systemFont(ofSize: CGFloat(parent.fontSize))
        textView.textColor = UIColor.label

        // Hauteur
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
