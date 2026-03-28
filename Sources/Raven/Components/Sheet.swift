// MARK: - Sheet (Modal Overlay)

/// A modal overlay that appears on top of the current content.
/// Controlled by a boolean binding — set to true to present, false to dismiss.
///
/// Usage:
/// ```swift
/// @State var showSettings = false
///
/// var body: some View {
///     ZStack {
///         Button("Open Settings") { showSettings = true }
///
///         Sheet(isPresented: $showSettings) {
///             VStack {
///                 Text("Settings")
///                 Button("Close") { showSettings = false }
///             }
///             .padding(24)
///             .background(.surface)
///             .cornerRadius(12)
///         }
///     }
/// }
/// ```
public struct Sheet: View {
    public typealias Body = Never
    public var body: Never { fatalError("Sheet is a primitive view") }

    public let isPresented: Binding<Bool>
    internal let sheetContent: [any View]

    /// Width and height of the sheet (nil = auto-size from content).
    public let sheetWidth: Float?
    public let sheetHeight: Float?

    public init(
        isPresented: Binding<Bool>,
        width: Float? = nil,
        height: Float? = nil,
        @ViewBuilder content: () -> some View
    ) {
        self.isPresented = isPresented
        self.sheetWidth = width
        self.sheetHeight = height
        self.sheetContent = [content()]
    }
}
