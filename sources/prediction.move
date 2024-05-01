module DefiPredictionMarket::defi_prediction_market {
    use std::vector;
    use sui::transfer;
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use std::option::{Option, none, some};
    use sui::tx_context::{Self, TxContext};

    /* Error Constants */
    const ENotMarketOwner: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EMaxMarketsReached: u64 = 2;
    const EMarketAlreadyResolved: u64 = 3;
    const EMarketNotResolved: u64 = 4;

    /* Structs */
    struct AdminCap has key, store {
        id: UID
    }

    struct MarketOwnerCap has key, store {
        id: UID,
        market_id: ID
    }

    struct OwnerAddressVector has key, store {
        id: UID,
        addresses: vector<address>
    }

    struct PredictionMarket has key, store {
        id: UID,
        name: String,
        resolved: bool,
        creator: address,
        yes_pool: Balance<SUI>,
        no_pool: Balance<SUI>,
        resolution: Option<bool>,
        started_at: u64,
        resolved_at: Option<u64>
    }

    struct Position has key, store {
        id: UID,
        owner: address,
        market: ID,
        bet: bool,
        amount: u64,
        placed_at: u64
    }

    /* Functions */
    fun init(ctx: &mut TxContext) {
        let admin = AdminCap {
            id: object::new(ctx)
        };

        let addresses = vector::empty<address>();
        let admin_address = tx_context::sender(ctx);

        let owner_address_vector = OwnerAddressVector {
            id: object::new(ctx),
            addresses,
        };

        transfer::share_object(owner_address_vector);
        transfer::transfer(admin, admin_address);
    }

    public entry fun create_market(
        name: String,
        clock: &Clock,
        address_vector: &mut OwnerAddressVector,
        ctx: &mut TxContext
    ) {
        let market_owner_address = tx_context::sender(ctx);
        assert!(!vector::contains<address>(&address_vector.addresses, &market_owner_address), EMaxMarketsReached);

        let market_uid = object::new(ctx);
        let market_id = object::uid_to_inner(&market_uid);

        let market = PredictionMarket {
            id: market_uid,
            name,
            resolved: false,
            creator: market_owner_address,
            yes_pool: balance::zero(),
            no_pool: balance::zero(),
            resolution: none(),
            started_at: clock::timestamp_ms(clock),
            resolved_at: none()
        };

        let market_owner_id = object::new(ctx);

        let market_owner = MarketOwnerCap {
            id: market_owner_id,
            market_id
        };

        vector::push_back<address>(&mut address_vector.addresses, market_owner_address);

        transfer::share_object(market);
        transfer::transfer(market_owner, market_owner_address);
    }

    public entry fun place_bet(
        bet: bool,
        amount: Coin<SUI>,
        market: &mut PredictionMarket,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!market.resolved, EMarketAlreadyResolved);

        let bet_amount = coin::value(&amount);
        let better_address = tx_context::sender(ctx);

        if (bet) {
            balance::join(&mut market.yes_pool, coin::into_balance(amount));
        } else {
            balance::join(&mut market.no_pool, coin::into_balance(amount));
        };

        let position = Position {
            id: object::new(ctx),
            owner: better_address,
            market: object::uid_to_inner(&market.id),
            bet,
            amount: bet_amount,
            placed_at: clock::timestamp_ms(clock)
        };

        transfer::share_object(position);
    }

    // public entry fun resolve_market(
    //     _: &AdminCap,
    //     resolution: bool,
    //     market: &mut PredictionMarket,
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ) {
    //     assert!(!market.resolved, EMarketAlreadyResolved);

    //     market.resolved = true;
    //     market.resolution = some(resolution);
    //     market.resolved_at = some(clock::timestamp_ms(clock));

    //     if (resolution) {
    //         transfer::public_transfer(coin::from_balance(market.yes_pool, ctx), market.creator);
    //     } else {
    //         transfer::public_transfer(coin::from_balance(market.no_pool, ctx), market.creator);
    //     }
    // }

    // public entry fun claim_winnings(
    //     position: &mut Position,
    //     market: &mut PredictionMarket,
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ) {
    //     assert!(market.resolved, EMarketNotResolved);
    //     assert!(position.owner == tx_context::sender(ctx), ENotMarketOwner);

    //     let winnings = if (position.bet == market.resolution.unwrap()) {
    //         position.amount
    //     } else {
    //         0
    //     };

    //     if (winnings > 0) {
    //         let winnings_balance = if (position.bet) {
    //             coin::take(&mut market.yes_pool, winnings, ctx)
    //         } else {
    //             coin::take(&mut market.no_pool, winnings, ctx)
    //         };

    //         transfer::public_transfer(winnings_balance, tx_context::sender(ctx));
    //     };

    //     object::delete(position);
    // }

    public entry fun get_market_details(market: &PredictionMarket): (bool, u64, u64, Option<bool>) {
        (market.resolved, balance::value(&market.yes_pool), balance::value(&market.no_pool), market.resolution)
    }
}
