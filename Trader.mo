/**
 * Module     : Trader.mo
 */
import ICDex "lib/ICDexTypes";
import DRC205 "lib/DRC205Types";
import DRC207 "lib/DRC207";
import List "mo:base/List";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import ICRC1 "./lib/ICRC1";
import DRC20 "./lib/DRC20";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Hex "lib/Hex";
import Tools "lib/Tools";

// Roles.
// owner: setting operator, setting whitelist pairs, trading, withdrawal
// operator: trading
shared(installMsg) actor class Trader(_owner: ?Principal, lockedPeriodDays: ?Nat) = this {
    type PairInfo = {
        canisterId: Principal; 
        info: {
            name: Text;
            version: Text;
            decimals: Nat8;
            owner: Principal;
            paused: Bool;
            setting: ICDex.DexSetting;
            token0: ICDex.TokenInfo;
            token1: ICDex.TokenInfo;
        }; 
        token0Decimals: Nat8; 
        token1Decimals: Nat8
    };

    private let version_: Text = "0.3";
    //private stable var hasInitialized: Bool = false;
    private stable var unlockTime: Int = Time.now() + Option.get(lockedPeriodDays, 0) * 24 * 3600 * 1_000_000_000;
    private stable var hasPaused: Bool = false; 
    private stable var owner: Principal = Option.get(_owner, installMsg.caller);
    private stable var operators: List.List<Principal> = List.nil();
    private stable var whitelistPairs: List.List<Principal> = List.nil();
    private stable var pairInfo: List.List<PairInfo> = List.nil();

    /* 
    * Local Functions
    */
    private func _onlyOwner(_caller: Principal) : Bool { 
        return _caller == owner;
    };  // assert(_onlyOwner(msg.caller));
    private func _onlyOperator(_caller: Principal) : Bool { 
        return List.some(operators, func (a: Principal): Bool{ a == _caller });
    };
    private func _onlyWhitelistPair(_pair: Principal) : Bool { 
        return List.some(whitelistPairs, func (p: Principal): Bool{ p == _pair });
    };

    private func _natToFloat(_n: Nat) : Float{
        let i : Int = _n;
        return Float.fromInt(i);
    };
    private func _floatToNat(_f: Float) : Nat{
        let i = Float.toInt(_f);
        assert(i >= 0);
        return Int.abs(i);
    };

    private func _getQuantity(_op: ICDex.OrderPrice): Nat{
        switch(_op.quantity){
            case(#Buy(v1, v2)){ v1 };
            case(#Sell(v1)){ v1 };
        };
    };

    private func _init(_pair: Principal) : async (){
        let pair: ICDex.Self = actor(Principal.toText(_pair));
        let info = await pair.info();
        assert(info.token0.2 == #drc20 or info.token0.2 == #icrc1 or info.token0.2 == #icp);
        assert(info.token1.2 == #drc20 or info.token1.2 == #icrc1 or info.token1.2 == #icp);
        let token0: ICRC1.Self = actor(Principal.toText(info.token0.0));
        let token0Decimals = await token0.icrc1_decimals(); 
        if (info.token0.2 == #drc20){
            let token0: DRC20.Self = actor(Principal.toText(info.token0.0));
            switch(await token0.drc20_approve(Principal.toText(_pair), 2 ** 63, null, null, null)){
                case(#err(v)){ assert(false); };
                case(_){};
            };
        };
        let token1: ICRC1.Self = actor(Principal.toText(info.token1.0));
        let token1Decimals = await token1.icrc1_decimals(); 
        if (info.token1.2 == #drc20){
            let token1: DRC20.Self = actor(Principal.toText(info.token1.0));
            switch(await token1.drc20_approve(Principal.toText(_pair), 2 ** 63, null, null, null)){
                case(#err(v)){ assert(false); };
                case(_){};
            };
        };
        pairInfo := List.filter(pairInfo, func (p: PairInfo): Bool{ p.canisterId != _pair });
        pairInfo := List.push({
            canisterId = _pair;
            info = info;
            token0Decimals = token0Decimals;
            token1Decimals = token1Decimals;
        }, pairInfo);
    };


    /* 
    * Public Functions
    */

    /// Query statistics of the pair
    public shared(msg) func price(_pair: Principal): async {price:Float; change24h:Float; vol24h:ICDex.Vol; totalVol:ICDex.Vol}{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        return await dex.stats();
    };

    /// Query orderbook of the pair
    public shared(msg) func orderbook(_pair: Principal): async (unitSize: Nat, orderBook: {ask: [(price: Float, quantity: Nat)]; bid: [(price: Float, quantity: Nat)]}){
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        if (not(List.some(pairInfo, func (pair: PairInfo): Bool{ pair.canisterId == _pair }))){
            await _init(_pair);
        };
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        let res = await dex.level100();
        var token0Decimals: Nat8 = 0;
        var token1Decimals: Nat8 = 0;
        switch(List.find(pairInfo, func (pair: PairInfo): Bool{ pair.canisterId == _pair })){
            case(?(pair)){
                token0Decimals := pair.token0Decimals;
                token1Decimals := pair.token1Decimals;
            };
            case(_){ assert(false); };
        };
        return (res.0, {
            ask = Array.map<ICDex.PriceResponse, (Float, Nat)>(res.1.ask, func (t: ICDex.PriceResponse): (Float, Nat){
                (_natToFloat(t.price) / _natToFloat(res.0) * _natToFloat(10**Nat8.toNat(token0Decimals)) / _natToFloat(10**Nat8.toNat(token1Decimals)), t.quantity)
            }); 
            bid = Array.map<ICDex.PriceResponse, (Float, Nat)>(res.1.bid, func (t: ICDex.PriceResponse): (Float, Nat){
                (_natToFloat(t.price) / _natToFloat(res.0) * _natToFloat(10**Nat8.toNat(token0Decimals)) / _natToFloat(10**Nat8.toNat(token1Decimals)), t.quantity)
            }); 
        });
    };

    /// Place an order
    /// Parameters:
    ///     _pair       Canister-id of the pair.
    ///     _side       Side of the order, its value is #Buy or #Sell.
    ///     _price      Human-readable Price, e.g. SNS1/ICP = 45.00, expressed as how many `base_unit`s (e.g. ICPs) of token1 can be exchanged for 1 `base_unit`s (e.g. SNS1s) of token0.
    ///                 Price = _price * 10**token1_decimals / 10**token0_decimals * UNIT_SIZE
    ///     _quantity   Quantity (smallest unit) of token0 to be traded for the order. It MUST be an integer multiple of UNIT_SIZE.
    /// Example: Purchase 2 SNS1s at 45.00 via SNS1/ICP pair.
    ///             order(Principal.fromText("32fn4-qqaaa-aaaak-ad65a-cai"), #Buy, 45.00, 200000000)
    public shared(msg) func order(_pair: Principal, _side: {#Buy;#Sell}, _price: Float, _quantity: Nat) : async ICDex.TradingResult{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(hasPaused));
        if (not(List.some(pairInfo, func (pair: PairInfo): Bool{ pair.canisterId == _pair }))){
            await _init(_pair);
        };
        switch(List.find(pairInfo, func (pair: PairInfo): Bool{ pair.canisterId == _pair })){
            case(?(pair)){
                let quantity = _quantity / pair.info.setting.UNIT_SIZE * pair.info.setting.UNIT_SIZE;
                assert(quantity > 0);
                let price = _floatToNat(_price * _natToFloat(pair.info.setting.UNIT_SIZE) * _natToFloat(10 ** Nat8.toNat(pair.token1Decimals)) / _natToFloat(10 ** Nat8.toNat(pair.token0Decimals)));
                let orderPrice = switch(_side){
                    case(#Buy){ { quantity = #Buy((quantity, 0)); price = price; } };
                    case(#Sell){ { quantity = #Sell(quantity); price = price; } };
                };
                let depositToken = switch(_side){
                    case(#Buy){ pair.info.token1.0 };
                    case(#Sell){ pair.info.token0.0 };
                };
                let tokenStd = switch(_side){
                    case(#Buy){ pair.info.token1.2 };
                    case(#Sell){ pair.info.token0.2 };
                };
                let depositValue = switch(_side){
                    case(#Buy){ quantity * price / pair.info.setting.UNIT_SIZE };
                    case(#Sell){ quantity };
                };
                let account = Tools.principalToAccountBlob(Principal.fromActor(this), null);
                let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
                let dex: ICDex.Self = actor(Principal.toText(pair.canisterId));
                let token: ICRC1.Self = actor(Principal.toText(depositToken));
                if (tokenStd == #icrc1 or tokenStd == #icp){
                    // Step1
                    let prepares = await dex.getTxAccount(address);
                    let tx_icrc1Account = prepares.0;
                    // Step2
                    let args : ICRC1.TransferArgs = {
                        memo = null;
                        amount = depositValue;
                        fee = null;
                        from_subaccount = null;
                        to = tx_icrc1Account;
                        created_at_time = null;
                    };
                    let res = await token.icrc1_transfer(args);
                };
                // Step3
                return await dex.trade(orderPrice, #LMT, null, null, null, null);
            };
            case(_){
                return #err({code = #UndefinedError; message = "Pair information does not exist."})
            };
        };
    };

    /// Query the status of an order
    public shared(msg) func status(_pair: Principal, _txid: ?ICDex.Txid): async ICDex.OrderStatusResponse{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        let prepares = await dex.getTxAccount(address);
        let nonce = prepares.2;
        switch(_txid){
            case(?(txid)){ 
                return await dex.statusByTxid(txid);
            };
            case(_){
                if (nonce > 0){
                    return await dex.status(address, Nat.sub(nonce, 1));
                };
            };
        };
        return #None;
    };

    /// Orders in pending status. Note, _page start from 1.
    public shared(msg) func pending(_pair: Principal, _page: ?Nat, _size: ?Nat): async ICDex.TrieList<ICDex.Txid, ICDex.TradingOrder>{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        return await dex.pending(?address, _page, _size);
    };

    /// Latest 100 events
    public shared(msg) func events(_pair: Principal): async [DRC205.TxnRecord]{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let drc205: DRC205.Impl = actor(Principal.toText(_pair));
        return await drc205.drc205_events(?address);
    };

    /// cancel order
    public shared(msg) func cancel(_pair: Principal, _txid: ?ICDex.Txid) : async (){
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(hasPaused));
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        let prepares = await dex.getTxAccount(address);
        let nonce = prepares.2;
        switch(_txid){
            case(?(txid)){
                await dex.cancelByTxid(txid, null);
            };
            case(_){
                if (nonce > 0){
                    await dex.cancel(Nat.sub(nonce, 1), null);
                };
            };
        };
    };

    /// fallback blocked funds
    public shared(msg) func fallback(_pair: Principal, _txid: ?ICDex.Txid) : async Bool{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(hasPaused));
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        let prepares = await dex.getTxAccount(address);
        let nonce = prepares.2;
        switch(_txid){
            case(?(txid)){
                return await dex.fallbackByTxid(txid, null);
            };
            case(_){
                if (nonce > 0){
                    return await dex.fallback(Nat.sub(nonce, 1), null);
                };
            };
        };
        return false;
    };

    /* 
    * Management
    */
    public query func version() : async Text{  
        return version_;
    };
    public query func getOwner() : async Principal{  
        return owner;
    };
    public query func getUnlockTime() : async Time.Time{  
        return unlockTime;
    };
    public shared(msg) func changeOwner(_newOwner: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        owner := _newOwner;
        return true;
    };
    public shared(msg) func setWhitelist(_pair: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        whitelistPairs := List.filter(whitelistPairs, func (p: Principal): Bool{ p != _pair });
        whitelistPairs := List.push(_pair, whitelistPairs);
        return true;
    };
    public shared(msg) func removeWhitelist(_pair: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        whitelistPairs := List.filter(whitelistPairs, func (p: Principal): Bool{ p != _pair });
        return true;
    };
    public query(msg) func getWhitelist() : async [Principal]{ 
        assert(_onlyOwner(msg.caller));
        return List.toArray(whitelistPairs);
    };
    public shared(msg) func setOperator(_operator: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        operators := List.filter(operators, func (p: Principal): Bool{ p != _operator });
        operators := List.push(_operator, operators);
        return true;
    };
    public shared(msg) func removeOperator(_operator: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        operators := List.filter(operators, func (p: Principal): Bool{ p != _operator });
        return true;
    };
    public query(msg) func getOperators() : async [Principal]{ 
        assert(_onlyOwner(msg.caller));
        return List.toArray(operators);
    };

    /// withdraw
    public shared(msg) func withdraw(_token: Principal, _to: ICRC1.Account, _value: Nat) : async (){ 
        assert(_onlyOwner(msg.caller));
        assert(Time.now() >= unlockTime);
        //let account = Tools.principalToAccountBlob(_to, null);
        let token: ICRC1.Self = actor(Principal.toText(_token));
        let args : ICRC1.TransferArgs = {
            memo = null;
            amount = _value;
            fee = null;
            from_subaccount = null;
            to = _to;
            created_at_time = null;
        };
        let res = await token.icrc1_transfer(args);
    };

    // DRC207: ICMonitor
    /// DRC207 support
    public query func drc207() : async DRC207.DRC207Support{
        return {
            monitorable_by_self = true;
            monitorable_by_blackhole = { allowed = true; canister_id = ?Principal.fromText("7hdtw-jqaaa-aaaak-aaccq-cai"); };
            cycles_receivable = true;
            timer = { enable = false; interval_seconds = null; }; 
        };
    };
    /// canister_status
    public func canister_status() : async DRC207.canister_status {
        let ic : DRC207.IC = actor("aaaaa-aa");
        await ic.canister_status({ canister_id = Principal.fromActor(this) });
    };
    /// receive cycles
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };

};