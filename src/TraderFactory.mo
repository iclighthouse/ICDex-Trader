/**
 * Module     : TraderFactory.mo
 * Author     : ICLighthouse Team
 * License    : GNU General Public License v3.0
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/ICDex-Trader
 */
import Prim "mo:⛔";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import CyclesWallet "mo:icl/CyclesWallet";
import TraderClass "Trader";
import ICRC1 "mo:icl/ICRC1";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Tools "mo:icl/Tools";
import IC "mo:icl/IC";
import DRC207 "mo:icl/DRC207";
import Error "mo:base/Error";
import Trie "mo:base/Trie";
import Int "mo:base/Int";

shared(installMsg) actor class TraderFactory() = this {
    type AccountId = Blob;
    type Timestamp = Nat; // Seconds
    type Trader = {
        name: Text;
        canisterId: Principal;
        owner: AccountId;
        createdTime: Timestamp;
    };

    private stable var BLACKHOLE: Text = "7hdtw-jqaaa-aaaak-aaccq-cai";
    private stable var SYSTOKEN: Principal = Principal.fromText("5573k-xaaaa-aaaak-aacnq-cai");
    private stable var SYSTOKEN_FEE: Nat = 1_000_000; // 0.01 ICL
    private stable var TRADER_CREATION_FEE: Nat = 500_000_000; // 5 ICL
    private stable var ic: IC.Self = actor("aaaaa-aa");
    private stable var accountTraders : Trie.Trie<AccountId, [Trader]> = Trie.empty();
    private let sa_zero : [Nat8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

    private func _now() : Timestamp{
        return Int.abs(Time.now() / 1_000_000_000);
    };
    private func keyb(t: Blob) : Trie.Key<Blob> { return { key = t; hash = Blob.hash(t) }; };

    private func _onlyOwner(_caller: Principal) : Bool {
        return Principal.isController(_caller);
    };
    private func _onlyTraderOwner(_caller: AccountId, _traderCanisterId: Principal) : Bool {
        switch(Trie.get(accountTraders, keyb(_caller), Blob.equal)){
            case(?(traders)){
                return Option.isSome(Array.find(traders, func (t: Trader): Bool{ _traderCanisterId == t.canisterId }));
            };
            case(_){ return false; };
        };
    };
    private func _toSaBlob(_sa: ?[Nat8]) : ?Blob{
        switch(_sa){
            case(?(sa)){ 
                if (sa.size() == 0 or sa == sa_zero){
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
                if (sa.size() == 0 or sa == Blob.fromArray(sa_zero)){
                    return null;
                }else{
                    return ?Blob.toArray(sa); 
                };
            };
            case(_){ return null; };
        }
    };
    private func _get(_user: AccountId, _traderCanisterId: Principal) : ?Trader{
        switch(Trie.get(accountTraders, keyb(_user), Blob.equal)){
            case(?(traders)){
                return Array.find(traders, func (t: Trader): Bool{ _traderCanisterId == t.canisterId });
            };
            case(_){ return null; };
        };
    };
    private func _put(_user: AccountId, _trader: Trader) : (){
        switch(Trie.get(accountTraders, keyb(_user), Blob.equal)){
            case(?(traders)){
                accountTraders := Trie.put(accountTraders, keyb(_user), Blob.equal, Tools.arrayAppend(Array.filter(traders, func (t: Trader): Bool{ 
                    t.canisterId != _trader.canisterId 
                }), [_trader])).0;
            };
            case(_){
                accountTraders := Trie.put(accountTraders, keyb(_user), Blob.equal, [_trader]).0;
            };
        };
    };
    private func _remove(_user: AccountId, _traderCanisterId: Principal) : (){
        switch(Trie.get(accountTraders, keyb(_user), Blob.equal)){
            case(?(traders)){
                let temp = Array.filter(traders, func (t: Trader): Bool{ 
                    t.canisterId != _traderCanisterId
                });
                if (temp.size() > 0){
                    accountTraders := Trie.put(accountTraders, keyb(_user), Blob.equal, temp).0;
                }else{
                    accountTraders := Trie.remove(accountTraders, keyb(_user), Blob.equal).0;
                };
            };
            case(_){};
        };
    };
    private func _transfer(_token: Principal, _to: ICRC1.Account, _amount: Nat, _fromSubaccount: ?Blob): async* (){
        let token: ICRC1.Self = actor(Principal.toText(_token));
        let result = await token.icrc1_transfer({
            from_subaccount = _fromSubaccount;
            to = _to;
            amount = _amount;
            fee = null;
            memo = null;
            created_at_time = null;
        });
        switch(result){
            case(#Ok(blockNumber)){};
            case(#Err(e)){
                throw Error.reject("Error: Error when paying the fee for creating a trading pair."); 
            };
        };
    };
    private func _transferFrom(_token: Principal, _from: ICRC1.Account, _amount: Nat): async* (){
        let token: ICRC1.Self = actor(Principal.toText(_token));
        let result = await token.icrc2_transfer_from({
            spender_subaccount = null; // *
            from = _from;
            to = {owner = Principal.fromActor(this); subaccount = null};
            amount = _amount;
            fee = null;
            memo = null;
            created_at_time = null;
        });
        switch(result){
            case(#Ok(blockNumber)){};
            case(#Err(e)){
                throw Error.reject("Error: Error when paying the fee for creating a trading pair."); 
            };
        };
    };

    /// Admin: Withdraw ICL
    public shared(msg) func ICLWithdraw(_to: ICRC1.Account, _amount: Nat): async (){
        assert(_onlyOwner(msg.caller));
        return await* _transfer(SYSTOKEN, _to, _amount, null);
    };
    /// Admin: Config
    public shared(msg) func config(_args: {
        BLACKHOLE: ?Principal;
        SYSTOKEN: ?Principal;
        SYSTOKEN_FEE: ?Nat;
        TRADER_CREATION_FEE: ?Nat;
    }) : async (){
        assert(_onlyOwner(msg.caller));
        BLACKHOLE := Principal.toText(Option.get(_args.BLACKHOLE, Principal.fromText(BLACKHOLE)));
        SYSTOKEN := Option.get(_args.SYSTOKEN, SYSTOKEN);
        SYSTOKEN_FEE := Option.get(_args.SYSTOKEN_FEE, SYSTOKEN_FEE);
        TRADER_CREATION_FEE := Option.get(_args.TRADER_CREATION_FEE, TRADER_CREATION_FEE);
    };

    /// Returns configurations
    public query func getConfig(): async {
        BLACKHOLE: Principal;
        SYSTOKEN: Principal;
        SYSTOKEN_FEE: Nat;
        TRADER_CREATION_FEE: Nat;
    }{
        return {
            BLACKHOLE = Principal.fromText(BLACKHOLE);
            SYSTOKEN = SYSTOKEN;
            SYSTOKEN_FEE = SYSTOKEN_FEE;
            TRADER_CREATION_FEE = TRADER_CREATION_FEE;
        };
    };

    /// Create a trader.  
    /// Creating a Trader Canister requires payment of `TRADER_CREATION_FEE` ICLs, which are used to add an initial 0.5 T Cycles to the canister.  
    /// Note: The `controller` of Trader Canister is the creator, and the Cycles balance of the canister needs to be monitored and topped up by the creator.  
    /// WARNING: If the Cycles balance of Trader Canister is insufficient, it may result in the deletion of the canister, which will result in the loss of all assets in the canister. The creator needs to monitor the Cycles balance of the canister at all times!
    public shared(msg) func create(_name: Text, _initPair: Principal, _traderOwner: ?Principal, _sa: ?[Nat8]) : async ?Principal {
        let accountId = Tools.principalToAccountBlob(msg.caller, _sa);
        var traderOwner = accountId;
        if (Option.isSome(_traderOwner)){
            traderOwner := Tools.principalToAccountBlob(Option.get(_traderOwner, msg.caller), null);
        };
        try{
            await* _transferFrom(SYSTOKEN, {owner = msg.caller; subaccount = _toSaBlob(_sa)}, TRADER_CREATION_FEE);
            try{
                Cycles.add(500_000_000_000);
                let trader = await TraderClass.Trader(_initPair, _traderOwner);
                let traderCanisterId = Principal.fromActor(trader);
                let res = await ic.update_settings({
                    canister_id = traderCanisterId; 
                    settings={ 
                        compute_allocation = null;
                        controllers = ?[traderCanisterId, msg.caller]; 
                        freezing_threshold = null;
                        memory_allocation = null;
                    };
                });
                _put(traderOwner, {
                    name = _name;
                    canisterId = traderCanisterId;
                    owner = traderOwner;
                    createdTime = _now();
                });
                return ?traderCanisterId;
            } catch(e){
                if (TRADER_CREATION_FEE > SYSTOKEN_FEE){
                    await* _transfer(SYSTOKEN, {owner = msg.caller; subaccount = _toSaBlob(_sa)}, Nat.sub(TRADER_CREATION_FEE, SYSTOKEN_FEE), null);
                };
                throw Error.reject("Error: Creation Failed. ("# Error.message(e) #")"); 
            };
        }catch(e){
            throw Error.reject(Error.message(e));
        };
        return null;
    };

    /// Modify the Trader.
    public shared(msg) func modifyTrader(_trader: Principal, _name: ?Text, _newOwner: ?AccountId, _sa: ?[Nat8]): async Bool{
        let accountId = Tools.principalToAccountBlob(msg.caller, _sa);
        assert(_onlyTraderOwner(accountId, _trader));
        switch(_get(accountId, _trader)){
            case(?trader){
                _put(accountId, {
                    name = Option.get(_name, trader.name);
                    canisterId = _trader;
                    owner = Option.get(_newOwner, accountId);
                    createdTime = trader.createdTime;
                });
                return true;
            };
            case(_){
                return false;
            };
        };
    };

    /// Delete from the Trader list of the 'user' account. (Note: not deleting Trader Canister).
    public shared(msg) func deleteTrader(_trader: Principal, _sa: ?[Nat8]): async Bool{
        let accountId = Tools.principalToAccountBlob(msg.caller, _sa);
        assert(_onlyTraderOwner(accountId, _trader));
        _remove(accountId, _trader);
        return true;
    };

    /// get user's Traders
    public query func getTraders(_user: AccountId) : async ?[Trader]{
        return Trie.get(accountTraders, keyb(_user), Blob.equal);
    };

    /// Admin: Canister memory
    public query func getMemory() : async (Nat,Nat,Nat){
        return (Prim.rts_memory_size(), Prim.rts_heap_size(), Prim.rts_total_allocation());
    };
    
    /// Admin: Cycles withdraw
    public shared(msg) func cyclesWithdraw(_wallet: Principal, _amount: Nat): async (){
        assert(_onlyOwner(msg.caller));
        let cyclesWallet: CyclesWallet.Self = actor(Principal.toText(_wallet));
        let balance = Cycles.balance();
        var value: Nat = _amount;
        if (balance <= _amount) {
            value := balance;
        };
        Cycles.add(value);
        await cyclesWallet.wallet_receive();
        //Cycles.refunded();
    };

    // DRC207 ICMonitor
    /// DRC207 support
    public query func drc207() : async DRC207.DRC207Support{
        return {
            monitorable_by_self = true;
            monitorable_by_blackhole = { allowed = false; canister_id = ?Principal.fromText(BLACKHOLE); };
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
    /// timer tick
    // public func timer_tick(): async (){
    //     //
    // };

    /*
    * upgrade functions
    */
    system func preupgrade() {
    };

    system func postupgrade() {
        
    };
};
