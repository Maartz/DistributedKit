public enum RestartStrategy: String, Sendable, Codable {
    case permanent
    case transient
    case temporary
}
