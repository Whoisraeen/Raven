import CSDL3

// MARK: - FocusManager

/// Manages keyboard focus for text input fields.
/// Only one node can have focus at a time.
public class FocusManager: @unchecked Sendable {
    public static let shared = FocusManager()

    /// The currently focused field's ID (matches LayoutNode identity)
    private(set) var focusedFieldId: ObjectIdentifier? = nil

    /// The cursor position (character index) in the focused field
    public private(set) var cursorPosition: Int = 0

    /// The text binding for the focused field
    private var focusedBinding: Binding<String>? = nil

    private init() {}

    /// Set focus to a specific field.
    public func setFocus(fieldId: ObjectIdentifier, binding: Binding<String>) {
        focusedFieldId = fieldId
        focusedBinding = binding
        cursorPosition = binding.wrappedValue.count
        SDL_StartTextInput(nil)
    }

    /// Clear focus (e.g., user clicked outside all fields).
    public func clearFocus() {
        focusedFieldId = nil
        focusedBinding = nil
        cursorPosition = 0
        SDL_StopTextInput(nil)
    }

    /// Check if a specific field has focus.
    public func hasFocus(_ fieldId: ObjectIdentifier) -> Bool {
        focusedFieldId == fieldId
    }

    /// Handle text input (from SDL_EVENT_TEXT_INPUT).
    public func handleTextInput(_ text: String) {
        guard var currentText = focusedBinding?.wrappedValue else { return }

        let insertIndex = currentText.index(
            currentText.startIndex,
            offsetBy: min(cursorPosition, currentText.count)
        )
        currentText.insert(contentsOf: text, at: insertIndex)
        focusedBinding?.wrappedValue = currentText
        cursorPosition += text.count
    }

    /// Handle backspace key.
    public func handleBackspace() {
        guard var currentText = focusedBinding?.wrappedValue,
              cursorPosition > 0 else { return }

        let deleteIndex = currentText.index(
            currentText.startIndex,
            offsetBy: cursorPosition - 1
        )
        currentText.remove(at: deleteIndex)
        focusedBinding?.wrappedValue = currentText
        cursorPosition -= 1
    }

    /// Handle delete key.
    public func handleDelete() {
        guard var currentText = focusedBinding?.wrappedValue,
              cursorPosition < currentText.count else { return }

        let deleteIndex = currentText.index(
            currentText.startIndex,
            offsetBy: cursorPosition
        )
        currentText.remove(at: deleteIndex)
        focusedBinding?.wrappedValue = currentText
    }

    /// Move cursor left.
    public func moveCursorLeft() {
        if cursorPosition > 0 { cursorPosition -= 1 }
    }

    /// Move cursor right.
    public func moveCursorRight() {
        let textLength = focusedBinding?.wrappedValue.count ?? 0
        if cursorPosition < textLength { cursorPosition += 1 }
    }

    /// Move cursor to beginning.
    public func moveCursorHome() {
        cursorPosition = 0
    }

    /// Move cursor to end.
    public func moveCursorEnd() {
        cursorPosition = focusedBinding?.wrappedValue.count ?? 0
    }
}
