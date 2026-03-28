// MARK: - Environment Keys & Values

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues: @unchecked Sendable {
    private var values: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { (values[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }

    /// Merge another set of values on top of this one (overrides take priority).
    public func merging(_ overrides: EnvironmentValues) -> EnvironmentValues {
        var result = self
        for (key, value) in overrides.values {
            result.values[key] = value
        }
        return result
    }
}

// MARK: - Standard Environment Keys

public enum Platform: Sendable {
    case windows
    case macOS
    case linux
}

private struct PlatformKey: EnvironmentKey {
    static let defaultValue: Platform = {
        #if os(Windows)
        return .windows
        #elseif os(macOS)
        return .macOS
        #else
        return .linux
        #endif
    }()
}

public enum ColorScheme: Sendable {
    case light
    case dark
}

private struct ColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .dark
}

extension EnvironmentValues {
    public var platform: Platform {
        get { self[PlatformKey.self] }
        set { self[PlatformKey.self] = newValue }
    }

    public var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
}

// MARK: - Environment Property Wrapper

/// Type-erased protocol so ViewResolver can inject environment values via reflection.
protocol AnyEnvironment {
    func inject(_ values: EnvironmentValues)
}

@propertyWrapper
public struct Environment<Value>: @unchecked Sendable, AnyEnvironment {
    private let keyPath: KeyPath<EnvironmentValues, Value>
    private class Storage {
        var values: EnvironmentValues? = nil
    }
    private let storage = Storage()

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        (storage.values ?? EnvironmentValues())[keyPath: keyPath]
    }

    func inject(_ values: EnvironmentValues) {
        storage.values = values
    }
}

// MARK: - Environment Modifier

/// A view modifier that injects a value into the environment for a subtree.
public struct EnvironmentModifier<V>: ViewModifier {
    let keyPath: WritableKeyPath<EnvironmentValues, V>
    let value: V

    public func apply(to node: LayoutNode) {
        // Environment propagation happens in ViewResolver, not on the node.
    }
}

extension View {
    /// Set an environment value for this view's subtree.
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> ModifiedView<Self, EnvironmentModifier<V>> {
        ModifiedView(content: self, modifier: EnvironmentModifier(keyPath: keyPath, value: value))
    }
}

// MARK: - EnvironmentStore

/// Global store for environment values during a view resolution pass.
/// ViewResolver pushes/pops scopes as it enters/leaves subtrees with environment overrides.
public class EnvironmentStore: @unchecked Sendable {
    public static let shared = EnvironmentStore()
    private init() {}

    private var stack: [EnvironmentValues] = [EnvironmentValues()]

    /// The current environment values (top of stack).
    public var current: EnvironmentValues {
        stack.last ?? EnvironmentValues()
    }

    /// Push a new environment scope (inheriting + merging overrides).
    public func push(_ overrides: EnvironmentValues) {
        stack.append(current.merging(overrides))
    }

    /// Pop the current scope, returning to the parent environment.
    @discardableResult
    public func pop() -> EnvironmentValues {
        guard stack.count > 1 else { return current }
        return stack.removeLast()
    }

    /// Reset to a fresh root environment (called at start of each resolution pass).
    public func reset(with base: EnvironmentValues = EnvironmentValues()) {
        stack = [base]
    }
}
