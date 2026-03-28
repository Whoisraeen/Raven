#!/usr/bin/env node

const { execSync, spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");

const VERSION = "0.1.0";

// Colors for terminal output
const c = {
  red: (s) => `\x1b[31m${s}\x1b[0m`,
  green: (s) => `\x1b[32m${s}\x1b[0m`,
  yellow: (s) => `\x1b[33m${s}\x1b[0m`,
  cyan: (s) => `\x1b[36m${s}\x1b[0m`,
};

function printUsage() {
  console.log(`${c.cyan("raven")} — Raven Framework CLI v${VERSION}\n`);
  console.log("Usage: raven <command> [options]\n");
  console.log("Commands:");
  console.log("  init        Create a new Raven project");
  console.log("  build       Build the Raven project (Rust + Swift)");
  console.log("  run         Build and run the application");
  console.log("  dev         Build, run, and watch for changes");
  console.log("  clean       Clean all build artifacts");
  console.log("  doctor      Check toolchain prerequisites");
  console.log("  version     Print version information");
  console.log("");
  console.log("Options:");
  console.log("  --release   Build in release mode (default: debug)");
  console.log("  --target    Specify the executable target (default: RavenDemo)");
  console.log("");
}

// Check if a command exists
function commandExists(cmd) {
  try {
    execSync(
      os.platform() === "win32" ? `where ${cmd}` : `which ${cmd}`,
      { stdio: "pipe" }
    );
    return true;
  } catch {
    return false;
  }
}

// Run a shell command with live output
function run(cmd, opts = {}) {
  const result = spawn(
    os.platform() === "win32" ? "cmd" : "bash",
    os.platform() === "win32" ? ["/c", cmd] : ["-c", cmd],
    { stdio: "inherit", cwd: opts.cwd || process.cwd(), ...opts }
  );

  return new Promise((resolve, reject) => {
    result.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`Command failed with exit code ${code}`));
    });
  });
}

// Find the project root (look for Package.swift)
function findProjectRoot() {
  let dir = process.cwd();
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, "Package.swift"))) return dir;
    dir = path.dirname(dir);
  }
  return null;
}

// === Commands ===

async function cmdDoctor() {
  console.log(`${c.cyan("raven doctor")} — Checking prerequisites...\n`);

  const checks = [
    { name: "Swift", cmd: "swift", version: "swift --version" },
    { name: "Cargo (Rust)", cmd: "cargo", version: "cargo --version" },
  ];

  let allOk = true;
  for (const check of checks) {
    if (commandExists(check.cmd)) {
      try {
        const ver = execSync(check.version, { encoding: "utf-8" }).trim().split("\n")[0];
        console.log(`  ${c.green("✓")} ${check.name}: ${ver}`);
      } catch {
        console.log(`  ${c.green("✓")} ${check.name}: found`);
      }
    } else {
      console.log(`  ${c.red("✗")} ${check.name}: not found`);
      allOk = false;
    }
  }

  // Check for Vulkan SDK
  const vulkanSdk = process.env.VULKAN_SDK || process.env.VK_SDK_PATH;
  if (vulkanSdk && fs.existsSync(vulkanSdk)) {
    console.log(`  ${c.green("✓")} Vulkan SDK: ${vulkanSdk}`);
  } else {
    console.log(`  ${c.yellow("?")} Vulkan SDK: not detected (set VULKAN_SDK env var)`);
  }

  console.log("");
  if (allOk) {
    console.log(c.green("All prerequisites met!"));
  } else {
    console.log(c.red("Some prerequisites are missing. Install them before building."));
    process.exit(1);
  }
}

async function cmdBuild(args) {
  const root = findProjectRoot();
  if (!root) {
    console.error(c.red("Error:") + " Not in a Raven project (no Package.swift found)");
    process.exit(1);
  }

  const isRelease = args.includes("--release");
  const mode = isRelease ? "release" : "debug";

  console.log(`${c.cyan("raven build")} — Building in ${mode} mode...\n`);

  // Build Rust
  const rustDir = path.join(root, "rust", "raven-core");
  if (fs.existsSync(rustDir)) {
    console.log(`${c.yellow("[1/2]")} Building raven-core (Rust)...`);
    await run(`cargo build${isRelease ? " --release" : ""}`, { cwd: rustDir });
    console.log(`  ${c.green("✓")} raven-core built`);
  } else {
    console.log(`${c.yellow("[1/2]")} Skipping Rust (no rust/raven-core/ found)`);
  }

  // Build Swift
  console.log(`${c.yellow("[2/2]")} Building Raven (Swift)...`);
  await run(`swift build${isRelease ? " -c release" : ""}`, { cwd: root });
  console.log(`  ${c.green("✓")} Raven built`);

  console.log(`\n${c.green("Build complete!")}`);
}

async function cmdRun(args) {
  await cmdBuild(args);

  const root = findProjectRoot();
  const isRelease = args.includes("--release");
  const mode = isRelease ? "release" : "debug";

  let target = "RavenDemo";
  const targetArg = args.find((a) => a.startsWith("--target="));
  if (targetArg) target = targetArg.split("=")[1];

  const ext = os.platform() === "win32" ? ".exe" : "";
  const exePath = path.join(root, ".build", mode, target + ext);

  if (!fs.existsSync(exePath)) {
    console.error(c.red("Error:") + ` Could not find executable: ${exePath}`);
    process.exit(1);
  }

  // Copy SDL3.dll on Windows if needed
  if (os.platform() === "win32") {
    const dllSrc = path.join(root, "vendor", "SDL3", "SDL3-3.4.2", "lib", "x64", "SDL3.dll");
    const dllDst = path.join(root, ".build", mode, "SDL3.dll");
    if (fs.existsSync(dllSrc) && !fs.existsSync(dllDst)) {
      fs.copyFileSync(dllSrc, dllDst);
      console.log(`  ${c.green("✓")} Copied SDL3.dll`);
    }
  }

  console.log(`\n${c.cyan("Running")} ${target}...`);
  console.log("---");
  await run(`"${exePath}"`, { cwd: root });
}

async function cmdClean() {
  const root = findProjectRoot();
  if (!root) {
    console.error(c.red("Error:") + " Not in a Raven project");
    process.exit(1);
  }

  console.log(`${c.cyan("raven clean")} — Cleaning build artifacts...\n`);

  try { await run("swift package clean", { cwd: root }); } catch {}

  const rustDir = path.join(root, "rust", "raven-core");
  if (fs.existsSync(rustDir)) {
    try { await run("cargo clean", { cwd: rustDir }); } catch {}
  }

  console.log(c.green("Clean complete."));
}

async function cmdInit(args) {
  const projectName = args[0] || "my-raven-app";
  const projectDir = path.join(process.cwd(), projectName);

  if (fs.existsSync(projectDir)) {
    console.error(c.red("Error:") + ` Directory '${projectName}' already exists`);
    process.exit(1);
  }

  console.log(`${c.cyan("raven init")} — Creating new Raven project: ${projectName}\n`);

  // Read template files from the cli/templates directory
  const templateDir = path.join(__dirname, "..", "templates", "default");

  if (fs.existsSync(templateDir)) {
    // Copy template
    copyDirSync(templateDir, projectDir, { PROJECT_NAME: projectName });
  } else {
    // Minimal scaffolding if templates don't exist
    fs.mkdirSync(projectDir, { recursive: true });
    fs.mkdirSync(path.join(projectDir, "Sources", projectName), { recursive: true });

    fs.writeFileSync(
      path.join(projectDir, "Package.swift"),
      `// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "${projectName}",
    dependencies: [
        .package(url: "https://github.com/raven-ui/raven.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "${projectName}",
            dependencies: ["Raven"]
        ),
    ]
)
`
    );

    fs.writeFileSync(
      path.join(projectDir, "Sources", projectName, "main.swift"),
      `import Raven

let app = RavenApp(title: "${projectName}") {
    VStack(spacing: 20) {
        Text("Hello, Raven!")
            .foreground(.white)
            .padding(16)

        Button("Click me") {
            print("Button clicked!")
        }

        Spacer()
    }
    .padding(32)
}

app.run()
`
    );
  }

  console.log(`  ${c.green("✓")} Created ${projectName}/`);
  console.log(`\nNext steps:`);
  console.log(`  cd ${projectName}`);
  console.log(`  raven build`);
  console.log(`  raven run`);
}

function copyDirSync(src, dst, replacements) {
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const dstPath = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, dstPath, replacements);
    } else {
      let content = fs.readFileSync(srcPath, "utf-8");
      for (const [key, value] of Object.entries(replacements)) {
        content = content.replace(new RegExp(`\\{\\{${key}\\}\\}`, "g"), value);
      }
      fs.writeFileSync(dstPath, content);
    }
  }
}

async function cmdVersion() {
  console.log(`raven ${VERSION}`);
}

// === Entry Point ===

const [command, ...args] = process.argv.slice(2);

const commands = {
  build: cmdBuild,
  run: cmdRun,
  dev: () => {
    // For dev mode, delegate to the bash script since it needs process management
    const root = findProjectRoot();
    if (!root) {
      console.error(c.red("Error:") + " Not in a Raven project");
      process.exit(1);
    }
    const script = path.join(root, os.platform() === "win32" ? "raven.bat" : "raven");
    return run(`"${script}" dev ${args.join(" ")}`, { cwd: root });
  },
  clean: cmdClean,
  init: () => cmdInit(args),
  doctor: cmdDoctor,
  version: cmdVersion,
  "--version": cmdVersion,
  "-v": cmdVersion,
  help: () => { printUsage(); },
  "--help": () => { printUsage(); },
  "-h": () => { printUsage(); },
};

if (!command || !commands[command]) {
  if (command) console.error(c.red("Unknown command:") + ` ${command}\n`);
  printUsage();
  process.exit(command ? 1 : 0);
} else {
  commands[command](args).catch((err) => {
    console.error(`\n${c.red("Error:")} ${err.message}`);
    process.exit(1);
  });
}
