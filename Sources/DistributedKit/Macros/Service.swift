/// Generates `DistributedKitService` conformance and a `childSpec` for the annotated actor, similar to OTP's `use GenServer`.
@attached(member, names: named(childSpec))
@attached(extension, conformances: DistributedKitService, names: named(serviceName), named(restartStrategy))
public macro Service(
    name: String,
    restart: RestartStrategy = .permanent
) = #externalMacro(module: "DistributedKitMacros", type: "ServiceMacro")
