import Raven

// MARK: - State

let selectedTab = StateVar("home")
let count = StateVar(0)
let isExpanded = StateVar(false)
let showSheet = StateVar(false)
let searchText = StateVar("")

// MARK: - App

let app = RavenApp(title: "Raven Demo", width: 1024, height: 680) {
    Sidebar(width: 200) {
        // Sidebar content
        VStack(alignment: .leading, spacing: 0) {
            Text("Raven")
                .foreground(.white)
                .padding(16)

            SidebarItem(label: "Home", isSelected: selectedTab.value == "home") {
                selectedTab.value = "home"
            }
            SidebarItem(label: "Animation", isSelected: selectedTab.value == "animation") {
                selectedTab.value = "animation"
            }
            SidebarItem(label: "Layout", isSelected: selectedTab.value == "layout") {
                selectedTab.value = "layout"
            }
            SidebarItem(label: "Input", isSelected: selectedTab.value == "input") {
                selectedTab.value = "input"
            }

            Spacer()
        }
    } detail: {
        // Detail content based on selected tab
        if selectedTab.value == "home" {
            homeTab()
        } else if selectedTab.value == "animation" {
            animationTab()
        } else if selectedTab.value == "layout" {
            layoutTab()
        } else if selectedTab.value == "input" {
            inputTab()
        }
    }

    // Modal sheet overlay
    Sheet(isPresented: showSheet.binding, width: 400, height: 250) {
        VStack(spacing: 16) {
            Text("Modal Sheet")
                .foreground(.white)
                .padding(8)

            Text("This is a modal overlay controlled by a Binding.")
                .foreground(Color(0.7, 0.7, 0.7))

            Spacer()

            Button("Close") {
                showSheet.value = false
            }
        }
    }
}

// MARK: - Tabs

func homeTab() -> some View {
    VStack(spacing: 20) {
        Text("Welcome to Raven")
            .foreground(.white)
            .padding(16)

        Text("A declarative UI framework for desktop apps.")
            .foreground(Color(0.7, 0.7, 0.7))
            .padding(8)

        HStack(spacing: 12) {
            Button("Open Sheet") {
                showSheet.value = true
            }

            Button("Count: \(count.value)") {
                count.value += 1
            }
        }

        Spacer()
    }
    .padding(24)
}

func animationTab() -> some View {
    VStack(spacing: 20) {
        Text("Animation Demo")
            .foreground(.white)
            .padding(12)

        // Toggle between two layouts with spring animation
        HStack {
            if isExpanded.value {
                Text("EXPANDED")
                    .foreground(.white)
                    .padding(30)
                    .background(.primary)
                    .cornerRadius(15)
            } else {
                Text("COLLAPSED")
                    .foreground(.white)
                    .padding(12)
                    .background(.surface)
                    .cornerRadius(6)
            }
        }

        HStack(spacing: 12) {
            Button("Spring Toggle") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isExpanded.value.toggle()
                }
            }

            Button("Ease In/Out") {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isExpanded.value.toggle()
                }
            }

            Button("Linear") {
                withAnimation(.linear(duration: 0.3)) {
                    count.value += 1
                }
            }
        }

        Text("Count: \(count.value)")
            .foreground(Color(0.6, 0.6, 0.6))

        Spacer()
    }
    .padding(24)
}

func layoutTab() -> some View {
    VStack(spacing: 20) {
        Text("Layout Demo")
            .foreground(.white)
            .padding(12)

        // FlowStack (flex-wrap)
        Text("FlowStack (wrapping):")
            .foreground(Color(0.7, 0.7, 0.7))

        FlowStack(spacing: 8, lineSpacing: 8) {
            Text("Swift")
                .foreground(.white)
                .padding(8)
                .background(.primary)
                .cornerRadius(4)
            Text("Vulkan")
                .foreground(.white)
                .padding(8)
                .background(.primary)
                .cornerRadius(4)
            Text("SDL3")
                .foreground(.white)
                .padding(8)
                .background(.primary)
                .cornerRadius(4)
            Text("Rust FFI")
                .foreground(.white)
                .padding(8)
                .background(.primary)
                .cornerRadius(4)
            Text("SDF Text")
                .foreground(.white)
                .padding(8)
                .background(.primary)
                .cornerRadius(4)
            Text("Animations")
                .foreground(.white)
                .padding(8)
                .background(.primary)
                .cornerRadius(4)
        }

        // Baseline alignment
        Text("Baseline alignment:")
            .foreground(Color(0.7, 0.7, 0.7))

        HStack(spacing: 12) {
            Text("Large")
                .foreground(.white)
                .padding(12)
            Text("Medium")
                .foreground(.white)
                .padding(8)
            Text("Small")
                .foreground(.white)
                .padding(4)
        }
        .alignToBaseline()

        Spacer()
    }
    .padding(24)
}

func inputTab() -> some View {
    VStack(spacing: 20) {
        Text("Input Demo")
            .foreground(.white)
            .padding(12)

        HStack(spacing: 12) {
            Text("Search:")
                .foreground(Color(0.7, 0.7, 0.7))
            TextField("Type something...", text: searchText.binding)
        }

        if !searchText.value.isEmpty {
            Text("You typed: \(searchText.value)")
                .foreground(Color(0.5, 0.8, 0.5))
                .padding(8)
        }

        Spacer()

        Text("Press ESC or close the window to exit.")
            .foreground(Color(0.4, 0.4, 0.4))
    }
    .padding(24)
}

app.run()
