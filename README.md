# DMM Protocol

This repository contains the Ethereum smart contracts for the DeFi Money Market Ecosystem.

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

#### Ethereum Mainnet

 **Contract Name**  	                            | **Contract Address**   	                    | Link   	                                                             
----------------------------------------------------|-----------------------------------------------|------------------------------------------------------------------------
| Delayed Owner  	                                | 0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD    | [Etherscan](https://etherscan.io/address/0x9e97ee8631da9e96bc36a6bf39d332c38d9834dd)
| DMG (Governance Token)  	                        | 0xEd91879919B71bB6905f23af0A68d231EcF87b14    | [Etherscan](https://etherscan.io/address/0xed91879919b71bb6905f23af0a68d231ecf87b14)
| DMG (Foundation Lockbox)  	                    | 0x3ED70f95C5A979572673558b2f1deEFdd46F1230    | [Etherscan](https://etherscan.io/address/0x3ed70f95c5a979572673558b2f1deefdd46f1230)
| DMG (Sales Lockbox #1 2020-11-15)  	            | 0x31254668ffa05e93fac6d06ade6706f644e14e8b    | [Etherscan](https://etherscan.io/address/0x31254668ffa05e93fac6d06ade6706f644e14e8b)
| ~~DMG (Sales Lockbox #2)~~ DEPRECATED  	        | 0xcd78950b160f80A6cC0f29CCc77044aD53366c21    | [Etherscan](https://etherscan.io/address/0xcd78950b160f80A6cC0f29CCc77044aD53366c21)
| DMG (Sales Lockbox/Forwarder #2)  	            | 0x39B7e9d93EF1C784adc3B94B9977d8a06d735783    | [Etherscan](https://etherscan.io/address/0x39B7e9d93EF1C784adc3B94B9977d8a06d735783)
| DMG (Incentives Lockbox #1 2020-11-15)  	        | 0xaA96a7890097a63EfcdFaceAC9225E51c79AfF96    | [Etherscan](https://etherscan.io/address/0xaA96a7890097a63EfcdFaceAC9225E51c79AfF96)
| DMG (Incentives Lockbox #2)  	                    | 0x382c4fd48Fbac7b5E973504cca1458A66A84a94f    | [Etherscan](https://etherscan.io/address/0x382c4fd48Fbac7b5E973504cca1458A66A84a94f)
| DMG (Incentives Forwarder #3)  	                | 0x704828d766181C906182C89CF1bC5A79bFf3a402    | [Etherscan](https://etherscan.io/address/0x704828d766181C906182C89CF1bC5A79bFf3a402)
| DMG Burner Impl V1 (*DO NOT INTERACT*)  	        | 0xE8d36D84C58Ba104C346726641D0DeCa05ad237C    | [Etherscan](https://etherscan.io/address/0xE8d36D84C58Ba104C346726641D0DeCa05ad237C)
| DMG Burner  	                                    | 0x51c9a18c87c89A34e1f3fE020b8f406F1300E909    | [Etherscan](https://etherscan.io/address/0x51c9a18c87c89A34e1f3fE020b8f406F1300E909)
| DMM Blacklist  	                                | 0x516d652E2f12876F5f0244aa661b1C262a2d96b1    | [Etherscan](https://etherscan.io/address/0x516d652e2f12876f5f0244aa661b1c262a2d96b1)
| ~~DMM Controller V1~~ DEPRECATED 	                | 0x4CB120Dd1D33C9A3De8Bc15620C7Cd43418d77E2    | [Etherscan](https://etherscan.io/address/0x4cb120dd1d33c9a3de8bc15620c7cd43418d77e2)
| DMM Controller V2 	                            | 0xB07EB3426d742cda9120931e7028d54F9dF34A3e    | [Etherscan](https://etherscan.io/address/0xB07EB3426d742cda9120931e7028d54F9dF34A3e)
| DMM Ether Factory  	                            | 0x1186d7dFf910Aa6c74bb9af71539C668133034aC    | [Etherscan](https://etherscan.io/address/0x1186d7dff910aa6c74bb9af71539c668133034ac)
| ~~DMM Token Factory V1~~ DEPRECATED 	            | 0x42665308F611b022df2fD48757A457BEC12BA668    | [Etherscan](https://etherscan.io/address/0x42665308f611b022df2fd48757a457bec12ba668)
| DMM Token Factory V2 	                            | 0x6Ce6C84Fe43Df6A28c209b36179bD84a52CAEEFe    | [Etherscan](https://etherscan.io/address/0x6Ce6C84Fe43Df6A28c209b36179bD84a52CAEEFe)
| DMM: DAI  	                                    | 0x06301057D77D54B6e14c7FafFB11Ffc7Cab4eaa7    | [Etherscan](https://etherscan.io/address/0x06301057d77d54b6e14c7faffb11ffc7cab4eaa7)
| DMM: ETH  	                                    | 0xdF9307DFf0a1B57660F60f9457D32027a55ca0B2    | [Etherscan](https://etherscan.io/address/0xdF9307DFf0a1B57660F60f9457D32027a55ca0B2)
| DMM: USDC  	                                    | 0x3564ad35b9E95340E5Ace2D6251dbfC76098669B    | [Etherscan](https://etherscan.io/address/0x3564ad35b9e95340e5ace2d6251dbfc76098669b)
| DMM: USDT  	                                    | 0x84d4AfE150dA7Ea1165B9e45Ff8Ee4798d7C38DA    | [Etherscan](https://etherscan.io/address/0x84d4AfE150dA7Ea1165B9e45Ff8Ee4798d7C38DA)
| Governor Alpha  	                                | 0x67Cb2868Ebf965b66d3dC81D0aDd6fd849BCF6D5    | [Etherscan](https://etherscan.io/address/0x67Cb2868Ebf965b66d3dC81D0aDd6fd849BCF6D5)
| Governance Timelock  	                            | 0xE679eBf544A6BE5Cb8747012Ea6B08F04975D264    | [Etherscan](https://etherscan.io/address/0xE679eBf544A6BE5Cb8747012Ea6B08F04975D264)
| Loopring Protocol V2 (for Trading DMG)  	        | 0xC0b569Ff46EEA7BfbB130bd6d7af0a0A7f513C6F    | [Etherscan](https://etherscan.io/address/0xC0b569Ff46EEA7BfbB130bd6d7af0a0A7f513C6F)
| Interest Rate Setter V1  	                        | 0x6F2A3b2EFa07D264EA79Ce0b96d3173a8feAcD35    | [Etherscan](https://etherscan.io/address/0x6f2a3b2efa07d264ea79ce0b96d3173a8feacd35)
| Off-Chain Assets Valuator V1  	                | 0xAcE9112EfE78D9E5018fd12164D30366cA629Ab4    | [Etherscan](https://etherscan.io/address/0xace9112efe78d9e5018fd12164d30366ca629ab4)
| Off-Chain Assets Valuator Proxy  	                | 0x4F9c3332D352F1ef22F010ba93A9653261e1634b    | [Etherscan](https://etherscan.io/address/0x4F9c3332D352F1ef22F010ba93A9653261e1634b)
| ~~Off-Chain Currency Valuator V1~~ DEPRECATED     | 0x35cceb6ED6EB90d0c89a8F8b28E00aE23545312b    | [Etherscan](https://etherscan.io/address/0x35cceb6ED6EB90d0c89a8F8b28E00aE23545312b)
| Off-Chain Currency Valuator Proxy  	            | 0x826d758AF2FeD387ac15843327e143b2CAfE9047    | [Etherscan](https://etherscan.io/address/0x826d758AF2FeD387ac15843327e143b2CAfE9047)
| Referral Program Proxy Factory                    | 0x926ebD23E6d5fD38dC6A4FD79C58B6A2b543e9aC    | [Etherscan](https://etherscan.io/address/0x926ebd23e6d5fd38dc6a4fd79c58b6a2b543e9ac)
| ~~Underlying Token Valuator V1~~ DEPRECATED       | 0xe8B313e7BfdC0eCB23e4BE47062dB0A65AE5705c    | [Etherscan](https://etherscan.io/address/0xe8b313e7bfdc0ecb23e4be47062db0a65ae5705c)
| ~~Underlying Token Valuator V2~~ DEPRECATED       | 0x693AA8eAD81D2F88A45e870Fa7E25f84Ca93Ca4d    | [Etherscan](https://etherscan.io/address/0x693aa8ead81d2f88a45e870fa7e25f84ca93ca4d)
| ~~Underlying Token Valuator V3~~ DEPRECATED       | 0x7812e0F5Da2F0917BD9054951415EDFF571964dB    | [Etherscan](https://etherscan.io/address/0x7812e0f5da2f0917bd9054951415edff571964db)
| ~~Underlying Token Valuator V4~~ DEPRECATED       | 0x0c65c147aAf2DbD5109ba74e36f730D081489B5B    | [Etherscan](https://etherscan.io/address/0x0c65c147aAf2DbD5109ba74e36f730D081489B5B)
| Underlying Token Valuator Proxy                   | 0xaC7e5e3b589D55a43D62b90c6b4C4ef28Ea35573    | [Etherscan](https://etherscan.io/address/0xaC7e5e3b589D55a43D62b90c6b4C4ef28Ea35573)
| Yield Farming Proxy                               | 0x502e90e092Cd08e6630e8E1cE426fC6d8ADb3975    | [Etherscan](https://etherscan.io/address/0x502e90e092Cd08e6630e8E1cE426fC6d8ADb3975)
| Yield Farming Router                              | 0x8209eD0259F99Abd593E8cd26e6a14f224C6cccA    | [Etherscan](https://etherscan.io/address/0x8209eD0259F99Abd593E8cd26e6a14f224C6cccA)
| ~~Yield Farming Impl V1~~ DEPRECATED              | 0x061f57eA8383558A7E20F84948d0F11A6e1BcDe2    | [Etherscan](https://etherscan.io/address/0x061f57eA8383558A7E20F84948d0F11A6e1BcDe2)
| Yield Farming Impl V2 (*DO NOT INTERACT*)         | 0x4BC1143b887Bb0A1d8C435e3c44CEBb75F3BB24b    | [Etherscan](https://etherscan.io/address/0x4BC1143b887Bb0A1d8C435e3c44CEBb75F3BB24b)

#### Ropsten Testnet

 **Contract Name**  	                            | **Contract Address**   	                    | Link   	                                                             
----------------------------------------------------|-----------------------------------------------|------------------------------------------------------------------------
| DAI  	                                            | 0xf15a6519b099A8eb7ffA9f12AF0D878B0f85a918    | [Etherscan](https://ropsten.etherscan.io/address/0xf15a6519b099A8eb7ffA9f12AF0D878B0f85a918)
| USDC  	                                        | 0x54db15edFb7552f0314e89966afa6C89ff157386    | [Etherscan](https://ropsten.etherscan.io/address/0x54db15edFb7552f0314e89966afa6C89ff157386)
| USDC (Circle)  	                                | 0x07865c6E87B9F70255377e024ace6630C1Eaa37F    | [Etherscan](https://ropsten.etherscan.io/address/0x07865c6E87B9F70255377e024ace6630C1Eaa37F)
| WETH  	                                        | 0x893178fBD1b3eb77cB85Ab39Bb3b3EDF2609a478    | [Etherscan](https://ropsten.etherscan.io/address/0x893178fbd1b3eb77cb85ab39bb3b3edf2609a478)
| Delayed Owner  	                                | 0x6C8C010354A010bee5E8b563eC457614B9Db8eFf    | [Etherscan](https://ropsten.etherscan.io/address/0x6c8c010354a010bee5e8b563ec457614b9db8eff)
| DMM Blacklist  	                                | 0x048cb15f882feA832B7513ed1Bd0Ed66504d0343    | [Etherscan](https://ropsten.etherscan.io/address/0x048cb15f882fea832b7513ed1bd0ed66504d0343)
| DMM Controller  	                                | 0x5Ac111AeD2B53F2b43B60d5f4729CF1076d48391    | [Etherscan](https://ropsten.etherscan.io/address/0x5Ac111AeD2B53F2b43B60d5f4729CF1076d48391)
| DMM Ether Factory  	                            | 0x96Dcf92C4eFBec5Cd83f36944b729C146FBe13B6    | [Etherscan](https://ropsten.etherscan.io/address/0x96Dcf92C4eFBec5Cd83f36944b729C146FBe13B6)
| DMM Token Factory  	                            | 0x500cD65Bd10c00907ED2B9AC0282baC412A482e8    | [Etherscan](https://ropsten.etherscan.io/address/0x500cD65Bd10c00907ED2B9AC0282baC412A482e8)
| DMM: DAI  	                                    | 0xC1d81D71b703f387A82510615b367928BD74C819    | [Etherscan](https://ropsten.etherscan.io/address/0xC1d81D71b703f387A82510615b367928BD74C819)
| DMM: ETH  	                                    | 0xF3516dC84E0322542320690818E292aBCCD954f2    | [Etherscan](https://ropsten.etherscan.io/address/0xF3516dC84E0322542320690818E292aBCCD954f2)
| DMM: USDC  	                                    | 0x402f9c5Dadb4D9E5cbf74A99693A379F875dBc25    | [Etherscan](https://ropsten.etherscan.io/address/0x402f9c5Dadb4D9E5cbf74A99693A379F875dBc25)
| DMM: USDC (Circle)  	                            | 0xC4Ff4B501e92792Aa5F048788447394858C32B3F    | [Etherscan](https://ropsten.etherscan.io/address/0xC4Ff4B501e92792Aa5F048788447394858C32B3F)
| Interest Rate Setter V1  	                        | 0x32df47ab270a1ec1450fa4b7abdfa94ee6b5f2fa    | [Etherscan](https://ropsten.etherscan.io/address/0x32df47ab270a1ec1450fa4b7abdfa94ee6b5f2fa)
| Off-Chain Assets Valuator V1  	                | 0x4f665be185c3ce125a7c81b2c6b26be6fd58c780    | [Etherscan](https://ropsten.etherscan.io/address/0x4f665be185c3ce125a7c81b2c6b26be6fd58c780)
| Off-Chain Currency Valuator V1  	                | 0x105808e0f32cf9b51567cf2dfce6403ca962fc0c    | [Etherscan](https://ropsten.etherscan.io/address/0x105808e0f32cf9b51567cf2dfce6403ca962fc0c)
| Underlying Token Valuator V3                      | 0xadeC704f3ce4498cAE4547F20152d58944aCd2D9    | [Etherscan](https://ropsten.etherscan.io/address/0xadeC704f3ce4498cAE4547F20152d58944aCd2D9)

In order to mint DAI or USDC for yourself on Ropsten, visit the corresponding Etherscan link and call the `write` 
function `setBalance`, passing in your address as the recipient. The `amount` must be encoded in `wei` format, with
the correct number of zeroes to account for decimal padding. Meaning, `1000000` is `1.0` for USDC and
`1000000000000000000` is `1.0` for DAI. See the image below for a screenshot of Ropsten's Etherscan token page:
![](./guides/set-balance-image.png)