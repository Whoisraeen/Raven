#!/usr/bin/env node

const { execSync, spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");

// Read version from the single source of truth: version.json at the repo root.
// Falls back to package.json, then hardcoded.
function loadVersion() {
  // Try repo-root version.json
  const repoRoot = findProjectRoot() || path.resolve(__dirname, "..", "..");
  const versionJsonPath = path.join(repoRoot, "version.json");
  try {
    const data = JSON.parse(fs.readFileSync(versionJsonPath, "utf-8"));
    if (data.version) return data.version;
  } catch {}
  // Fallback to package.json
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "package.json"), "utf-8"));
    if (pkg.version) return pkg.version;
  } catch {}
  return "0.1.0";
}
const VERSION = loadVersion();

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
  console.log("  bundle      Bundle the app for distribution");
  console.log("  clean       Clean all build artifacts");
  console.log("  doctor      Check toolchain prerequisites");
  console.log("  version     Print version information");
  console.log("");
  console.log("Options:");
  console.log("  --release   Build in release mode (default: debug)");
  console.log("  --target    Specify the executable target (default: RavenDemo)");
  console.log("  --platform  Target platform for bundle (windows, macos, linux)");
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
        .package(url: "https://github.com/Whoisraeen/Raven.git", branch: "main"),
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

async function cmdBundle(args) {
  const root = findProjectRoot();
  if (!root) {
    console.error(c.red("Error:") + " Not in a Raven project (no Package.swift found)");
    process.exit(1);
  }

  const isRelease = true; // Bundles are always release
  const hostPlatform = os.platform() === "win32" ? "windows" : os.platform() === "darwin" ? "macos" : "linux";

  // Parse --platform flag (defaults to host platform)
  let targetPlatform = hostPlatform;
  const platformArg = args.find((a) => a.startsWith("--platform="));
  if (platformArg) targetPlatform = platformArg.split("=")[1].toLowerCase();

  if (!["windows", "macos", "linux"].includes(targetPlatform)) {
    console.error(c.red("Error:") + ` Unknown platform '${targetPlatform}'. Use: windows, macos, linux`);
    process.exit(1);
  }

  if (targetPlatform !== hostPlatform) {
    console.error(c.red("Error:") + ` Cross-compilation to '${targetPlatform}' from '${hostPlatform}' is not yet supported.`);
    console.error("  Build on the target platform directly, or use CI (GitHub Actions) to build for each platform.");
    process.exit(1);
  }

  let target = "RavenDemo";
  const targetArg = args.find((a) => a.startsWith("--target="));
  if (targetArg) target = targetArg.split("=")[1];

  console.log(`${c.cyan("raven bundle")} — Bundling ${target} for ${targetPlatform}...\n`);

  // Step 1: Build in release mode
  console.log(`${c.yellow("[1/4]")} Building in release mode...`);
  await cmdBuild(["--release"]);

  // Step 2: Create bundle directory
  const bundleDir = path.join(root, "bundle", targetPlatform);
  if (fs.existsSync(bundleDir)) {
    fs.rmSync(bundleDir, { recursive: true, force: true });
  }
  fs.mkdirSync(bundleDir, { recursive: true });
  console.log(`${c.yellow("[2/4]")} Created bundle directory: bundle/${targetPlatform}/`);

  // Step 3: Copy executable and dependencies
  console.log(`${c.yellow("[3/4]")} Copying executable and dependencies...`);

  if (targetPlatform === "windows") {
    await bundleWindows(root, bundleDir, target);
  } else if (targetPlatform === "macos") {
    await bundleMacOS(root, bundleDir, target);
  } else {
    await bundleLinux(root, bundleDir, target);
  }

  // Step 4: Copy resources (shaders, fonts, assets)
  console.log(`${c.yellow("[4/4]")} Copying resources...`);
  copyResources(root, bundleDir, targetPlatform);

  const bundleSize = getDirSize(bundleDir);
  console.log(`\n${c.green("Bundle complete!")} ${c.cyan(formatSize(bundleSize))}`);
  console.log(`  Output: ${path.relative(root, bundleDir)}/`);
}

function bundleWindows(root, bundleDir, target) {
  const ext = ".exe";
  const exeSrc = path.join(root, ".build", "release", target + ext);
  if (!fs.existsSync(exeSrc)) {
    console.error(c.red("Error:") + ` Executable not found: ${exeSrc}`);
    process.exit(1);
  }
  fs.copyFileSync(exeSrc, path.join(bundleDir, target + ext));
  console.log(`  ${c.green("✓")} ${target}${ext}`);

  // Copy SDL3.dll
  const sdlDll = path.join(root, "vendor", "SDL3", "SDL3-3.4.2", "lib", "x64", "SDL3.dll");
  if (fs.existsSync(sdlDll)) {
    fs.copyFileSync(sdlDll, path.join(bundleDir, "SDL3.dll"));
    console.log(`  ${c.green("✓")} SDL3.dll`);
  }

  // Copy vulkan-1.dll from SDK if available
  const vulkanSdk = process.env.VULKAN_SDK || process.env.VK_SDK_PATH;
  if (vulkanSdk) {
    const vulkanDll = path.join(vulkanSdk, "Bin", "vulkan-1.dll");
    if (fs.existsSync(vulkanDll)) {
      fs.copyFileSync(vulkanDll, path.join(bundleDir, "vulkan-1.dll"));
      console.log(`  ${c.green("✓")} vulkan-1.dll`);
    }
  }

  // Copy Swift runtime DLLs from the build directory
  const buildDir = path.join(root, ".build", "release");
  const dllPattern = /\.(dll)$/i;
  if (fs.existsSync(buildDir)) {
    for (const f of fs.readdirSync(buildDir)) {
      if (dllPattern.test(f) && f !== "SDL3.dll" && f !== "vulkan-1.dll") {
        const src = path.join(buildDir, f);
        const dst = path.join(bundleDir, f);
        if (!fs.existsSync(dst)) {
          fs.copyFileSync(src, dst);
          console.log(`  ${c.green("✓")} ${f}`);
        }
      }
    }
  }

  return Promise.resolve();
}

function bundleMacOS(root, bundleDir, target) {
  // Create .app bundle structure
  const appDir = path.join(bundleDir, `${target}.app`);
  const contentsDir = path.join(appDir, "Contents");
  const macOSDir = path.join(contentsDir, "MacOS");
  const resourcesDir = path.join(contentsDir, "Resources");
  const frameworksDir = path.join(contentsDir, "Frameworks");

  fs.mkdirSync(macOSDir, { recursive: true });
  fs.mkdirSync(resourcesDir, { recursive: true });
  fs.mkdirSync(frameworksDir, { recursive: true });

  // Copy executable
  const exeSrc = path.join(root, ".build", "release", target);
  if (!fs.existsSync(exeSrc)) {
    console.error(c.red("Error:") + ` Executable not found: ${exeSrc}`);
    process.exit(1);
  }
  fs.copyFileSync(exeSrc, path.join(macOSDir, target));
  fs.chmodSync(path.join(macOSDir, target), 0o755);
  console.log(`  ${c.green("✓")} ${target} (executable)`);

  // Write Info.plist
  const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${target}</string>
    <key>CFBundleDisplayName</key>
    <string>${target}</string>
    <key>CFBundleIdentifier</key>
    <string>com.raven.${target.toLowerCase()}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${target}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>`;
  fs.writeFileSync(path.join(contentsDir, "Info.plist"), plist);
  console.log(`  ${c.green("✓")} Info.plist`);

  // Copy dylibs from build dir
  const buildDir = path.join(root, ".build", "release");
  if (fs.existsSync(buildDir)) {
    for (const f of fs.readdirSync(buildDir)) {
      if (f.endsWith(".dylib")) {
        fs.copyFileSync(path.join(buildDir, f), path.join(frameworksDir, f));
        console.log(`  ${c.green("✓")} ${f}`);
      }
    }
  }

  return Promise.resolve();
}

function bundleLinux(root, bundleDir, target) {
  // Linux: flat directory with executable + libs + wrapper script
  const binDir = path.join(bundleDir, "bin");
  const libDir = path.join(bundleDir, "lib");
  fs.mkdirSync(binDir, { recursive: true });
  fs.mkdirSync(libDir, { recursive: true });

  // Copy executable
  const exeSrc = path.join(root, ".build", "release", target);
  if (!fs.existsSync(exeSrc)) {
    console.error(c.red("Error:") + ` Executable not found: ${exeSrc}`);
    process.exit(1);
  }
  fs.copyFileSync(exeSrc, path.join(binDir, target));
  fs.chmodSync(path.join(binDir, target), 0o755);
  console.log(`  ${c.green("✓")} bin/${target}`);

  // Copy .so files from build dir
  const buildDir = path.join(root, ".build", "release");
  if (fs.existsSync(buildDir)) {
    for (const f of fs.readdirSync(buildDir)) {
      if (f.endsWith(".so") || f.includes(".so.")) {
        fs.copyFileSync(path.join(buildDir, f), path.join(libDir, f));
        console.log(`  ${c.green("✓")} lib/${f}`);
      }
    }
  }

  // Write launcher script
  const launcher = `#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"
exec "$DIR/bin/${target}" "$@"
`;
  fs.writeFileSync(path.join(bundleDir, target.toLowerCase()), launcher);
  fs.chmodSync(path.join(bundleDir, target.toLowerCase()), 0o755);
  console.log(`  ${c.green("✓")} ${target.toLowerCase()} (launcher script)`);

  return Promise.resolve();
}

function copyResources(root, bundleDir, platform) {
  // Determine resource destination
  let resourceDst;
  if (platform === "macos") {
    // Find the .app bundle
    const apps = fs.readdirSync(bundleDir).filter((f) => f.endsWith(".app"));
    if (apps.length > 0) {
      resourceDst = path.join(bundleDir, apps[0], "Contents", "Resources");
    } else {
      resourceDst = bundleDir;
    }
  } else {
    resourceDst = path.join(bundleDir, "resources");
    fs.mkdirSync(resourceDst, { recursive: true });
  }

  // Copy SPIR-V shaders
  const shaderDirs = [
    path.join(root, "Sources", "Raven", "Renderer", "Shaders"),
    path.join(root, "Shaders"),
    path.join(root, "Resources", "Shaders"),
  ];
  let shadersFound = false;
  for (const shaderDir of shaderDirs) {
    if (fs.existsSync(shaderDir)) {
      const shaderDst = path.join(resourceDst, "Shaders");
      fs.mkdirSync(shaderDst, { recursive: true });
      for (const f of fs.readdirSync(shaderDir)) {
        if (f.endsWith(".spv")) {
          fs.copyFileSync(path.join(shaderDir, f), path.join(shaderDst, f));
          console.log(`  ${c.green("✓")} Shaders/${f}`);
          shadersFound = true;
        }
      }
      if (shadersFound) break;
    }
  }

  // Copy fonts
  const fontDirs = [
    path.join(root, "Resources", "Fonts"),
    path.join(root, "Fonts"),
    path.join(root, "Assets", "Fonts"),
  ];
  for (const fontDir of fontDirs) {
    if (fs.existsSync(fontDir)) {
      const fontDst = path.join(resourceDst, "Fonts");
      fs.mkdirSync(fontDst, { recursive: true });
      for (const f of fs.readdirSync(fontDir)) {
        if (f.endsWith(".ttf") || f.endsWith(".otf")) {
          fs.copyFileSync(path.join(fontDir, f), path.join(fontDst, f));
          console.log(`  ${c.green("✓")} Fonts/${f}`);
        }
      }
      break;
    }
  }

  // Copy assets directory if it exists
  const assetsDir = path.join(root, "Assets");
  if (fs.existsSync(assetsDir)) {
    const assetDst = path.join(resourceDst, "Assets");
    copyDirRecursive(assetsDir, assetDst, [".ttf", ".otf"]); // skip fonts already copied
  }
}

function copyDirRecursive(src, dst, skipExtensions) {
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const dstPath = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "Fonts") continue; // skip if already handled
      copyDirRecursive(srcPath, dstPath, skipExtensions);
    } else {
      const ext = path.extname(entry.name).toLowerCase();
      if (skipExtensions && skipExtensions.includes(ext)) continue;
      fs.copyFileSync(srcPath, dstPath);
    }
  }
}

function getDirSize(dir) {
  let size = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      size += getDirSize(fullPath);
    } else {
      size += fs.statSync(fullPath).size;
    }
  }
  return size;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

async function cmdVersion() {
  console.log(`raven ${VERSION}`);
}

// === Entry Point ===

const [command, ...args] = process.argv.slice(2);

const commands = {
  build: cmdBuild,
  bundle: () => cmdBundle(args),
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
