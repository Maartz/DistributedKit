/// Determines how sibling children are affected when one child fails, mirroring OTP's supervisor strategies.
public enum SupervisionStrategy: Sendable {
    /// Only the failed child is restarted (OTP `:one_for_one`).
    case oneForOne
    /// All children are terminated and restarted when any one fails (OTP `:one_for_all`).
    case oneForAll
    /// The failed child and all children started after it are restarted (OTP `:rest_for_one`).
    case restForOne
}
