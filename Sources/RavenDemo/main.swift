import Raven

// Reactive state — captured by reference in the content closure.
// When .value is set, Raven automatically re-renders.
let count = StateVar(0)

let app = RavenApp(title: "Raven Demo", width: 960, height: 640) {
    VStack(spacing: 20) {
        // Title
        Text("Hello from Raven!")
            .foreground(.white)
            .padding(16)
            .background(.surface)

        // Live counter display — updates on every state change
        Text("Count: \(count.value)")
            .foreground(.white)
            .padding(12)
            .background(.primary)

        // Controls
        HStack(spacing: 12) {
            Button("- Decrease") {
                count.value -= 1
            }

            Button("+ Increase") {
                count.value += 1
            }
        }

        // Color showcase
        HStack(spacing: 12) {
            Text("Red")
                .padding(12)
                .background(.red)

            Text("Green")
                .padding(12)
                .background(.green)

            Text("Blue")
                .padding(12)
                .background(.blue)
        }

        // Push reset button to the bottom
        Spacer()

        // Reset button
        Button("Reset") {
            count.value = 0
        }
    }
    .padding(32)
    .background(Color(0.10, 0.12, 0.16))
}

app.run()
