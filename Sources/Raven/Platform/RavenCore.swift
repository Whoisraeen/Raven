import CRavenCore


/// Swift wrapper around the Rust raven-core library.
enum RavenCore {
    static func initialize() {
        let result = raven_core_init()
        if result != 0 {
            print("Warning: raven_core_init returned \(result)")
        }
    }

    static var version: String {
        String(cString: raven_core_version())
    }

    static var platformName: String {
        String(cString: raven_core_platform_name())
    }

    static var osVersion: String {
        guard let ptr = raven_core_os_version() else { return "unknown" }
        defer { raven_core_free_string(ptr) }
        return String(cString: ptr)
    }
}
