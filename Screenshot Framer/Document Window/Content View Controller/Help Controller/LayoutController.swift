//
//  LayoutController.swift
//  Screenshot Framer
//
//  Created by Patrick Kladek on 12.12.17.
//  Copyright © 2017 Patrick Kladek. All rights reserved.
//

import Cocoa

enum LayoutError: String {
    case none = """
                - No errors
                  Everything went fine
                """
    case noLayers = """
                    - No layers present.
                      Check your project file and make sure it contains at least one layer
                    """
    case fontToBig = """
                     - The font of one label is too big. This often happens in a different language than you design.
                       Check all languages in your project and decrease the font size or increase the frame of the label
                       The font is decresed on affected labels so the contents fit on screen.
                       You can ignore this warning with the '-ignoreFontToBig' flag
                     """
    case noOutputFile = """
                        - You forgot to specify an output path or entered an incorrect one.
                          The default path is: 'Export/$language/iPhone XXX-$image framed.png'
                        """
}


class LayoutController {

    // MARK: - Properties

    let viewStateController: ViewStateController
    let languageController: LanguageController
    var highlightLayer: Int = 0
    var shouldHighlightSelectedLayer = false
    var fileController: FileController
    private(set) var layoutErrors: [LayoutError] = []


    // MARK: Init

    init(viewStateController: ViewStateController, languageController: LanguageController, fileController: FileController) {
        self.viewStateController = viewStateController
        self.languageController = languageController
        self.fileController = fileController
    }


    // MARK: - Public Functions

    func layouthierarchy(layers: [LayoutableObject]) -> NSView? {
        self.layoutErrors = []
        guard layers.hasElements else { self.layoutErrors = [.noLayers]; return nil }

        let firstLayoutableObject = layers[0]
        let rootView = self.view(from: firstLayoutableObject)
        (rootView as? SSFView)?.backgroundColor = NSColor.lightGray

        for object in layers where object != layers[0] {
            let view: NSView

            if object.type == .text {
                view = self.textField(from: object)
            } else {
                view = self.view(from: object)
            }

            if self.shouldHighlightSelectedLayer && object == layers[self.highlightLayer] {
                view.wantsLayer = true
                view.layer?.borderColor = NSColor.red.cgColor
                view.layer?.borderWidth = 2.0
            }

            rootView.addSubview(view)
        }
        return rootView
    }
}


// MARK: - Private

private extension LayoutController {

    func textField(from object: LayoutableObject) -> NSTextView {
        let viewState = self.viewStateController.viewState
        let absoluteURL = self.fileController.absoluteURL(for: object.file, viewState: viewState)
        let text = self.fileController.localizedTitle(from: absoluteURL, viewState: viewState)

        let textView = NSTextView(frame: object.frame)
//        textView.textColor = NSColor.white
        textView.backgroundColor = NSColor.clear
        textView.isEditable = false
//        textView.alignment = .center
        textView.textContainer?.lineBreakMode = .byTruncatingTail
        textView.maxSize = object.frame.size

        if let text = text {
            let cssFile = object.file.replacingOccurrences(of: ".strings", with: ".css")
            let cssURL = self.fileController.absoluteURL(for: cssFile, viewState: viewState)
            if let cssURL = cssURL, let cssData = try? Data(contentsOf: cssURL) {
                let cssText = String(data: cssData, encoding: .utf8)!
                let htmlText = "<html><head><style>\(cssText)</style></head><body>\(text)</body></html>"
                let htmlData = htmlText.data(using: .utf16)!
                let attributedText = NSAttributedString(html: htmlData, documentAttributes: nil)!
                textView.textStorage?.setAttributedString(attributedText)
            } else {
                textView.textStorage?.setAttributedString(NSAttributedString(string: text))
            }
        } else {
            textView.backgroundColor = NSColor.red
        }

//        textView.font = self.font(for: object)

//        if !self.fitText(for: textView) {
//            self.layoutErrors.append(.fontToBig)
//        }

        return textView
    }

    func fitText(for textView: NSTextView) -> Bool {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer, let textStorage = textView.textStorage else { return true }

        layoutManager.ensureLayout(for: textContainer)

        let kMinFontSize = CGFloat(6.0)
        let viewSize = textView.bounds.size

        let font = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        var fontSize = font.pointSize
        var textSize = layoutManager.usedRect(for: textContainer).size
        while !viewSize.contains(textSize) && fontSize > kMinFontSize {
            fontSize -= 0.5
            guard let newFont = NSFont(name: font.fontName, size: fontSize) else { return false }
            textStorage.font = newFont
            layoutManager.ensureLayout(for: textContainer)
            textSize = layoutManager.usedRect(for: textContainer).size
        }

        return viewSize.contains(textSize)
    }

//    @discardableResult
//    func limitFontSize(for textField: NSTextView) -> Bool {
//        guard let font = textField.font else { return false }
//        guard let fontSizeObject = font.fontDescriptor.object(forKey: NSFontDescriptor.AttributeName.size) as? NSNumber else { return false }
//
//        var fontSize = CGFloat(fontSizeObject.floatValue)
//        let kMinFontSize = CGFloat(6.0)
//        let frame = textField.frame
//        let string = textField.textStorage?.string as NSString
//        var limited = false
//
//        func calculateStringSize(withFont font: NSFont) -> CGSize {
//            textField.font = font
//            return textField.sizeThatFits(CGSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude))
//        }
//
//        var size = calculateStringSize(withFont: NSFont(name: font.fontName, size: fontSize)!)
//        while (size.width >= frame.width || size.height >= frame.height) && fontSize > kMinFontSize {
//            limited = true
//            fontSize -= 0.5
//            let newFontSize = CGFloat(fontSize)
//            guard let newFont = NSFont(name: font.fontName, size: newFontSize) else { return limited }
//
//            size = calculateStringSize(withFont: newFont)
//        }
//        return limited
//    }

    func view(from object: LayoutableObject) -> NSView {
        let viewState = self.viewStateController.viewState
        if let url = self.fileController.absoluteURL(for: object.file, viewState: viewState) {
            let imageView = NSImageView(frame: object.frame)
            imageView.image = NSImage(contentsOf: url)
            imageView.imageScaling = .scaleAxesIndependently
            imageView.layer?.shouldRasterize = true
            imageView.frameCenterRotation = object.rotation ?? 0
            return imageView
        } else {
            let view = SSFView(frame: object.frame)
            view.backgroundColor = NSColor.red
            view.frameCenterRotation = object.rotation ?? 0
            return view
        }
    }

    func font(for object: LayoutableObject) -> NSFont? {
        var fontName: String?

        if let fontFamily = object.font {
            fontName = fontFamily
        }

        // swiftlint:disable:next empty_count
        if fontName == nil || fontName?.count == 0 {
            fontName = "Helvetica Neue"
        }

        let font = NSFont(name: fontName!, size: object.fontSize ?? 25)
        return font
    }
}

extension CGSize {
    func contains(_ other: CGSize) -> Bool {
        return (other.width <= width) && (other.height <= height)
    }
}
