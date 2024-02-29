import ICDex "mo:icl/ICDexTypes";
import Maker "mo:icl/ICDexMaker";
module {
  public type AccountId = Blob;
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type Address = Text;
  public type Amount = Nat;
  public type BalanceChange = {
    #DebitRecord : Nat;
    #CreditRecord : Nat;
    #NoChange;
  };
  public type CyclesWallet = Principal;
  public type Data = [Nat8];
  public type Nonce = Nat;
  public type OperationType = {
    #AddLiquidity;
    #Swap;
    #Claim;
    #RemoveLiquidity;
  };
  public type OrderFilled = {
    time : Time;
    token0Value : BalanceChange;
    counterparty : Txid;
    token1Value : BalanceChange;
  };
  public type OrderPrice = {
    quantity : { #Buy : (Nat, Nat); #Sell : Nat };
    price : Nat;
  };
  public type OrderStatusResponse = {
    #Failed : TradingOrder;
    #None;
    #Completed : TxnRecord;
    #Pending : TradingOrder;
  };
  public type OrderType = { #FAK; #FOK; #LMT; #MKT };
  public type ShareChange = { #Burn : Shares; #Mint : Shares; #NoChange };
  public type Shares = Nat;
  public type Status = {
    #Failed;
    #Cancelled;
    #PartiallyCompletedAndCancelled;
    #Completed;
    #Pending;
  };
  public type Time = Int;
  public type Toid = Nat;
  public type TokenType = { #Icp; #Token : Principal; #Cycles };
  public type TradingOrder = {
    fee : { fee0 : Int; fee1 : Int };
    gas : { gas0 : Nat; gas1 : Nat };
    status : TradingStatus;
    toids : [Toid];
    data : ?[Nat8];
    time : Time;
    txid : Txid;
    icrc1Account : ?{ owner : Principal; subaccount : ?[Nat8] };
    orderType : OrderType;
    filled : [OrderFilled];
    expiration : Time;
    nonce : Nat;
    account : AccountId;
    remaining : OrderPrice;
    index : Nat;
    orderPrice : OrderPrice;
    refund : (Nat, Nat, Nat);
  };
  public type TradingResult = {
    #ok : { status : TradingStatus; txid : Txid; filled : [OrderFilled] };
    #err : {
      code : {
        #NonceError;
        #InvalidAmount;
        #UndefinedError;
        #UnacceptableVolatility;
        #TransactionBlocking;
        #InsufficientBalance;
        #TransferException;
      };
      message : Text;
    };
  };
  public type TradingStatus = { #Todo; #Closed; #Cancelled; #Pending };
  public type TrieList = {
    total : Nat;
    data : [(Txid, TradingOrder)];
    totalPage : Nat;
  };
  public type Txid = [Nat8];
  public type TxnRecord = {
    fee : { token0Fee : Int; token1Fee : Int };
    status : Status;
    shares : ShareChange;
    msgCaller : ?Principal;
    order : { token0Value : ?BalanceChange; token1Value : ?BalanceChange };
    data : ?Data;
    time : Time;
    txid : Txid;
    orderMode : { #AMM; #OrderBook };
    orderType : ?{ #FAK; #FOK; #LMT; #MKT };
    filled : { token0Value : BalanceChange; token1Value : BalanceChange };
    token0 : TokenType;
    token1 : TokenType;
    nonce : Nonce;
    operation : OperationType;
    account : AccountId;
    details : [
      {
        time : Time;
        token0Value : BalanceChange;
        counterparty : Txid;
        token1Value : BalanceChange;
      }
    ];
    caller : AccountId;
    index : Nat;
    cyclesWallet : ?CyclesWallet;
  };
  public type Vol = { value0 : Amount; value1 : Amount };
  public type canister_status = {
    status : { #stopped; #stopping; #running };
    memory_size : Nat;
    cycles : Nat;
    settings : definite_canister_settings;
    module_hash : ?[Nat8];
  };
  public type definite_canister_settings = {
    freezing_threshold : Nat;
    controllers : [Principal];
    memory_allocation : Nat;
    compute_allocation : Nat;
  };
  public type PairInfo = {
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
        token1Decimals: Nat8;
        token0Fee: ?Nat; 
        token1Fee: ?Nat;
        isToken0SupportApproval: ?Bool;
        isToken1SupportApproval: ?Bool;
        isKeptInPair: ?Bool;
        OAMMPools: ?[Principal];
    };
  public type Self = actor {
    addLiquidity : shared (_maker: Principal, _value0: Nat, _value1: Nat) -> async Nat;
    removeLiquidity : shared (_maker: Principal, _shares: ?Nat) -> async (value0: Nat, value1: Nat);
    buyWall : shared (_pair: Principal, _buywall: [{price: Float; quantity: Nat}]) -> async [{price: Float; quantity: Nat; result: ?ICDex.TradingResult }];
    cancel : shared (pair: Principal, ?Txid) -> async ();
    cancelAll : shared (_pair: Principal) -> async ();
    canister_status : shared () -> async canister_status;
    events : shared composite query (pair: Principal) -> async [TxnRecord];
    fallbackFromPair : shared (_pair: Principal) -> async (value0: Nat, value1: Nat);
    fallbackFromMaker : shared (_maker: Principal) -> async (value0: Nat, value1: Nat);
    getBalances : shared () -> async [{
        pair: Principal; 
        tokens: (Text, Text); 
        traderBalances: (Nat, Nat); 
        keptInPairBalances: ICDex.KeepingBalance;
        OAMMPools: [{maker: Principal; shares: Nat; shareDecimals: Nat8; NAV: Maker.UnitNetValue }]
    }];
    getOperators : shared query () -> async [Principal];
    getWhitelist : shared query () -> async [Principal];
    order : shared ( pair: Principal, { #Buy; #Sell }, price: Float, quantity: Nat) -> async TradingResult;
    orderbook : shared composite query (pair: Principal) -> async (unitSize: Nat, orderBook: { ask : [(Float, Nat)]; bid : [(Float, Nat)] });
    pending : shared composite query (pair: Principal, page: ?Nat, size: ?Nat) -> async TrieList;
    price : shared composite query (pair: Principal) -> async { change24h : Float; vol24h : Vol; totalVol : Vol; price : Float;};
    removeOperator : shared Principal -> async Bool;
    removeWhitelist : shared Principal -> async Bool;
    setOperator : shared Principal -> async Bool;
    setWhitelist : shared Principal -> async Bool;
    status : shared composite query (pair: Principal, ?Txid) -> async OrderStatusResponse;
    depositToPair : shared (_pair: Principal, _value0: ?Nat, _value1: ?Nat) -> async ();
    withdrawFromPair : shared (_pair: Principal) -> async ();
    withdraw : shared ( token: Principal, to: Account, value: Nat ) -> async ();
    version : shared query () -> async Text;
    getOwner : shared query () -> async Principal;
    changeOwner : shared (_owner: Principal) -> async ();
    pause : shared (_pause: Bool) -> async ();
    isPaused : shared query () -> async Bool;
    init : shared () -> async ();
    wallet_receive : shared () -> async ();
  };
  public type Trader = (initPair: Principal, initOwner: ?Principal) -> async Self
}