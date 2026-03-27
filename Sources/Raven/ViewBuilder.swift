// MARK: - ViewBuilder Result Builder

/// Enables the declarative `{ ... }` syntax for building view trees.
@resultBuilder
public struct ViewBuilder {
    // Single child
    public static func buildBlock<C0: View>(_ c0: C0) -> C0 {
        c0
    }

    // Two children
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView2<C0, C1> {
        TupleView2(c0, c1)
    }

    // Three children
    public static func buildBlock<C0: View, C1: View, C2: View>(
        _ c0: C0, _ c1: C1, _ c2: C2
    ) -> TupleView3<C0, C1, C2> {
        TupleView3(c0, c1, c2)
    }

    // Four children
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3
    ) -> TupleView4<C0, C1, C2, C3> {
        TupleView4(c0, c1, c2, c3)
    }

    // Five children
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4
    ) -> TupleView5<C0, C1, C2, C3, C4> {
        TupleView5(c0, c1, c2, c3, c4)
    }

    // Six children
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5
    ) -> TupleView6<C0, C1, C2, C3, C4, C5> {
        TupleView6(c0, c1, c2, c3, c4, c5)
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
