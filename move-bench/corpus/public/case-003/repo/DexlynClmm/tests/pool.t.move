#[test_only]
module dexlyn_clmm::pool_test {
    use std::option;
    use std::signer;
    use std::string::{Self, utf8};
    use std::vector;

    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::fungible_asset::Metadata;
    use supra_framework::object;
    use supra_framework::primary_fungible_store;
    use supra_framework::timestamp;

    use dexlyn_clmm::clmm_router;
    use dexlyn_clmm::clmm_router::{add_fee_tier, add_liquidity_fix_value};
    use dexlyn_clmm::factory;
    use dexlyn_clmm::pool;
    use dexlyn_clmm::pool::{get_pool_index, repay_add_liquidity};
    use dexlyn_clmm::test_helpers::{mint_tokens, setup_fungible_assets, TestCoinA, TestCoinB};
    use dexlyn_clmm::utils;
    use integer_mate::i64;

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm
    )]
    #[expected_failure] // E_SAME_COIN_TYPE
    public fun test_create_pool_same_coin_type(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        factory::init_factory_module(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;

        let asset_a_addr = utils::coin_to_fa_address<TestCoinA>();
        let asset_b_addr = utils::coin_to_fa_address<TestCoinA>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(asset_a_addr, asset_b_addr);
        clmm_router::create_pool_coin_coin<TestCoinA, TestCoinA>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            asset_a_sorted,
            asset_b_sorted
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm
    )]
    #[expected_failure(abort_code = factory::EINVALID_SQRTPRICE)] // E_INVALID_SQRT_PRICE
    public fun test_invalid_sqrt_price(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        factory::init_factory_module(admin);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 100;

        let asset_a_addr = utils::coin_to_fa_address<TestCoinA>();
        let asset_b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(asset_a_addr, asset_b_addr);

        clmm_router::create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            asset_a_sorted,
            asset_b_sorted
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm
    )]
    public fun test_nonexistent_pool(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        factory::init_factory_module(admin);
        mint_tokens(admin);

        let asset_a_addr = utils::coin_to_fa_address<TestCoinA>();
        let asset_b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(asset_a_addr, asset_b_addr);


        let pool_opt = factory::get_pool(200, asset_a_sorted, asset_b_sorted);
        assert!(option::is_none(&pool_opt), 1);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm
    )]
    public fun test_fetch_positions_and_get_position(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        factory::init_factory_module(admin);
        mint_tokens(admin);


        let tick_spacing = 100;
        let init_sqrt_price = 18446744073709551616;
        let fee_rate = 1000;

        add_fee_tier(admin, tick_spacing, fee_rate);

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);

        clmm_router::create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), asset_a_sorted, asset_b_sorted
        );

        let pool_address = get_pool_address(tick_spacing, asset_a_sorted, asset_b_sorted);

        // Open a position
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 400;
        let pos_id = pool::open_position(
            admin, pool_address, integer_mate::i64::from_u64(tick_lower), integer_mate::i64::from_u64(tick_upper)
        );

        // fetch_positions
        let (_start, positions) = pool::fetch_positions(pool_address, 0, 10);
        assert!(std::vector::length<pool::Position>(&positions) > 0, 100);

        // get_position
        let position_vec = vector[pos_id, pos_id, 2, 3];
        let pos = pool::get_positions(pool_address, position_vec);
        let position = vector::borrow(&pos, 0);
        let (pos_pool_address, pos_index, liquidity,
            tick_lower_index, tick_upper_index, fee_growth_inside_a, fee_owed_a, fee_growth_inside_b, fee_owed_b, rewarder_infos) = pool::destructure_position(
            position
        );
        assert!(pos_pool_address == pool_address, 101);
        assert!(pos_index == pos_id, 102);
        assert!(liquidity == 0, 103);
        assert!(tick_lower_index == integer_mate::i64::from_u64(tick_lower), 104);
        assert!(tick_upper_index == integer_mate::i64::from_u64(tick_upper), 105);
        assert!(fee_growth_inside_a == 0, 106);
        assert!(fee_owed_a == 0, 107);
        assert!(fee_growth_inside_b == 0, 108);
        assert!(fee_owed_b == 0, 109);
        assert!(vector::length(&rewarder_infos) > 0, 110);

        let rewarder_info = vector::borrow(&rewarder_infos, 0);
        let (growth_inside, amount_owed) = pool::destructure_position_rewarder(rewarder_info);
        assert!(growth_inside == 0, 111);
        assert!(amount_owed == 0, 112);
    }


    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm
    )]
    public fun test_fetch_ticks_and_get_position_tick_range(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        factory::init_factory_module(admin);
        mint_tokens(admin);

        let fee_rate = 1000;
        let tick_spacing = 100;
        let init_sqrt_price = 18446744073709551616;

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);

        add_fee_tier(admin, tick_spacing, fee_rate);
        clmm_router::create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), asset_a_sorted, asset_b_sorted
        );

        let pool_address = get_pool_address(tick_spacing, b_addr, a_addr);

        // fetch_ticks
        let (_tick_index, _bit_index, ticks) = pool::fetch_ticks(pool_address, 0, 0, 10);
        assert!(std::vector::length<pool::Tick>(&ticks) >= 0, 101);

        // Open a position and get its tick range
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 400;
        let pos_id = pool::open_position(
            admin, pool_address, integer_mate::i64::from_u64(tick_lower), integer_mate::i64::from_u64(tick_upper)
        );
        let (_lower, _upper) = pool::get_position_tick_range(pool_address, pos_id);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm
    )]
    public fun test_get_rewarder_len_and_get_tick_spacing(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        factory::init_factory_module(admin);
        mint_tokens(admin);

        let tick_spacing = 100;
        let fee_rate = 1000;
        let init_sqrt_price = 18446744073709551616;
        add_fee_tier(admin, tick_spacing, fee_rate);

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);

        clmm_router::create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), asset_a_sorted, asset_b_sorted
        );


        let pool_address = get_pool_address(tick_spacing, b_addr, a_addr);

        // get_rewarder_len
        let rewarder_len = pool::get_rewarder_len(pool_address);
        assert!(rewarder_len >= 0, 102);

        // get_tick_spacing
        let spacing = pool::get_tick_spacing(pool_address);
        assert!(spacing == tick_spacing, 103);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm
    )]
    public fun test_reset_init_price_v2_and_tick_offset_and_update_fee_rate(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        factory::init_factory_module(admin);
        clmm_router::init_clmm_acl(admin);
        clmm_router::add_role(admin, signer::address_of(admin), 1);
        clmm_router::add_role(admin, signer::address_of(admin), 2);
        mint_tokens(admin);

        let tick_spacing = 100;
        let init_sqrt_price = 18446744073709551616;
        let fee_rate = 1000;
        add_fee_tier(admin, tick_spacing, fee_rate);

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);

        clmm_router::create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), asset_a_sorted, asset_b_sorted
        );

        let pool_address = get_pool_address(tick_spacing, asset_a_sorted, asset_b_sorted);

        // reset_init_price_v2
        pool::reset_init_price(admin, pool_address, init_sqrt_price);

        // update_fee_rate
        pool::update_fee_rate(admin, pool_address, 1234);
    }

    #[test_only]
    public fun get_pool_address(tick_spacing: u64, a_addr: address, b_addr: address): address {
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);
        let clmm_pool_addr_opt = factory::get_pool(tick_spacing, asset_a_sorted, asset_b_sorted);
        option::extract(&mut clmm_pool_addr_opt)
    }


    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_get_pool_details(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));


        // Create Pool 1
        let tick_spacing1 = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 155668;
        let amount_b = 300000;
        let tick_lower = 18446744073709551416;
        let tick_upper = 200;

        let fee_rate1 = 1000;
        let fee_rate2 = 500;
        let fee_rate3 = 100;

        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing1, fee_rate1);

        let pool_address1 = factory::create_pool(
            admin, tick_spacing1, init_sqrt_price, string::utf8(b""), token_a, token_b
        );

        let collection = dexlyn_clmm::position_nft::collection_name(tick_spacing1, token_a, token_b);

        add_liquidity_fix_value(
            admin, pool_address1, amount_a, amount_b, true, tick_lower, tick_upper, true, 0
        );


        // Create Pool 2
        let tick_spacing = 60;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 358963;
        let amount_b = 400000;
        let tick_lower = 18446744073709551556;
        let tick_upper = 60;
        add_fee_tier(admin, tick_spacing, fee_rate2);

        let pool_address2 = factory::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), token_a, token_b
        );

        add_liquidity_fix_value(
            admin, pool_address2, amount_a, amount_b, true, tick_lower, tick_upper, true, 0
        );


        // Create Pool 3
        let tick_spacing = 30;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 125669;
        let amount_b = 256856;
        let tick_lower = 18446744073709551586;
        let tick_upper = 30;
        add_fee_tier(admin, tick_spacing, fee_rate3);

        let pool_address3 = factory::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), token_a, token_b
        );
        add_liquidity_fix_value(
            admin, pool_address3, amount_a, amount_b, true, tick_lower, tick_upper, true, 0
        );

        // vector of pool addresses
        let pool_addresses = vector[pool_address1, pool_address2, pool_address3, signer::address_of(admin)];
        let pool_details = pool::get_pool_details(pool_addresses);
        assert!(vector::length(&pool_details) == 4, 101);

        let details_opt = vector::borrow(&pool_details, 0);
        let details = option::borrow(details_opt);
        let (
            index, pool_addr, collection_name, asset_a, asset_b, tick_spacing_val, fee_rate_val,
            liquidity, current_sqrt_price, current_tick_index, fee_growth_global_a, fee_growth_global_b,
            fee_protocol_asset_a, fee_protocol_asset_b, position_count, is_pause, uri, asset_a_addr, asset_b_addr
        ) = pool::destructure_pool_details(details);

        assert!(index == get_pool_index(pool_address1), 102);
        assert!(pool_addr == pool_address1, 103);
        assert!(collection_name == collection, 104);
        assert!(asset_a == 155668, 105);
        assert!(asset_b == 155668, 106);
        assert!(tick_spacing_val == tick_spacing1, 107);
        assert!(fee_rate_val == fee_rate1, 108);
        assert!(liquidity > 0, 109);
        assert!(current_sqrt_price == init_sqrt_price, 110);
        assert!(current_tick_index == i64::from_u64(0), 111);
        assert!(fee_growth_global_a == 0, 112);
        assert!(fee_growth_global_b == 0, 113);
        assert!(fee_protocol_asset_a == 0, 114);
        assert!(fee_protocol_asset_b == 0, 115);
        assert!(position_count == 2, 116);
        assert!(is_pause == false, 117);
        assert!(uri == string::utf8(b"https://qa-cdn.dexlyn.com/clmm/clmm.json"), 118);
        assert!(asset_a_addr == token_a, 119);
        assert!(asset_b_addr == token_b, 120);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public fun test_destructure_position_rewarder(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        factory::init_factory_module(admin);
        mint_tokens(admin);

        let tick_spacing = 100;
        let fee_rate = 1000;
        let init_sqrt_price = 18446744073709551616;
        add_fee_tier(admin, tick_spacing, fee_rate);

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);

        clmm_router::create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), asset_a_sorted, asset_b_sorted
        );

        let pool_address = get_pool_address(tick_spacing, asset_a_sorted, asset_b_sorted);

        // Open position
        let tick_lower = 18446744073709551216;
        let tick_upper = 400;
        let pos_id = pool::open_position(
            admin, pool_address, i64::from_u64(tick_lower), i64::from_u64(tick_upper)
        );

        // Get position and rewarder info
        let position_vec = vector[pos_id];
        let positions = pool::get_positions(pool_address, position_vec);
        let position = vector::borrow(&positions, 0);
        let (_, _, _, _, _, _, _, _, _, rewarder_infos) = pool::destructure_position(position);

        // Test each rewarder
        let i = 0;
        while (i < vector::length(&rewarder_infos)) {
            let rewarder = vector::borrow(&rewarder_infos, i);
            let (growth_inside, amount_owed) = pool::destructure_position_rewarder(rewarder);

            assert!(growth_inside >= 0, 401 + i);
            assert!(amount_owed >= 0, 404 + i);
            i = i + 1;
        };
    }


    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public fun test_destructure_add_liquidity_receipt(
        admin: &signer,
        supra_framework: &signer
    ) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        factory::init_factory_module(admin);

        // Setup fungible assets instead of minting coins
        let a_addr = setup_fungible_assets(admin, string::utf8(b"TestTokenA"), string::utf8(b"TTA"));
        let b_addr = setup_fungible_assets(admin, string::utf8(b"TestTokenB"), string::utf8(b"TTB"));

        let tick_spacing = 100;
        let fee_rate = 1000;
        let init_sqrt_price = 18446744073709551616;
        add_fee_tier(admin, tick_spacing, fee_rate);

        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);

        // Create pool with fungible assets
        clmm_router::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), asset_a_sorted, asset_b_sorted
        );

        let pool_address = get_pool_address(tick_spacing, asset_a_sorted, asset_b_sorted);

        // Open position
        let tick_lower = 18446744073709551216;
        let tick_upper = 400;
        let pos_id = pool::open_position(
            admin, pool_address, i64::from_u64(tick_lower), i64::from_u64(tick_upper)
        );

        // Add liquidity and get receipt
        let liquidity = 1000000;
        let receipt = pool::add_liquidity_v2(admin, pool_address, liquidity, pos_id);

        // Destructure receipt
        let (receipt_pool_address, amount_a, amount_b) = pool::destructure_add_liquidity_receipt(&receipt);

        // Verify receipt properties
        assert!(receipt_pool_address == pool_address, 601);
        assert!(amount_a > 0, 602);
        assert!(amount_b >= 0, 603);

        // Withdraw tokens and repay
        let a_metadata = object::address_to_object<Metadata>(asset_a_sorted);
        let b_metadata = object::address_to_object<Metadata>(asset_b_sorted);
        let token_a = primary_fungible_store::withdraw(admin, a_metadata, amount_a);
        let token_b = primary_fungible_store::withdraw(admin, b_metadata, amount_b);
        repay_add_liquidity(token_a, token_b, receipt);
    }
}