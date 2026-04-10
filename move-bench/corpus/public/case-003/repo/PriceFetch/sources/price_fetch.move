module dexlyn_price_fetcher::fetch_clmm_price {

    use std::option;
    use std::vector;

    use dexlyn_clmm::pool::{destructure_pool_details, get_pool_details};
    use integer_mate::full_math_u128;
    use supra_framework::fungible_asset::{Self, Metadata};
    use supra_framework::object::address_to_object;
    use supra_framework::timestamp;

    const DEFAULT_DECIMAL: u16 = 18;
    const DEFAULT_DECIMAL_PRECISION_9: u64 = 1_000_000_000;
    const E_INCORRECT_VALUES: u64 = 0;
    const E_POOL_NOT_EXIST: u64 = 1;

    struct Price has drop {
        pool_address: address,
        asset_a_address: address,
        asset_b_address: address,
        value: u256,
        decimal: u16,
        timestamp: u64,
    }

    #[view]
    public fun get_prices(pool_addresses: vector<address>): vector<Price> {
        let pool_details = get_pool_details(pool_addresses);
        let price_details = vector<Price>[];
        let pool_address;
        let sqrt_price;
        let asset_a_address;
        let asset_b_address;

        let value;
        vector::for_each_reverse(pool_details, |pool| {
            if (option::is_some(&pool)) {
                (_, pool_address, _, _, _, _, _, _, sqrt_price, _, _, _, _, _, _, _, _, asset_a_address, asset_b_address) = destructure_pool_details(
                    option::borrow(&pool)
                );

                value = find_price(sqrt_price, asset_a_address, asset_b_address);

                vector::push_back(&mut price_details, Price {
                    pool_address,
                    asset_a_address,
                    asset_b_address,
                    value,
                    decimal: DEFAULT_DECIMAL,
                    timestamp: timestamp::now_seconds()
                })
            }
        });

        price_details
    }

    #[view]
    public fun get_price(pool_address: address): Price {
        let pool = vector::pop_back(&mut get_pool_details(vector[pool_address]));
        assert!(option::is_some(&pool), E_POOL_NOT_EXIST);
        let (_, pool_address, _, _, _, _, _, _, sqrt_price, _, _, _, _, _, _, _, _, asset_a_address, asset_b_address) = destructure_pool_details(
            option::borrow(&pool)
        );

        let value = find_price(sqrt_price, asset_a_address, asset_b_address);

        Price {
            pool_address,
            asset_a_address,
            asset_b_address,
            value,
            decimal: DEFAULT_DECIMAL,
            timestamp: timestamp::now_seconds()
        }
    }

    public fun extract_price(price: &Price): (address, address, address, u256, u16, u64) {
        (
            price.pool_address,
            price.asset_a_address,
            price.asset_b_address,
            price.value,
            price.decimal,
            price.timestamp,
        )
    }

    fun find_price(sqrt_price: u128, asset_a_address: address, asset_b_address: address): u256 {
        let asset_a_decimal = fungible_asset::decimals(address_to_object<Metadata>(asset_a_address));
        let asset_b_decimal = fungible_asset::decimals(address_to_object<Metadata>(asset_b_address));

        let value = calculate_power(
            full_math_u128::mul_shr(sqrt_price, (DEFAULT_DECIMAL_PRECISION_9 as u128), 64),
            2
        );

        if (asset_a_decimal > asset_b_decimal) {
            value = value * calculate_power(10, ((asset_a_decimal - asset_b_decimal) as u16));
        }
        else if (asset_a_decimal < asset_b_decimal) {
            value = value / calculate_power(10, ((asset_b_decimal - asset_a_decimal) as u16));
        };

        value
    }

    /// Calculates the power of a base raised to an exponent. The result of `base` raised to the power of `exponent`
    public fun calculate_power(base: u128, exponent: u16): u256 {
        let result: u256 = 1;
        let base: u256 = (base as u256);
        assert!((base | (exponent as u256)) != 0, E_INCORRECT_VALUES);
        if (base == 0) { return 0 };
        while (exponent != 0) {
            if ((exponent & 0x1) == 1) { result = result * base; };
            base = base * base;
            exponent = (exponent >> 1);
        };
        result
    }
}