module bridge_addr::checkdot_bridge_v1 {
    use aptos_framework::coin::{Self, Coin};
    use std::signer;
    use std::vector;
    use std::string::String;
    use std::aptos_hash;
    use std::bcs;

    use aptos_std::debug;
    use aptos_std::table::{Self, Table};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use aptos_framework::block;

    use liquidswap::router;
    use liquidswap::curves::Uncorrelated;
    use liquidswap::math;

    use cdt::CdtCoin::CDT;

    const ERR_NOT_INITIALIZED: u64 = 100;
    const ERR_NOT_OWNER: u64 = 200;
    const ERR_NOT_OWNER_OR_PROGRAM: u64 = 201;
    const ERR_NOT_ACTIVED: u64 = 300;
    const ERR_ZERO_DIVISION: u64 = 400;
    const ERR_INSUFFICIENT_QUANTITY: u64 = 500;
    const ERR_PAYMENT_ABORTED: u64 = 501;
    const ERR_NOT_EXISTS: u64 = 502;
    const ERR_OUT_OF_BOUNDS: u64 = 503;
    const ERR_INSUFFICIENT_BALANCE: u64 = 504;
    const ERR_MINIMUM_LOCEKD_PERIOD: u64 = 505;
    const ERR_MAXIMUM_LOCKED_PERIOD: u64 = 506;

    struct Transfer has copy, store {
        hash: vector<u8>,
        from: address,
        quantity: u64,
        fromChain: String,
        toChain: String,
        fees_in_cdt: u64,
        fees_in_apt: u64,
        block_timestamp: u64,
        block_number: u64,
        data: String
    }

    struct BridgeConfig has key {
        owner: address,
        program: address,
        paused: bool,
        coin: Coin<AptosCoin>
    }

    struct Bridge has key {
        coin: Coin<CDT>,
        chain: String,
        fees_in_dollar: u64,
        fees_in_cdt_percentage: u64,
        minimum_transfer_quantity: u64,
        bridge_fees_in_cdt: u64,
        lock_ask_duration: u64,
        unlock_ask_duration: u64,
        unlock_ask_time: u64,
        transfers: vector<Transfer>,
        transfers_indexs: Table<vector<u8>, u64>,
        transfers_hashs: Table<vector<u8>, vector<u8>>
    }

    public entry fun initialize(owner_admin: &signer, chain: String, fees_in_dollar: u64, fees_in_cdt_percentage: u64) {
        debug::print_stack_trace();
        let addr = signer::address_of(owner_admin);

        assert!(addr == @bridge_addr, ERR_NOT_OWNER);

        move_to(owner_admin, Bridge {
            coin: coin::zero<CDT>(),
            chain: chain,
            fees_in_dollar: fees_in_dollar,
            fees_in_cdt_percentage: fees_in_cdt_percentage,
            minimum_transfer_quantity: 100000000,
            bridge_fees_in_cdt: 0,
            lock_ask_duration: (((86400 * 1000) * 2) * 1000), // 2 days
            unlock_ask_duration: (((86400 * 1000) * 15) * 1000), // 15 days
            unlock_ask_time: 0,
            transfers: vector::empty(),
            transfers_indexs: table::new(),
            transfers_hashs: table::new()
        });

        move_to(owner_admin, BridgeConfig {
            owner: addr,
            program: addr,
            paused: false,
            coin: coin::zero<AptosCoin>()
        });
    }

    public fun assert_is_owner(addr: address) acquires BridgeConfig {
        let owner = borrow_global<BridgeConfig>(@bridge_addr).owner;
        assert!(addr == owner, ERR_NOT_OWNER);
    }

    public fun assert_is_owner_or_program(addr: address) acquires BridgeConfig {
        let config = borrow_global<BridgeConfig>(@bridge_addr);

        assert!(addr == config.owner || addr == config.program, ERR_NOT_OWNER_OR_PROGRAM);
    }

    public fun assert_is_actived() acquires BridgeConfig {
        let bridge = borrow_global<BridgeConfig>(@bridge_addr);
        assert!(!bridge.paused, ERR_NOT_ACTIVED);
    }

    public fun assert_is_initialized() {
        assert!(exists<Bridge>(@bridge_addr), ERR_NOT_INITIALIZED);
        assert!(exists<BridgeConfig>(@bridge_addr), ERR_NOT_INITIALIZED);
    }

    public entry fun set_fees_in_dollar(acc: &signer, cost: u64) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let fees_in_dollar = &mut borrow_global_mut<Bridge>(@bridge_addr).fees_in_dollar;

        *fees_in_dollar = cost;
    }

    public entry fun set_fees_in_cdt_percentage(acc: &signer, fees: u64) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let fees_in_cdt_percentage = &mut borrow_global_mut<Bridge>(@bridge_addr).fees_in_cdt_percentage;

        *fees_in_cdt_percentage = fees;
    }

    public entry fun set_paused(acc: &signer, stat: bool) acquires BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let paused = &mut borrow_global_mut<BridgeConfig>(@bridge_addr).paused;

        *paused = stat;
    }

    public entry fun set_minimum_transfer_quantity(acc: &signer, quantity: u64) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let minimum_transfer_quantity = &mut borrow_global_mut<Bridge>(@bridge_addr).minimum_transfer_quantity;

        *minimum_transfer_quantity = quantity;
    }

    public entry fun set_owner(acc: &signer, owner: address) acquires BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let bridge_owner = &mut borrow_global_mut<BridgeConfig>(@bridge_addr).owner;

        *bridge_owner = owner;
    }

    public entry fun set_program(acc: &signer, program: address) acquires BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let bridge_program = &mut borrow_global_mut<BridgeConfig>(@bridge_addr).program;

        *bridge_program = program;
    }

    public entry fun ask_withdraw(acc: &signer) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_owner(addr);

        let unlock_ask_time = &mut borrow_global_mut<Bridge>(@bridge_addr).unlock_ask_time;
        *unlock_ask_time = timestamp::now_microseconds();
    }

    public entry fun init_transfer<USD>(acc: &signer, fee: u64, quantity: u64, to_chain: String, data: String) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_actived();

        let bridge = borrow_global_mut<Bridge>(@bridge_addr);

        assert!(fee >= fees_in_apt<USD>(bridge), ERR_PAYMENT_ABORTED);
        assert!(quantity >= bridge.minimum_transfer_quantity, ERR_INSUFFICIENT_QUANTITY);
        assert!(coin::balance<AptosCoin>(addr) >= fee, ERR_INSUFFICIENT_BALANCE);

        let config = borrow_global_mut<BridgeConfig>(@bridge_addr);
        let withdraw_fee = coin::withdraw<AptosCoin>(acc, fee);
        coin::merge(&mut config.coin, withdraw_fee);        

        let coin = coin::withdraw<CDT>(acc, quantity);

        let transfer_fees_in_cdt = fees_in_cdt_by_quantity(bridge, quantity);
        
        coin::merge(&mut bridge.coin, coin);

        let transfer_quantity = quantity - transfer_fees_in_cdt;
        let transfer_apt_fees = fee;

        *(&mut bridge.bridge_fees_in_cdt) = bridge.bridge_fees_in_cdt + transfer_fees_in_cdt;
        let index = vector::length<Transfer>(&bridge.transfers);
        let transfer_hash = get_hash(addr);

        vector::push_back<Transfer>(&mut bridge.transfers, Transfer {
            hash: transfer_hash,
            from: addr,
            quantity: transfer_quantity,
            fromChain: bridge.chain,
            toChain: to_chain,
            fees_in_cdt: transfer_fees_in_cdt,
            fees_in_apt: transfer_apt_fees,
            block_timestamp: timestamp::now_microseconds(),
            block_number: block::get_current_block_height(),
            data: data
        });

        table::add(&mut bridge.transfers_hashs, transfer_hash, transfer_hash);
        table::add(&mut bridge.transfers_indexs, transfer_hash, index);
    }
    
    public entry fun add_transfers_from(acc: &signer, _memory: String/* fromChain */, transfers_address: address, amount: u64, _transfers_hash: vector<u8>) acquires Bridge, BridgeConfig {
        let admin = signer::address_of(acc);
        assert_is_initialized();
        assert_is_owner_or_program(admin);

        let bridge = borrow_global_mut<Bridge>(@bridge_addr);

        assert!(coin::value<CDT>(&bridge.coin) >= amount, ERR_INSUFFICIENT_BALANCE);
        
        let coin = coin::extract<CDT>(&mut bridge.coin, amount);
        coin::deposit<CDT>(transfers_address, coin);
    }

    public entry fun collect_cdt_fees(acc: &signer) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let bridge = borrow_global_mut<Bridge>(@bridge_addr);

        assert!(coin::value(&bridge.coin) >= bridge.bridge_fees_in_cdt, ERR_INSUFFICIENT_BALANCE);

        let extract = coin::extract<CDT>(&mut bridge.coin, bridge.bridge_fees_in_cdt);
        coin::deposit(addr, extract);

        *(&mut bridge.bridge_fees_in_cdt) = 0;
    }

    public entry fun deposit(acc: &signer, quantity: u64) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        assert!(coin::balance<CDT>(addr) >= quantity, ERR_INSUFFICIENT_BALANCE);

        let bridge = borrow_global_mut<Bridge>(@bridge_addr);

        let coin = coin::withdraw<CDT>(acc, quantity);
        coin::merge(&mut bridge.coin, coin);
    }

    public entry fun withdraw(acc: &signer, quantity: u64) acquires Bridge, BridgeConfig {
        let addr = signer::address_of(acc);

        assert_is_initialized();
        assert_is_owner(addr);

        let bridge = borrow_global_mut<Bridge>(@bridge_addr);

        let cur_timestamp = timestamp::now_microseconds();
        assert!(bridge.unlock_ask_time < cur_timestamp - bridge.lock_ask_duration, ERR_MINIMUM_LOCEKD_PERIOD);
        assert!(bridge.unlock_ask_time > cur_timestamp - bridge.unlock_ask_duration, ERR_MAXIMUM_LOCKED_PERIOD);

        assert!(coin::value<CDT>(&bridge.coin) >= quantity, ERR_INSUFFICIENT_BALANCE);

        let extract = coin::extract<CDT>(&mut bridge.coin, quantity);
        coin::deposit(addr, extract);
    }

    public entry fun deposit_apt(acc: &signer, quantity: u64) acquires BridgeConfig {
        let addr = signer::address_of(acc);

        assert!(exists<BridgeConfig>(@bridge_addr), ERR_NOT_INITIALIZED);
        assert_is_owner(addr);
        assert!(coin::balance<AptosCoin>(addr) >= quantity, ERR_INSUFFICIENT_BALANCE);

        let config = borrow_global_mut<BridgeConfig>(@bridge_addr);

        let coin = coin::withdraw<AptosCoin>(acc, quantity);
        coin::merge(&mut config.coin, coin);
    }

    public entry fun withdraw_apt(acc: &signer, quantity: u64) acquires BridgeConfig {
        let addr = signer::address_of(acc);

        assert!(exists<BridgeConfig>(@bridge_addr), ERR_NOT_INITIALIZED);
        assert_is_owner(addr);

        let config = borrow_global_mut<BridgeConfig>(@bridge_addr);

        assert!(coin::value<AptosCoin>(&config.coin) >= quantity, ERR_INSUFFICIENT_BALANCE);

        let coin = coin::extract<AptosCoin>(&mut config.coin, quantity);
        coin::deposit(addr, coin);
    }

    #[view]
    public fun balance(): u64 acquires BridgeConfig {
        assert!(exists<BridgeConfig>(@bridge_addr), ERR_NOT_INITIALIZED);

        let coin = &borrow_global<BridgeConfig>(@bridge_addr).coin;

        coin::value<AptosCoin>(coin)
    }

    #[view]
    public fun balance_CDT(): u64 acquires Bridge {
        assert!(exists<Bridge>(@bridge_addr), ERR_NOT_INITIALIZED);

        let coin = &borrow_global<Bridge>(@bridge_addr).coin;

        coin::value<CDT>(coin)
    }

    #[view]
    public fun transfer_exists(transfer_hash: vector<u8>): bool acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);

        table::contains(&bridge.transfers_hashs, transfer_hash)
    }

    #[view]
    public fun get_transfer(transfer_hash: vector<u8>): Transfer acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);
        assert!(table::contains(&bridge.transfers_indexs, transfer_hash), ERR_NOT_EXISTS);

        let index: &u64 = table::borrow(&bridge.transfers_indexs, transfer_hash);

        let transfer: &Transfer = vector::borrow(&bridge.transfers, *index);

        return *transfer
    }

    #[view]
    public fun get_transfers(page: u64, page_size: u64): vector<Transfer> acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);

        let len = vector::length(&bridge.transfers);
        assert!(len >= page * page_size, ERR_OUT_OF_BOUNDS);
        let start_id = len - page * page_size;
        let end_id = if(start_id >= page_size) {
            start_id - page_size
        } else {
            0
        };
        let current_id = start_id;
        assert!(current_id <= len, ERR_OUT_OF_BOUNDS);
        let transfers: vector<Transfer> = vector::empty<Transfer>();

        while(current_id > end_id) {
            let transfer = vector::borrow(&bridge.transfers, current_id - 1);
            vector::push_back(&mut transfers, *transfer);
            current_id = current_id - 1;
        };

        transfers
    }

    #[view]
    public fun get_last_transfers(size: u64): vector<Transfer> acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);

        let len = vector::length(&bridge.transfers);
        let start = if(len > size) {
            len - size
        } else {
            0
        };
        let transfers: vector<Transfer> = vector::empty<Transfer>();

        while(start < len) {
            let transfer = vector::borrow(&bridge.transfers, start);
            vector::push_back(&mut transfers, *transfer);
            start = start + 1;
        };

        transfers
    }

    #[view]
    public fun get_transfer_length(): u64 acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);

        vector::length(&bridge.transfers)
    }
    
    #[view]
    public fun get_fees_in_apt<USD>(): u64 acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);

        fees_in_apt<USD>(bridge)
    }

    #[view]
    public fun get_fees_in_dollar(): u64 acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);
        bridge.fees_in_dollar
    }

    #[view]
    public fun get_fees_in_cdt_by_quantity(quantity: u64): u64 acquires Bridge {
        assert_is_initialized();

        let bridge = borrow_global<Bridge>(@bridge_addr);
        quantity * bridge.fees_in_cdt_percentage / 100
    }

    #[view]
    public fun is_paused(): bool acquires BridgeConfig {
        assert_is_initialized();

        let bridge = borrow_global<BridgeConfig>(@bridge_addr);
        bridge.paused
    }


    fun fees_in_apt<USD>(bridge: &Bridge): u64 {
        assert_is_initialized();

        let fees_in_dollar = bridge.fees_in_dollar;

        let decimals = coin::decimals<USD>();

        let (x_res, y_res) = router::get_reserves_size<AptosCoin, USD, Uncorrelated>();

        assert!(y_res > 0, ERR_ZERO_DIVISION);

        let fees = (fees_in_dollar as u256) * (math::pow_10(decimals) as u256) / (math::pow_10(8) as u256) * (x_res as u256) / (y_res as u256);

        (fees as u64)
    }

    fun fees_in_cdt_by_quantity(bridge: &Bridge, quantity: u64): u64 {
        assert_is_initialized();

        quantity * bridge.fees_in_cdt_percentage / 100
    }

    fun get_hash(addr: address): vector<u8> {
        let t = timestamp::now_microseconds();
        let t_vec:vector<u8> = bcs::to_bytes<u64>(&t);
        let addr_vec:vector<u8> = bcs::to_bytes<address>(&addr);

        vector::append(&mut t_vec, addr_vec);

        return aptos_hash::keccak256(t_vec)
    }
}
