use std::fs;
use std::path::Path;

fn main() {
    // Read version from the single source of truth: ../../version.json
    let version_path = Path::new("../../version.json");
    if let Ok(contents) = fs::read_to_string(version_path) {
        // Simple JSON parsing without serde — find "version": "x.y.z"
        if let Some(start) = contents.find("\"version\"") {
            let rest = &contents[start..];
            if let Some(colon) = rest.find(':') {
                let after_colon = rest[colon + 1..].trim();
                if let Some(quote_start) = after_colon.find('"') {
                    let after_quote = &after_colon[quote_start + 1..];
                    if let Some(quote_end) = after_quote.find('"') {
                        let version = &after_quote[..quote_end];
                        println!("cargo:rustc-env=RAVEN_VERSION={}", version);
                        println!("cargo:rerun-if-changed=../../version.json");
                        return;
                    }
                }
            }
        }
    }
    // Fallback
    println!("cargo:rustc-env=RAVEN_VERSION=0.1.0");
}
