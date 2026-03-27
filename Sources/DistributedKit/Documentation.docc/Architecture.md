# Architecture

How DistributedKit layers OTP patterns on top of Swift's distributed actor system.

## Overview

DistributedKit is a framework layer between your application and Apple's `swift-distributed-actors` (DistributedCluster). It adds supervision, service discovery, and lifecycle management — concepts from Erlang/OTP — using Swift-native patterns.

### Layer Diagram

```
┌─────────────────────────────────────────┐
│            Your Application             │
│   @Service actors, business logic       │
├─────────────────────────────────────────┤
│            DistributedKit               │
│   SupervisorTree, Registry, Lifecycle   │
├─────────────────────────────────────────┤
│          DistributedCluster             │
│   ClusterSystem, ActorID, LifecycleWatch│
├─────────────────────────────────────────┤
│      swift-service-lifecycle            │
│   ServiceGroup, graceful shutdown       │
├─────────────────────────────────────────┤
│           Swift Concurrency             │
│   async/await, actors, Sendable         │
└─────────────────────────────────────────┘
```

## Supervision

Supervision is the core value proposition. When an actor crashes (terminates unexpectedly), its supervisor detects the termination via `LifecycleWatch` and restarts it according to the configured strategy.

### Supervision Tree Structure

```
SupervisorTree ("App")
├── Supervisor ("api", strategy: .oneForOne)
│   ├── RequestHandler (restart: .permanent)
│   ├── RateLimiter (restart: .permanent)
│   └── MetricsCollector (restart: .temporary)
└── Supervisor ("data", strategy: .oneForAll)
    ├── DatabasePool (restart: .permanent)
    └── CacheLayer (restart: .permanent)
```

### How Restart Works

1. `SupervisorRuntime` (a `distributed actor: LifecycleWatch`) watches each child
2. When a child terminates, DistributedCluster calls `terminated(actor:)`
3. The runtime checks the child's `RestartStrategy`:
   - `.permanent` — always restart
   - `.transient` — restart only on abnormal termination
   - `.temporary` — never restart
4. The runtime applies the `SupervisionStrategy`:
   - `.oneForOne` — restart only the crashed child
   - `.oneForAll` — restart all siblings
   - `.restForOne` — restart the crashed child and all children started after it
5. Rate limiter checks `maxRestarts` / `withinSeconds`; if exceeded, the supervisor shuts down

### Restart Flow

```
Actor terminates
       │
       ▼
terminated(actor: id)
       │
       ▼
┌──────────────┐     ┌──────────────────┐
│ .temporary?  │────▶│ Remove, don't    │
│              │ yes │ restart           │
└──────┬───────┘     └──────────────────┘
       │ no
       ▼
┌──────────────┐     ┌──────────────────┐
│ Rate limit   │────▶│ Supervisor       │
│ exceeded?    │ yes │ shuts down       │
└──────┬───────┘     └──────────────────┘
       │ no
       ▼
┌──────────────┐
│ Apply        │
│ strategy     │
│ (.oneForOne, │
│  .oneForAll, │
│  .restForOne)│
└──────┬───────┘
       │
       ▼
  Restart child(ren)
  Watch new actor(s)
```

## Lifecycle

DistributedKit integrates with `swift-service-lifecycle` through three types:

### Service Composition

```
ServiceGroup
├── ClusterSystemService     ← wraps ClusterSystem
│   └── run() suspends until shutdown
│       onGracefulShutdown: system.shutdown()
└── BoundSupervisorTree      ← tree.bind(to: system)
    └── run() starts children, suspends
        onGracefulShutdown: runtime.initiateShutdown()
```

`DistributedKitApplication` is a convenience that wires both together:

```
DistributedKitApplication.run()
  1. Create ClusterSystem
  2. Create SupervisorTree
  3. tree.bind(to: system) → BoundSupervisorTree
  4. ServiceGroup(services: [ClusterSystemService, BoundSupervisorTree])
  5. group.run() → blocks until SIGTERM/SIGINT
  6. Graceful shutdown: stop tree → shut down cluster
```

## Registry and Service Discovery

### Registry vs Singleton

| Pattern | Use Case | How It Works |
|---------|----------|-------------|
| `Registry` | Multiple instances, manual registration | Wraps DistributedCluster's receptionist with typed keys |
| `Singleton` | One instance per service name | Looks up actors registered by `@Service` macro |

### Discovery Flow

```
@Service(name: "counter")
distributed actor Counter { ... }

       ┌──────────────────┐
       │  Counter.init()  │
       │  System assigns  │
       │  ActorID         │
       └────────┬─────────┘
                │
                ▼
       ┌──────────────────┐
       │  Receptionist     │
       │  checkIn(actor,  │
       │  key: "counter") │
       └────────┬─────────┘
                │
                ▼
       ┌──────────────────┐
       │  Singleton        │
       │  .resolve(on:)   │
       │  → lookup key    │
       │  → return actor  │
       └──────────────────┘
```

## The @Service Macro

`@Service` is an attached macro that generates two things:

1. **`childSpec()`** — a static method returning `ChildSpec<Self>` for supervision tree registration
2. **`DistributedKitService` conformance** — provides `serviceName` and `restartStrategy`

### Before / After

```swift
// You write:
@Service(name: "worker", restart: .transient)
distributed actor Worker {
    typealias ActorSystem = ClusterSystem
}

// Macro generates:
extension Worker {
    static func childSpec() -> ChildSpec<Worker> {
        ChildSpec(name: "worker", restart: .transient,
                  factory: { sys in try Worker(actorSystem: sys) })
    }
}
extension Worker: DistributedKitService {
    static var serviceName: String { "worker" }
    static var restartStrategy: RestartStrategy { .transient }
}
```

## TestKit

`DistributedKitTestKit` provides utilities for testing distributed actors without full cluster setup:

- **`withCluster(_:_:)`** — creates an ephemeral `ClusterSystem` with a unique port, runs the test body, then shuts down
- **`TestProbe<Message>`** — a distributed actor that captures messages and provides assertion methods (`expectMessage`, `expectNoMessage`)
- **`LocalActorSystem`** — a lightweight wrapper around `ClusterSystem` for simple test scenarios
