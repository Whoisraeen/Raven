import Raven
import Foundation

// Animation Demo State
let count = StateVar(0)
let isExpanded = StateVar(false)

let app = RavenApp(title: "Raven Animation Demo", width: 960, height: 640) {
    VStack(spacing: 20) {
        // Title with fixed background
        Text("Raven Animation Engine")
            .foreground(.white)
            .padding(16)
            .background(.surface)
            .cornerRadius(12)

        // Animated Pulse Box
        HStack {
            if isExpanded.value {
                Text("SPRING!")
                    .foreground(.white)
                    .padding(30)
                    .background(.primary)
                    .cornerRadius(15)
            } else {
                Text("STATIC")
                    .foreground(.white)
                    .padding(15)
                    .background(.surface)
                    .cornerRadius(8)
            }
        }
        .padding(20)

        // Controls
        VStack(spacing: 12) {
            Text("Count: \(count.value)")
                .foreground(.white)
                .padding(12)
                .background(.surface)

            HStack(spacing: 12) {
                Button("Animate Counter") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        count.value += 1
                    }
                }

                Button("Toggle Layout") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.value.toggle()
                    }
                }
            }
        }

        Spacer()

        Button("Reset") {
            withAnimation(.easeInOut(duration: 0.5)) {
                count.value = 0
                isExpanded.value = false
            }
        }
    }
    .padding(32)
    .background(Color(0.08, 0.09, 0.12))
}

app.run()
