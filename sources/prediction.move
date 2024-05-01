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
    use sui::tx_context::{Self, TxContext, sender};

    /* Error Constants */
    const ENotMarketOwner: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EMaxMarketsReached: u64 = 2;
    const EMarketAlreadyResolved: u64 = 3;
    const EMarketNotResolved: u64 = 4;

    /* Structs */
    struct AdminCap has key {
        id: UID
    }

    struct MarketOwnerCap has key, store {
        id: UID,
        market_id: ID
    }

    struct PredictionMarket has key, store {
        id: UID,
        name: String,
        resolved: bool,
        creator: address,
        balance: Balance<SUI>,
        resolution: Option<bool>,
        started_at: u64,
        resolved_at: Option<u64>
    }

    struct Position has key, store {
        id: UID,
        market: ID,
        owner: address,
        amount: u64,
        placed_at: u64
    }

    /* Functions */
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap{id: object::new(ctx)}, sender(ctx));
    }

    public entry fun create_market(
        c: &Clock,
        name: String,
        ctx: &mut TxContext
    ) {
        let owner = sender(ctx);

        let market_uid = object::new(ctx);
        let market_id = object::uid_to_inner(&market_uid);

        let market = PredictionMarket {
            id: market_uid,
            name,
            resolved: false,
            creator: owner,
            balance: balance::zero(),
            resolution: none(),
            started_at: clock::timestamp_ms(c),
            resolved_at: none()
        };

        let market_owner = MarketOwnerCap {
            id: object::new(ctx),
            market_id
        };

        transfer::share_object(market);
        transfer::transfer(market_owner, owner);
    }

    public entry fun place_bet(
        market: &mut PredictionMarket,
        c: &Clock,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(!market.resolved, EMarketAlreadyResolved);

        let bet_amount = coin::value(&amount);
        let better_address = sender(ctx);

        balance::join(&mut market.balance, coin::into_balance(amount));

        let position = Position {
            id: object::new(ctx),
            market: object::uid_to_inner(&market.id),
            owner: better_address,
            amount: bet_amount,
            placed_at: clock::timestamp_ms(c)
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

}
