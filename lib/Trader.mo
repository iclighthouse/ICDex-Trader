module {
  public type AccountId = [Nat8];
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
  public type Self = actor {
    cancel : shared (pair: Principal, ?Txid) -> async ();
    canister_status : shared () -> async canister_status;
    changeOwner : shared Principal -> async Bool;
    events : shared (pair: Principal) -> async [TxnRecord];
    fallback : shared (pair: Principal, ?Txid) -> async Bool;
    getOperators : shared query () -> async [Principal];
    getOwner : shared query () -> async Principal;
    getWhitelist : shared query () -> async [Principal];
    order : shared ( pair: Principal, { #Buy; #Sell }, price: Float, quantity: Nat) -> async TradingResult;
    orderbook : shared (pair: Principal) -> async (unitSize: Nat, orderBook: { ask : [(Float, Nat)]; bid : [(Float, Nat)] });
    pending : shared (pair: Principal, page: ?Nat, size: ?Nat) -> async TrieList;
    price : shared (pair: Principal) -> async { change24h : Float; vol24h : Vol; totalVol : Vol; price : Float;};
    removeOperator : shared Principal -> async Bool;
    removeWhitelist : shared Principal -> async Bool;
    setOperator : shared Principal -> async Bool;
    setWhitelist : shared Principal -> async Bool;
    status : shared (pair: Principal, ?Txid) -> async OrderStatusResponse;
    version : shared query () -> async Text;
    wallet_receive : shared () -> async ();
    withdraw : shared ( token: Principal, { #icrc1; #drc20 }, to: Principal, Nat ) -> async ();
  };
  public type Trader = (?Principal, ?Nat) -> async Self
}