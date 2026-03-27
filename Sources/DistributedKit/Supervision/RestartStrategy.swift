/// Per-child restart policy, equivalent to OTP's `:permanent | :transient | :temporary` child restart type.
public enum RestartStrategy: String, Sendable, Codable {
    /// Always restart the child when it terminates, regardless of reason (OTP `:permanent`).
    case permanent
    /// Restart the child only when it terminates abnormally (OTP `:transient`).
    case transient
    /// Never restart the child; once it stops, it stays stopped (OTP `:temporary`).
    case temporary
}
