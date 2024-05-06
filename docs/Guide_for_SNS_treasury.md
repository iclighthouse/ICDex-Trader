# A guide for SNS treasury to add liquidity to ICDex

## ICDex-Trader: A decentralized trader for SNS Treasury

SNS Treasury funds participate in ICDex trading or provide liquidity in a non-custodial manner, maintaining decentralization. Agent moral hazard can be effectively mitigated by transferring SNS Treasury funds to Trader Canister and assigning a non-drawing operator to manage them. 

## 1. Deploy a trader canister

```
dfx canister --network ic create Trader --controller __your principal__
dfx build --network ic Trader
dfx canister --network ic install Trader --argument '(principal "__trading_pair_canister-id__", opt principal "__DAO_governance_canister-id__")'
```
Or (Your account needs to have a sufficient ICL balance, default TRADER_CREATION_FEE is 5 ICL): 
```
dfx canister --network ic call hhaaz-2aaaa-aaaaq-aacla-cai icrc2_approve '(record{ spender = record{owner = principal "ibnyg-oiaaa-aaaar-qaa3q-cai"; subaccount = null }; amount = 10_000_000_000: nat })'
dfx canister --network ic call ibnyg-oiaaa-aaaar-qaa3q-cai create '("Trader-1", principal "__trading_pair_canister-id__", opt principal "__DAO_governance_canister-id__", null)'
```
Notes:
- Remember to monitor Trader cansiter's cycles balance and top it up in a timely manner.

## 2. (Optional) Adding an operator
```
dfx canister --network ic call __trader_canister_id__ setOperator '(principal "__operator_principal__")'
```
Query operators
```
dfx canister --network ic call __trader_canister_id__ getOperators
```

## 3. Register Trader as a dApp canister through SNS proposal.

- Add SNS Root canister-id as one of Trader's controllers.
```
dfx canister --network ic call aaaaa-aa update_settings '(record{ canister_id = principal "__trader_canister_id__"; settings = record{ controllers = opt vec{principal "__original_owner__"; principal "__SNS_Root_canister-id__"} } })'
```
- Make a #RegisterDappCanisters proposal to add Trader to the SNS DAO.

## 4. SNS Treasury funds transferred to the Trader canister.

- Make a #TransferSnsTreasuryFunds proposal to transfer small amount of funds (from_treasury = 1-ICP; 2-SNSLedger) from the treasury into trader_canister_id and try to make another proposal to call Trade.withdraw() in step 6 to check if the token can be successfully transferred back to the treasury.
- Make a new #TransferSnsTreasuryFunds proposal to transfer funds used to provide liquidity from the treasury into trader_canister_id.

## 5. The operator adds liquidity or creates a buy wall.

If no operators are set up, the SNS proposal can call them directly.

Notes:

- `__trading_pair_canister-id__` is SNS token trading pair on ICDex.
- `__trader_canister_id__` is trader canister-id you deployed.
- The unit of `amount` is the smallest_unit of token.
- An additional 2x token fee must be retained in the balance of Trader, and the entire amount cannot be used for placing orders.
- When the operator calls `order()` or `buyWall()`, he is using funds that have been kept in the Pair canister by the Trader canister, so `depositToPair()` has to be called first, followed by `order()` or `buyWall()`. If you want to get the funds back into the Trader canister, you need to execute `withdrawFundsFromPair()`.
- When the operator calls `addLiquidity()`, the funds in Trader canister are used. If there are insufficient funds in the Trader canister, it is necessary to execute `withdrawFundsFromPair()` and withdraw the funds kept in the Pair canister to the Trader canister.

Operations:

- Adds liquidity  
Notes: 
- First create a public OAMM pool via https://iclight.io/icdex/pools and make it vip-maker, then you can get public OAMM pool canister-id.
- The OAMM pool must be initialised before this operation can be performed successfully. The initialisation is done by the creator of the OAMM pool adding the first liquidity.
```
dfx canister --network ic call __trader_canister_id__ addLiquidity '(principal "__public_OAMM_pool_canister-id__", __amount-of-Token0__ : nat, __amount-of-Token1__ : nat)'
```

- Removes liquidity
```
dfx canister --network ic call __trader_canister_id__ removeLiquidity '(principal "__trading_pair_canister-id__", null)'
```

- Sends funds to Pair canister (If you are about to call `order()` or `buyWall()`).
```
dfx canister --network ic call __trader_canister_id__ depositToPair '(principal "__trading_pair_canister-id__", __token0_amount__, __token1_amount__)'
```

- Creates a buy wall  
Notes: 
    `price` : float, is the human-readable price, i.e. the price displayed on the UI of the trading pair;  
    `quantity` : nat, is the AMOUNT (its unit is the smallest_unit) of the SNS token for the order.
```
dfx canister --network ic call __trader_canister_id__ buyWall '(principal "__trading_pair_canister-id__", vec{ __Example: record{price = 2.1 : float; quantity = 1000_000_000 : nat}; record{price = 3.5 : float; quantity = 500_000_000 : nat}__ })'
```

- Creates a #LMT order  
Notes: 
    `pair` : principal, Canister-id of the pair.  
    `side` : variant, Side of the order, its value is #Buy or #Sell.  
    `price` : float, is the human-readable price, i.e. the price displayed on the UI of the trading pair;  
    `quantity` : nat, is the AMOUNT (its unit is the smallest_unit) of the SNS token for the order. It MUST be an integer multiple of UNIT_SIZE. Note: An additional 2x token fee must be retained in the balance. 
```
dfx canister --network ic call __trader_canister_id__ order '(principal "__trading_pair_canister-id__", variant{ __Buy/Sell__ }, 2.1 : float, 1000_000_000 : nat)'
```

- Cancel all orders
```
dfx canister --network ic call __trader_canister_id__ cancelAll '(principal "__trading_pair_canister-id__")'
```

- Withdraws funds from Pair canister to Trader canister
```
dfx canister --network ic call __trader_canister_id__ withdrawFundsFromPair '(principal "__trading_pair_canister-id__", opt __token0_amount__ : opt nat, opt __token1_amount__ : opt nat)'
```
or (Trader v0.5.4)
```
dfx canister --network ic call __trader_canister_id__ withdrawFromPair '(principal "__trading_pair_canister-id__")'
```

## 6. Sends funds from Trader canister back to SNS Treasury through SNS proposal.

Make an #AddGenericNervousSystemFunction proposal to add Trader's withdraw() method. (Just add it once).

Make an #ExecuteGenericNervousSystemFunction proposal to execute Trader's withdraw() method.
```
withdraw : shared ( token: Principal, to: Account, value: Nat ) -> async ();
```
Notes:
- The treasury account of ICP is `{ owner = principal "__SNS_Governance_canister_id__"; subaccount = null }`.
- The treasury account of SNS ledger is `{ owner = principal "__SNS_Governance_canister_id__"; subaccount = opt blob "__Token_treasury__" }`, The `__Token_treasury__` should be gotten from earlier SNS mint records. 
- Only ICP and SNS ledger tokens (1-ICP; 2-SNSLedger) can be sent to the SNS Treasury, other tokens sent to the Treasury may not be withdrawn and lost.
