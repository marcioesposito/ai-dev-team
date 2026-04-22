# Mapping Strategies

When an adapter converts data between the external world and the core (or vice versa), choose one of these four strategies.

---

## 1. Two-Way Mapping (Recommended)

Each layer has its own model class. Adapters map to/from core models at the boundary.

**Use when**: You want complete isolation between core and infrastructure.

```
Core domain model  ←→  Mapper  ←→  Adapter model (e.g., JPA entity, JSON DTO)
```

**Pros:**
- Core domain objects are free of technical annotations (`@Entity`, `@JsonProperty`, etc.)
- Layers evolve independently
- Changes to the DB schema don't touch domain classes

**Cons:**
- More classes to maintain
- Mapping code must be written and tested

```java
// Core model — no JPA annotations
public class Order {
    private OrderId id;
    private Money total;
}

// Adapter model — JPA entity
@Entity
@Table(name = "orders")
class OrderJpaEntity {
    @Id UUID id;
    BigDecimal total;
    String currency;
}

// Mapper lives in the adapter layer
class OrderMapper {
    Order toDomain(OrderJpaEntity entity) { ... }
    OrderJpaEntity toJpa(Order order) { ... }
}
```

---

## 2. One-Way Mapping

Core defines an interface; both the core model and adapter model implement it. Translation only needed from core to adapter direction.

**Use when**: Adapter models are a strict superset of core models, and you want to avoid dual-direction mapping.

**Cons:**
- Core interfaces may leak adapter concerns if not carefully designed.

---

## 3. External Configuration

Technical metadata (ORM mappings, serialization config) stored in XML or config files, not code annotations.

**Use when**: You cannot modify the domain classes (e.g., third-party library) but need ORM mapping.

**Cons:**
- Reduces code clarity; mapping is not co-located with the class.

---

## 4. Boundary Weakening (Avoid)

Adapter annotations (`@Entity`, `@Column`, `@JsonProperty`) placed directly on core domain classes.

**Why it's bad:**
- Core depends on infrastructure frameworks
- Violates the dependency rule
- Makes the core untestable without the full infrastructure stack
- Infrastructure changes force domain class changes

**Only acceptable** for trivially simple CRUD services with no real business logic and short lifespans.

---

## Choosing a Strategy

| Situation | Recommended Strategy |
|-----------|---------------------|
| Complex domain with rich business logic | Two-Way Mapping |
| Simple read models / projections | One-Way Mapping |
| Legacy / third-party domain classes | External Configuration |
| Prototype / throwaway CRUD | Boundary Weakening (with awareness) |
