import AppKit
import SwiftUI

/// Native editing explicitly claims keyboard focus when the user clicks to type.
final class AssistantTextField: NSTextField {
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
struct AssistantInput: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusToken: Int
    var submit: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> AssistantTextField {
        let field = AssistantTextField(string: text)
        field.isBordered = false; field.drawsBackground = false; field.focusRingType = .none
        field.font = .systemFont(ofSize: 14, weight: .medium); field.textColor = .white
        field.isEditable = true; field.isSelectable = true
        field.cell?.isScrollable = true; field.maximumNumberOfLines = 1
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.target = nil; field.action = nil
        (field.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = false
        field.identifier = NSUserInterfaceItemIdentifier("VELINPrompt")
        return field
    }
    func updateNSView(_ field: AssistantTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            let editor = field.currentEditor() as? NSTextView
            if editor?.hasMarkedText() != true {
                field.stringValue = text
                if let editor, editor.string != text { editor.string = text; editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0)) }
            }
        }
        field.placeholderString = placeholder
        if context.coordinator.focusToken != focusToken {
            context.coordinator.focusToken = focusToken
            DispatchQueue.main.async { [weak field] in
                guard let field, let window = field.window else { return }
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil); window.makeFirstResponder(field)
            }
        }
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AssistantInput
        var focusToken = 0
        init(_ parent: AssistantInput) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.text = textView.string; parent.submit(); return true
        }
    }
}

final class SpeechDraftTextView: NSTextView {
    var submit: () -> Void = {}
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 36 || event.keyCode == 76), !event.modifierFlags.contains(.shift) {
            submit(); return
        }
        super.keyDown(with: event)
    }
}
/// Follow new speech at the end until the user edits. Edited text isn't replaced
/// by subsequent recognition updates, and native scrolling remains available.
struct SpeechDraftEditor: NSViewRepresentable {
    @ObservedObject var model: AppModel
    var compact = false
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false; scroll.hasVerticalScroller = false; scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        let view = SpeechDraftTextView(frame: .zero)
        view.drawsBackground = false; view.isRichText = false; view.importsGraphics = false
        view.isEditable = true; view.isSelectable = true; view.allowsUndo = true
        view.textColor = .white; view.insertionPointColor = NSColor(red: 0.64, green: 0.93, blue: 0.84, alpha: 1)
        view.font = .systemFont(ofSize: compact ? 11 : 13)
        view.textContainerInset = NSSize(width: 8, height: 6)
        view.isVerticallyResizable = true; view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
        view.minSize = .zero; view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.delegate = context.coordinator
        view.identifier = NSUserInterfaceItemIdentifier("VELINSpeechDraft")
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? SpeechDraftTextView else { return }
        view.submit = { [weak model] in model?.ask() }
        let text = model.pendingHeardQuestion
        if view.string != text {
            let atEnd = scroll.contentView.bounds.maxY >= view.bounds.height - 8
            let followLive = !model.heardQuestion.isEdited && (view.string.isEmpty || atEnd || context.coordinator.wasEdited)
            let origin = scroll.contentView.bounds.origin
            view.string = text
            if followLive { view.scrollRangeToVisible(NSRange(location: (text as NSString).length, length: 0)) }
            else { scroll.contentView.scroll(to: origin); scroll.reflectScrolledClipView(scroll.contentView) }
        }
        context.coordinator.wasEdited = model.heardQuestion.isEdited
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SpeechDraftEditor
        var wasEdited = false
        init(_ parent: SpeechDraftEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.model.heardQuestion.edit(view.string)
        }
    }
}
