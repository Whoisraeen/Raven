import Swift

// MARK: - State Property Wrapper

/// A property wrapper that stores mutable state and triggers
/// a re-render when the value changes.
///
/// Usage inside View structs:
/// ```swift
/// struct CounterView: View {
///     @State var count = 0
///     var body: some View {
///         Button("Count: \(count)") {
///             count += 1
///         }
///     }
/// }
/// ```
@propertyWrapper
public struct State<Value: Sendable>: @unchecked Sendable {
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
public class StateTracker: @unchecked Sendable {
    public static let shared = StateTracker()

    private var dirty = false

    private init() {}

    /// Mark that a state value has changed.
    public func markDirty() {
        dirty = true
    }

    /// Check and clear the dirty flag.
    /// Returns true if any state changed since last check.
    public func checkAndClear() -> Bool {
        let wasDirty = dirty
        dirty = false
        return wasDirty
    }
}
