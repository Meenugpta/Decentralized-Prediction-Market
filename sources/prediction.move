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
    use sui::table::{Self, Table};

    /* Error Constants */
    const ENotMarketOwner: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EAlreadyBet: u64 = 2;
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
        winner: address,
        users: Table<address, bool>,
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
            winner: owner,
            users: table::new(ctx),
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

    public fun place_bet(
        market: &mut PredictionMarket,
        c: &Clock,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) : Position {
        assert!(!market.resolved, EMarketAlreadyResolved);
        assert!(coin::value(&amount) > balance::value(&market.balance), EInsufficientBalance);
        assert!(!table::contains(&market.users, sender(ctx)), EAlreadyBet);
        // set the winner 
        market.winner = sender(ctx);
        table::add(&mut market.users, sender(ctx), true);

        let bet_amount = coin::value(&amount);

        balance::join(&mut market.balance, coin::into_balance(amount));

        let position = Position {
            id: object::new(ctx),
            market: object::uid_to_inner(&market.id),
            owner: sender(ctx),
            amount: bet_amount,
            placed_at: clock::timestamp_ms(c)
        };
        position
    }

    public fun resolve_market(
        _: &AdminCap,
        market: &mut PredictionMarket,
        c: &Clock,
        ctx: &mut TxContext
    ) : Coin<SUI> {
        assert!(!market.resolved, EMarketAlreadyResolved);

        market.resolved = true;
        market.resolved_at = some(clock::timestamp_ms(c));

        let balance_ = balance::withdraw_all(&mut market.balance);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    public fun claim_winnings(
        position: &mut Position,
        market: &mut PredictionMarket,
        ctx: &mut TxContext
    ) : Coin<SUI> {
        assert!(market.resolved, EMarketNotResolved);
        assert!(position.market == object::id(market), ENotMarketOwner);

        let balance_ = balance::withdraw_all(&mut market.balance);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

}
