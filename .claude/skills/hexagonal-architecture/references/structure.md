# Project Structure Guide

## Canonical Package Layout

```
src/
├── core/
│   ├── domain/                        # Pure business logic
│   │   ├── model/
│   │   │   ├── Order.java             # Aggregate root
│   │   │   ├── OrderId.java           # Value object
│   │   │   └── Money.java             # Value object
│   │   └── service/
│   │       └── PricingDomainService.java
│   ├── application/
│   │   ├── port/
│   │   │   ├── in/                    # Primary ports (use case interfaces)
│   │   │   │   ├── PlaceOrderUseCase.java
│   │   │   │   └── GetOrderQuery.java
│   │   │   └── out/                   # Secondary ports (infrastructure interfaces)
│   │   │       ├── OrderRepository.java
│   │   │       └── PaymentPort.java
│   │   └── service/                   # Use case implementations
│   │       ├── PlaceOrderService.java
│   │       └── GetOrderService.java
└── adapter/
    ├── in/                            # Primary (driving) adapters
    │   ├── web/
    │   │   ├── OrderController.java
    │   │   ├── OrderRequest.java      # Web-layer DTO
    │   │   └── OrderResponse.java
    │   └── messaging/
    │       └── OrderCreatedConsumer.java
    └── out/                           # Secondary (driven) adapters
        ├── persistence/
        │   ├── JpaOrderRepository.java  # Implements OrderRepository port
        │   ├── OrderJpaEntity.java      # Has @Entity, @Column, etc.
        │   └── OrderMapper.java
        └── payment/
            ├── StripePaymentAdapter.java  # Implements PaymentPort
            └── StripeClient.java
```

## What Goes Where

### Core / Domain
- Entities with business identity and lifecycle
- Value objects (immutable, equality by value)
- Aggregate roots (consistency boundary)
- Domain services (logic that doesn't belong to one entity)
- Domain events
- **No framework annotations. No imports from adapters.**

### Core / Application
- Use case interfaces (primary ports) — one interface per use case
- Use case implementations (application services) — orchestrate domain objects
- Repository interfaces (secondary ports)
- External service interfaces (secondary ports)
- Commands and queries (input models for use cases)
- **May import domain. No imports from adapters.**

### Adapters / In
- REST controllers, GraphQL resolvers, gRPC handlers
- CLI entry points
- Message/event consumers
- Web-layer DTOs (request/response objects with JSON annotations)
- **Depends on primary ports. Never on application services directly (use the interface).**

### Adapters / Out
- JPA/JDBC repository implementations
- HTTP clients for external APIs
- Email/SMS senders
- Cache adapters
- ORM entities with `@Entity`, `@Column`, etc.
- Mappers between adapter models and domain models
- **Implements secondary ports defined in the core.**

## Configuration / Wiring

Framework config and dependency injection setup lives outside both core and adapters — in a separate `config/` or `infrastructure/` package, or the framework's bootstrap class.

```
src/
├── core/         # Business logic
├── adapter/      # Technical implementations
└── config/       # DI wiring, Spring @Configuration, etc.
```

## Multi-module Maven/Gradle Layout (Advanced)

For strong compile-time enforcement:

```
modules/
├── core/           # No framework dependencies in compile scope
├── adapter-web/    # Depends on core
├── adapter-persistence/  # Depends on core
└── bootstrap/      # Depends on all; wires everything together
```

This ensures adapters literally cannot be imported by the core at build time.
