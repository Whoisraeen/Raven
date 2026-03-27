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

public protocol AnyTupleView {
    var childrenViews: [any View] { get }
}

public struct TupleView<each Content: View>: View, AnyTupleView {
    public typealias Body = Never
    public var body: Never { fatalError("TupleView has no body") }
    
    public let value: (repeat each Content)
    public let childrenViews: [any View]
    
    public init(_ content: repeat each Content) {
        self.value = (repeat each content)
        
        var views: [any View] = []
        repeat views.append(each content)
        self.childrenViews = views
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
