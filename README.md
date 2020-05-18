# DMM Protocol

This repository contains the the Ethereum smart contracts for the DeFi Money Market Ecosystem.

### Installation

Firstly, clone the repository to your local machine by running 
`git clone https://github.com/defi-money-market-ecosystem/protocol.git`.

To install the repository's dependencies, run `npm install` (be sure to have already `cd`'ed into the cloned 
repository, first).

### Testing

Tests for the repository are generally broken up into categories and sub-categories for larger suites. To run all tests
at once, run `npm run test`. Doing so uses Open Zeppelin's testing SDK and libraries to spin up a private Ethereum 
chain using [Ganache](https://github.com/trufflesuite/ganache-cli) and runs simple setup for each test in the 
corresponding file's `beforeEach` hook.

To run more specific tests, you can see the ones that are preconfigured in the `package.json` file. Generally, the 
standard is `npm run test-...` where "..." is the category you want to test. To test the controller, run: 
```shell script
npm run test-controller
```
To only test the collateralization functions of the controller, run:
```shell script
npm run test-controller-collateralization
```

### Deployment

Deploying the protocol requires a web3 provider. You can set one via environment variable prior to invoking the script.
For example, to deploy to the Rinkeby Test Network using a pre-configured private key:

```shell script
PROVIDER=https://rinkeby.infura.io/v3/<PROJECT_ID> npm run deploy-testnet
```

This private key is simply `1234567812345678123456781234567812345678123456781234567812345678`.

**DO NOT USE THE PRIOR PRIVATE KEY** for anything other than test network. It is simply a dummy one and anyone would
be able to steal your funds or control your contracts if you use it on the main Ethereum network.

Deploying the protocol to the Ethereum Mainnet requires a private key in addition to a web3 provider. 

You can also deploy the protocol to a local Ethereum Ganache instance running on your machine by getting the port on
which it is running and invoking the following command:

```shell script
PROVIDER=http://localhost:<GANACHE_PORT_NUMBER> npm run deploy-testnet
```

### Docs & Integrating

Read more about the protocol, using it, and integrating it in the [Wiki](https://github.com/defi-money-market-ecosystem/protocol/wiki).

### Deployed Addresses

#### Mainnet

 **Contract**  	                                | **Address**   	                            | Link   	                                                             
------------------------------------------------|-----------------------------------------------|------------------------------------------------------------------------
| Delayed Owner  	                            | 0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD    | [Etherscan](https://etherscan.io/address/0x9e97ee8631da9e96bc36a6bf39d332c38d9834dd)
| DMG (Governance Token)  	                    | 0xEd91879919B71bB6905f23af0A68d231EcF87b14    | [Etherscan](https://etherscan.io/address/0xed91879919b71bb6905f23af0a68d231ecf87b14)
| DMM Blacklist  	                            | 0x516d652E2f12876F5f0244aa661b1C262a2d96b1    | [Etherscan](https://etherscan.io/address/0x516d652e2f12876f5f0244aa661b1c262a2d96b1)
| DMM Controller  	                            | 0x4CB120Dd1D33C9A3De8Bc15620C7Cd43418d77E2    | [Etherscan](https://etherscan.io/address/0x4cb120dd1d33c9a3de8bc15620c7cd43418d77e2)
| DMM Ether Factory  	                        | 0x1186d7dFf910Aa6c74bb9af71539C668133034aC    | [Etherscan](https://etherscan.io/address/0x1186d7dff910aa6c74bb9af71539c668133034ac)
| DMM Token Factory  	                        | 0x42665308F611b022df2fD48757A457BEC12BA668    | [Etherscan](https://etherscan.io/address/0x42665308f611b022df2fd48757a457bec12ba668)
| DMM: DAI  	                                | 0x06301057D77D54B6e14c7FafFB11Ffc7Cab4eaa7    | [Etherscan](https://etherscan.io/address/0x06301057d77d54b6e14c7faffb11ffc7cab4eaa7)
| DMM: ETH  	                                | 0xdF9307DFf0a1B57660F60f9457D32027a55ca0B2    | [Etherscan](https://etherscan.io/address/0xdF9307DFf0a1B57660F60f9457D32027a55ca0B2)
| DMM: USDC  	                                | 0x3564ad35b9E95340E5Ace2D6251dbfC76098669B    | [Etherscan](https://etherscan.io/address/0x3564ad35b9e95340e5ace2d6251dbfc76098669b)
| Interest Rate Setter V1  	                    | 0x6F2A3b2EFa07D264EA79Ce0b96d3173a8feAcD35    | [Etherscan](https://etherscan.io/address/0x6f2a3b2efa07d264ea79ce0b96d3173a8feacd35)
| Off-Chain Assets Valuator V1  	            | 0xAcE9112EfE78D9E5018fd12164D30366cA629Ab4    | [Etherscan](https://etherscan.io/address/0xace9112efe78d9e5018fd12164d30366ca629ab4)
| Off-Chain Currency Valuator V1  	            | 0x35cceb6ED6EB90d0c89a8F8b28E00aE23545312b    | [Etherscan](https://etherscan.io/address/0x35cceb6ed6eb90d0c89a8f8b28e00ae23545312b)
| Referral Program Proxy Factory                | 0x926ebD23E6d5fD38dC6A4FD79C58B6A2b543e9aC    | [Etherscan](https://etherscan.io/address/0x926ebd23e6d5fd38dc6a4fd79c58b6a2b543e9ac)
| ~~Underlying Token Valuator V1~~ DEPRECATED   | 0xe8B313e7BfdC0eCB23e4BE47062dB0A65AE5705c    | [Etherscan](https://etherscan.io/address/0xe8b313e7bfdc0ecb23e4be47062db0a65ae5705c)
| ~~Underlying Token Valuator V2~~ DEPRECATED   | 0x693AA8eAD81D2F88A45e870Fa7E25f84Ca93Ca4d    | [Etherscan](https://etherscan.io/address/0x693aa8ead81d2f88a45e870fa7e25f84ca93ca4d)
| Underlying Token Valuator V3                  | 0x9CFa15A1a8BDA741D41A6B8de8b2B04E693c9eA5    | [Etherscan](https://etherscan.io/address/0x9cfa15a1a8bda741d41a6b8de8b2b04e693c9ea5)