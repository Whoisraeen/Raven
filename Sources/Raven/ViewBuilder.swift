// MARK: - ViewBuilder Result Builder

/// Enables the declarative `{ ... }` syntax for building view trees.
@resultBuilder
public struct ViewBuilder {
    // Empty block
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    // Variadic buildBlock using parameter packs
    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<repeat each Content> {
        TupleView(repeat each content)
    }

    // Optional (if without else)
    public static func buildOptional<C: View>(_ component: C?) -> OptionalView<C> {
        OptionalView(component)
    }

    // Conditional (if-else)
    public static func buildEither<T: View, F: View>(first component: T) -> ConditionalView<T, F> {
        ConditionalView(storage: .trueContent(component))
    }

    public static func buildEither<T: View, F: View>(second component: F) -> ConditionalView<T, F> {
        ConditionalView(storage: .falseContent(component))
    }
}
