// MARK: - View Protocol

/// The base protocol for all Raven UI components.
/// Every view must declare a `body` that returns its content.
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

// MARK: - Primitive Views (terminal nodes — they don't have a body)

/// A view that draws nothing.
public struct EmptyView: View {
    public typealias Body = Never
    public var body: Never { fatalError("EmptyView has no body") }
    public init() {}
}

extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError("Never has no body") }
}

// MARK: - TupleView (holds multiple child views)

public struct TupleView2<C0: View, C1: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("TupleView2 has no body") }
    public let c0: C0
    public let c1: C1
    public init(_ c0: C0, _ c1: C1) { self.c0 = c0; self.c1 = c1 }
}

public struct TupleView3<C0: View, C1: View, C2: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("TupleView3 has no body") }
    public let c0: C0
    public let c1: C1
    public let c2: C2
    public init(_ c0: C0, _ c1: C1, _ c2: C2) { self.c0 = c0; self.c1 = c1; self.c2 = c2 }
}

public struct TupleView4<C0: View, C1: View, C2: View, C3: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("TupleView4 has no body") }
    public let c0: C0
    public let c1: C1
    public let c2: C2
    public let c3: C3
    public init(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) {
        self.c0 = c0; self.c1 = c1; self.c2 = c2; self.c3 = c3
    }
}

public struct TupleView5<C0: View, C1: View, C2: View, C3: View, C4: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("TupleView5 has no body") }
    public let c0: C0
    public let c1: C1
    public let c2: C2
    public let c3: C3
    public let c4: C4
    public init(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) {
        self.c0 = c0; self.c1 = c1; self.c2 = c2; self.c3 = c3; self.c4 = c4
    }
}

public struct TupleView6<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("TupleView6 has no body") }
    public let c0: C0
    public let c1: C1
    public let c2: C2
    public let c3: C3
    public let c4: C4
    public let c5: C5
    public init(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) {
        self.c0 = c0; self.c1 = c1; self.c2 = c2; self.c3 = c3; self.c4 = c4; self.c5 = c5
    }
}

// MARK: - Optional / Conditional Views

public struct OptionalView<Content: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("OptionalView has no body") }
    public let content: Content?
    public init(_ content: Content?) { self.content = content }
}

public struct ConditionalView<TrueContent: View, FalseContent: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError("ConditionalView has no body") }
    public enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
    public let storage: Storage
}

// MARK: - Modified View

public struct ModifiedView<Content: View, Modifier: ViewModifier>: View {
    public typealias Body = Never
    public var body: Never { fatalError("ModifiedView has no body") }
    public let content: Content
    public let modifier: Modifier
    public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}

/// Protocol for view modifiers
public protocol ViewModifier {
    func apply(to node: LayoutNode)
}
