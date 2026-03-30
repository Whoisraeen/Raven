import Raven

print("Hello from RavenDemo — module loaded OK")

// MARK: - Discord Demo State
let selectedServer = StateVar(1).preserveOnReload("selectedServer")
let selectedChannel = StateVar(0).preserveOnReload("selectedChannel")

// Discord Color Palette
let serverBg = Color(0.118, 0.125, 0.137)   // #1E1F22
let channelBg = Color(0.169, 0.176, 0.192)  // #2B2D31
let chatBg = Color(0.192, 0.200, 0.216)     // #313338
let memberBg = Color(0.169, 0.176, 0.192)   // #2B2D31
let textNormal = Color(0.859, 0.863, 0.878) // #DBDEE1
let textMuted = Color(0.584, 0.608, 0.639)  // #949BA4
let blurple = Color(0.345, 0.396, 0.949)    // #5865F2
let hoverBg = Color(0.247, 0.255, 0.275)    // #3F4147

let channelNames = ["# general", "# announcements", "# development"]

let app = RavenApp(title: "Discord - Raven Framework Demo", width: 1060, height: 720) {
    HStack(spacing: 0) {

        // --- 1. Server List (Far Left, 72px) ---
        VStack(spacing: 12) {
            // Discord Home Icon
            Text("D")
                .foreground(.white)
                .frame(width: 48, height: 48)
                .background(blurple)
                .cornerRadius(24)
                .onTapGesture {
                    selectedServer.value = 0
                }

            Divider()

            // Server 1
            Text("RA")
                .foreground(.white)
                .frame(width: 48, height: 48)
                .background(selectedServer.value == 1 ? blurple : Color(0.19, 0.20, 0.22))
                .cornerRadius(selectedServer.value == 1 ? 16 : 24)
                .onTapGesture {
                    selectedServer.value = 1
                }

            // Server 2
            Text("SW")
                .foreground(.white)
                .frame(width: 48, height: 48)
                .background(selectedServer.value == 2 ? blurple : Color(0.19, 0.20, 0.22))
                .cornerRadius(selectedServer.value == 2 ? 16 : 24)
                .onTapGesture {
                    selectedServer.value = 2
                }

            // Add Server
            Text("+")
                .foreground(.green)
                .frame(width: 48, height: 48)
                .background(Color(0.19, 0.20, 0.22))
                .cornerRadius(24)

            Spacer()
        }
        .padding(12)
        .frame(width: 72)
        .background(serverBg)

        // --- 2. Channel List (240px) ---
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Raven Developers")
                    .foreground(.white)
                Spacer()
            }
            .padding(18)

            Divider()

            // Channels
            VStack(spacing: 2) {
                // Category
                HStack {
                    Text("TEXT CHANNELS")
                        .font(size: 12)
                        .foreground(textMuted)
                    Spacer()
                }
                .padding(12)

                // Channel 1
                HStack {
                    Text("# general")
                        .foreground(selectedChannel.value == 0 ? .white : textMuted)
                    Spacer()
                }
                .padding(8)
                .background(selectedChannel.value == 0 ? hoverBg : .clear)
                .cornerRadius(4)
                .onTapGesture {
                    selectedChannel.value = 0
                }

                // Channel 2
                HStack {
                    Text("# announcements")
                        .foreground(selectedChannel.value == 1 ? .white : textMuted)
                    Spacer()
                }
                .padding(8)
                .background(selectedChannel.value == 1 ? hoverBg : .clear)
                .cornerRadius(4)
                .onTapGesture {
                    selectedChannel.value = 1
                }

                // Channel 3
                HStack {
                    Text("# development")
                        .foreground(selectedChannel.value == 2 ? .white : textMuted)
                    Spacer()
                }
                .padding(8)
                .background(selectedChannel.value == 2 ? hoverBg : .clear)
                .cornerRadius(4)
                .onTapGesture {
                    selectedChannel.value = 2
                }
            }
            .padding(8)

            Spacer()

            // User Profile Area at Bottom
            HStack(spacing: 8) {
                Text("U")
                    .foreground(.white)
                    .frame(width: 32, height: 32)
                    .background(blurple)
                    .cornerRadius(16)

                VStack(spacing: 2) {
                    Text("Developer")
                        .font(size: 13)
                        .foreground(.white)
                    Text("#1234")
                        .font(size: 11)
                        .foreground(textMuted)
                }
                Spacer()
            }
            .padding(8)
            .background(Color(0.14, 0.15, 0.16))
        }
        .frame(width: 240)
        .background(channelBg)

        // --- 3. Main Chat Area (fills remaining space) ---
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 8) {
                Text(channelNames[selectedChannel.value])
                    .foreground(.white)
                Spacer()
                Text("Search")
                    .foreground(textMuted)
                    .padding(6)
                    .background(serverBg)
                    .cornerRadius(4)
            }
            .padding(16)

            Divider()

            // Chat History
            VStack(spacing: 20) {
                // Message 1
                HStack(spacing: 16) {
                    Text("R")
                        .font(size: 15)
                        .foreground(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.red)
                        .cornerRadius(20)

                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Raeen")
                                .font(size: 15)
                                .foreground(.white)
                            Text("Today at 10:00 AM")
                                .font(size: 12)
                                .foreground(textMuted)
                        }
                        Text("Welcome to the new Raven UI Framework! It's super fast.")
                            .font(size: 14)
                            .foreground(textNormal)
                    }
                    Spacer()
                }

                // Message 2
                HStack(spacing: 16) {
                    Text("R")
                        .font(size: 15)
                        .foreground(.white)
                        .frame(width: 40, height: 40)
                        .background(blurple)
                        .cornerRadius(20)

                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Raven Bot")
                                .font(size: 15)
                                .foreground(.white)
                            Text("Today at 10:05 AM")
                                .font(size: 12)
                                .foreground(textMuted)
                        }
                        Text("The Vulkan backend is running smoothly.")
                            .font(size: 14)
                            .foreground(textNormal)

                        // Embedded UI Component Demo
                        HStack(spacing: 16) {
                            Button("Acknowledge") {
                                // Action
                            }
                            Toggle("Show Details", isOn: StateVar(false).binding)
                        }
                        .padding(12)
                        .background(channelBg)
                        .cornerRadius(8)
                    }
                    Spacer()
                }

                Spacer()
            }
            .padding(20)

            // Message Input
            HStack {
                Text("Message \(channelNames[selectedChannel.value])")
                    .foreground(textMuted)
                Spacer()
            }
            .padding(16)
            .background(channelBg)
            .cornerRadius(8)
            .padding(20)
        }
        .background(chatBg)

        // --- 4. Member List (Far Right, 240px) ---
        VStack(spacing: 4) {
            Text("ONLINE — 2")
                .font(size: 11)
                .foreground(textMuted)
                .padding(top: 4, leading: 0, bottom: 4, trailing: 0)

            // Member 1
            HStack(spacing: 8) {
                Text("R")
                    .font(size: 13)
                    .foreground(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.red)
                    .cornerRadius(16)
                Text("Raeen")
                    .font(size: 14)
                    .foreground(textNormal)
                Spacer()
            }
            .padding(4)

            // Member 2
            HStack(spacing: 8) {
                Text("R")
                    .font(size: 13)
                    .foreground(.white)
                    .frame(width: 32, height: 32)
                    .background(blurple)
                    .cornerRadius(16)
                Text("Raven Bot")
                    .font(size: 14)
                    .foreground(blurple)
                Spacer()
            }
            .padding(4)

            Text("OFFLINE — 1")
                .font(size: 11)
                .foreground(textMuted)
                .padding(top: 12, leading: 0, bottom: 4, trailing: 0)

            // Member 3
            HStack(spacing: 8) {
                Text("G")
                    .font(size: 13)
                    .foreground(.white)
                    .frame(width: 32, height: 32)
                    .background(textMuted)
                    .cornerRadius(16)
                Text("Guest")
                    .font(size: 14)
                    .foreground(textMuted)
                Spacer()
            }
            .padding(4)

            Spacer()
        }
        .padding(12)
        .frame(width: 240)
        .background(memberBg)
    }
}

print("App object created, about to call run()...")
app.run()
