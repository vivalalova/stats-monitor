import Darwin

enum MachHost {
    /// `mach_host_self()` returns a new send right on every call; cache it for the process lifetime.
    static let port: mach_port_t = mach_host_self()
}
