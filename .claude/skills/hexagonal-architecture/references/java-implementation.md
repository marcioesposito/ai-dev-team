# Java Implementation Guide

Based on the HappyCoders.eu tutorial: https://www.happycoders.eu/software-craftsmanship/hexagonal-architecture-java/

---

## Maven Multi-Module Layout (Recommended)

Separate modules enforce the dependency rule at **compile time** — the core literally cannot import adapter code.

```
parent/
├── model/          # Domain entities and value objects
├── application/    # Ports (in/out) and use case implementations
├── adapter/        # REST, persistence, messaging adapters
└── bootstrap/      # DI wiring, server startup — depends on all modules
```

`pom.xml` dependency directions:
- `model` → (no dependencies on other modules)
- `application` → `model`
- `adapter` → `application`, `model`
- `bootstrap` → `adapter`, `application`, `model`

---

## Domain Model

### Value Objects as Java Records

Use records for immutable identifiers and value objects. Put validation in the compact constructor.

```java
public record CustomerId(UUID value) {
    public CustomerId {
        Objects.requireNonNull(value, "value must not be null");
    }
}

public record Money(int cents) {
    public Money {
        if (cents < 0) throw new IllegalArgumentException("cents must not be negative");
    }

    public Money add(Money other) {
        return new Money(this.cents + other.cents);
    }
}
```

### Rich Domain Entities

Business logic lives in the entity, not the service. Services orchestrate; entities enforce invariants.

```java
public class Cart {
    private final CustomerId customerId;
    private final List<CartLineItem> lineItems = new ArrayList<>();

    public void addProduct(Product product, int quantity) {
        // Business rule: cannot add more than available stock
        if (quantity > product.itemsInStock()) {
            throw new NotEnoughItemsInStockException(product, quantity);
        }
        findLineItem(product.id())
            .ifPresentOrElse(
                item -> item.increaseQuantityBy(quantity),
                () -> lineItems.add(new CartLineItem(product, quantity))
            );
    }
}
```

---

## Application Layer

### Primary Ports (Use Case Interfaces)

One interface per use case. Place in `application/port/in/`.

```java
public interface AddToCartUseCase {
    Cart addToCart(CustomerId customerId, ProductId productId, int quantity);
}

public interface GetCartUseCase {
    Cart getCart(CustomerId customerId);
}
```

### Secondary Ports (Repository Interfaces)

Named by intent, not technology. Place in `application/port/out/`.

```java
public interface CartRepository {
    Optional<Cart> findByCustomerId(CustomerId customerId);
    Cart save(Cart cart);
}

public interface ProductRepository {
    Optional<Product> findById(ProductId productId);
}
```

### Use Case Implementations (Application Services)

Receive all dependencies via constructor (no framework annotations in the core).

```java
public class CartService implements AddToCartUseCase, GetCartUseCase {
    private final CartRepository cartRepository;
    private final ProductRepository productRepository;

    public CartService(CartRepository cartRepository, ProductRepository productRepository) {
        this.cartRepository = cartRepository;
        this.productRepository = productRepository;
    }

    @Override
    public Cart addToCart(CustomerId customerId, ProductId productId, int quantity) {
        var product = productRepository.findById(productId)
            .orElseThrow(() -> new ProductNotFoundException(productId));
        var cart = cartRepository.findByCustomerId(customerId)
            .orElseGet(() -> new Cart(customerId));
        cart.addProduct(product, quantity);
        return cartRepository.save(cart);
    }
}
```

---

## Adapter Layer

### REST Adapter (Primary / Driving)

Use Jakarta REST (`@Path`, `@GET`, `@POST`). Inject use case interfaces, not service classes. Map to/from web models.

```java
@Path("/carts")
public class CartController {
    private final AddToCartUseCase addToCartUseCase;
    private final GetCartUseCase getCartUseCase;

    public CartController(AddToCartUseCase addToCartUseCase, GetCartUseCase getCartUseCase) {
        this.addToCartUseCase = addToCartUseCase;
        this.getCartUseCase = getCartUseCase;
    }

    @POST
    @Path("/{customerId}/line-items")
    public Response addLineItem(@PathParam("customerId") String customerId,
                                AddToCartRequest request) {
        Cart cart = addToCartUseCase.addToCart(
            new CustomerId(UUID.fromString(customerId)),
            new ProductId(UUID.fromString(request.productId())),
            request.quantity()
        );
        return Response.ok(CartWebModel.fromDomainModel(cart)).build();
    }
}
```

### Web Models (Adapter-Layer DTOs)

Separate from domain models. Use records. Denormalize as needed for the API response.

```java
public record CartWebModel(String customerId, List<LineItemWebModel> lineItems, int totalCents) {
    public static CartWebModel fromDomainModel(Cart cart) {
        return new CartWebModel(
            cart.customerId().value().toString(),
            cart.lineItems().stream().map(LineItemWebModel::fromDomainModel).toList(),
            cart.totalPrice().cents()
        );
    }
}
```

### Persistence Adapter (Secondary / Driven)

Implements the repository port. Uses `ConcurrentHashMap` for in-memory, or JPA entities for DB-backed.

```java
public class InMemoryCartRepository implements CartRepository {
    private final Map<CustomerId, Cart> store = new ConcurrentHashMap<>();

    @Override
    public Optional<Cart> findByCustomerId(CustomerId customerId) {
        return Optional.ofNullable(store.get(customerId));
    }

    @Override
    public Cart save(Cart cart) {
        store.put(cart.customerId(), cart);
        return cart;
    }
}
```

For JPA, use a separate `@Entity` class and a mapper — never put `@Entity` on the domain model.

---

## Bootstrap Module

Wires everything together. This is the only place that knows about all modules.

```java
// CDI / Weld example
public class Application {
    public static void main(String[] args) {
        var cartRepository = new InMemoryCartRepository();
        var productRepository = new InMemoryProductRepository();
        var cartService = new CartService(cartRepository, productRepository);
        var controller = new CartController(cartService, cartService);
        // Start server with controller registered...
    }
}
```

With Spring Boot, use `@Configuration` classes here, keeping `@Bean` definitions out of the core.

---

## Testing (Abstract Test Contracts)

Define an abstract test class for each secondary port. Run it against every adapter implementation to verify the contract.

```java
abstract class CartRepositoryTest {
    abstract CartRepository repository();

    @Test
    void save_thenFindByCustomerId_returnsCart() {
        var cart = new Cart(new CustomerId(UUID.randomUUID()));
        repository().save(cart);
        assertThat(repository().findByCustomerId(cart.customerId())).contains(cart);
    }
}

// Concrete test for each adapter:
class InMemoryCartRepositoryTest extends CartRepositoryTest {
    @Override CartRepository repository() { return new InMemoryCartRepository(); }
}

class JpaCartRepositoryTest extends CartRepositoryTest {
    @Override CartRepository repository() { return new JpaCartRepository(entityManager); }
}
```

Export abstract tests from the `application` module using Maven `classifier=tests` so adapter modules can inherit them.

---

## Java-Specific Checklist

- [ ] Domain entities: pure Java, no `@Entity`, `@JsonProperty`, or Spring annotations
- [ ] Value objects implemented as `record` with validation in compact constructor
- [ ] Service constructors inject port interfaces (not `@Autowired` on fields in core)
- [ ] Web models (`*WebModel`, `*Request`, `*Response`) are separate from domain models
- [ ] `@Entity` classes live only in the persistence adapter package
- [ ] Bootstrap module is the only one that `new`s concrete adapters or configures Spring beans
- [ ] Abstract repository test verifies every adapter implementation against the same contract
