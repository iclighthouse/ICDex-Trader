# An guide for SNS treasury to add liquidity to ICDex

## ICDex-Trader: A decentralized trader for SNS Treasury

SNS Treasury funds participate in ICDex trading or provide liquidity in a non-custodial manner, maintaining decentralization. Agent moral hazard can be effectively mitigated by transferring SNS Treasury funds to Trader Canister and assigning a non-drawing operator to manage them. 

## 1. Deploy Trader Canister

```
dfx canister --network ic create Trader --controller __your principal__
dfx build --network ic Trader
dfx canister --network ic install Trader --argument '(principal "__trading_pair_canister-id__")'
```
Or (Your account needs to have a sufficient ICL balance): 
```
dfx canister --network ic call __ICL_canister_id__ icrc2_approve '(record{ spender = record{owner = principal "ibnyg-oiaaa-aaaar-qaa3q-cai"; subaccount = null }; amount = 10_000_000_000: nat })'
dfx canister --network ic call ibnyg-oiaaa-aaaar-qaa3q-cai create '("Trader-1", principal "__trading_pair_canister-id__", null, null)'
```

## 2. (Optional) Adding an operator
```
dfx canister --network ic call Trader setOperator '(principal "__operator_principal__")'
```
Query operators
```
dfx canister --network ic call Trader getOperators
```

## 3. Register Trader as a dApp canister through SNS proposal.

## 4. SNS Treasury funds transferred to the Trader canister.

## 5. The operator adds liquidity or creates a buy wall.

If no operators are set up, the SNS proposal can call them directly.

(The unit of `amount` is the smallest_unit of token)

Sends funds to Pair canister
```
dfx canister --network ic call Trader depositToPair '(principal "__trading_pair_canister-id__", null, null)'
```
Adds liquidity
```
dfx canister --network ic call Trader addLiquidity '(principal "__maker_pool_canister-id__", __amount-of-Token0__, __amount-of-Token1__)'
```
Creates a buy wall
```
dfx canister --network ic call Trader buyWall '(principal "__trading_pair_canister-id__", vec{ __Example:record{price = 2.1; quantity = 1000_000_000}; record{price = 3.5; quantity = 500_000_000}__ })'
```

Removes liquidity
```
dfx canister --network ic call Trader removeLiquidity '(principal "__trading_pair_canister-id__", null)'
```

Cancel all orders
```
dfx canister --network ic call Trader cancelAll '(principal "__trading_pair_canister-id__")'
```

Withdraws funds from Pair canister to Maker canister
```
dfx canister --network ic call Trader withdrawFromPair '(principal "__trading_pair_canister-id__")'
```

## 6. Sends funds from Trader canister back to SNS Treasury through SNS proposal.
```
withdraw : shared ( token: Principal, to: Account, value: Nat ) -> async ();
```
