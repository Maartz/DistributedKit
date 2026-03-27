# ``DistributedKit``

OTP-inspired supervision, service discovery, and lifecycle management for Swift Distributed Actors.

## Overview

DistributedKit brings Erlang/OTP patterns to Swift's distributed actor ecosystem. Built on top of Apple's [swift-distributed-actors](https://github.com/apple/swift-distributed-actors), it provides:

- **Supervision trees** with automatic restart strategies (`oneForOne`, `oneForAll`, `restForOne`)
- **ServerBehavior** protocol — a GenServer-equivalent with `call`/`cast` message processing
- **Registry** and **Singleton** for typed service discovery
- **@Service macro** that generates `childSpec()` and protocol conformances
- **Lifecycle integration** with `swift-service-lifecycle` for graceful shutdown
- **TestKit** with `TestProbe` and cluster test helpers

```
┌─────────────────────────────────────────────────────────┐
│                DistributedKitApplication                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │              SupervisorTree ("App")                │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │     Supervisor (strategy: .oneForOne)        │  │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐    │  │  │
│  │  │  │WorkerA   │ │WorkerB   │ │WorkerC   │    │  │  │
│  │  │  │@Service  │ │@Service  │ │@Service  │    │  │  │
│  │  │  └──────────┘ └──────────┘ └──────────┘    │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
│  ClusterSystem ←→ ServiceGroup (SIGTERM/SIGINT)         │
└─────────────────────────────────────────────────────────┘
```

### Quick Start

```swift
import DistributedKit

@Service(name: "counter", restart: .permanent)
distributed actor Counter {
    typealias ActorSystem = ClusterSystem
    var count = 0

    distributed func increment() -> Int {
        count += 1
        return count
    }
}

try await DistributedKitApplication(name: "MyApp") {
    Supervisor(strategy: .oneForOne) {
        Counter.childSpec()
    }
}.run()
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>
- <doc:OTPMapping>

### Behaviors

- ``ServerBehavior``
- ``GenServerBehavior``
- ``CallReply``
- ``CastReply``
- ``TerminationReason``

### Macros and Protocols

- ``Service(name:restart:)``
- ``DistributedKitService``

### Registry and Service Discovery

- ``Registry``
- ``ServiceKey``
- ``Singleton``
- ``RegistryEvent``

### Supervision

- ``SupervisorTree``
- ``Supervisor(_:strategy:maxRestarts:withinSeconds:children:)``
- ``SupervisorSpec``
- ``ChildSpec``
- ``ChildSpecProtocol``
- ``SupervisionStrategy``
- ``RestartStrategy``
- ``SupervisionChild``
- ``SupervisionTreeBuilder``

### Lifecycle

- ``DistributedKitApplication``
- ``ClusterSystemService``
- ``BoundSupervisorTree``

### Errors

- ``DistributedKitError``
