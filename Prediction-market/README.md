## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


  FtsoV2PriceFeed deployed at: 0x9035681200aAA554E61B2D13319991c5ABCB92C8
  MarketFactory deployed at: 0x8dA4b77EC801b547b44D6eDe559c1005F2fE7917

  rpc: https://coston2.enosys.global/ext/C/rpc
  private: fb9bbe44182c19ddfc3a8ad89dfc86b9e4e18c91d40256af949fc6ffbef78b8a

  Crypto pool 1: 0x20d39847f01386820e30bc0af5e5733147e363dc //BTC
  Crypto pool 2: 0x3ede4e9ebc046eefe822189573d44e378577ef10 //FLR
  Crypto pool 3: 0x6ac56d3767009f42d3ab849fdb1b088d1a9143fc //DOGE