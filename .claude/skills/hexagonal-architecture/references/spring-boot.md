# Spring Boot Implementation Guide

Based on: https://www.happycoders.eu/software-craftsmanship/hexagonal-architecture-spring-boot/

The application core requires **zero modifications** when switching from one framework to another (e.g., Quarkus → Spring Boot). Only adapters and the bootstrap module change.

---

## REST Adapter (Primary — Spring MVC)

Replace Jakarta REST annotations with Spring MVC equivalents:

| Jakarta REST | Spring MVC |
|---|---|
| `@Path` | `@RequestMapping` |
| `@RestController` (same) | `@RestController` |
| `@GET`, `@POST`, `@DELETE` | `@GetMapping`, `@PostMapping`, `@DeleteMapping` |
| `@PathParam` | `@PathVariable` |
| `@QueryParam` | `@RequestParam` |

```java
@RestController
@RequestMapping("/carts")
public class CartController {
    private final AddToCartUseCase addToCartUseCase;
    private final GetCartUseCase getCartUseCase;

    public CartController(AddToCartUseCase addToCartUseCase, GetCartUseCase getCartUseCase) {
        this.addToCartUseCase = addToCartUseCase;
        this.getCartUseCase = getCartUseCase;
    }

    @PostMapping("/{customerId}/line-items")
    public CartWebModel addLineItem(@PathVariable String customerId,
                                    @RequestBody AddToCartRequest request) {
        Cart cart = addToCartUseCase.addToCart(
            new CustomerId(UUID.fromString(customerId)),
            new ProductId(UUID.fromString(request.productId())),
            request.quantity()
        );
        return CartWebModel.fromDomainModel(cart);
    }

    @DeleteMapping("/{customerId}")
    public ResponseEntity<Void> deleteCart(@PathVariable String customerId) {
        // Spring @DeleteMapping defaults to 200 OK — must be explicit for 204
        deleteCartUseCase.deleteCart(new CustomerId(UUID.fromString(customerId)));
        return ResponseEntity.noContent().build();
    }
}
```

### Error Handling

Spring lacks Jakarta's built-in `ClientErrorException`. Use `@RestControllerAdvice`:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(ProductNotFoundException.class)
    public ResponseEntity<String> handleNotFound(ProductNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ex.getMessage());
    }

    @ExceptionHandler(NotEnoughItemsInStockException.class)
    public ResponseEntity<String> handleConflict(NotEnoughItemsInStockException ex) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(ex.getMessage());
    }
}
```

Keep this class in the `adapter.in.rest` package — it's adapter infrastructure, not core logic.

---

## Persistence Adapter (Secondary — Spring Data JPA)

Spring Data `JpaRepository` replaces manual persistence. The adapter still implements the core's port interface.

```java
// Spring Data interface — lives in adapter.out.persistence
interface SpringDataCartRepository extends JpaRepository<CartJpaEntity, UUID> {
    Optional<CartJpaEntity> findByCustomerId(UUID customerId);
}

// Adapter — implements the core's secondary port
@Component
public class JpaCartRepository implements CartRepository {
    private final SpringDataCartRepository springRepo;
    private final CartMapper mapper;

    public JpaCartRepository(SpringDataCartRepository springRepo, CartMapper mapper) {
        this.springRepo = springRepo;
        this.mapper = mapper;
    }

    @Override
    public Optional<Cart> findByCustomerId(CustomerId customerId) {
        return springRepo.findByCustomerId(customerId.value())
                         .map(mapper::toDomain);     // Optional.map, not null check
    }

    @Override
    public Cart save(Cart cart) {
        CartJpaEntity entity = mapper.toJpa(cart);
        return mapper.toDomain(springRepo.save(entity));
    }
}
```

`@Entity` classes and `@Column` annotations stay in the persistence adapter package — never on domain models.

---

## Dependency Injection & Bootstrap

Use `@SpringBootApplication` and `@Bean` methods for wiring. Conditional beans replace manual profile checks.

```java
@SpringBootApplication
public class ShopApplication {
    public static void main(String[] args) {
        SpringApplication.run(ShopApplication.class, args);
    }

    // Wire the use case with its port implementations
    @Bean
    public CartService cartService(CartRepository cartRepository,
                                   ProductRepository productRepository) {
        return new CartService(cartRepository, productRepository);
    }
}
```

### Conditional Adapters

Switch between in-memory and DB-backed adapters via a property:

```java
@Bean
@ConditionalOnProperty(name = "persistence", havingValue = "inmemory", matchIfMissing = true)
public CartRepository inMemoryCartRepository() {
    return new InMemoryCartRepository();
}

@Bean
@ConditionalOnProperty(name = "persistence", havingValue = "mysql")
public CartRepository jpaCartRepository(SpringDataCartRepository repo, CartMapper mapper) {
    return new JpaCartRepository(repo, mapper);
}
```

`application.properties`:
```properties
persistence=inmemory
```

`application-mysql.properties`:
```properties
persistence=mysql
spring.datasource.url=jdbc:mysql://localhost:3306/shop
```

**Gotcha**: Spring Data JPA scans for a datasource at startup even when in-memory mode is active. Add an H2 fallback or exclude `DataSourceAutoConfiguration` to avoid startup failures.

---

## Testing

### Unit Tests (Core — unchanged)

No Spring context needed. Same as the plain Java approach: mock secondary ports via Mockito.

```java
class CartServiceTest {
    private final CartRepository cartRepo = mock(CartRepository.class);
    private final ProductRepository productRepo = mock(ProductRepository.class);
    private final CartService service = new CartService(cartRepo, productRepo);
    // ...
}
```

### Integration Tests (REST Adapter)

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test-inmemory")
class CartControllerIntegrationTest {
    @LocalServerPort int port;

    @Test
    void addToCart_returns200WithCart() {
        given().port(port)
               .contentType(ContentType.JSON)
               .body(new AddToCartRequest(productId, 2))
               .when().post("/carts/{id}/line-items", customerId)
               .then().statusCode(200)
               .body("lineItems.size()", is(1));
    }
}
```

### Integration Tests (Persistence Adapter — Testcontainers)

Unlike Quarkus, Spring requires explicit Testcontainers setup:

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = Replace.NONE)
@Testcontainers
class JpaCartRepositoryTest {
    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url",
            () -> "jdbc:tc:mysql:8.0:///" + mysql.getDatabaseName());
    }

    @Autowired JpaCartRepository repository;

    @Test
    void save_thenFind_returnsCart() { ... }
}
```

---

## Spring Boot Checklist

- [ ] `@RestController`, `@RequestMapping`, `@PathVariable` in `adapter.in.rest` only
- [ ] `@RestControllerAdvice` error handler in `adapter.in.rest` — not in core
- [ ] `@Entity`, `@Column`, Spring Data interfaces in `adapter.out.persistence` only
- [ ] `@SpringBootApplication` and `@Bean` wiring in bootstrap/config only — core classes have no Spring annotations
- [ ] `@ConditionalOnProperty` used to swap adapters without modifying core
- [ ] `@DeleteMapping` handlers return `ResponseEntity.noContent().build()` for 204
- [ ] Testcontainers configured with explicit `@DynamicPropertySource` for DB URL
- [ ] Unit tests for core run without any Spring context (`@SpringBootTest` free)
