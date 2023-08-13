# CheckDot Aptos Bridge Contract

#### Install

UTIL: https://imcoding.online/tutorials/how-to-issue-your-coins-on-aptos

https://aptos.dev/tools/install-cli/

`aptos init`

#### Compile

`aptos move compile`

#### Deploy

```shell
cd Bridge
aptos move publish
aptos move run --function-id b366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::CdtCoin::initialize
```

#### Important information

You need to bear in mind that tokens on EVM generally have 18 decimals, whereas the maximum number of decimals possible on Aptos is 8.

Be sure to take this information into account for every transfer from one blockchain to another.

Here's an example with two solutions, although I recommend solution two to avoid any manipulation.

```js
// 100000000 = 1 CDT on aptos
// 1000000000000000000 = 1 CDT on EVM
// EVM to APTOS => 1000000000000000000/10000000000 = 100000000 
// APTOS to EVM => 100000000 * 10000000000 =  1000000000000000000 
//----
// EVM to APTOS
// Possibility 1: 
 (EVMBridgedAmount) => EVMBridgedAmount / 10000000000;
// Possibility 2: (10 integer numbers to be erased)
// exemple ->
["1000000000000000000"].map(v => v.slice(0, v.length - 10))[0]
// function ->
(EVMBridgedAmount) => [EVMBridgedAmount].map(v => v.slice(0, v.length - 10))[0]
// ----
// APTOS vers EVM
// Possibility 1:
(APTOSBridgedAmount) => APTOSBridgedAmount * 10000000000;
// Possibility 2: (add 10 integer numbers at the end)
// exemple ->
["100000000"].map(v => v + [...Array(10)].map(()=>'0').join(''))[0]
// function ->
(APTOSBridgedAmount) => [APTOSBridgedAmount].map(v => v + [...Array(10)].map(()=>'0').join(''))[0] 
```

#### Deposit

Example of deposit 9897808 CDT:

```js
const pendingTransaction = await aptosUtils.signAndSubmit('PRIVATE OR MEMOIC', {
        "function": `0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridge_v1::deposit`,
        "type_arguments": [],
        "arguments": ["989780800000000"]
    });
console.log(pendingTransaction);
```

#### Bridging APTOS network to X

Example of user bridge 1 CDT to BSC network

```js

const feesInAPT = await aptosUtils.view({
        "function": `0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridge_v1::get_fees_in_apt`,
        "type_arguments": ["0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::USDC"],
        "arguments": []
    });

const pendingTransaction = await aptosUtils.signAndSubmit('PRIVATE OR MEMOIC', {
        "function": `0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridge_v1::init_transfer`,
        "type_arguments": ['0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::USDC'],
        "arguments": [
            (Number(feesInAPT) + 1000).toFixed(0), // 10 USD in APT
            '100000000', // 1 CDT
            'BSC', // Destination Chain Name
            '0x0000000000000000000000000000000000000000' // DATA (Destination Address)
        ]
    });
console.log(pendingTransaction);
```

#### Detecting Bridge transactions

```js
    let lastsTenTransactions = await aptosUtils.view({
        "function": "0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridge_v1::get_last_transfers",
        "type_arguments": [],
        "arguments": ["10"]
    });

    // here Check the hashs and compare with already transfered on destination chain
    // make your transfer on the destination chain.
```

#### Bot program / owner apply the destination transfer from X to Aptos

Warning before any transfer of your token to unknown address.
Please to be sure the destination address have authorized token.
If not the transaction should be failed (No TOKEN is losed).

```js
    // here check your others bridge networks if one transaction is destinated for APT
    aptDestinationTx = ...; // example

    const tx = {
        "function": `${bridgeAddress}::add_transfers_from`,
        "type_arguments": [],
        "arguments": [aptDestinationTx.fromChainName, aptDestinationTx.data, EVMQuantityToAptosQuantity(aptDestinationTx.quantity), aptDestinationTx.hash]
    };
    const pendingTransaction = await aptosUtils.signAndSubmit('PRIVATE OR MEMOIC', tx);
```

#### Unused Test Addresses (On Mainnet)

0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridge
0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridgeTwo
0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridgeThree
0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridgeFour
0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridgeFive
0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridgeSix

#### Final Address (On Mainnet Final used Address)

0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::checkdot_bridge_v1
TraceMove Link: https://tracemove.io/account/0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f?tab=modules&moduleName=checkdot_bridge_v1&type=1


## Contributors

- Jeremy Guyet
- SunlightLuck
