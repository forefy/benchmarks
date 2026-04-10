/// Simple per-owner counter on Sui.
/// Each user creates their own Counter object; only the owner may mutate it.
module counter::counter {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    struct Counter has key {
        id: UID,
        owner: address,
        value: u64,
    }

    /// Create a new Counter owned by the caller.
    public fun create(ctx: &mut TxContext) {
        let counter = Counter {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            value: 0,
        };
        transfer::transfer(counter, tx_context::sender(ctx));
    }

    /// Increment the counter by 1. Only the owner may call this.
    public fun increment(counter: &mut Counter, ctx: &TxContext) {
        assert!(counter.owner == tx_context::sender(ctx), 0);
        counter.value = counter.value + 1;
    }

    /// Decrement the counter by 1. Only the owner may call this.
    /// Aborts if the counter is already zero.
    public fun decrement(counter: &mut Counter, ctx: &TxContext) {
        assert!(counter.owner == tx_context::sender(ctx), 0);
        assert!(counter.value > 0, 1);
        counter.value = counter.value - 1;
    }

    /// Reset the counter to zero. Only the owner may call this.
    public fun reset(counter: &mut Counter, ctx: &TxContext) {
        assert!(counter.owner == tx_context::sender(ctx), 0);
        counter.value = 0;
    }

    /// Read the current value (anyone may read).
    public fun value(counter: &Counter): u64 {
        counter.value
    }
}
