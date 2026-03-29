import Raven
import Foundation

// MARK: - Component Demo State

let count = StateVar(0)
let isExpanded = StateVar(false)

// New component state
let isDarkMode = StateVar(false)
let isNotificationsOn = StateVar(true)
let volume = StateVar<Float>(0.5)
let brightness = StateVar<Float>(60)
let selectedTab = StateVar(0)
let sortIndex = StateVar(0)
let downloadProgress = StateVar<Float>(0.65)

let app = RavenApp(title: "Raven Component Showcase", width: 960, height: 640) {
    VStack(spacing: 20) {
        // Title
        Text("Raven Component Showcase")
            .foreground(.white)
            .padding(16)
            .background(.surface)
            .cornerRadius(12)

        // --- Toggle Section ---
        VStack(spacing: 12) {
            Text("Toggles")
                .foreground(.textSecondary)

            Toggle("Dark Mode", isOn: isDarkMode.binding)
            Toggle("Notifications", isOn: isNotificationsOn.binding)

            Text("Dark Mode: \(isDarkMode.value ? "ON" : "OFF")")
                .foreground(.textSecondary)
        }
        .padding(16)
        .background(.surface)
        .cornerRadius(8)

        // --- Slider Section ---
        VStack(spacing: 12) {
            Text("Sliders")
                .foreground(.textSecondary)

            HStack(spacing: 16) {
                Text("Volume:")
                    .foreground(.text)
                Slider(value: volume.binding, in: 0...1)
                Text(String(format: "%.0f%%", volume.value * 100))
                    .foreground(.textSecondary)
            }

            HStack(spacing: 16) {
                Text("Brightness:")
                    .foreground(.text)
                Slider(value: brightness.binding, in: 0...100, step: 10)
                Text(String(format: "%.0f", brightness.value))
                    .foreground(.textSecondary)
            }
        }
        .padding(16)
        .background(.surface)
        .cornerRadius(8)

        // --- Picker Section ---
        VStack(spacing: 12) {
            Text("Pickers")
                .foreground(.textSecondary)

            // Segmented control (default style)
            Picker("View", selection: selectedTab.binding, options: ["Day", "Week", "Month"])

            // Dropdown menu style
            Picker("Sort By", selection: sortIndex.binding, options: ["Name", "Date", "Size"])
                .pickerStyle(.menu)
        }
        .padding(16)
        .background(.surface)
        .cornerRadius(8)

        // --- ProgressView Section ---
        VStack(spacing: 12) {
            Text("Progress")
                .foreground(.textSecondary)

            ProgressView("Downloading...", value: downloadProgress.value)
            ProgressView("Indeterminate")
        }
        .padding(16)
        .background(.surface)
        .cornerRadius(8)

        // --- Controls ---
        HStack(spacing: 12) {
            Button("Animate Counter") {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    count.value += 1
                }
            }

            Button("Reset Progress") {
                downloadProgress.value = 0.0
            }

            Button("+10% Progress") {
                downloadProgress.value = min(downloadProgress.value + 0.1, 1.0)
            }
        }

        Spacer()
    }
    .padding(32)
    .background(Color(0.08, 0.09, 0.12))
}

app.run()
