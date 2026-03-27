// MARK: - Spacer

/// A flexible space element that expands to fill available space
/// in a VStack or HStack.
public struct Spacer: View {
    public typealias Body = Never
    public var body: Never { fatalError("Spacer is a primitive view") }

    public init() {}
}
