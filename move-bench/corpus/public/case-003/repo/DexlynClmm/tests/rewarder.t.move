#[test_only]
module dexlyn_clmm::rewarder_test {

    use std::signer;
    use std::string::utf8;
    use std::vector;

    use supra_framework::account;
    use supra_framework::fungible_asset::{Self, Metadata};
    use supra_framework::object;
    use supra_framework::primary_fungible_store;
    use supra_framework::timestamp;

    use dexlyn_clmm::clmm_router;
    use dexlyn_clmm::factory;
    use dexlyn_clmm::fee_tier;
    use dexlyn_clmm::pool;
    use dexlyn_clmm::test_helpers::setup_fungible_assets;
    use integer_mate::i64;

    #[test_only]
    struct RewarderTestAssets has key, drop {
        reward_asset_1_addr: address,
        reward_asset_2_addr: address,
        reward_asset_3_addr: address,
    }

    #[test_only]
    fun setup_rewarder_test_assets(clmm: &signer): RewarderTestAssets {
        let reward_asset_1 = setup_fungible_assets(clmm, utf8(b"Reward Token 1"), utf8(b"RT1"));
        let reward_asset_2 = setup_fungible_assets(clmm, utf8(b"Reward Token 2"), utf8(b"RT2"));
        let reward_asset_3 = setup_fungible_assets(clmm, utf8(b"Reward Token 3"), utf8(b"RT3"));

        RewarderTestAssets {
            reward_asset_1_addr: reward_asset_1,
            reward_asset_2_addr: reward_asset_2,
            reward_asset_3_addr: reward_asset_3,
        }
    }

    #[test_only]
    fun new_pool_for_rewarder_testing(
        clmm: &signer,
        tick_spacing: u64,
        fee_rate: u64,
        init_sqrt_price: u128,
    ): (address, RewarderTestAssets, address, address) {
        let (asset_a_name, asset_b_name) = (utf8(b"Token A"), utf8(b"Token B"));
        let asset_a = setup_fungible_assets(clmm, asset_a_name, utf8(b"TA"));
        let asset_b = setup_fungible_assets(clmm, asset_b_name, utf8(b"TB"));

        let rewarder_assets = setup_rewarder_test_assets(clmm);

        factory::init_factory_module(clmm);
        fee_tier::add_fee_tier(clmm, tick_spacing, fee_rate);

        let pool_address = factory::create_pool(
            clmm,
            tick_spacing,
            init_sqrt_price,
            utf8(b""),
            asset_a,
            asset_b
        );

        (pool_address, rewarder_assets, asset_a, asset_b)
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::EINVALID_REWARD_INDEX)]
    fun test_initialize_rewarder_invalid_index(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            1,
            rewarder_assets.reward_asset_1_addr
        );
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::EINVALID_REWARD_INDEX)]
    fun test_initialize_rewarder_exceed_max(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);
        let rewards: vector<address> = vector[rewarder_assets.reward_asset_1_addr, rewarder_assets.reward_asset_2_addr, rewarder_assets.reward_asset_3_addr, rewarder_assets.reward_asset_1_addr];
        let i = 0;
        vector::for_each(rewards, |reward_addr| {
            pool::initialize_rewarder(
                clmm,
                pool_address,
                signer::address_of(authority),
                i,
                reward_addr
            );
            i = i + 1;
        });
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456,
        wrong_authority = @0x999
    )]
    #[expected_failure(abort_code = pool::EREWARD_AUTH_ERROR)]
    fun test_update_emission_wrong_authority(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer,
        wrong_authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(wrong_authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        pool::update_emission(wrong_authority, pool_address, 0, 1000000000, rewarder_assets.reward_asset_1_addr);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::EINVALID_REWARD_INDEX)]
    fun test_update_emission_invalid_index(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::update_emission(authority, pool_address, 0, 1000000000, rewarder_assets.reward_asset_1_addr);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::EREWARD_NOT_MATCH_WITH_INDEX)]
    fun test_update_emission_wrong_asset(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        pool::update_emission(authority, pool_address, 0, 1000000000, rewarder_assets.reward_asset_2_addr);
    }


    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456,
        owner = @0x789
    )]
    #[expected_failure(abort_code = pool::EREWARD_AMOUNT_INSUFFICIENT)]
    fun test_update_emission_insufficient_balance(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer,
        owner: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(owner));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _asset_a, _asset_b) = new_pool_for_rewarder_testing(
            clmm,
            60,
            2000,
            18446744073709551616
        );

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        clmm_router::add_liquidity_fix_value(
            clmm,
            pool_address,
            100000,
            400000,
            true,
            i64::as_u64(i64::neg_from(60)),
            i64::as_u64(i64::from(60)),
            true,
            0,
        );

        let emissions_per_second = 18446744073709551616; // 1 token per second
        pool::update_emission(authority, pool_address, 0, emissions_per_second, rewarder_assets.reward_asset_1_addr);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456,
        owner = @0x789
    )]
    #[expected_failure(abort_code = pool::EREWARD_AMOUNT_INSUFFICIENT)]
    fun test_update_emission_same_asset_as_pool(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer,
        owner: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(owner));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, _rewarder_assets, asset_a_addr, _) = new_pool_for_rewarder_testing(
            clmm,
            60,
            2000,
            18446744073709551616
        );

        pool::initialize_rewarder(clmm, pool_address, signer::address_of(authority), 0, asset_a_addr);
        clmm_router::add_liquidity_fix_value(
            clmm,
            pool_address,
            100000,
            400000,
            true,
            i64::as_u64(i64::neg_from(60)),
            i64::as_u64(i64::from(60)),
            true,
            0,
        );

        let emissions_per_second = 18446744073709551616; // 1 token per second
        pool::update_emission(authority, pool_address, 0, emissions_per_second, asset_a_addr);
    }


    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456,
        wrong_authority = @0x999
    )]
    #[expected_failure(abort_code = pool::EREWARD_AUTH_ERROR)]
    fun test_transfer_rewarder_authority_wrong_authority(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer,
        wrong_authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(wrong_authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        pool::transfer_rewarder_authority(wrong_authority, pool_address, 0, @0x789);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456,
        new_authority = @0x789
    )]
    #[expected_failure(abort_code = pool::EREWARD_AUTH_ERROR)]
    fun test_accept_rewarder_authority_wrong_pending(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer,
        new_authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(new_authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        pool::accept_rewarder_authority(new_authority, pool_address, 0);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::EINVALID_REWARD_INDEX)]
    fun test_transfer_rewarder_authority_invalid_index(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, _rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 1000000000000);
        pool::transfer_rewarder_authority(authority, pool_address, 0, @0x789);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456,
        owner = @0x789
    )]
    #[expected_failure(abort_code = pool::EINVALID_REWARD_INDEX)]
    fun test_collect_rewarder_invalid_index(
        supra_framework: &signer,
        clmm: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        clmm_router::add_liquidity_fix_value(
            clmm,
            pool_address,
            100000,
            400000,
            true,
            i64::as_u64(i64::neg_from(60)),
            i64::as_u64(i64::from(60)),
            true,
            0,
        );

        let reward_asset = pool::collect_rewarder(
            clmm,
            pool_address,
            1,
            0,
            true,
            rewarder_assets.reward_asset_1_addr
        );
        fungible_asset::destroy_zero(reward_asset);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::EREWARD_NOT_MATCH_WITH_INDEX)]
    fun test_collect_rewarder_wrong_asset(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        clmm_router::add_liquidity_fix_value(
            clmm,
            pool_address,
            10000000000,
            10000000000,
            true,
            i64::as_u64(i64::neg_from(60)),
            i64::as_u64(i64::from(60)),
            true,
            0,
        );

        let reward_asset = pool::collect_rewarder(
            clmm,
            pool_address,
            1,
            0,
            true,
            rewarder_assets.reward_asset_2_addr
        );
        fungible_asset::destroy_zero(reward_asset);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456,
        wrong_owner = @0x999
    )]
    #[expected_failure(abort_code = pool::EPOSITION_OWNER_ERROR)]
    fun test_collect_rewarder_wrong_owner(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer,
        wrong_owner: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(wrong_owner));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        clmm_router::add_liquidity_fix_value(
            clmm,
            pool_address,
            100000,
            400000,
            true,
            i64::as_u64(i64::neg_from(60)),
            i64::as_u64(i64::from(60)),
            true,
            0,
        );

        let reward_asset = pool::collect_rewarder(
            wrong_owner,
            pool_address,
            1,
            0,
            true,
            rewarder_assets.reward_asset_1_addr
        );
        fungible_asset::destroy_zero(reward_asset);
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    fun test_clmm_router_deposit_reward(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        let reward_amount = 10000000;
        primary_fungible_store::transfer(
            clmm,
            object::address_to_object<Metadata>(rewarder_assets.reward_asset_1_addr),
            signer::address_of(authority),
            reward_amount
        );

        let rewarder_index = 0;
        let days_in_seconds = 24 * 60 * 60;
        clmm_router::deposit_reward(
            authority,
            pool_address,
            rewarder_index,
            rewarder_assets.reward_asset_1_addr,
            reward_amount
        );

        clmm_router::update_rewarder_emission(
            authority,
            pool_address,
            rewarder_index,
            days_in_seconds,
            rewarder_assets.reward_asset_1_addr
        );
    }

    #[test(
        supra_framework = @0x1,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::ENOT_ENOUGH_REWARD)]
    fun test_collect_rewarder_not_enough_reward(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        clmm_router::add_liquidity_fix_value(
            clmm,
            pool_address,
            100000,
            400000,
            true,
            i64::as_u64(i64::neg_from(60)),
            i64::as_u64(i64::from(60)),
            true,
            0,
        );

        let reward_asset = pool::collect_rewarder(
            clmm,
            pool_address,
            1,
            0,
            true,
            rewarder_assets.reward_asset_1_addr
        );
        fungible_asset::destroy_zero(reward_asset);
    }

    #[test(
        supra_framework = @supra_framework,
        clmm = @dexlyn_clmm,
        authority = @0x123456
    )]
    #[expected_failure(abort_code = pool::EPOOL_IS_PAUSED)]
    fun test_collect_rewarder_when_pool_paused(
        supra_framework: &signer,
        clmm: &signer,
        authority: &signer
    ) {
        account::create_account_for_test(signer::address_of(clmm));
        account::create_account_for_test(signer::address_of(authority));
        account::create_account_for_test(signer::address_of(supra_framework));
        timestamp::set_time_has_started_for_testing(supra_framework);

        let (pool_address, rewarder_assets, _, _) = new_pool_for_rewarder_testing(clmm, 60, 2000, 18446744073709551616);

        pool::initialize_rewarder(
            clmm,
            pool_address,
            signer::address_of(authority),
            0,
            rewarder_assets.reward_asset_1_addr
        );

        clmm_router::add_liquidity_fix_value(
            clmm,
            pool_address,
            100000,
            400000,
            true,
            i64::as_u64(i64::neg_from(60)),
            i64::as_u64(i64::from(60)),
            true,
            0,
        );

        clmm_router::pause_pool(clmm, pool_address);

        let reward_asset = pool::collect_rewarder(
            clmm,
            pool_address,
            1,
            0,
            true,
            rewarder_assets.reward_asset_1_addr
        );
        fungible_asset::destroy_zero(reward_asset);
    }
}