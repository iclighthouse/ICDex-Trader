/**
 * Module     : Trader.mo
 * Author     : ICLighthouse Team
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/ICDex-Trader
 */

import ICDex "mo:icl/ICDexTypes";
import Maker "mo:icl/ICDexMaker";
import DRC205 "mo:icl/DRC205Types";
import DRC207 "mo:icl/DRC207";
import List "mo:base/List";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import ICRC1 "mo:icl/ICRC1";
import DRC20 "mo:icl/DRC20";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Error "mo:base/Error";
import Hex "mo:icl/Hex";
import Tools "mo:icl/Tools";
import T "lib/Trader";

// Roles.
// owner: setting operator, setting whitelist pairs, trading, withdrawal
// operator: trading

shared(installMsg) actor class Trader(initPair: Principal) = this {
    type PairInfo = T.PairInfo;
    type AccountId = T.AccountId;
    type Timestamp = Nat; // seconds

    private let version_: Text = "0.5.2";
    private let timeoutSeconds: Nat = 300;
    private stable var paused: Bool = false; 
    private stable var operators: List.List<Principal> = List.nil();
    private stable var whitelistPairs: List.List<Principal> = ?(initPair, null);
    private stable var pairInfo: List.List<PairInfo> = List.nil();

    /* 
    * Local Functions
    */
    private func _onlyOwner(_caller: Principal) : Bool { 
        return Principal.isController(_caller);
    };  // assert(_onlyOwner(msg.caller));
    private func _onlyOperator(_caller: Principal) : Bool { 
        return List.some(operators, func (a: Principal): Bool{ a == _caller });
    };
    private func _onlyWhitelistPair(_pair: Principal) : Bool { 
        return List.some(whitelistPairs, func (p: Principal): Bool{ p == _pair });
    };

    private func _now() : Timestamp{
        return Int.abs(Time.now() / 1_000_000_000);
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

    private func _toSaBlob(_sa: ?[Nat8]) : ?Blob{
        switch(_sa){
            case(?(sa)){ 
                if (sa.size() == 0){
                    return null;
                }else{
                    return ?Blob.fromArray(sa); 
                };
            };
            case(_){ return null; };
        }
    };
    private func _toSaNat8(_sa: ?Blob) : ?[Nat8]{
        switch(_sa){
            case(?(sa)){ 
                if (sa.size() == 0){
                    return null;
                }else{
                    return ?Blob.toArray(sa); 
                };
            };
            case(_){ return null; };
        }
    };
    private func _getPairInfo(_pair: Principal) : ?PairInfo{
        return List.find(pairInfo, func (pair: PairInfo): Bool{ pair.canisterId == _pair });
    };
    private func _accountIdToHex(_a: AccountId) : Text{
        return Hex.encode(Blob.toArray(_a));
    };
    private func _drc20Balance(_token: Principal, _accountId: AccountId) : async* Nat{
        let token: DRC20.Self = actor(Principal.toText(_token));
        return await token.drc20_balanceOf(_accountIdToHex(_accountId));
    };
    private func _icrc1Balance(_token: Principal, _account: {owner: Principal; subaccount: ?Blob}) : async* Nat{
        let token: ICRC1.Self = actor(Principal.toText(_token));
        return await token.icrc1_balance_of(_account);
    };
    private func _tokenBalance(_token: Principal, _std: ICDex.TokenStd, _account: {owner: Principal; subaccount: ?Blob}) : async* Nat{
        switch(_std){
            case(#drc20){
                let accountId = Tools.principalToAccountBlob(_account.owner, _toSaNat8(_account.subaccount));
                return await* _drc20Balance(_token, accountId);
            };
            case(_){
                return await* _icrc1Balance(_token, _account);
            };
        };
    };
    private func _getTokenBalances(_pair: Principal, _account: {owner: Principal; subaccount: ?Blob}) : async* (Nat, Nat){ // (token0, token1)
        switch(_getPairInfo(_pair)){
            case(?pair){
                let token0Cid = pair.info.token0.0;
                let token0Std = pair.info.token0.2;
                let token1Cid = pair.info.token1.0;
                let token1Std = pair.info.token1.2;
                let token0Balance = await* _tokenBalance(token0Cid, token0Std, _account);
                let token1Balance = await* _tokenBalance(token1Cid, token1Std, _account);
                return (token0Balance, token1Balance);
            };
            case(_){
                return (0, 0);
            };
        };
    };
    private func _getPairBalances(_pair: Principal, _account: {owner: Principal; subaccount: ?Blob}) : async* ICDex.KeepingBalance{
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        let accountId = Tools.principalToAccountBlob(_account.owner, _toSaNat8(_account.subaccount));
        return await dex.accountBalance(_accountIdToHex(accountId));
    };
    private func _drc20Transfer(_token: Principal, _to: AccountId, _value: Nat) : async* (){
        let token: DRC20.Self = actor(Principal.toText(_token));
        let res = await token.drc20_transfer(_accountIdToHex(_to), _value, null,null,null);
        switch(res){
            case(#ok(txid)){};
            case(#err(e)){ throw Error.reject("DRC20 transfer error."); };
        };
    };
    private func _icrc1Transfer(_token: Principal, _to: {owner: Principal; subaccount: ?Blob}, _value: Nat) : async* (){
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
        switch(res){
            case(#Ok(blockIndex)){};
            case(#Err(e)){ throw Error.reject("ICRC1 transfer error."); };
        };
    };
    private func _tokenTransfer(_token: Principal, _std: ICDex.TokenStd, _to: {owner: Principal; subaccount: ?Blob}, _value: Nat) : async* (){
        switch(_std){
            case(#drc20){
                let accountId = Tools.principalToAccountBlob(_to.owner, _toSaNat8(_to.subaccount));
                return await* _drc20Transfer(_token, accountId, _value);
            };
            case(_){
                return await* _icrc1Transfer(_token, _to, _value);
            };
        };
    };
    private func _tokenApprove(_token: Principal, _std: ICDex.TokenStd, _spender: {owner: Principal; subaccount: ?Blob}) : async* Bool{
        var isTokenSupportApproval: Bool = false;
        if (_std == #drc20){
            let token: DRC20.Self = actor(Principal.toText(_token));
            let accountId = Tools.principalToAccountBlob(_spender.owner, _toSaNat8(_spender.subaccount));
            switch(await token.drc20_approve(_accountIdToHex(accountId), 2 ** 128, null, null, null)){
                case(#err(v)){};
                case(_){ isTokenSupportApproval := true; };
            };
        }else{
            try{
                let token: ICRC1.Self = actor(Principal.toText(_token));
                switch(await token.icrc2_approve({
                    from_subaccount = null;
                    spender = _spender;
                    amount = 2 ** 128;
                    expected_allowance = null;
                    expires_at = null;
                    fee = null;
                    memo = null;
                    created_at_time = null;
                })){
                    case(#Err(v)){};
                    case(_){ isTokenSupportApproval := true; };
                };
            }catch(e){};
        };
        return isTokenSupportApproval;
    };
    private func _depositToPair(_pair: Principal, _value0: ?Nat, _value1: ?Nat) : async* (){
        let traderIcrc1Account = {owner = Principal.fromActor(this); subaccount = null };
        let traderAccountId = Tools.principalToAccountBlob(Principal.fromActor(this), null);
        let pairDepositIcrc1Account = {owner = _pair; subaccount = ?traderAccountId };
        switch(_getPairInfo(_pair)){
            case(?pair){
                if (pair.isKeptInPair != ?true){
                    throw Error.reject("Initialization not completed.");
                };
                let token0Fee = Option.get(pair.token0Fee, 0);
                let token1Fee = Option.get(pair.token1Fee, 0);
                // get balances
                let (balance0, balance1) = await* _getTokenBalances(_pair, traderIcrc1Account);
                let value0 = Option.get(_value0, balance0);
                let value1 = Option.get(_value1, balance1);
                // deposit
                let dex: ICDex.Self = actor(Principal.toText(_pair));
                if (value0 > token0Fee * 2){
                    if (pair.isToken0SupportApproval != ?true){
                        await* _tokenTransfer(pair.info.token0.0, pair.info.token0.2, pairDepositIcrc1Account, Nat.sub(value0, token0Fee));
                    };
                    await dex.deposit(#token0, Nat.sub(value0, token0Fee*2), null);
                };
                if (value1 > token1Fee * 2){
                    if (pair.isToken1SupportApproval != ?true){
                        await* _tokenTransfer(pair.info.token1.0, pair.info.token1.2, pairDepositIcrc1Account, Nat.sub(value1, token1Fee));
                    };
                    await dex.deposit(#token1, Nat.sub(value1, token1Fee*2), null);
                };
            };
            case(_){ throw Error.reject("Pair information does not exist."); };
        };
    };
    // This only withdraws the available funds, if you want to withdraw all the funds, execute the .cancelAll() method first.
    private func _withdrawFromPair(_pair: Principal) : async* (){
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        ignore await dex.withdraw(null, null, null);
    };

    private func _placeAnOrder(_pair: Principal, _side: {#Buy;#Sell}, _price: Float, _quantity: Nat) : async* ICDex.TradingResult{
        switch(_getPairInfo(_pair)){
            case(?(pair)){
                let quantity = _quantity / pair.info.setting.UNIT_SIZE * pair.info.setting.UNIT_SIZE;
                assert(quantity > 0);
                let price = _floatToNat(_price * _natToFloat(pair.info.setting.UNIT_SIZE) * _natToFloat(10 ** Nat8.toNat(pair.token1Decimals)) / _natToFloat(10 ** Nat8.toNat(pair.token0Decimals)));
                let orderPrice = switch(_side){
                    case(#Buy){ { quantity = #Buy((quantity, 0)); price = price; } };
                    case(#Sell){ { quantity = #Sell(quantity); price = price; } };
                };
                let dex: ICDex.Self = actor(Principal.toText(pair.canisterId));
                // Enable: Pool Mode; Balance kept in Pair.
                return await dex.trade(orderPrice, #LMT, null, null, null, null);
            };
            case(_){
                return #err({code = #UndefinedError; message = "Pair information does not exist."})
            };
        };
    };

    private func _putOAMM(_pair: Principal, _maker: Principal): (){
        switch(_getPairInfo(_pair)){
            case(?(pair)){
                var OAMMPools: [Principal] = Option.get(pair.OAMMPools, []);
                pairInfo := List.filter(pairInfo, func (p: PairInfo): Bool{ p.canisterId != _pair });
                pairInfo := List.push({
                    canisterId = _pair;
                    info = pair.info;
                    token0Decimals = pair.token0Decimals;
                    token1Decimals = pair.token1Decimals;
                    token0Fee = pair.token0Fee; 
                    token1Fee = pair.token1Fee;
                    isToken0SupportApproval = pair.isToken0SupportApproval;
                    isToken1SupportApproval = pair.isToken1SupportApproval;
                    isKeptInPair = pair.isKeptInPair;
                    OAMMPools = ?Tools.arrayAppend(Array.filter(OAMMPools, func (t: Principal): Bool{ t != _maker }), [_maker]);
                }, pairInfo);
            };
            case(_){};
        };
    };

    private func _isInitialized(_pair: Principal) : Bool{
        return List.some(pairInfo, func (pair: PairInfo): Bool{ 
            pair.canisterId == _pair and Option.isSome(pair.isKeptInPair) 
        });
    };
    private func _init(_pair: Principal) : async (){
        let pair: ICDex.Self = actor(Principal.toText(_pair));
        let info = await pair.info();
        assert(info.token0.2 == #drc20 or info.token0.2 == #icrc1 or info.token0.2 == #icp);
        assert(info.token1.2 == #drc20 or info.token1.2 == #icrc1 or info.token1.2 == #icp);
        var token0Decimals : Nat8 = 8; 
        var token0Fee : Nat = 0;
        let isToken0SupportApproval = await* _tokenApprove(info.token0.0, info.token0.2, {owner = _pair; subaccount = null});
        if (info.token0.2 == #drc20){
            let token0: DRC20.Self = actor(Principal.toText(info.token0.0));
            token0Decimals := await token0.drc20_decimals();
            token0Fee := await token0.drc20_fee();
        }else{
            try{
                let token0: ICRC1.Self = actor(Principal.toText(info.token0.0));
                token0Decimals := await token0.icrc1_decimals();
                token0Fee := await token0.icrc1_fee();
            }catch(e){};
        };
        var token1Decimals : Nat8 = 8; 
        var token1Fee : Nat = 0;
        let isToken1SupportApproval = await* _tokenApprove(info.token1.0, info.token1.2, {owner = _pair; subaccount = null});
        if (info.token1.2 == #drc20){
            let token1: DRC20.Self = actor(Principal.toText(info.token1.0));
            token1Decimals := await token1.drc20_decimals();
            token1Fee := await token1.drc20_fee();
        }else{
            try{
                let token1: ICRC1.Self = actor(Principal.toText(info.token1.0));
                token1Decimals := await token1.icrc1_decimals();
                token1Fee := await token1.icrc1_fee();
            }catch(e){};
        };
        await pair.accountConfig(#PoolMode, true, null);
        pairInfo := List.filter(pairInfo, func (p: PairInfo): Bool{ p.canisterId != _pair });
        pairInfo := List.push({
            canisterId = _pair;
            info = info;
            token0Decimals = token0Decimals;
            token1Decimals = token1Decimals;
            token0Fee = ?token0Fee; 
            token1Fee = ?token1Fee;
            isToken0SupportApproval = ?isToken0SupportApproval;
            isToken1SupportApproval = ?isToken1SupportApproval;
            isKeptInPair = ?true;
            OAMMPools = null;
        }, pairInfo);
    };


    /* 
    * Public Functions
    */

    /// Query statistics of the pair.  
    /// Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
    /// Solution: query through the stats() method of the trading pair.
    public composite query func price(_pair: Principal): async {price:Float; change24h:Float; vol24h:ICDex.Vol; totalVol:ICDex.Vol}{
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        return await dex.stats();
    };

    /// Query orderbook of the pair.  
    /// Tip: It is more efficient to query directly using the query method of the ICDex trading pair.
    /// Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
    /// Solution: query through the level100() method of the trading pair.
    public composite query func orderbook(_pair: Principal): async (unitSize: Nat, orderBook: {ask: [(price: Float, quantity: Nat)]; bid: [(price: Float, quantity: Nat)]}){
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

    /// Query the status of an order.  
    /// Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
    /// Solution: query through the statusByTxid() method of the trading pair.
    public composite query func status(_pair: Principal, _txid: ?ICDex.Txid): async ICDex.OrderStatusResponse{
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
    /// Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
    /// Solution: query through the pending() method of the trading pair.
    public composite query func pending(_pair: Principal, _page: ?Nat, _size: ?Nat): async ICDex.TrieList<ICDex.Txid, ICDex.TradingOrder>{
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        return await dex.pending(?address, _page, _size);
    };

    /// Latest 100 events.  
    /// Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
    /// Solution: query through the drc205_events() method of the trading pair.
    public composite query func events(_pair: Principal): async [DRC205.TxnRecord]{
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let drc205: DRC205.Impl = actor(Principal.toText(_pair));
        return await drc205.drc205_events(?address);
    };

    /// Place an order  
    /// Parameters:
    /// - pair       Canister-id of the pair.
    /// - side       Side of the order, its value is #Buy or #Sell.
    /// - price      Human-readable Price, e.g. SNS1/ICP = 45.00, expressed as how many `base_unit`s (e.g. ICPs) of token1 can be exchanged for 1 `base_unit`s (e.g. SNS1s) of token0.
    ///                 Price = _price * 10\**token1_decimals / 10\**token0_decimals * UNIT_SIZE
    /// - quantity   Quantity (smallest unit) of token0 to be traded for the order. It MUST be an integer multiple of UNIT_SIZE.
    /// 
    /// Example:  
    ///     Purchase 2 SNS1s at 45.00 via SNS1/ICP pair.  
    ///     order(Principal.fromText("xxxxx-xxxxx-xxxxx-cai"), #Buy, 45.00, 200000000)
    public shared(msg) func order(_pair: Principal, _side: {#Buy;#Sell}, _price: Float, _quantity: Nat) : async ICDex.TradingResult{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(paused));
        if (not(_isInitialized(_pair))){
            await _init(_pair);
        };
        let res = await* _placeAnOrder(_pair, _side, _price, _quantity);
        return res;
    };

    /// Create buy-wall
    public shared(msg) func buyWall(_pair: Principal, _buywall: [{price: Float; quantity: Nat}]) : 
    async [{price: Float; quantity: Nat; result: ?ICDex.TradingResult }]{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(paused));
        if (not(_isInitialized(_pair))){
            await _init(_pair);
        };
        var results: [{price: Float; quantity: Nat; result: ?ICDex.TradingResult }] = [];
        for (order in _buywall.vals()){
            var result: ?ICDex.TradingResult = null;
            try{
                result := ?(await* _placeAnOrder(_pair, #Buy, order.price, order.quantity));
            }catch(e){};
            results := Tools.arrayAppend(results, [{ price = order.price; quantity = order.quantity; result = result }]);
        };
        return results;
    };

    /// Add liquidity to OAMM 
    public shared(msg) func addLiquidity(_maker: Principal, _value0: Nat, _value1: Nat) : async Maker.Shares{
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(not(paused));
        let maker: Maker.Self = actor(Principal.toText(_maker));
        let makerInfo = await maker.info();
        let pairCanisterId = makerInfo.pairInfo.pairPrincipal;
        assert(_onlyWhitelistPair(pairCanisterId));
        if (not(_isInitialized(pairCanisterId))){
            await _init(pairCanisterId);
        };
        if (_now() > Option.get(addLiquidity_runningTime, 0) + timeoutSeconds){
            addLiquidity_runningTime := ?_now();
            try{
                var result: Nat = 0;
                let traderAccountId = Tools.principalToAccountBlob(Principal.fromActor(this), null);
                let makerDepositIcrc1Account = {owner = _maker; subaccount = ?traderAccountId };
                switch(_getPairInfo(pairCanisterId)){
                    case(?pair){
                        let token0Fee = Option.get(pair.token0Fee, 0);
                        let token1Fee = Option.get(pair.token1Fee, 0);
                        if (_value0 <= token0Fee*2 or _value1 <= token1Fee*2){
                            throw Error.reject("The amount entered is too low.");
                        };
                        let isToken0Approved = await* _tokenApprove(pair.info.token0.0, pair.info.token0.2, {owner = _maker; subaccount = null});
                        if (not(isToken0Approved)){
                            await* _tokenTransfer(pair.info.token0.0, pair.info.token0.2, makerDepositIcrc1Account, Nat.sub(_value0, token0Fee));
                        };
                        let isToken1Approved = await* _tokenApprove(pair.info.token1.0, pair.info.token1.2, {owner = _maker; subaccount = null});
                        if (not(isToken1Approved)){
                            await* _tokenTransfer(pair.info.token1.0, pair.info.token1.2, makerDepositIcrc1Account, Nat.sub(_value1, token1Fee));
                        };
                        result := await maker.add(Nat.sub(_value0, token0Fee*2), Nat.sub(_value1, token1Fee*2), null);
                        _putOAMM(pairCanisterId, _maker);
                    };
                    case(_){};
                };
                addLiquidity_runningTime := null;
                return result;
            }catch(e){
                addLiquidity_runningTime := null;
                throw Error.reject("Error: "# Error.message(e));
            };
        }else{
            throw Error.reject("Another operator is performing this operation. Try again later.");
        };
    };
    private var addLiquidity_runningTime: ?Timestamp = null;

    /// Remove liquidity from OAMM
    public shared(msg) func removeLiquidity(_maker: Principal, _shares: ?Nat) : async (value0: Nat, value1: Nat){
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(not(paused));
        let maker: Maker.Self = actor(Principal.toText(_maker));
        let makerInfo = await maker.info();
        let pairCanisterId = makerInfo.pairInfo.pairPrincipal;
        assert(_onlyWhitelistPair(pairCanisterId));
        if (not(_isInitialized(pairCanisterId))){
            await _init(pairCanisterId);
        };
        if (_now() > Option.get(removeLiquidity_runningTime, 0) + timeoutSeconds){
            removeLiquidity_runningTime := ?_now();
            try{
                var result: (Nat, Nat) = (0, 0);
                let traderAccountId = Tools.principalToAccountBlob(Principal.fromActor(this), null);
                switch(_getPairInfo(pairCanisterId)){
                    case(?pair){
                        let shares = Option.get(_shares, (await maker.getAccountShares(_accountIdToHex(traderAccountId))).0);
                        result := await maker.remove(shares, null);
                        _putOAMM(pairCanisterId, _maker);
                    };
                    case(_){};
                };
                removeLiquidity_runningTime := null;
                return result;
            }catch(e){
                removeLiquidity_runningTime := null;
                throw Error.reject("Error: "# Error.message(e));
            };
        }else{
            throw Error.reject("Another operator is performing this operation. Try again later.");
        };
    };
    private var removeLiquidity_runningTime: ?Timestamp = null;

    /// cancel order
    public shared(msg) func cancel(_pair: Principal, _txid: ICDex.Txid) : async (){
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(paused));
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        await dex.cancelByTxid(_txid, null);
    };

    /// fallback blocked funds from Pair
    public shared(msg) func fallbackFromPair(_pair: Principal) : async (value0: Nat, value1: Nat){
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(paused));
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        return await dex.depositFallback(null);
    };

    /// fallback blocked funds from Maker
    public shared(msg) func fallbackFromMaker(_maker: Principal) : async (value0: Nat, value1: Nat){
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        assert(not(paused));
        let maker: Maker.Self = actor(Principal.toText(_maker));
        return await maker.fallback(null);
    };

    /// Deposit funds from Trader to Pair
    public shared(msg) func depositToPair(_pair: Principal, _value0: ?Nat, _value1: ?Nat) : async (){ 
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        if (not(_isInitialized(_pair))){
            await _init(_pair);
        };
        if (_now() > Option.get(depositToPair_runningTime, 0) + timeoutSeconds){
            depositToPair_runningTime := ?_now();
            try{
                await* _depositToPair(_pair, _value0, _value1);
                depositToPair_runningTime := null;
            }catch(e){
                depositToPair_runningTime := null;
                throw Error.reject("Error: "# Error.message(e));
            };
        }else{
            throw Error.reject("Another operator is performing this operation. Try again later.");
        };
    };
    private var depositToPair_runningTime: ?Timestamp = null;

    /// Withdraw funds from Pair to Trader.  
    /// Note: This only withdraws the available funds, if you want to withdraw all the funds, execute the `cancelAll()` method first.
    public shared(msg) func withdrawFromPair(_pair: Principal) : async (){ 
        assert(_onlyOwner(msg.caller) or _onlyOperator(msg.caller));
        if (not(_isInitialized(_pair))){
            await _init(_pair);
        };
        if (_now() > Option.get(withdrawFromPair_runningTime, 0) + timeoutSeconds){
            withdrawFromPair_runningTime := ?_now();
            try{
                await* _withdrawFromPair(_pair);
                withdrawFromPair_runningTime := null;
            }catch(e){
                withdrawFromPair_runningTime := null;
                throw Error.reject("Error: "# Error.message(e));
            };
        }else{
            throw Error.reject("Another operator is performing this operation. Try again later.");
        };
    };
    private var withdrawFromPair_runningTime: ?Timestamp = null;

    /* 
    * Management
    */
    public query func version() : async Text{  
        return version_;
    };
    /// Pause or enable this Canister.
    public shared(msg) func pause(_pause: Bool) : async (){ 
        assert(_onlyOwner(msg.caller));
        paused := _pause;
    };
    /// Returns whether to pause or not.
    public query func isPaused() : async Bool{ 
        return paused;
    };
    /// Re-acquire trading pair information.  
    /// The initialization can be repeated.
    public shared(msg) func init() : async (){
        assert(_onlyOwner(msg.caller));
        for (pair in List.toIter(whitelistPairs)){
            await _init(pair);
        };
    };
    /// Add a whitelist trading pair (only these pairs are allowed to be traded)
    public shared(msg) func setWhitelist(_pair: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        whitelistPairs := List.filter(whitelistPairs, func (p: Principal): Bool{ p != _pair });
        whitelistPairs := List.push(_pair, whitelistPairs);
        return true;
    };
    /// Remove a whitelist trading pair
    public shared(msg) func removeWhitelist(_pair: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        whitelistPairs := List.filter(whitelistPairs, func (p: Principal): Bool{ p != _pair });
        return true;
    };
    /// Return whitelist trading pairs
    public query func getWhitelist() : async [Principal]{ 
        return List.toArray(whitelistPairs);
    };
    /// Add an operator (he can only submit trade orders, not withdraw funds).
    public shared(msg) func setOperator(_operator: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        operators := List.filter(operators, func (p: Principal): Bool{ p != _operator });
        operators := List.push(_operator, operators);
        return true;
    };
    /// Remove an operator
    public shared(msg) func removeOperator(_operator: Principal) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        operators := List.filter(operators, func (p: Principal): Bool{ p != _operator });
        return true;
    };
    /// Return operators
    public query func getOperators() : async [Principal]{
        return List.toArray(operators);
    };

    /// Return trader's balances.  
    /// Tip: It is more efficient to query directly using the query method of the ICDex trading pair and Tokens.
    public shared(msg) func getBalances() : async [{
        pair: Principal; 
        tokens: (Text, Text); 
        traderBalances: (Nat, Nat); 
        keptInPairBalances: ICDex.KeepingBalance;
        OAMMPools: [{maker: Principal; shares: Nat; shareDecimals: Nat8; NAV: Maker.UnitNetValue }]
    }]{
        assert(_onlyOwner(msg.caller));
        let traderIcrc1Account = {owner = Principal.fromActor(this); subaccount = null };
        let traderAccountId = Tools.principalToAccountBlob(Principal.fromActor(this), null);
        var balances : [{
            pair: Principal; 
            tokens: (Text, Text); 
            traderBalances: (Nat, Nat); 
            keptInPairBalances: ICDex.KeepingBalance;
            OAMMPools: [{maker: Principal; shares: Nat; shareDecimals: Nat8; NAV: Maker.UnitNetValue }]
        }] = [];
        for (pair in List.toIter(pairInfo)){
            let traderBalances = await* _getTokenBalances(pair.canisterId, traderIcrc1Account);
            let keptInPairBalances = await* _getPairBalances(pair.canisterId, traderIcrc1Account);
            var OAMMPools : [{maker: Principal; shares: Nat; shareDecimals: Nat8; NAV: Maker.UnitNetValue }] = [];
            for (makerCId in Option.get(pair.OAMMPools, []).vals()){
                let maker: Maker.Self = actor(Principal.toText(makerCId));
                let shares = (await maker.getAccountShares(_accountIdToHex(traderAccountId))).0;
                let shareDecimals: Nat8 = (await maker.info()).shareDecimals;
                let nav = (await maker.stats()).latestUnitNetValue;
                OAMMPools := Tools.arrayAppend(OAMMPools, [{maker = makerCId; shares = shares; shareDecimals = shareDecimals; NAV = nav}]);
            };
            balances := Tools.arrayAppend(balances, [{
                pair = pair.canisterId;
                tokens = (pair.info.token0.1, pair.info.token1.1);
                traderBalances = traderBalances;
                keptInPairBalances = keptInPairBalances;
                OAMMPools = OAMMPools;
            }]);
        };
        return balances;
    };

    /// cancel all orders
    public shared(msg) func cancelAll(_pair: Principal) : async (){
        assert(_onlyOwner(msg.caller));
        assert(_onlyWhitelistPair(_pair));
        assert(not(paused));
        let address = Tools.principalToAccountHex(Principal.fromActor(this), null);
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        await dex.cancelAll(#self_sa(null), null);
    };

    /// Withdraw
    /// Note: To withdraw the funds being traded, you need to first call `withdrawFromPair()`.
    public shared(msg) func withdraw(_token: Principal, _to: ICRC1.Account, _value: Nat) : async (){ 
        assert(_onlyOwner(msg.caller));
        try{
            await* _tokenTransfer(_token, #icrc1, _to, _value);
        }catch(e){
            await* _tokenTransfer(_token, #drc20, _to, _value);
        };
    };

    // DRC207: ICMonitor
    /// DRC207 support
    public query func drc207() : async DRC207.DRC207Support{
        return {
            monitorable_by_self = true;
            monitorable_by_blackhole = { allowed = false; canister_id = null; };
            cycles_receivable = true;
            timer = { enable = false; interval_seconds = null; }; 
        };
    };
    /// Return canister_status (Need to add this CanisterId as its own controller)
    public func canister_status() : async DRC207.canister_status {
        let ic : DRC207.IC = actor("aaaaa-aa");
        await ic.canister_status({ canister_id = Principal.fromActor(this) });
    };
    /// Receive cycles
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };

};