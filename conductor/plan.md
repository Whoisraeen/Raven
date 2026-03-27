# Implementation Plan: TrueType Text Shaping & Accessibility Hooks

## 1. Objective
Transform Raven from a high-performance graphics demo into a viable UI framework by replacing the hardcoded 8x16 bitmap font system with true proportional TrueType/OpenType text shaping and measurement, and injecting the foundational Accessibility (A11y) hooks directly into the layout and view hierarchy.

## 2. Scope & Impact
- **Text Shaping:** We will utilize the existing `CSTBTrueType` (`stb_truetype`) integration to measure text accurately during the Layout pass, rather than guessing sizes. This includes applying kerning and accurate advance widths.
- **Accessibility:** We will introduce the core data structures for an Accessibility Tree. This requires adding A11y properties to `LayoutNode`, setting default roles for primitives (Button, Text, TextField), and adding standard `.accessibilityLabel()` View Modifiers so developers can annotate their UI.

## 3. Key Files to Modify
- `Sources/Raven/Renderer/FontManager.swift`
- `Sources/Raven/LayoutNode.swift`
- `Sources/Raven/RenderCollector.swift`
- `Sources/Raven/Components/Text.swift`, `Button.swift`
- `Sources/Raven/ViewResolver.swift`
- `Sources/Raven/ViewModifiers.swift`

## 4. Implementation Steps

### Phase 1: TrueType Proportional Text Measurement
1. **Add Measurement to FontManager:**
   - Add a `measureText(_ text: String, fontSize: Float) -> (width: Float, height: Float)` method to `FontManager.swift`.
   - This method will iterate through the text's characters, fetch advances and kerning from `stb_truetype`, and return the exact pixel bounds.
2. **Update LayoutNode Intrinsic Sizes:**
   - In `LayoutNode.swift`, update `intrinsicWidth` and `intrinsicHeight`. Instead of `Float(text.count) * 8.0`, call `FontManager.shared.measureText(text, fontSize: 16.0)` (assuming 16pt default for now).
3. **Update RenderCollector Positioning:**
   - In `RenderCollector.swift`, when emitting a `TextDrawCommand`, remove the references to `FontAtlas.glyphWidth` and `FontAtlas.glyphHeight`. Use the new measurement to perfectly center text inside its parent bounds.

### Phase 2: Basic Accessibility Hooks
1. **Define Accessibility Models:**
   - Create `Sources/Raven/Accessibility.swift` (or similar).
   - Define `AccessibilityRole` enum (`button`, `text`, `textField`, `image`, `group`, `window`).
2. **Expand LayoutNode:**
   - Add A11y properties to `LayoutNode`: `accessibilityRole`, `accessibilityLabel`, `accessibilityValue`, `accessibilityHint`, `isAccessibilityElement`.
3. **Map Primitives in ViewResolver:**
   - Automatically assign roles during resolution. E.g., `Text` sets `role = .text` and `label = content`. `Button` sets `role = .button`. `TextField` sets `role = .textField`.
4. **Create View Modifiers:**
   - Add new modifiers in `ViewModifiers.swift`:
     - `.accessibilityLabel(_ label: String)`
     - `.accessibilityValue(_ value: String)`
     - `.accessibilityHidden(_ hidden: Bool)`
   - Implement the `apply(to:)` logic to map these into `LayoutNode`.
5. **Accessibility Tree Hook:**
   - Create an `AccessibilityCollector` (similar to `RenderCollector`) that walks the `LayoutNode` tree and builds an OS-agnostic accessibility representation.

## 5. Verification
- **Visual:** Run the demo app and verify that text elements have tight layout bounds, correctly spaced characters, and are perfectly centered within buttons/containers.
- **A11y:** Print the derived accessibility tree to the console after layout to verify that buttons and text fields correctly propagate their roles and labels to the leaf nodes.