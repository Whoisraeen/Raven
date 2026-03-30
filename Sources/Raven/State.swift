import Swift

// MARK: - State Property Wrapper

public protocol AnyState {
    func setViewPath(_ path: String)
}

/// A property wrapper that stores mutable state and triggers
/// a re-render when the value changes.
@propertyWrapper
public struct State<Value: Sendable>: @unchecked Sendable, AnyState {
    private class Storage {
        var value: Value
        var viewPath: String? = nil
        init(_ value: Value) { self.value = value }
    }

    private let storage: Storage

    public init(wrappedValue: Value) {
        self.storage = Storage(wrappedValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set {
            storage.value = newValue
            if let path = storage.viewPath {
                StateTracker.shared.markDirty(path: path)
            } else {
                StateTracker.shared.markDirty()
            }
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }

    public func setViewPath(_ path: String) {
        storage.viewPath = path
    }
}

// MARK: - Published Property Wrapper

/// A property wrapper for use inside ObservableObject classes.
/// Triggers a re-render when the value changes, just like @State.
///
/// Usage:
/// ```swift
/// class AppState: ObservableObject {
///     @Published var count = 0
///     @Published var name = "Raven"
/// }
/// ```
@propertyWrapper
public struct Published<Value: Sendable>: @unchecked Sendable {
    private class Storage {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private let storage: Storage

    public init(wrappedValue: Value) {
        self.storage = Storage(wrappedValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set {
            storage.value = newValue
            StateTracker.shared.markDirty()
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

// MARK: - Binding

/// A two-way reference to a value owned by a parent view.
/// Child views use `@Binding` to read and write a parent's state.
@propertyWrapper
public struct Binding<Value>: @unchecked Sendable {
    private let getter: @Sendable () -> Value
    private let setter: @Sendable (Value) -> Void

    public init(get: @escaping @Sendable () -> Value, set: @escaping @Sendable (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    /// Allows passing $binding to child views.
    public var projectedValue: Binding<Value> {
        self
    }

    /// Create a read-only binding with a constant value.
    public static func constant(_ value: Value) -> Binding<Value> where Value: Sendable {
        Binding(get: { value }, set: { _ in })
    }
}

// MARK: - ObservableObject

/// A protocol for reference-type state containers.
/// Classes conforming to ObservableObject hold @Published properties
/// that automatically trigger re-renders when mutated.
///
/// Usage:
/// ```swift
/// class AppState: ObservableObject {
///     @Published var count = 0
///     @Published var items: [String] = []
/// }
///
/// let state = AppState()
/// let app = RavenApp(title: "Demo") {
///     Text("Count: \(state.count)")
///     Button("Increment") { state.count += 1 }
/// }
/// ```
public protocol ObservableObject: AnyObject {}

// MARK: - StateVar

/// A standalone reactive value for use in closures and top-level code
/// where @State property wrappers aren't supported.
///
/// Usage:
/// ```swift
/// let count = StateVar(0)
/// let name = StateVar("Raven")
///
/// let app = RavenApp(title: "Demo") {
///     Text("Count: \(count.value)")
///     Button("Increment") { count.value += 1 }
/// }
/// ```
public class StateVar<Value: Sendable>: @unchecked Sendable {
    private var _value: Value

    public init(_ value: Value) {
        self._value = value
    }

    /// The current value. Setting this triggers a re-render.
    public var value: Value {
        get { _value }
        set {
            _value = newValue
            StateTracker.shared.markDirty()
        }
    }

    /// A two-way Binding to this value, for passing to child views.
    public var binding: Binding<Value> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
}

// MARK: - State Tracker

/// Global tracker that monitors whether any @State/@Published/StateVar has changed.
/// The app loop checks this each frame to decide whether to re-render.
/// Thread-safe via an unfair lock so background closures can safely mutate state.
public class StateTracker: @unchecked Sendable {
    @MainActor public static let shared = StateTracker()

    private var dirty = false
    public private(set) var dirtyPaths: Set<String> = []
    private let lock = RavenLock()

    private init() {}

    /// Mark that a state value has changed globally.
    public func markDirty() {
        lock.withLock {
            dirty = true
        }
    }

    /// Mark a specific view path as dirty.
    public func markDirty(path: String) {
        lock.withLock {
            dirty = true
            dirtyPaths.insert(path)
        }
    }

    /// Check and clear the dirty flag.
    /// Returns the set of dirty paths if any state changed since last check, nil otherwise.
    public func checkAndClear() -> Set<String>? {
        lock.withLock {
            guard dirty else { return nil }
            let paths = dirtyPaths
            dirty = false
            dirtyPaths.removeAll()
            return paths
        }
    }
}
