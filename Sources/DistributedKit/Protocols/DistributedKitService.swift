import DistributedCluster

/// A distributed actor that declares itself as a supervisable service, analogous to an OTP `child_spec`.
public protocol DistributedKitService: DistributedActor where ActorSystem == ClusterSystem {
    /// A unique name identifying this service within the supervision tree, like the `:id` in an OTP child spec.
    static var serviceName: String { get }
    /// The restart strategy applied when this service crashes, analogous to OTP's `:permanent`, `:transient`, or `:temporary`.
    static var restartStrategy: RestartStrategy { get }
}
