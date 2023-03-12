# ICDex-Trader

This is a smart contract for agents to trade on ICDex. There are several main possible application scenarios.
- SNS treasury funds participate in ICDex trading in an uncustodied way by transferring SNS treasury funds to this canister and appointing an operator, who has no withdrawal rights.
- A capital party delegates a trader to trade on ICDex in an uncustodial way without having to send the funds to him.
- It provides support for quantitative trading, decentralized fund management.

## Guide

1. Deploy Trader Canister
2. Configure whitelisted trading pairs
3. Configure operators
4. Send token0 and token1 to Trader Canister
5. Enjoy trading
6. Withdraw token0 and token1

## Core interface

### Place an order
```
order: (principal, variant { Buy; Sell; }, float64, nat) -> (TradingResult);
```
Parameters:
- _pair:       Canister-id of the pair.
- _side:       Side of the order, its value is #Buy or #Sell.
- _price:      Human-readable Price, e.g. SNS1/ICP = 45.00, expressed as how many `base_unit`s (e.g. ICPs) of token1 can be exchanged for 1 `base_unit`s (e.g. SNS1s) of token0. `Price in integer representation = _price * 10**token1_decimals / 10**token0_decimals * UNIT_SIZE`
- _quantity:   Quantity (smallest unit) of token0 to be traded for the order. It MUST be an integer multiple of `UNIT_SIZE`.

Example: Purchase 2 SNS1s at 45.00 via SNS1/ICP pair.
```
order(Principal.fromText("32fn4-qqaaa-aaaak-ad65a-cai"), #Buy, 45.00, 200000000)
```