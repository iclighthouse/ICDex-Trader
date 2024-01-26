# ICDex-Trader

This is a smart contract for agents to trade on ICDex. There are several main possible application scenarios.

- **A decentralized trader for SNS Treasury**

SNS Treasury funds participate in ICDex trading or provide liquidity in a non-custodial manner, maintaining decentralization. Agent moral hazard can be effectively mitigated by transferring SNS Treasury funds to Trader Canister and assigning a non-drawing operator to manage them. 
[Guide](./docs/Guide_for_SNS_treasury.md)>>

- **Delegation to a third-party trader**

The owner of the funds delegates to a trader to trade on ICDex in a non-custodial manner without sending funds to him/her.

- **Quantitative trader**

Adds a non-withdrawal operator to the Trader, which acts as the account in the quantitative trading program that interacts with the Trader. This effectively prevents the quantitative trading program from losing funds due to private key leakage incidents.

- **Other**

## Guide

1. Deploy Trader Canister
2. Configure whitelisted trading pairs
3. Configure operators
4. Send token0 and token1 to Trader Canister
5. Enjoy trading
6. Withdraw token0 and token1

## Core interface

Doc: [/docs/Trader.md](./docs/Trader.md)

### Place an order
```
order: (principal, variant { Buy; Sell; }, float64, nat) -> (TradingResult);
```
Parameters:
- pair: Principal       Canister-id of the pair.
- side: {#Buy; #Sell}   Side of the order, its value is #Buy or #Sell.
- price: Float          Human-readable Price, e.g. SNS1/ICP = 45.00, expressed as how many `base_unit`s (e.g. ICPs) of token1 can be exchanged for 1 `base_unit`s (e.g. SNS1s) of token0. `Price in integer representation = _price * 10**token1_decimals / 10**token0_decimals * UNIT_SIZE`
- quantity: Nat         Quantity (smallest unit) of token0 to be traded for the order. It MUST be an integer multiple of `UNIT_SIZE`.

Example: Purchase 2 Token at 45.00 via Token/ICP pair.
```
dfx canister --network ic call Trader '(principal "__trading_pair_canister-id__", variant{ Buy }, 45.00: float64, 200_000_000: nat)'
```

## Canisters

**Tools & Dependencies**

- dfx: 0.15.3 (https://github.com/dfinity/sdk/releases/tag/0.15.3)
    - moc: 0.10.3 
- vessel: 0.7.0 (https://github.com/dfinity/vessel/releases/tag/v0.7.0)

**Testnet**

- Canister-id: cirzd-3aaaa-aaaak-afk2q-cai
- Module hash: c67842683c20a1ceaa89e448fc30aace5d2fdf3b0b9ac8f136eab0ea72fe399d
- Version: 0.4.0
- Build: {
    "args": "--compacting-gc"
}

## Disclaimer

ICDex-Trader is an open source trading tool for technical reference only. Use it only after you understand the technical background and risks involved, and you need to bear all the consequences resulting from the use of this tool.