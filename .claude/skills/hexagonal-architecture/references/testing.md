# Testing in Hexagonal Architecture

One of the core benefits of this architecture is independently testable components. Each layer has its own test strategy.

---

## Unit Tests — Application Core

Test use cases through the primary port interface. Replace secondary adapters with test doubles (mocks/stubs/fakes).

**What to test:**
- All business rules and domain logic
- Use case orchestration
- Edge cases and error paths

**What NOT to need:**
- No database, no HTTP server, no Spring context

```java
class PlaceOrderServiceTest {
    private final OrderRepository orderRepository = mock(OrderRepository.class);
    private final PaymentPort paymentPort = mock(PaymentPort.class);
    private final PlaceOrderUseCase useCase =
        new PlaceOrderService(orderRepository, paymentPort);

    @Test
    void placeOrder_persistsOrderAndChargesPayment() {
        var command = new PlaceOrderCommand(...);
        var orderId = useCase.placeOrder(command);

        verify(orderRepository).save(any(Order.class));
        verify(paymentPort).charge(any(Payment.class));
        assertThat(orderId).isNotNull();
    }
}
```

---

## Integration Tests — Adapters

Test each adapter in isolation from the core. Verify it correctly translates between the external system and the port contract.

### Primary adapter (REST)

Use REST Assured or MockMvc. Replace the use case with a test double.

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {
    @MockBean PlaceOrderUseCase placeOrderUseCase;

    @Test
    void postOrder_returns201WithLocation() throws Exception {
        given(placeOrderUseCase.placeOrder(any())).willReturn(new OrderId("123"));

        mockMvc.perform(post("/orders").content(...))
               .andExpect(status().isCreated())
               .andExpect(header().string("Location", containsString("123")));
    }
}
```

### Secondary adapter (Persistence)

Use Testcontainers (real DB in Docker) or an in-memory DB. Test that the adapter fulfills the port contract.

```java
@DataJpaTest
class JpaOrderRepositoryTest {
    @Autowired JpaOrderRepository repository;

    @Test
    void save_thenFindById_returnsOrder() {
        var order = new Order(...);
        repository.save(order);

        var found = repository.findById(order.getId());
        assertThat(found).isPresent().contains(order);
    }
}
```

### Secondary adapter (External HTTP service)

Use WireMock to stub the external service.

```java
@WireMockTest
class StripePaymentAdapterTest {
    @Test
    void charge_callsStripeAndReturnsConfirmation(WireMockRuntimeInfo wm) {
        stubFor(post("/v1/charges").willReturn(okJson("{\"id\":\"ch_123\"}")));

        var adapter = new StripePaymentAdapter(wm.getHttpBaseUrl());
        var result = adapter.charge(new Payment(...));

        assertThat(result.confirmationId()).isEqualTo("ch_123");
    }
}
```

---

## System / E2E Tests

Start the full application (real or containerized dependencies). Verify complete flows end to end.

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class PlaceOrderSystemTest {
    @Container static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");

    @Test
    void fullOrderFlow_persistsAndReturns201() {
        given().body(orderJson).contentType(JSON)
               .when().post("/orders")
               .then().statusCode(201);
    }
}
```

---

## Test Pyramid Summary

| Layer | Scope | Speed | Tools |
|-------|-------|-------|-------|
| Unit (core) | Use cases + domain | Fast (ms) | JUnit, Mockito |
| Integration (adapters) | Each adapter alone | Medium (seconds) | MockMvc, Testcontainers, WireMock |
| System | Full application | Slow (minutes) | REST Assured, Testcontainers |

**Aim for**: many unit tests, moderate integration tests, few system tests.
