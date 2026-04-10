/// Simple address whitelist registry on Aptos.
/// The deployer owns the registry and is the only one who can add or remove entries.
module whitelist::registry {
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;

    struct Registry has key {
        entries: vector<address>,
        created_at: u64,
    }

    /// Capability proving that the holder initialized and owns this registry.
    struct OwnerCap has key {}

    const E_ALREADY_INITIALIZED: u64 = 0;
    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_REGISTERED: u64 = 2;
    const E_NOT_REGISTERED: u64 = 3;

    /// Initialize a new registry. Can only be called once per address.
    public fun initialize(owner: &signer) {
        let addr = signer::address_of(owner);
        assert!(!exists<Registry>(addr), E_ALREADY_INITIALIZED);
        move_to(owner, Registry {
            entries: vector::empty<address>(),
            created_at: timestamp::now_seconds(),
        });
        move_to(owner, OwnerCap {});
    }

    /// Add an address to the registry. Only the owner may call this.
    public fun add(owner: &signer, addr: address) acquires Registry {
        let owner_addr = signer::address_of(owner);
        assert!(exists<OwnerCap>(owner_addr), E_NOT_OWNER);
        let registry = borrow_global_mut<Registry>(owner_addr);
        assert!(!vector::contains(&registry.entries, &addr), E_ALREADY_REGISTERED);
        vector::push_back(&mut registry.entries, addr);
    }

    /// Remove an address from the registry. Only the owner may call this.
    public fun remove(owner: &signer, addr: address) acquires Registry {
        let owner_addr = signer::address_of(owner);
        assert!(exists<OwnerCap>(owner_addr), E_NOT_OWNER);
        let registry = borrow_global_mut<Registry>(owner_addr);
        let (found, idx) = vector::index_of(&registry.entries, &addr);
        assert!(found, E_NOT_REGISTERED);
        vector::remove(&mut registry.entries, idx);
    }

    /// Check whether an address is registered (read-only, callable by anyone).
    public fun is_registered(owner_addr: address, addr: address): bool acquires Registry {
        if (!exists<Registry>(owner_addr)) return false;
        let registry = borrow_global<Registry>(owner_addr);
        vector::contains(&registry.entries, &addr)
    }

    /// Return the number of registered entries.
    public fun count(owner_addr: address): u64 acquires Registry {
        if (!exists<Registry>(owner_addr)) return 0;
        let registry = borrow_global<Registry>(owner_addr);
        vector::length(&registry.entries)
    }
}
