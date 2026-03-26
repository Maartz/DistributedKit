# DistributedKit

**OTP-inspired distributed actor framework for Swift**

DistributedKit layers an ergonomic, [Elixir/OTP](https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html)-inspired developer experience on top of Apple's [`swift-distributed-actors`](https://github.com/apple/swift-distributed-actors) (`DistributedCluster`). Think in familiar actor-model terms -- behaviours, supervision, named registries -- without wrestling with raw cluster boilerplate.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alembic-labs/DistributedKit.git", branch: "main"),
]
```

Then add the products to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "DistributedKit", package: "DistributedKit"),
    ]
)
```

For testing targets:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: [
        "MyApp",
        .product(name: "DistributedKitTestKit", package: "DistributedKit"),
    ]
)
```

## Modules

| Module | Purpose |
|--------|---------|
| `DistributedKit` | Core framework: `ServerBehavior`, `@Service` macro, supervision trees, registry |
| `DistributedKitTestKit` | Testing utilities: `TestProbe`, `LocalActorSystem`, `withCluster` |

---

## Core Concepts

### ServerBehavior

The `ServerBehavior` protocol is DistributedKit's equivalent of Elixir's `GenServer`. It provides a structured way to handle synchronous calls and asynchronous casts with explicit state management.

```swift
public protocol ServerBehavior: DistributedActor where ActorSystem == ClusterSystem {
    associatedtype CallMessage: Sendable & Codable
    associatedtype CastMessage: Sendable & Codable
    associatedtype State: Sendable

    func handleCall(_ message: CallMessage, state: inout State) async throws -> CallReply<State>
    func handleCast(_ message: CastMessage, state: inout State) async throws -> CastReply<State>

    func onInit() async throws
    func onTerminate(reason: TerminationReason) async
}
```

**Associated types:**

- `CallMessage` -- Synchronous request types (like `GenServer.call`)
- `CastMessage` -- Asynchronous fire-and-forget message types (like `GenServer.cast`)
- `State` -- The actor's managed state

**Lifecycle callbacks** (`onInit` and `onTerminate`) have default empty implementations. Override them when you need setup/teardown logic.

**Default implementations:**

- `handleCall` throws `DistributedKitError.unhandledCall` if not implemented
- `handleCast` returns `.noreply(state)` if not implemented

#### Reply Types

```swift
enum CallReply<S: Sendable>: Sendable {
    case reply(S)       // Reply with updated state
    case noReply(S)     // Update state, no meaningful reply distinction
    case stop(TerminationReason, S)  // Signal termination
}

enum CastReply<S: Sendable>: Sendable {
    case noreply(S)     // Continue with updated state
    case stop(TerminationReason, S)  // Signal termination
}

enum TerminationReason: Sendable {
    case normal
    case shutdown
    case error(any Error & Sendable)
}
```

#### processCall / processCast Helpers

Instead of manually copying state in and out of handlers, use the convenience helpers:

```swift
// Without helpers (manual state management):
distributed func getCount() async throws -> Int {
    var state = _state
    let reply = try await handleCall(.get, state: &state)
    _state = state
    // ... extract value from reply
}

// With helpers (recommended):
distributed func getCount() async throws -> Int {
    let (reply, newState) = try await processCall(.get, state: _state)
    _state = newState
    // ... extract value from reply
}
```

Both `processCall` and `processCast` take the current state by value, run the handler, and return a tuple of `(reply, newState)`.

#### Full Example

```swift
import DistributedCluster
import DistributedKit

enum CounterCall: Sendable, Codable {
    case get
}

enum CounterCast: Sendable, Codable {
    case increment
    case decrement
}

@Service(name: "counter")
distributed actor Counter: ServerBehavior {
    typealias CallMessage = CounterCall
    typealias CastMessage = CounterCast
    typealias State = Int

    var _state: Int = 0

    init(actorSystem: ClusterSystem) {
        self.actorSystem = actorSystem
    }

    func handleCall(_ message: CounterCall, state: inout Int) async throws -> CallReply<Int> {
        switch message {
        case .get: return .reply(state)
        }
    }

    func handleCast(_ message: CounterCast, state: inout Int) async throws -> CastReply<Int> {
        switch message {
        case .increment: state += 1
        case .decrement: state -= 1
        }
        return .noreply(state)
    }

    distributed func getCount() async throws -> Int {
        let (reply, newState) = try await processCall(.get, state: _state)
        _state = newState
        switch reply {
        case .reply(let v): return v
        case .noReply(let v): return v
        case .stop(_, let v): return v
        }
    }

    distributed func increment() async throws {
        let (_, newState) = try await processCast(.increment, state: _state)
        _state = newState
    }
}
```

---

### @Service Macro

The `@Service` macro reduces boilerplate for distributed actors that participate in supervision trees and service discovery.

```swift
@Service(name: "counter")
distributed actor Counter: ServerBehavior { ... }
```

**What it generates:**

1. `static func childSpec() -> ChildSpec<Counter>` -- for use in supervision trees
2. `extension Counter: DistributedKitService` -- conformance with `serviceName` and `restartStrategy`

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `String` | (required) | Service name for discovery and supervision |
| `restart` | `RestartStrategy` | `.permanent` | How the supervisor handles crashes |

**Expansion example:**

```swift
// You write:
@Service(name: "cache", restart: .transient)
distributed actor MyCache { }

// The macro expands to:
distributed actor MyCache {
    static func childSpec() -> ChildSpec<MyCache> {
        ChildSpec(
            name: "cache",
            restart: .transient,
            factory: { system in try MyCache(actorSystem: system) }
        )
    }
}

extension MyCache: DistributedKitService {
    static var serviceName: String { "cache" }
    static var restartStrategy: RestartStrategy { .transient }
}
```

> **Note:** Swift 6.3+ auto-synthesizes the `actorSystem` property for distributed actors, so the macro does not inject it.

**Usage in supervision trees:**

```swift
let tree = SupervisorTree("MyApp") {
    Supervisor(strategy: .oneForOne) {
        Counter.childSpec()   // Uses macro-generated spec
        MyCache.childSpec()
    }
}
```

**Usage with Singleton:**

```swift
// Because @Service generates DistributedKitService conformance,
// you can resolve actors by type:
let counter = try await Singleton<Counter>.resolve(on: system)
```

---

### Supervision

DistributedKit provides declarative supervision trees inspired by OTP supervisors. A supervision tree defines how child actors are started, monitored, and restarted on failure.

#### SupervisorTree

The top-level container. Uses a `@resultBuilder` DSL:

```swift
let tree = SupervisorTree("MyApp") {
    Supervisor("workers", strategy: .oneForOne, maxRestarts: 5, withinSeconds: 10) {
        Counter.childSpec()
        ChildSpec<Worker>(
            name: "worker-1",
            restart: .transient,
            factory: { sys in Worker(actorSystem: sys) }
        )
    }
}

// Start the tree on a cluster
try await tree.run(on: system)
```

#### Supervisor

A function that creates a `SupervisorSpec`:

```swift
Supervisor(
    _ name: String = "supervisor",
    strategy: SupervisionStrategy = .oneForOne,
    maxRestarts: Int = 3,
    withinSeconds: TimeInterval = 5,
    @SupervisionTreeBuilder children: () -> [SupervisionChild]
)
```

Supervisors can be nested for hierarchical supervision.

#### ChildSpec

Describes how to start a child actor:

```swift
ChildSpec<MyActor>(
    name: "my-actor",
    restart: .permanent,    // default
    factory: { system in MyActor(actorSystem: system) }
)
```

Or use the `@Service` macro to auto-generate it: `MyActor.childSpec()`.

#### SupervisionStrategy

Determines which children restart when one fails:

| Strategy | Behavior | OTP Equivalent |
|----------|----------|----------------|
| `.oneForOne` | Only the crashed child restarts | `:one_for_one` |
| `.oneForAll` | All children restart | `:one_for_all` |
| `.restForOne` | The crashed child and all children started after it restart | `:rest_for_one` |

#### RestartStrategy

Controls whether a child is restarted:

| Strategy | Behavior | OTP Equivalent |
|----------|----------|----------------|
| `.permanent` | Always restart | `:permanent` |
| `.transient` | Restart only on abnormal exit | `:transient` |
| `.temporary` | Never restart | `:temporary` |

---

### Registry & ServiceKey

The `Registry` provides typed, named actor lookup backed by `DistributedCluster`'s receptionist.

```swift
let registry = Registry(system: system)

// Register an actor under a typed key
let key = ServiceKey<Counter>(id: "main-counter")
await registry.register(counter, key: key)

// Lookup returns the first matching actor (or nil)
if let found = await registry.lookup(key) {
    let count = try await found.getCount()
}

// Get an async listing of all actors registered under a key
let listing = await registry.listing(key)
```

`ServiceKey<A>` is a generic, `Hashable`, `Sendable` struct that wraps an `id: String` and is scoped to a specific actor type.

---

### Singleton

`Singleton` resolves a `DistributedKitService`-conforming actor by its `serviceName`. This requires the `@Service` macro (or manual `DistributedKitService` conformance).

```swift
@Service(name: "counter")
distributed actor Counter: ServerBehavior { ... }

// Later, resolve by type:
let counter = try await Singleton<Counter>.resolve(on: system)
```

Throws `DistributedKitError.serviceNotFound` if no actor is registered under that service name.

---

### DistributedKitService Protocol

The protocol that `@Service` conforms your actor to. You can also conform manually:

```swift
public protocol DistributedKitService: DistributedActor where ActorSystem == ClusterSystem {
    static var serviceName: String { get }
    static var restartStrategy: RestartStrategy { get }
}
```

---

### Error Handling

All framework errors are cases of `DistributedKitError`:

| Case | When |
|------|------|
| `.unhandledCall(String)` | `handleCall` not implemented and default is invoked |
| `.unhandledCast(String)` | `handleCast` not implemented (reserved) |
| `.serviceNotFound(String)` | `Singleton.resolve` finds no registered actor |
| `.supervisionMaxRestartsExceeded(name:count:)` | Child exceeded `maxRestarts` within the time window |
| `.factoryFailed(name:underlying:)` | `ChildSpec.factory` threw during startup |

---

## Testing with DistributedKitTestKit

Import `DistributedKitTestKit` in your test targets for ergonomic cluster testing.

### withCluster

Scoped cluster lifecycle -- boots a `ClusterSystem`, runs your test, and shuts down:

```swift
import DistributedKitTestKit

@Test func counterIncrements() async throws {
    try await withCluster("CounterTest") { system in
        let counter = Counter(actorSystem: system)
        try await counter.increment()
        let count = try await counter.getCount()
        #expect(count == 1)
    }
}
```

Each call gets a unique port, so tests can run in parallel.

### LocalActorSystem

When you need the system to outlive a single closure:

```swift
let local = await LocalActorSystem(name: "my-test")
let counter = Counter(actorSystem: local.clusterSystem)
// ... use counter ...
try local.shutdown()
```

### TestProbe

A distributed actor that captures messages for assertion. Useful for verifying that actors send expected messages:

```swift
try await withCluster { system in
    let probe = TestProbe<String>(actorSystem: system)

    // Send a message to the probe
    try await probe.send("hello")

    // Assert it was received
    let msg = try await probe.expectMessage()  // timeout: 3s default
    #expect(msg == "hello")

    // Assert no unexpected messages
    try await probe.expectNoMessage(for: .seconds(1))
}
```

---

## Samples

The `Samples/` directory contains runnable demos:

| Sample | What it demonstrates |
|--------|---------------------|
| [`SampleWorker`](Samples/SampleWorker/) | `@Service` macro, `ServerBehavior`, `Registry`, `Singleton`, `SupervisorTree` |
| [`SupervisionDemo`](Samples/SupervisionDemo/) | Supervision strategies, crash/restart lifecycle, `processCall`/`processCast` |

Run a sample:

```bash
cd Samples/SampleWorker
swift run
```

---

## OTP Equivalence

| Elixir/OTP | DistributedKit |
|---|---|
| `use GenServer` | `ServerBehavior` protocol + `@Service` macro |
| `GenServer.call/2` | `handleCall` / `processCall` |
| `GenServer.cast/2` | `handleCast` / `processCast` |
| `GenServer.init/1` | `onInit()` |
| `GenServer.terminate/2` | `onTerminate(reason:)` |
| `{:reply, reply, state}` | `CallReply.reply(state)` |
| `{:noreply, state}` | `CastReply.noreply(state)` |
| `{:stop, reason, state}` | `.stop(reason, state)` |
| `Supervisor.start_link/2` | `SupervisorTree { Supervisor { ... } }` |
| `:one_for_one` / `:one_for_all` / `:rest_for_one` | `.oneForOne` / `.oneForAll` / `.restForOne` |
| `:permanent` / `:transient` / `:temporary` | `.permanent` / `.transient` / `.temporary` |
| `Supervisor.child_spec/1` | `@Service` macro generates `childSpec()` |
| `Registry` | `Registry` + `ServiceKey` |
| `GenServer.start_link(name: {:via, ...})` | `Singleton<T>.resolve(on:)` |

## Requirements

- Swift 6.3+
- macOS 15+ / iOS 18+ / tvOS 18+ / watchOS 11+
- [`swift-distributed-actors`](https://github.com/apple/swift-distributed-actors) (main branch)

## License

Apache 2.0
