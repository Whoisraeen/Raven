// MARK: - Picker

/// A selection control that allows choosing from a list of options.
/// Supports two visual styles: `.segmented` (inline horizontal buttons)
/// and `.menu` (dropdown that expands on click).
///
/// Usage:
/// ```swift
/// let selectedTab = StateVar(0)
///
/// // Segmented control (default):
/// Picker("View", selection: selectedTab.binding, options: ["Day", "Week", "Month"])
///
/// // Dropdown menu:
/// Picker("Sort By", selection: sortIndex.binding, options: ["Name", "Date", "Size"])
///     .pickerStyle(.menu)
/// ```
public struct Picker: View {
    public typealias Body = Never
    public var body: Never { fatalError("Picker is a primitive view") }

    /// Label for the picker (shown to the left or above).
    public let label: String

    /// Binding to the selected index.
    public let selection: Binding<Int>

    /// The list of string options.
    public let options: [String]

    /// The visual style of the picker.
    public var style: PickerStyle = .segmented

    public init(_ label: String = "", selection: Binding<Int>, options: [String]) {
        self.label = label
        self.selection = selection
        self.options = options
    }

    /// Set the visual style for the Picker (`.segmented` or `.menu`).
    /// Returns a new Picker with the updated style.
    public func pickerStyle(_ style: PickerStyle) -> Picker {
        var copy = self
        copy.style = style
        return copy
    }
}
