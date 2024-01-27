# Trader
* Module     : Trader.mo
 * Author     : ICLighthouse Team
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/ICDex-Trader

## Function `price`
``` motoko no-repl
func price(_pair : Principal) : async { price : Float; change24h : Float; vol24h : ICDex.Vol; totalVol : ICDex.Vol }
```

Query statistics of the pair.  
Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
Solution: query through the stats() method of the trading pair.

## Function `orderbook`
``` motoko no-repl
func orderbook(_pair : Principal) : async (unitSize : Nat, orderBook : { ask : [(price : Float, quantity : Nat)]; bid : [(price : Float, quantity : Nat)] })
```

Query orderbook of the pair.  
Tip: It is more efficient to query directly using the query method of the ICDex trading pair.
Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
Solution: query through the level100() method of the trading pair.

## Function `status`
``` motoko no-repl
func status(_pair : Principal, _txid : ?ICDex.Txid) : async ICDex.OrderStatusResponse
```

Query the status of an order.  
Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
Solution: query through the statusByTxid() method of the trading pair.

## Function `pending`
``` motoko no-repl
func pending(_pair : Principal, _page : ?Nat, _size : ?Nat) : async ICDex.TrieList<ICDex.Txid, ICDex.TradingOrder>
```

Orders in pending status. Note, _page start from 1.  
Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
Solution: query through the pending() method of the trading pair.

## Function `events`
``` motoko no-repl
func events(_pair : Principal) : async [DRC205.TxnRecord]
```

Latest 100 events.  
Tip: This is a composite_query method that does not get results if the trading pair and Trader are not in the same subnet.   
Solution: query through the drc205_events() method of the trading pair.

## Function `order`
``` motoko no-repl
func order(_pair : Principal, _side : {#Buy; #Sell}, _price : Float, _quantity : Nat) : async ICDex.TradingResult
```

Place an order
Parameters:
    _pair       Canister-id of the pair.
    _side       Side of the order, its value is #Buy or #Sell.
    _price      Human-readable Price, e.g. SNS1/ICP = 45.00, expressed as how many `base_unit`s (e.g. ICPs) of token1 can be exchanged for 1 `base_unit`s (e.g. SNS1s) of token0.
                Price = _price * 10**token1_decimals / 10**token0_decimals * UNIT_SIZE
    _quantity   Quantity (smallest unit) of token0 to be traded for the order. It MUST be an integer multiple of UNIT_SIZE.
Example: 
    Purchase 2 SNS1s at 45.00 via SNS1/ICP pair.
    order(Principal.fromText("xxxxx-xxxxx-xxxxx-cai"), #Buy, 45.00, 200000000)

## Function `buyWall`
``` motoko no-repl
func buyWall(_pair : Principal, _buywall : [{ price : Float; quantity : Nat }]) : async [{ price : Float; quantity : Nat; result : ?ICDex.TradingResult }]
```

Create buy-wall

## Function `addLiquidity`
``` motoko no-repl
func addLiquidity(_maker : Principal, _value0 : Nat, _value1 : Nat) : async Maker.Shares
```

Add liquidity to OAMM 

## Function `removeLiquidity`
``` motoko no-repl
func removeLiquidity(_maker : Principal, _shares : ?Nat) : async (value0 : Nat, value1 : Nat)
```

Remove liquidity from OAMM

## Function `cancel`
``` motoko no-repl
func cancel(_pair : Principal, _txid : ICDex.Txid) : async ()
```

cancel order

## Function `fallbackFromPair`
``` motoko no-repl
func fallbackFromPair(_pair : Principal) : async (value0 : Nat, value1 : Nat)
```

fallback blocked funds from Pair

## Function `fallbackFromMaker`
``` motoko no-repl
func fallbackFromMaker(_maker : Principal) : async (value0 : Nat, value1 : Nat)
```

fallback blocked funds from Maker

## Function `depositToPair`
``` motoko no-repl
func depositToPair(_pair : Principal, _value0 : ?Nat, _value1 : ?Nat) : async ()
```

Deposit funds from Trader to Pair

## Function `withdrawFromPair`
``` motoko no-repl
func withdrawFromPair(_pair : Principal) : async ()
```

Withdraw funds from Pair to Trader.  
Note: This only withdraws the available funds, if you want to withdraw all the funds, execute the `cancelAll()` method first.

## Function `version`
``` motoko no-repl
func version() : async Text
```


## Function `pause`
``` motoko no-repl
func pause(_pause : Bool) : async ()
```

Pause or enable this Canister.

## Function `isPaused`
``` motoko no-repl
func isPaused() : async Bool
```

Returns whether to pause or not.

## Function `init`
``` motoko no-repl
func init() : async ()
```

Re-acquire trading pair information.  
The initialization can be repeated.

## Function `setWhitelist`
``` motoko no-repl
func setWhitelist(_pair : Principal) : async Bool
```

Add a whitelist trading pair (only these pairs are allowed to be traded)

## Function `removeWhitelist`
``` motoko no-repl
func removeWhitelist(_pair : Principal) : async Bool
```

Remove a whitelist trading pair

## Function `getWhitelist`
``` motoko no-repl
func getWhitelist() : async [Principal]
```

Return whitelist trading pairs

## Function `setOperator`
``` motoko no-repl
func setOperator(_operator : Principal) : async Bool
```

Add an operator (he can only submit trade orders, not withdraw funds).

## Function `removeOperator`
``` motoko no-repl
func removeOperator(_operator : Principal) : async Bool
```

Remove an operator

## Function `getOperators`
``` motoko no-repl
func getOperators() : async [Principal]
```

Return operators

## Function `getBalances`
``` motoko no-repl
func getBalances() : async [{ pair : Principal; tokens : (Text, Text); traderBalances : (Nat, Nat); keptInPairBalances : ICDex.KeepingBalance }]
```

Return trader's balances.  
Tip: It is more efficient to query directly using the query method of the ICDex trading pair and Tokens.

## Function `cancelAll`
``` motoko no-repl
func cancelAll(_pair : Principal) : async ()
```

cancel all orders

## Function `withdraw`
``` motoko no-repl
func withdraw(_token : Principal, _to : ICRC1.Account, _value : Nat) : async ()
```

Withdraw
Note: To withdraw the funds being traded, you need to first call `withdrawFromPair()`.

## Function `drc207`
``` motoko no-repl
func drc207() : async DRC207.DRC207Support
```

DRC207 support

## Function `canister_status`
``` motoko no-repl
func canister_status() : async DRC207.canister_status
```

Return canister_status (Need to add this CanisterId as its own controller)

## Function `wallet_receive`
``` motoko no-repl
func wallet_receive() : async ()
```

Receive cycles
