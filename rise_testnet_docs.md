# About RISE
RISE is a next-generation Ethereum Layer 2 blockchain redefining performance with infinite speed—delivering instant transaction confirmation at unprecedented scale, all while upholding Ethereum’s core principle of decentralization. Its unique architecture enables 10-millisecond latency, making it the fastest blockchain.

RISE is also on course to exceed 100,000 transactions per second throughput capacity, enabling it to support millions of users simultaneously.

By eliminating long standing barriers to blockchain adoption, RISE offers a radically improved experience for both developers and users, and unlocks a new generation of crypto applications.

# RISE Network Testnet - Complete Documentation

## Table of Contents
1. [Testnet Overview](#testnet-overview)
2. [Network Details](#network-details)
3. [Contract Addresses](#contract-addresses)
4. [Deployed Tokens](#deployed-tokens)
5. [RISE System Contracts](#rise-system-contracts)
6. [Internal Oracles](#internal-oracles)

---

## Testnet Overview

The RISE internal testnet is ready for developers to start building high performance applications. The RISE team is excited to welcome builders to get involved and join the Gigagas Era. Builders can contact the team via the builders [form](https://docs.risechain.com/build-on-rise/builder-community.html).

[Launch Testnet Portal](https://portal.risechain.com/)

### Quick Navigation

- [**Network Details**](https://docs.risechain.com/rise-testnet/network-details) - Connect to RISE Testnet with RPC endpoints, chain ID, and explorer links
- [**Contract Addresses**](https://docs.risechain.com/rise-testnet/contract-addresses) - Key system contracts and predeploys for testnet development
- [**Testnet Tokens**](https://docs.risechain.com/rise-testnet/testnet-tokens) - Test tokens available for development on RISE Testnet

---

## Network Details

This page provides all the necessary details to connect to the RISE Testnet network.

### Network Configuration

Use these parameters to add RISE Testnet to your wallet or development environment:

| Parameter | Value |
| --- | --- |
| Network Name | `RISE Testnet` |
| Chain ID | `11155931` |
| Currency Symbol | `ETH` |
| Block Explorer URL | [https://explorer.testnet.riselabs.xyz](https://explorer.testnet.riselabs.xyz/) |

### RPC Endpoints

| Endpoint Type | URL |
| --- | --- |
| HTTPS RPC URL | `https://testnet.riselabs.xyz` |
| WebSocket URL | `wss://testnet.riselabs.xyz/ws` |

### Useful Links

| Resource | URL |
| --- | --- |
| Explorer | [https://explorer.testnet.riselabs.xyz](https://explorer.testnet.riselabs.xyz/) |
| Bridge UI | [https://bridge-ui.testnet.riselabs.xyz](https://bridge-ui.testnet.riselabs.xyz/) |
| Network Status | [https://status.testnet.risechain.com](https://status.testnet.risechain.com/) |
| Faucet | [https://faucet.testnet.riselabs.xyz](https://faucet.testnet.riselabs.xyz/) |
| Testnet Portal | [https://portal.testnet.riselabs.xyz](https://portal.testnet.riselabs.xyz/) |

### Wallet Configuration

#### MetaMask

To add RISE Testnet to MetaMask:

1. Open MetaMask and click on the network selector at the top
2. Click "Add Network"
3. Click "Add a network manually"
4. Fill in the following details:
   - Network Name: `RISE Testnet`
   - New RPC URL: `https://testnet.riselabs.xyz`
   - Chain ID: `11155931`
   - Currency Symbol: `ETH`
   - Block Explorer URL: `https://explorer.testnet.riselabs.xyz`
5. Click "Save"

#### Using with Development Tools

##### Hardhat Configuration

```javascript
// hardhat.config.js
module.exports = {
  networks: {
    riseTestnet: {
      url: "https://testnet.riselabs.xyz",
      chainId: 11155931,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    }
  }
};
```

##### Foundry Configuration

```toml
# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
rise_testnet = "https://testnet.riselabs.xyz"

[etherscan]
rise_testnet = { key = "", url = "https://explorer.testnet.riselabs.xyz/api" }
```

### Getting Testnet ETH

You can obtain testnet ETH from the official RISE faucet:

1. Visit [https://faucet.testnet.riselabs.xyz](https://faucet.testnet.riselabs.xyz/)
2. Connect your wallet or enter your wallet address
3. Complete any verification steps
4. Receive testnet ETH directly to your wallet

For other testnet tokens, visit the Testnet Portal at [https://portal.testnet.riselabs.xyz](https://portal.testnet.riselabs.xyz/).

---

## Contract Addresses

This page provides a reference for the early-stage contract addresses on RISE Testnet.

### Pre-deployed Early-stage Contracts

These contracts are pre-deployed and available from genesis.

| Contract Name | Description | Address |
| --- | --- | --- |
| Create2Deployer | Helper for CREATE2 opcode usage | [`0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2`](https://explorer.testnet.riselabs.xyz/address/0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2) |
| DeterministicDeploymentProxy | Integrated with Foundry for deterministic deployments | [`0x4e59b44847b379578588920ca78fbf26c0b4956c`](https://explorer.testnet.riselabs.xyz/address/0x4e59b44847b379578588920ca78fbf26c0b4956c) |
| MultiCall3 | Allows bundling multiple transactions | [`0xcA11bde05977b3631167028862bE2a173976CA11`](https://explorer.testnet.riselabs.xyz/address/0xcA11bde05977b3631167028862bE2a173976CA11) |
| GnosisSafe (v1.3.0) | Multisignature wallet | [`0x69f4D1788e39c87893C980c06EdF4b7f686e2938`](https://explorer.testnet.riselabs.xyz/address/0x69f4D1788e39c87893C980c06EdF4b7f686e2938) |
| GnosisSafeL2 (v1.3.0) | Events-based implementation of GnosisSafe | [`0xfb1bffC9d739B8D520DaF37dF666da4C687191EA`](https://explorer.testnet.riselabs.xyz/address/0xfb1bffC9d739B8D520DaF37dF666da4C687191EA) |
| MultiSendCallOnly (v1.3.0) | Batches multiple transactions (calls only) | [`0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B`](https://explorer.testnet.riselabs.xyz/address/0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B) |
| MultiSend (v1.3.0) | Batches multiple transactions | [`0x998739BFdAAdde7C933B942a68053933098f9EDa`](https://explorer.testnet.riselabs.xyz/address/0x998739BFdAAdde7C933B942a68053933098f9EDa) |
| Permit2 | Next-generation token approval system | [`0x000000000022D473030F116dDEE9F6B43aC78BA3`](https://explorer.testnet.riselabs.xyz/address/0x000000000022D473030F116dDEE9F6B43aC78BA3) |
| EntryPoint (v0.7.0) | ERC-4337 entry point for account abstraction | [`0x0000000071727De22E5E9d8BAf0edAc6f37da032`](https://explorer.testnet.riselabs.xyz/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032) |
| SenderCreator (v0.7.0) | Helper for EntryPoint | [`0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C`](https://explorer.testnet.riselabs.xyz/address/0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C) |
| WETH | Wrapped ETH | [`0x4200000000000000000000000000000000000006`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000006) |

For information about system contracts (L1 and L2), see the [RISE System Contracts](https://docs.risechain.com/rise-testnet/rise-contracts.html) page.

---

## Deployed Tokens

Below is a list of ERC20 tokens deployed on RISE Testnet (Chain ID: 11155931).

### Token Purpose

These tokens have been minted purely for testing purposes, and in particular so common tokens can be shared across apps on the testnet. These tokens hold no value.

You may acquire tokens via the faucet on the testnet portal: [https://portal.testnet.riselabs.xyz](https://portal.testnet.riselabs.xyz/)

If you need an excessive amount of tokens, ask the team, they will happily provide them!

### Token Details

| Name | Symbol | Decimals | Contract Address |
| --- | --- | --- | --- |
| Wrapped ETH | WETH | 18 | [0x4200000000000000000000000000000000000006](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000006) |
| USD Coin | USDC | 6 | [0x8a93d247134d91e0de6f96547cb0204e5be8e5d8](https://explorer.testnet.riselabs.xyz/address/0x8a93d247134d91e0de6f96547cb0204e5be8e5d8) |
| Tether USD | USDT | 8 | [0x40918ba7f132e0acba2ce4de4c4baf9bd2d7d849](https://explorer.testnet.riselabs.xyz/address/0x40918ba7f132e0acba2ce4de4c4baf9bd2d7d849) |
| Wrapped Bitcoin | WBTC | 18 | [0xf32d39ff9f6aa7a7a64d7a4f00a54826ef791a55](https://explorer.testnet.riselabs.xyz/address/0xf32d39ff9f6aa7a7a64d7a4f00a54826ef791a55) |
| RISE | RISE | 18 | [0xd6e1afe5ca8d00a2efc01b89997abe2de47fdfaf](https://explorer.testnet.riselabs.xyz/address/0xd6e1afe5ca8d00a2efc01b89997abe2de47fdfaf) |
| Mog Coin | MOG | 18 | [0x99dbe4aea58e518c50a1c04ae9b48c9f6354612f](https://explorer.testnet.riselabs.xyz/address/0x99dbe4aea58e518c50a1c04ae9b48c9f6354612f) |
| Pepe | PEPE | 18 | [0x6f6f570f45833e249e27022648a26f4076f48f78](https://explorer.testnet.riselabs.xyz/address/0x6f6f570f45833e249e27022648a26f4076f48f78) |

### Contract Features

All tokens implement the following features:

- ERC20 standard functionality (transfer, approve, transferFrom)
- Custom decimals support (from 6 to 18)
- Minting capability (restricted to owner)
- Burning capability (anyone can burn their own tokens)

#### WETH Special Features

The WETH (Wrapped ETH) token at address `0x4200000000000000000000000000000000000006` is a special predeploy contract that provides the following additional functionality:

- Wrap ETH by sending ETH to the contract or calling the `deposit()` function
- Unwrap WETH by calling the `withdraw(uint)` function
- Standard ERC20 interface for wrapped ETH
- Compatible with DeFi protocols requiring ERC20 tokens

### Interacting with Tokens

You can interact with these tokens through:

- The RISE explorer: [https://explorer.testnet.riselabs.xyz/](https://explorer.testnet.riselabs.xyz/)
- Ethers.js or web3.js libraries
- Foundry tools like `cast` for command-line interactions

#### Example Cast Commands

```bash
# Check token balance
cast call <TOKEN_ADDRESS> "balanceOf(address)(uint256)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# Transfer tokens
cast send <TOKEN_ADDRESS> "transfer(address,uint256)(bool)" <RECIPIENT_ADDRESS> <AMOUNT> --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Check token allowance
cast call <TOKEN_ADDRESS> "allowance(address,address)(uint256)" <OWNER_ADDRESS> <SPENDER_ADDRESS> --rpc-url $RPC_URL

# Approve tokens
cast send <TOKEN_ADDRESS> "approve(address,uint256)(bool)" <SPENDER_ADDRESS> <AMOUNT> --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Wrap ETH (WETH specific)
cast send 0x4200000000000000000000000000000000000006 "deposit()" --value <AMOUNT_WEI> --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Unwrap WETH (WETH specific)
cast send 0x4200000000000000000000000000000000000006 "withdraw(uint256)" <AMOUNT_WEI> --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

**Note:** All tokens are verified on the RISE blockchain explorer and their source code can be viewed there.

---

## RISE System Contracts

This page provides a reference for all the system contract addresses on RISE Testnet.

### Layer 1 (Sepolia) Contracts

These contracts are deployed on the Sepolia Ethereum testnet and handle the communication between L1 and RISE Testnet.

| Contract Name | Description | Address |
| --- | --- | --- |
| AnchorStateRegistryProxy | Stores state roots of the L2 chain | [`0x5ca4bfe196aa3a1ed9f8522f224ec5a7a7277d5a`](https://sepolia.etherscan.io/address/0x5ca4bfe196aa3a1ed9f8522f224ec5a7a7277d5a) |
| BatchSubmitter | Submits batches of transactions | [`0x45Bd8Bc15FfC21315F8a1e3cdF67c73b487768e8`](https://sepolia.etherscan.io/address/0x45Bd8Bc15FfC21315F8a1e3cdF67c73b487768e8) |
| Challenger | Handles challenges to invalid state transitions | [`0xb49077bAd82968A1119B9e717DBCFb9303E91f0F`](https://sepolia.etherscan.io/address/0xb49077bAd82968A1119B9e717DBCFb9303E91f0F) |
| DelayedWETHProxy | Wrapped ETH with withdrawal delay | [`0x3547e7b4af6f0a2d626c72fd7066b939e8489450`](https://sepolia.etherscan.io/address/0x3547e7b4af6f0a2d626c72fd7066b939e8489450) |
| DisputeGameFactoryProxy | Creates dispute games for challenging invalid state | [`0x790e18c477bfb49c784ca0aed244648166a5022b`](https://sepolia.etherscan.io/address/0x790e18c477bfb49c784ca0aed244648166a5022b) |
| L1CrossDomainMessengerProxy | Handles message passing from L1 to L2 | [`0xcc1c4f905d0199419719f3c3210f43bb990953fc`](https://sepolia.etherscan.io/address/0xcc1c4f905d0199419719f3c3210f43bb990953fc) |
| L1ERC721BridgeProxy | Bridge for NFTs between L1 and L2 | [`0xfc197687ac16218bad8589420978f40097c42a44`](https://sepolia.etherscan.io/address/0xfc197687ac16218bad8589420978f40097c42a44) |
| L1StandardBridgeProxy | Bridge for ETH and ERC20 tokens | [`0xe9a531a5d7253c9823c74af155d22fe14568b610`](https://sepolia.etherscan.io/address/0xe9a531a5d7253c9823c74af155d22fe14568b610) |
| MIPS | MIPS verification for fault proofs | [`0xaa33f21ada0dc6c40a33d94935de11a0b754fec4`](https://sepolia.etherscan.io/address/0xaa33f21ada0dc6c40a33d94935de11a0b754fec4) |
| OptimismMintableERC20FactoryProxy | Factory for creating bridged tokens on L2 | [`0xb9b92645886135838abd71a1bbf55e34260dabf6`](https://sepolia.etherscan.io/address/0xb9b92645886135838abd71a1bbf55e34260dabf6) |
| OptimismPortalProxy | Main entry point for L1 to L2 transactions | [`0x77cce5cd26c75140c35c38104d0c655c7a786acb`](https://sepolia.etherscan.io/address/0x77cce5cd26c75140c35c38104d0c655c7a786acb) |
| PreimageOracle | Stores preimages for fault proofs | [`0xca8f0068cd4894e1c972701ce8da7f934444717d`](https://sepolia.etherscan.io/address/0xca8f0068cd4894e1c972701ce8da7f934444717d) |
| Proposer | Proposes new L2 state roots | [`0x407379B3eBd88B4E92F8fF8930D244B592D65c06`](https://sepolia.etherscan.io/address/0x407379B3eBd88B4E92F8fF8930D244B592D65c06) |
| SystemConfigProxy | Configuration for the RISE system | [`0x5088a091bd20343787c5afc95aa002d13d9f3535`](https://sepolia.etherscan.io/address/0x5088a091bd20343787c5afc95aa002d13d9f3535) |
| UnsafeBlockSigner | Signs blocks in development mode | [`0x8d451372bAdE8723F45BF5134550017F639dFb11`](https://sepolia.etherscan.io/address/0x8d451372bAdE8723F45BF5134550017F639dFb11) |

### Layer 2 (RISE Testnet) Contracts

These are the predeploy contracts on RISE Testnet (L2).

| Contract Name | Description | Address |
| --- | --- | --- |
| L2ToL1MessagePasser | Initiates withdrawals to L1 | [`0x4200000000000000000000000000000000000016`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000016) |
| L2CrossDomainMessenger | Handles message passing from L2 to L1 | [`0x4200000000000000000000000000000000000007`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000007) |
| L2StandardBridge | L2 side of the token bridge | [`0x4200000000000000000000000000000000000010`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000010) |
| L2ERC721Bridge | L2 side of the NFT bridge | [`0x4200000000000000000000000000000000000014`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000014) |
| SequencerFeeVault | Collects sequencer fees | [`0x4200000000000000000000000000000000000011`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000011) |
| OptimismMintableERC20Factory | Creates standard bridged tokens | [`0x4200000000000000000000000000000000000012`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000012) |
| OptimismMintableERC721Factory | Creates bridged NFTs | [`0x4200000000000000000000000000000000000017`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000017) |
| L1Block | Provides L1 block information | [`0x4200000000000000000000000000000000000015`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000015) |
| GasPriceOracle | Provides gas price information | [`0x420000000000000000000000000000000000000F`](https://explorer.testnet.riselabs.xyz/address/0x420000000000000000000000000000000000000F) |
| ProxyAdmin | Admin for proxy contracts | [`0x4200000000000000000000000000000000000018`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000018) |
| BaseFeeVault | Collects base fee | [`0x4200000000000000000000000000000000000019`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000019) |
| L1FeeVault | Collects L1 data fees | [`0x420000000000000000000000000000000000001A`](https://explorer.testnet.riselabs.xyz/address/0x420000000000000000000000000000000000001A) |
| GovernanceToken | RISE governance token | [`0x4200000000000000000000000000000000000042`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000042) |
| SchemaRegistry | EAS schema registry | [`0x4200000000000000000000000000000000000020`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000020) |
| EAS | Ethereum Attestation Service | [`0x4200000000000000000000000000000000000021`](https://explorer.testnet.riselabs.xyz/address/0x4200000000000000000000000000000000000021) |

### Using System Contracts

These system contracts follow similar interfaces to other Ethereum Layer 2 solutions. You can interact with these contracts using standard Ethereum libraries and tools.

#### Example: Bridging ETH from L1 to L2

```solidity
// On Sepolia (L1)
IL1StandardBridge bridge = IL1StandardBridge(0xe9a531a5d7253c9823c74af155d22fe14568b610);

// Deposit ETH to L2
bridge.depositETH{value: amount}(
    minGasLimit,
    emptyBytes  // No additional data
);
```

#### Example: Sending a Message from L2 to L1

```solidity
// On RISE Testnet (L2)
IL2CrossDomainMessenger messenger = IL2CrossDomainMessenger(0x4200000000000000000000000000000000000007);

// Send message to L1
messenger.sendMessage(
    targetL1Address,
    abi.encodeWithSignature("someFunction(uint256)", value),
    minGasLimit
);
```

For detailed information about how to use these contracts, refer to the [RISE Developer Documentation](https://docs.risechain.com/build-on-rise/developer-resources.html).

---

## Internal Oracles

We have deployed internal oracles for the following assets:

| Ticker | Address | Link |
| --- | --- | --- |
| ETH | `0x7114E2537851e727678DE5a96C8eE5d0Ca14f03D` | [View on Explorer](https://explorer.testnet.riselabs.xyz/address/0x7114E2537851e727678DE5a96C8eE5d0Ca14f03D) |
| USDC | `0x50524C5bDa18aE25C600a8b81449B9CeAeB50471` | [View on Explorer](https://explorer.testnet.riselabs.xyz/address/0x50524C5bDa18aE25C600a8b81449B9CeAeB50471) |
| USDT | `0x9190159b1bb78482Dca6EBaDf03ab744de0c0197` | [View on Explorer](https://explorer.testnet.riselabs.xyz/address/0x9190159b1bb78482Dca6EBaDf03ab744de0c0197) |
| BTC | `0xadDAEd879D549E5DBfaf3e35470C20D8C50fDed0` | [View on Explorer](https://explorer.testnet.riselabs.xyz/address/0xadDAEd879D549E5DBfaf3e35470C20D8C50fDed0) |

**Note:** The oracle price for each asset can be fetched by calling the `latest_answer` function on the respective oracle address.

### Oracle Providers

Check out the [Oracle Providers](https://docs.risechain.com/build-on-rise/developer-resources.html#oracles) for a list of external Oracle providers.

---

*This documentation is extracted from the official RISE Network documentation available at https://docs.risechain.com/rise-testnet/*
