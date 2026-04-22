# Hexagonal Architecture — Core Concepts

Source: Alistair Cockburn, 2005. Also known as "Ports & Adapters".

## Goals

1. Applications must be equally controllable by users, automated tests, or other systems — without code changes.
2. Business logic develops and tests independently from databases and external systems.
3. Infrastructure can be modernized without touching business rules.

## Key Terms

**Application Core (Hexagon)**
Contains all business logic and use cases. Defines ports for communicating with the outside world. Completely ignorant of technical implementations.

**Ports**
Interfaces at the boundary of the core. Two kinds:
- **Primary (driving) ports**: Entry points into the core (use case interfaces). Driven by adapters.
- **Secondary (driven) ports**: Exit points from the core (repository, external service interfaces). Implemented by adapters.

**Adapters**
Technical implementations outside the core. Translate between external systems and the core's ports. Two kinds:
- **Primary (driving) adapters**: REST controllers, CLI handlers, message consumers — they call primary ports.
- **Secondary (driven) adapters**: JPA repositories, HTTP clients, email senders — they implement secondary ports.

## The Dependency Rule

```
Outside → Core    ✅  (adapters depend on ports)
Core → Outside    ❌  (core never imports adapters)
```

When the core must trigger an outward action (e.g., persist data), the Dependency Inversion Principle applies:
- The core defines an **interface** (secondary port)
- The adapter **implements** that interface
- At runtime, the adapter is injected (via DI container or constructor)

## Why "Hexagon"?

The shape has no special meaning — it's chosen because it has enough sides to draw multiple adapters per side without crowding. The important insight is the **inside vs. outside** distinction, not the number of sides.

## Comparison with Layered Architecture

| | Hexagonal | Traditional Layers |
|---|---|---|
| Focus | Business logic first | Database-driven |
| Dependencies | Inward only | Transitive (UI → Service → DB) |
| Testability | Core isolated, no infra needed | Tightly coupled |
| Infrastructure swap | New adapter only | Changes ripple through layers |
| Technical leakage | Prevented by ports | Common across layers |

## Related Patterns

**Clean Architecture (Uncle Bob)**: Nearly identical — business rules at center, concentric rings pointing inward, infrastructure interchangeable.

**Onion Architecture**: Equivalent structure; optional internal rings for application services and domain services within the core.

**Domain-Driven Design (DDD)**: Complementary. Tactical DDD patterns (entities, aggregates, value objects, domain services) naturally structure the application core.

**Microservices**: Each microservice can be a hexagon. Other services are external components accessed through secondary ports.
