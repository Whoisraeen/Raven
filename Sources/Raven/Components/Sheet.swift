// MARK: - Sheet (Modal Overlay)

/// A modal sheet that overlays content on top of the current view.
/// Controlled by a boolean binding that determines visibility.
///
/// Usage:
/// ```swift
/// let showSettings = StateVar(false)
///
/// VStack {
///     Button("Open Settings") { showSettings.value = true }
/// }
/// .sheet(isPresented: showSettings.binding) {
///     VStack {
///         Text("Settings")
///         Button("Close") { showSettings.value = false }
///     }
///     .padding(24)
///     .background(.surface)
///     .cornerRadius(12)
/// }
/// ```
public struct Sheet: View {
    public typealias Body = Never
    public var body: Never { fatalError("Sheet is a primitive view") }

    /// Binding that controls whether the sheet is visible.
    public let isPresented: Binding<Bool>

    /// The content of the sheet.
    public let content: [any View]

    public init(isPresented: Binding<Bool>, content: [any View]) {
        self.isPresented = isPresented
        self.content = content
    }
}

/// Modifier to attach a sheet to any view.
public struct SheetModifier: ViewModifier {
    public let isPresented: Binding<Bool>
    public let sheetContent: [any View]

    public func apply(to node: LayoutNode) {
        node.hasSheet = true
        node.sheetIsPresented = isPresented
    }
}

extension View {
    /// Present a modal sheet overlay when `isPresented` is true.
    public func sheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) -> ModifiedView<Self, SheetModifier> {
        ModifiedView(
            content: self,
            modifier: SheetModifier(isPresented: isPresented, sheetContent: [content()])
        )
    }
}
