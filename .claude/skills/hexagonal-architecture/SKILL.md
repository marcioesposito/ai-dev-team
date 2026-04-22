---
name: hexagonal-architecture
description: Apply Hexagonal Architecture (Ports & Adapters) to a codebase. Use this skill when the user asks to "implement hexagonal architecture", "apply ports and adapters", "restructure with hexagonal", "add a port", "add an adapter", "isolate business logic from infrastructure", or discusses separating domain from technical concerns. Also activate when reviewing code for architecture violations or when migrating from layered architecture. Works for Java and other languages; includes Java-specific patterns with Maven modules, records, Spring Boot, and Jakarta REST.
version: 1.1.0
---

# Hexagonal Architecture (Ports & Adapters)

Apply Hexagonal Architecture to isolate business logic from technical infrastructure. All source code dependencies must point **inward** toward the application core.

Reference materials:
- [Core concepts](references/concepts.md)
- [Structure guide](references/structure.md)
- [Java implementation](references/java-implementation.md)
- [Mapping strategies](references/mapping-strategies.md)
- [Testing guide](references/testing.md)

## When This Skill Applies

Activate for requests involving:
- Implementing or migrating to hexagonal architecture
- Adding ports (interfaces) or adapters (implementations)
- Reviewing code for dependency rule violations
- Isolating domain logic from databases, APIs, or frameworks
- Structuring microservices with clear boundaries

## Core Principle: The Dependency Rule

**All dependencies point inward.** The application core never imports from adapters or infrastructure. When the core must call outward (e.g., save to DB), apply the **Dependency Inversion Principle**: define an interface (port) in the core, and have the adapter implement it.

```
[ Primary Adapter ] ---> [ Primary Port ] ---> [ Application Core ]
[ Application Core ] ---> [ Secondary Port ] <--- [ Secondary Adapter ]
```

## Workflow

### 1. Identify Components

Before writing code, classify each component:

| Component | Location | Purpose |
|-----------|----------|---------|
| **Domain entities / aggregates** | Core | Business rules, invariants |
| **Use cases / application services** | Core | Orchestrate domain logic |
| **Primary (driving) ports** | Core boundary | Interfaces to drive the app (e.g., REST input) |
| **Secondary (driven) ports** | Core boundary | Interfaces the app drives (e.g., DB, external APIs) |
| **Primary adapters** | Outside | REST controllers, CLI, message consumers |
| **Secondary adapters** | Outside | DB repositories, HTTP clients, email senders |

### 2. Define Ports First

Ports are interfaces owned by the **core**. Name them by intent, not technology:

```java
// Secondary port — core defines what it needs
public interface OrderRepository {
    void save(Order order);
    Optional<Order> findById(OrderId id);
}

// Primary port — core exposes what it offers
public interface PlaceOrderUseCase {
    OrderId placeOrder(PlaceOrderCommand command);
}
```

### 3. Implement Adapters Outside the Core

Adapters translate between the external world and the core. They depend on core ports, never the reverse:

```java
// Secondary adapter — infrastructure implements the core's port
public class JpaOrderRepository implements OrderRepository {
    @Override
    public void save(Order order) { /* JPA logic */ }
}

// Primary adapter — calls the core's use case
@RestController
public class OrderController {
    private final PlaceOrderUseCase placeOrderUseCase;
    // ...
}
```

### 4. Apply the Right Mapping Strategy

See [mapping-strategies.md](references/mapping-strategies.md). Default to **Two-Way Mapping** for clean isolation.

### 5. Verify the Dependency Rule

Check every import in the core: it must not reference adapter packages, ORM annotations, HTTP types, or framework-specific classes.

## Package Structure

```
src/
├── core/                          # Application hexagon
│   ├── domain/                    # Entities, value objects, aggregates
│   │   └── Order.java
│   ├── application/               # Use cases, application services
│   │   ├── PlaceOrderUseCase.java  # Primary port (interface)
│   │   └── PlaceOrderService.java  # Use case implementation
│   └── ports/
│       └── out/                   # Secondary ports
│           └── OrderRepository.java
└── adapters/
    ├── in/                        # Primary adapters
    │   ├── web/
    │   │   └── OrderController.java
    │   └── messaging/
    │       └── OrderEventConsumer.java
    └── out/                       # Secondary adapters
        ├── persistence/
        │   └── JpaOrderRepository.java
        └── external/
            └── PaymentGatewayAdapter.java
```

## Decision Checklist

Before completing any hexagonal architecture task, verify:

- [ ] Core has zero imports from adapter packages
- [ ] All database/ORM annotations live in adapters only
- [ ] Secondary ports (interfaces) are defined in the core
- [ ] Adapters implement core interfaces, not the other way around
- [ ] Domain entities have no framework annotations
- [ ] Use cases are testable without starting a server or DB
