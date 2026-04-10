#[test_only]
module dexlyn_clmm::add_liquidity_test {
    use std::option;
    use std::signer::{Self, address_of};
    use std::string::{Self, utf8};
    use std::vector;

    use aptos_token_objects::token;
    use supra_framework::account;
    use supra_framework::coin::{Self, migrate_to_fungible_store};
    use supra_framework::fungible_asset::{Self, Metadata};
    use supra_framework::object;
    use supra_framework::primary_fungible_store;
    use supra_framework::timestamp;

    use dexlyn_clmm::clmm_math;
    use dexlyn_clmm::clmm_router::{
        add_fee_tier,
        add_liquidity,
        add_liquidity_coin_asset,
        add_liquidity_coin_coin,
        add_liquidity_fix_value,
        add_liquidity_fix_value_coin_asset,
        create_pool_coin_asset,
        create_pool_coin_coin,
        remove_liquidity
    };
    use dexlyn_clmm::config;
    use dexlyn_clmm::factory;
    use dexlyn_clmm::fee_tier;
    use dexlyn_clmm::fee_tier::get_fee_rate;
    use dexlyn_clmm::pool;
    use dexlyn_clmm::pool::get_pool_liquidity;
    use dexlyn_clmm::position_nft;
    use dexlyn_clmm::test_helpers::{
        mint_tokens,
        setup_fungible_assets,
        TestCoinA,
        TestCoinB
    };
    use dexlyn_clmm::tick_math;
    use dexlyn_clmm::token_factory;
    use dexlyn_clmm::utils;
    use integer_mate::i64;

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_create_and_add_liquidity(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);

        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000;
        let amount_b = 400000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 1001);

        let user_balance_a_before = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );
        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 181602, 1002); // min[181602.549077, 20201666.612228]

        let user_balance_a_after = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1003); // 99999.6976491452
        assert!((user_balance_b_before - user_balance_b_after) == 3596, 1004); // 3595.782535883948
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
        user_a = @0xA,
        user_b = @0xB,
    )]
    public entry fun test_nft_transfer_and_close_position(
        user_a: &signer,
        user_b: &signer,
        supra_framework: &signer,
        admin: &signer
    ) {
        // Setup: mint tokens to user_a
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(user_a));
        account::create_account_for_test(signer::address_of(user_b));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000;
        let amount_b = 400000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;

        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 2001);

        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );
        let pool_index = dexlyn_clmm::pool::get_pool_index(pool_address);

        let position_index = 1;
        let collection = dexlyn_clmm::position_nft::collection_name(tick_spacing, token_a, token_b);
        let nft_name = dexlyn_clmm::position_nft::position_name(pool_index, position_index);
        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 181602, 2002); // min[181602.549077, 20201666.612228]

        let token_address = aptos_token_objects::token::create_token_address(
            &pool_address,
            &collection,
            &nft_name
        );

        // check nft owner and is vaild
        let is_valid_nft = position_nft::is_valid_nft(token_address, pool_address);
        assert!(is_valid_nft == true, 1001);

        let token_obj = aptos_framework::object::address_to_object<aptos_token_objects::token::Token>(token_address);
        aptos_framework::object::transfer(admin, token_obj, signer::address_of(user_b));

        // get the NFT details from Token Address
        let vec_token_address = vector[token_address, token_address];
        let _nft_details = position_nft::get_nft_details(vec_token_address);


        remove_liquidity(
            user_b,
            pool_address,
            181602,
            0,
            0,
            1,
            true
        );

        let pool_liquidity2 = get_pool_liquidity(pool_address);
        assert!(pool_liquidity2 == 0, 2003);
    }


    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
        user_a = @0xA,
        user_b = @0xB,
    )]
    public entry fun test_update_collection_and_nfts_uri(
        user_a: &signer,
        user_b: &signer,
        supra_framework: &signer,
        admin: &signer
    ) {
        // Setup: mint tokens to user_a
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(user_a));
        account::create_account_for_test(signer::address_of(user_b));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000;
        let amount_b = 400000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;


        factory::init_factory_module(admin);
        config::init_clmm_acl(admin);
        config::add_role(admin, signer::address_of(admin), 1);
        config::add_role(admin, signer::address_of(admin), 2);

        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 2001);


        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"init"),
            token_a,
            token_b,
        );
        let pool_index = dexlyn_clmm::pool::get_pool_index(pool_address);

        let position_index = 1;
        let collection = dexlyn_clmm::position_nft::collection_name(tick_spacing, token_a, token_b);
        let nft_name = dexlyn_clmm::position_nft::position_name(pool_index, position_index);

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 181602, 2002); // min[181602.549077, 20201666.612228]

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let token_address = aptos_token_objects::token::create_token_address(
            &pool_address,
            &collection,
            &nft_name
        );

        // check nft owner and is vaild
        let is_valid_nft = position_nft::is_valid_nft(token_address, pool_address);
        assert!(is_valid_nft == true, 1001);

        let token_obj = aptos_framework::object::address_to_object<aptos_token_objects::token::Token>(token_address);
        let uri = string::utf8(b"init");
        let token_uri = token::uri(token_obj);
        assert!(token_uri == uri, 1001); // check inital token uri

        // update uri
        pool::update_collection_and_nfts_uri(admin, pool_address, string::utf8(b"new_updated_uri"), 0, 10);

        let token_uri2 = token::uri(token_obj);
        let uri_update1 = string::utf8(b"new_updated_uri");
        assert!(token_uri2 == uri_update1, 1002); // check updated token uri

        aptos_framework::object::transfer(admin, token_obj, signer::address_of(user_b));

        // get the NFT details from Token Address
        let vec_token_address = vector[token_address, token_address];
        let _nft_details = position_nft::get_nft_details(vec_token_address);


        remove_liquidity(
            admin,
            pool_address,
            181602,
            0,
            0,
            2,
            true
        );

        pool::update_collection_and_nfts_uri(admin, pool_address, string::utf8(b"again_updated_uri"), 0, 10);
        let uri_update2 = string::utf8(b"again_updated_uri");
        let token_uri3 = token::uri(token_obj);
        assert!(token_uri3 == uri_update2, 1002); // check again updated token uri
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_add_liquidity_full_range(admin: &signer, supra_framework: &signer) {
        let admin_addr = signer::address_of(admin);
        account::create_account_for_test(admin_addr);

        timestamp::set_time_has_started_for_testing(supra_framework);

        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 2;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709107980; // -min_lower
        let tick_upper = 443636;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let user_balance_a_before = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 100000, 1001); // min[100000.000023, 100000.000023]

        let user_balance_a_after = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1002); // 99999.9999767165
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003); // 99999.9999767165

        add_liquidity(
            admin,
            pool_address,
            25000,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            true,
            1,
        );
        let pool_liquidity2 = get_pool_liquidity(pool_address);
        assert!(pool_liquidity2 == 100000 + 25000, 1004);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_liquidity_below_current_tick(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709549616; // -2000
        let tick_upper = 18446744073709550616; // -1000

        let user_balance_a_before = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            false,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 0, 1001); // one-side-liquidity

        let user_balance_a_after = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_before - user_balance_a_after) == 0, 1002);
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003); // 99999.98553585552
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_liquidity_above_current_tick(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 16000;
        let tick_upper = 26000;

        let user_balance_a_before = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 0, 1001); // one-side-liquidity

        let user_balance_a_after = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1002); // 99999.3271327113
        assert!((user_balance_b_before - user_balance_b_after) == 0, 1003);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_multiple_overlapping_positions(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let user_balance_a_before = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        // Position 1
        add_liquidity_fix_value(
            admin,
            pool_address,
            100000,
            100000,
            false,
            18446744073709549616, // -2000
            0, // 0
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 0, 1001); // min[0.000000, 1050883.152001]

        let user_balance_a_after = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_before - user_balance_a_after) == 0, 1002);
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003);

        // Position 2
        add_liquidity_fix_value(
            admin,
            pool_address,
            100000,
            100000,
            true,
            18446744073709550616, // -1000
            16000,
            true,
            0,
        );

        let pool_liquidity2 = get_pool_liquidity(pool_address);
        assert!(pool_liquidity2 == 181602, 1004); // min[181602.549077, 2050516.626811]

        let user_balance_a_after2 = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after2 = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_after - user_balance_a_after2) == 100000, 1005); // 99999.6976491452
        assert!((user_balance_b_after - user_balance_b_after2) == 8857, 1006); // 8856.402217154447

        // Position 3
        add_liquidity_fix_value(
            admin,
            pool_address,
            100000,
            100000,
            true,
            0,
            26000,
            true,
            0,
        );

        let pool_liquidity3 = get_pool_liquidity(pool_address);
        assert!(pool_liquidity3 == 137466 + pool_liquidity2, 1007); // [137466.399379, 0]

        let user_balance_a_after3 = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after3 = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_after2 - user_balance_a_after3) == 100000, 1008);
        assert!((user_balance_b_after3 - user_balance_b_after2) == 0, 1009);

        let position_ids = vector[1, 2, 3];
        let token_addressess = pool::generate_token_addresses(pool_address, position_ids);
        assert!(vector::length(&token_addressess) == 3, 1010);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_narrow_range_position(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 2;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709551596; // -20
        let tick_upper = 20;

        let user_balance_a_before = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        add_liquidity_fix_value(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 100055008, 1001); // min[ 100055008.249595, 200060003.999810 ]

        let user_balance_a_after = token_factory::get_token_balance(admin, address_of(admin), token_a_name);
        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1002); // 99999.99975054196
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003); // 99999.99975053998
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = pool::EIS_NOT_VALID_TICK)] // EIS_NOT_VALID_TICK
    public entry fun test_invalid_tick_range(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        add_liquidity_fix_value(
            admin,
            pool_address,
            100000,
            100000,
            true,
            16000,
            0,
            true,
            0,
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = clmm_math::EINVALID_FIXED_TOKEN_TYPE)] // EINVALID_FIXED_TOKEN_TYPE
    public entry fun test_uninitialized_tick(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        add_liquidity_fix_value(
            admin,
            pool_address,
            100000,
            100000,
            true,
            18446744073709549616, // -2000
            18446744073709550616, // -1000
            true,
            0,
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = pool::EAMOUNT_IS_ZERO)] // EAMOUNT_IS_ZERO
    public entry fun test_insufficient_liquidity(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        // add liquidity with zero amounts
        add_liquidity_fix_value(
            admin,
            pool_address,
            0,
            0,
            true,
            0,
            16000,
            true,
            0,
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = pool::EIS_NOT_VALID_TICK)] // EIS_NOT_VALID_TICK
    public entry fun test_invalid_tick_spacing(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        add_liquidity_fix_value(
            admin,
            pool_address,
            100000,
            100000,
            true,
            100, // not aligned to tick spacing
            16000,
            true,
            0,
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure] // EINSUFFICIENT_BALANCE
    public entry fun test_invalid_token_amounts(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        add_liquidity_fix_value(
            admin,
            pool_address,
            18446744073709551615,
            18446744073709551615,
            true,
            0,
            16000,
            true,
            0,
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = factory::EINVALID_SQRTPRICE)] // E_INVALID_SQRT_PRICE
    public entry fun test_invalid_sqrt_price(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 0;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        add_liquidity_fix_value(
            admin,
            pool_address,
            100000,
            100000,
            true,
            0,
            16000,
            true,
            0,
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = fee_tier::EINVALID_FEE_RATE)] // EINVALID_FEE_RATE
    public entry fun test_invalid_fee_rate(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let tick_spacing = 200;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000000);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure] // ERESOURCE_ACCCOUNT_EXISTS
    public entry fun test_create_pool_with_same_token_types(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);

        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 2;
        let tick_spacing2 = 200;
        let init_sqrt_price = 18446744073709551616;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, 1000);
        add_fee_tier(admin, tick_spacing2, 1000);
        factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );
        factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_create_and_add_liquidity_fix_token_with_coins(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 400000;
        let amount_b = 100000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 1001);

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);


        create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            asset_a_sorted,
            asset_b_sorted
        );

        let clmm_pool_addr_opt = factory::get_pool(tick_spacing, asset_a_sorted, asset_b_sorted);
        let pool_address = option::extract(&mut clmm_pool_addr_opt);

        migrate_to_fungible_store<TestCoinB>(admin);
        add_liquidity_fix_value_coin_asset<TestCoinA>(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 726410, 1002); // min[726410.196307, 5050416.653057]

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_before - user_balance_a_after) == 14384, 1003); // 99999.6976491452
        assert!((user_balance_b_before - user_balance_b_after) == 400000, 1004); // 3595.782535883948
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_create_and_add_liquidity_fix_token_with_coin_asset(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let token_b_name = utf8(b"Token B");
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));


        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 400000;
        let amount_b = 100000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 1001);

        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, token_b);
        create_pool_coin_asset<TestCoinA>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            asset_a_sorted,
            asset_b_sorted
        );

        let clmm_pool_addr_opt = factory::get_pool(tick_spacing, asset_a_sorted, asset_b_sorted);
        let pool_address = option::extract(&mut clmm_pool_addr_opt);

        add_liquidity_fix_value_coin_asset<TestCoinA>(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 726410, 1002); // min[726410.196307, 5050416.653057]

        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_b_before - user_balance_b_after) == 400000, 1004); // 400000.0
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_create_and_add_liquidity_with_coins(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000;
        let amount_b = 400000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 1001);

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let b_addr = utils::coin_to_fa_address<TestCoinB>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, b_addr);

        create_pool_coin_coin<TestCoinB, TestCoinA>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            asset_a_sorted,
            asset_b_sorted
        );


        let clmm_pool_addr_opt = factory::get_pool(tick_spacing, asset_a_sorted, asset_b_sorted);
        let pool_address = option::extract(&mut clmm_pool_addr_opt);

        add_liquidity_coin_coin<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            25000,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            true,
            1,
        );

        let pool_liquidity2 = get_pool_liquidity(pool_address);
        assert!(pool_liquidity2 == 25000, 1004);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_create_and_add_liquidity_with_coin_asset(admin: &signer, supra_framework: &signer) {
        coin::create_coin_conversion_map(supra_framework);
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let token_b_name = utf8(b"Token B");
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));


        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 400000;
        let amount_b = 100000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 1001);

        let user_balance_b_before = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        let a_addr = utils::coin_to_fa_address<TestCoinA>();
        let (asset_a_sorted, asset_b_sorted) = utils::sort_tokens(a_addr, token_b);

        create_pool_coin_asset<TestCoinA>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            asset_a_sorted,
            asset_b_sorted
        );


        let clmm_pool_addr_opt = factory::get_pool(tick_spacing, asset_a_sorted, asset_b_sorted);
        let pool_address = option::extract(&mut clmm_pool_addr_opt);

        add_liquidity_coin_asset<TestCoinA>(
            admin,
            pool_address,
            726410,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            true,
            1,
        );

        let pool_liquidity = get_pool_liquidity(pool_address);
        assert!(pool_liquidity == 726410, 1002);

        let user_balance_b_after = token_factory::get_token_balance(admin, address_of(admin), token_b_name);

        assert!((user_balance_b_before - user_balance_b_after) == 400000, 1004); // 400000.0
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_is_pool_exists(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (token_a_name, token_b_name, token_c_name) = (utf8(b"Token A"), utf8(b"Token B"), utf8(b"Token C"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));
        let token_c = setup_fungible_assets(admin, token_c_name, utf8(b"TC"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let fee_rate = 1000;

        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 1001);

        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let pool_address1 = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_c,
        );

        let pool_addresses = vector[pool_address, pool_address1, @dexlyn_clmm];
        let pool_exists = pool:: is_pool_exists(pool_addresses);
        assert!(*vector::borrow(&pool_exists, 0), 1001);
        assert!(*vector::borrow(&pool_exists, 1), 1002);
        assert!(!*vector::borrow(&pool_exists, 2), 1003);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_find_best_swap(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 155668;
        let amount_b = 300000;
        let tick_lower = 18446744073709551416;
        let tick_upper = 200;

        let fee_rate1 = 1000;
        let fee_rate2 = 500;
        let fee_rate3 = 100;

        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, fee_rate1);


        // Create two pools
        let pool_address1 = factory::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), token_a, token_b
        );

        // Add different liquidity to each pool
        add_liquidity_fix_value(
            admin, pool_address1, amount_a, amount_b, true, tick_lower, tick_upper, true, 0
        );


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


        let pool_addresses = vector[pool_address1, pool_address2, pool_address3];
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, true, true, false, 100000);

        assert!(best_pool == pool_address3, 9001);

        let swap_results = pool::calculate_all_pools_swap_results(pool_addresses, true, true, 100000);
        assert!(vector::length(&swap_results) == 3, 9002);

        // exact amount_out for a2b
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, true, false, true, 100000);

        // pool1: 100644+101=100745, pool2:100084+51=100135, pool3:100120+11=100131
        assert!(best_pool == pool_address3, 9002);

        // exact input for b2a
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, false, true, false, 100000);

        //amount_out: pool1: 99266, pool2:99866, pool3:99870
        assert!(best_pool == pool_address3, 9003);

        // exact output for b2a
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, false, false, true, 100000);

        // amount_in: pool1: 100644+101=100745, pool2:100084+51=100135, pool3:100120+11=100131
        assert!(best_pool == pool_address3, 9004);

        // all pool exceeds: a2b when is_exceed=false, by_amount_in=false
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, true, false, true, 100000000);
        assert!(best_pool == @0x0, 9005);

        // all pool exceeds: a2b when is_exceed=false, by_amount_in=true
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, true, true, false, 100000000000);
        assert!(best_pool == @0x0, 9006);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_find_best_swap_for_same_amount_out_when_pool_exceeds(
        admin: &signer,
        supra_framework: &signer
    ) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000000;
        let amount_b = 100000000;
        let tick_lower = 18446744073709551016;
        let tick_upper = 600;

        let fee_rate1 = 1000;
        let fee_rate2 = 500;
        let fee_rate3 = 100;

        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, fee_rate1);


        // Create two pools
        let pool_address1 = factory::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), token_a, token_b
        );

        // Add different liquidity to each pool
        add_liquidity_fix_value(
            admin, pool_address1, amount_a, amount_b, true, tick_lower, tick_upper, true, 0
        );


        let tick_spacing = 60;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000000;
        let amount_b = 100000000;
        let tick_lower = 18446744073709551016;
        let tick_upper = 600;
        add_fee_tier(admin, tick_spacing, fee_rate2);

        let pool_address2 = factory::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), token_a, token_b
        );

        add_liquidity_fix_value(
            admin, pool_address2, amount_a, amount_b, true, tick_lower, tick_upper, true, 0
        );


        let tick_spacing = 30;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 100000000;
        let amount_b = 100000000;
        let tick_lower = 18446744073709551016;
        let tick_upper = 600;
        add_fee_tier(admin, tick_spacing, fee_rate3);

        let pool_address3 = factory::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), token_a, token_b
        );

        add_liquidity_fix_value(
            admin, pool_address3, amount_a, amount_b, true, tick_lower, tick_upper, true, 0
        );


        let pool_addresses = vector[pool_address1, pool_address2, pool_address3];

        // same amount_out for b2a when is_exceed=true, by_amount_in=false
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, false, false, false, 100000000);
        assert!(best_pool == pool_address3, 9001);

        // same amount_out for a2b, is_exceed:true
        let (best_pool, _best_amount) = pool::swap_routing(pool_addresses, true, false, false, 100000000000);
        assert!(best_pool == pool_address3, 9002);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = pool::EDIFFERENT_ASSET_TYPE)]
    public fun test_repay_add_liquidity_with_wrong_assets_fails_on_withdraw(
        admin: &signer,
        supra_framework: &signer
    ) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        factory::init_factory_module(admin);

        let asset_a_addr = setup_fungible_assets(admin, utf8(b"USDC"), utf8(b"USDC"));
        let asset_b_addr = setup_fungible_assets(admin, utf8(b"USDT"), utf8(b"USDT"));

        let tick_spacing = 1;
        let fee_rate = 2000;
        let init_sqrt_price = tick_math::get_sqrt_price_at_tick(i64::from(0));
        add_fee_tier(admin, tick_spacing, fee_rate);

        let pool_address = factory::create_pool(
            admin, tick_spacing, init_sqrt_price, string::utf8(b""), asset_a_addr, asset_b_addr
        );

        let pos_index = pool::open_position(
            admin,
            pool_address,
            i64::neg_from(50000),
            i64::from(50000)
        );
        let liq = 10_000_000u128;
        let receipt = pool::add_liquidity_v2(admin, pool_address, liq, pos_index);
        let (amt_a_needed, amt_b_needed) = pool::add_liqudity_pay_amount(&receipt);

        let wrong_x_addr = setup_fungible_assets(admin, utf8(b"Wrong X"), utf8(b"WX"));
        let wrong_y_addr = setup_fungible_assets(admin, utf8(b"Wrong Y"), utf8(b"WY"));
        let wrong_x_metadata = object::address_to_object<Metadata>(wrong_x_addr);
        let wrong_y_metadata = object::address_to_object<Metadata>(wrong_y_addr);

        let token_x = if (amt_a_needed > 0) {
            primary_fungible_store::withdraw(admin, wrong_x_metadata, amt_a_needed)
        } else {
            fungible_asset::zero(wrong_x_metadata)
        };
        let token_y = if (amt_b_needed > 0) {
            primary_fungible_store::withdraw(admin, wrong_y_metadata, amt_b_needed)
        } else {
            fungible_asset::zero(wrong_y_metadata)
        };

        pool::repay_add_liquidity(token_x, token_y, receipt);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
        owner = @0xA,
        non_owner = @0xB,
    )]
    #[expected_failure(abort_code = pool::EPOSITION_OWNER_ERROR)]
    public fun test_add_liquidity_v2_only_owner_can_add(
        admin: &signer,
        owner: &signer,
        non_owner: &signer,
        supra_framework: &signer
    ) {
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(owner));
        account::create_account_for_test(signer::address_of(non_owner));
        timestamp::set_time_has_started_for_testing(supra_framework);
        
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let fee_rate = 1000;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, fee_rate);
        
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let pos_index = pool::open_position(
            owner,
            pool_address,
            i64::from_u64(tick_lower),
            i64::from_u64(tick_upper)
        );

        let liquidity = 1000000u128;
        let receipt = pool::add_liquidity_v2(owner, pool_address, liquidity, pos_index);
        let (amt_a_needed, amt_b_needed) = pool::add_liqudity_pay_amount(&receipt);
        
        let a_metadata = object::address_to_object<Metadata>(token_a);
        let b_metadata = object::address_to_object<Metadata>(token_b);
        let token_a_asset = primary_fungible_store::withdraw(admin, a_metadata, amt_a_needed);
        let token_b_asset = primary_fungible_store::withdraw(admin, b_metadata, amt_b_needed);
        pool::repay_add_liquidity(token_a_asset, token_b_asset, receipt);

        let receipt2 = pool::add_liquidity_v2(non_owner, pool_address, liquidity, pos_index);
        
        let (amt_a_needed2, amt_b_needed2) = pool::add_liqudity_pay_amount(&receipt2);
        let token_a_asset2 = primary_fungible_store::withdraw(admin, a_metadata, amt_a_needed2);
        let token_b_asset2 = primary_fungible_store::withdraw(admin, b_metadata, amt_b_needed2);
        pool::repay_add_liquidity(token_a_asset2, token_b_asset2, receipt2);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
        owner = @0xA,
        non_owner = @0xB,
    )]
    #[expected_failure(abort_code = pool::EPOSITION_OWNER_ERROR)]
    public fun test_add_liquidity_fix_asset_v2_only_owner_can_add(
        admin: &signer,
        owner: &signer,
        non_owner: &signer,
        supra_framework: &signer
    ) {
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(owner));
        account::create_account_for_test(signer::address_of(non_owner));
        timestamp::set_time_has_started_for_testing(supra_framework);
        
        let (token_a_name, token_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let token_a = setup_fungible_assets(admin, token_a_name, utf8(b"TA"));
        let token_b = setup_fungible_assets(admin, token_b_name, utf8(b"TB"));

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let fee_rate = 1000;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, fee_rate);
        
        let pool_address = factory::create_pool(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b""),
            token_a,
            token_b,
        );

        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let pos_index = pool::open_position(
            owner,
            pool_address,
            i64::from_u64(tick_lower),
            i64::from_u64(tick_upper)
        );

        let amount = 100000u64;
        let fix_amount_a = true;
        let receipt = pool::add_liquidity_fix_asset_v2(owner, pool_address, amount, fix_amount_a, pos_index);
        let (amt_a_needed, amt_b_needed) = pool::add_liqudity_pay_amount(&receipt);
        
        let a_metadata = object::address_to_object<Metadata>(token_a);
        let b_metadata = object::address_to_object<Metadata>(token_b);
        let token_a_asset = primary_fungible_store::withdraw(admin, a_metadata, amt_a_needed);
        let token_b_asset = primary_fungible_store::withdraw(admin, b_metadata, amt_b_needed);
        pool::repay_add_liquidity(token_a_asset, token_b_asset, receipt);

        let receipt2 = pool::add_liquidity_fix_asset_v2(non_owner, pool_address, amount, fix_amount_a, pos_index);
        
        let (amt_a_needed2, amt_b_needed2) = pool::add_liqudity_pay_amount(&receipt2);
        let token_a_asset2 = primary_fungible_store::withdraw(admin, a_metadata, amt_a_needed2);
        let token_b_asset2 = primary_fungible_store::withdraw(admin, b_metadata, amt_b_needed2);
        pool::repay_add_liquidity(token_a_asset2, token_b_asset2, receipt2);
    }
}