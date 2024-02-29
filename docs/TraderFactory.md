# TraderFactory
* Module     : TraderFactory.mo
 * Author     : ICLighthouse Team
 * License    : GNU General Public License v3.0
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/ICDex-Trader

## Function `ICLWithdraw`
``` motoko no-repl
func ICLWithdraw(_to : ICRC1.Account, _amount : Nat) : async ()
```

Admin: Withdraw ICL

## Function `config`
``` motoko no-repl
func config(_args : { BLACKHOLE : ?Principal; SYSTOKEN : ?Principal; SYSTOKEN_FEE : ?Nat; TRADER_CREATION_FEE : ?Nat }) : async ()
```

Admin: Config

## Function `getConfig`
``` motoko no-repl
func getConfig() : async { BLACKHOLE : Principal; SYSTOKEN : Principal; SYSTOKEN_FEE : Nat; TRADER_CREATION_FEE : Nat }
```

Returns configurations

## Function `create`
``` motoko no-repl
func create(_name : Text, _initPair : Principal, _traderOwner : ?Principal, _sa : ?[Nat8]) : async ?Principal
```

Create a trader.  
Creating a Trader Canister requires payment of `TRADER_CREATION_FEE` ICLs, which are used to add an initial 0.5 T Cycles to the canister.  
Note: The `controller` of Trader Canister is the creator, and the Cycles balance of the canister needs to be monitored and topped up by the creator.  
WARNING: If the Cycles balance of Trader Canister is insufficient, it may result in the deletion of the canister, which will result in the loss of all assets in the canister. The creator needs to monitor the Cycles balance of the canister at all times!

## Function `modifyTrader`
``` motoko no-repl
func modifyTrader(_trader : Principal, _name : ?Text, _newOwner : ?AccountId, _sa : ?[Nat8]) : async Bool
```

Modify the Trader.

## Function `deleteTrader`
``` motoko no-repl
func deleteTrader(_trader : Principal, _sa : ?[Nat8]) : async Bool
```

Delete from the Trader list of the 'user' account. (Note: not deleting Trader Canister).

## Function `getTraders`
``` motoko no-repl
func getTraders(_user : AccountId) : async ?[Trader]
```

get user's Traders

## Function `getMemory`
``` motoko no-repl
func getMemory() : async (Nat, Nat, Nat)
```

Admin: Canister memory

## Function `cyclesWithdraw`
``` motoko no-repl
func cyclesWithdraw(_wallet : Principal, _amount : Nat) : async ()
```

Admin: Cycles withdraw

## Function `drc207`
``` motoko no-repl
func drc207() : async DRC207.DRC207Support
```

DRC207 support

## Function `canister_status`
``` motoko no-repl
func canister_status() : async DRC207.canister_status
```

canister_status

## Function `wallet_receive`
``` motoko no-repl
func wallet_receive() : async ()
```

receive cycles
