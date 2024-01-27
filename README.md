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

1. Create a Trader canister
2. Configure whitelisted trading pairs
3. Configure operators
4. Send token0 and token1 to Trader Canister
5. Enjoy trading
6. Withdraw token0 and token1

## Note:

The `controller` of Trader Canister is the creator, and the Cycles balance of the canister needs to be monitored and topped up by the creator.

**WARNING**: If the Cycles balance of Trader Canister is insufficient, it may result in the deletion of the canister, which will result in the loss of all assets in the canister. The creator needs to monitor the Cycles balance of the canister at all times!

## Docs

- [/docs/Trader.md](./docs/Trader.md)
- [/docs/TraderFactory.md](./docs/TraderFactory.md)

### Create a Trader canister
```
dfx canister --network ic call TraderFactory create '("Trader-1", principal "xjazg-fiaaa-aaaar-qacrq-cai", null, null)'
```

## Canisters

**Tools & Dependencies**

- dfx: 0.15.3 (https://github.com/dfinity/sdk/releases/tag/0.15.3)
    - moc: 0.10.3 
- vessel: 0.7.0 (https://github.com/dfinity/vessel/releases/tag/v0.7.0)

**Trader Factory**

- Canister-id: ibnyg-oiaaa-aaaar-qaa3q-cai (Mainnet)

**Trader Example**

- Canister-id: cirzd-3aaaa-aaaak-afk2q-cai (Test)
- Module hash: a139d40b03a3bf2e13d4560fdad79997e0ff31fab843a46c3824f207f6184fe1
- Version: 0.5.0
- Build: {
    "args": "--compacting-gc"
}

## Disclaimer

ICDex-Trader is an open source trading tool for technical reference only. Use it only after you understand the technical background and risks involved, and you need to bear all the consequences resulting from the use of this tool.