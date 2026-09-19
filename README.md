# arbitrary-funds-sweep

DefCamp CTF 2026 · blockchain · author: kristoferUA

This repository contains the solution for the `arbitrary-funds-sweep` challenge. The instance models an L1/L2 pair: an Ethereum-like L1 and an Arbitrum-like L2. The objective is to reduce the L2 vault balance to zero.

## TL;DR

`Vault` trusts a `Saylor` contract address as its owner. `Saylor` is deployed with `CREATE2` by a factory whose address is identical on L1 and L2. Recovering the *exact* L1 init code and reusing the original salt therefore deploys `Saylor` at the same address on L2. Its public `call` function can then make the owner-authorized `Vault.execute` call and transfer the entire balance to the player.

Flag: `DCTF{b4s3_l4y3r_15_4lw4y5_b0r1ng_th4t5_l1f3}`

## Challenge model

The supplied source places `Saylor` behind a `Factory`:

```solidity
address saylor = factory.deploy(type(Saylor).creationCode, salt);
```

The L2 vault accepts calls only from the resulting address:

```solidity
require(msg.sender == owner, "not the owner");
```

That would be sufficient if `Saylor` did not expose an unrestricted arbitrary-call helper:

```solidity
function call(address to, bytes calldata data) external payable returns (bytes memory ret) {
    (bool ok, bytes memory ret) = to.call{value: msg.value}(data);
    require(ok, "call failed");
}
```

The contract's address is not tied to its chain ID. For `CREATE2`, it is derived solely from the deployer, salt, and the hash of the init code:

```text
address = last_20_bytes(keccak256(0xff ++ factory ++ salt ++ keccak256(init_code)))
```

Because the factory address was deliberately mirrored across the two chains, the L1 deployment can be reproduced on L2 only if every input in that formula is byte-for-byte identical.

## The metadata pitfall

Compiling `Saylor.sol` locally did not work. The creation bytecode used in `CREATE2` includes Solidity's CBOR metadata suffix, so differences in compiler version, compiler settings, source inputs, or metadata configuration change `keccak256(init_code)`. A different init-code hash means a different `CREATE2` address, and the vault rejects the call with `not the owner`.

The reliable input already exists on-chain: the L1 transaction that called `Factory.deploy` contains the original creation code. Rather than guessing the original compilation environment, recover that init code directly from the deployment transaction.

## Recovering the original creation code

`solve.py` is the renamed and cleaned-up reconnaissance script. It performs these steps:

1. Reads the deployed runtime bytecode for the known L1 `Saylor` address.
2. Scans the early L1 blocks for a transaction input containing that runtime bytecode.
3. Finds the Solidity init-code prefix immediately before it and saves the exact creation bytecode.

Run the recovery against an instance (it uses only the Python standard library):

```bash
python solve.py \
  --rpc-url http://HOST:PORT/rpc/l1 \
  --target 0x8054b6A618636CC6F877ec97381b5778f055ff9f \
  --max-block 14
```

The script writes `artifacts/saylor-creation-code.hex`. The solved exploit already embeds the recovered init code, so the script is included both to document the recovery and to make the technique reproducible on a fresh instance.

### Captured recovery output

The following is the translated output from the successful recovery session:

```text
$ python solve.py
1. Reading Saylor runtime code from L1...
2. Searching for the deployment transaction in early blocks...
3. Bytecode found successfully! Generating Exploit.s.sol...
Done! Now simply run: forge script Exploit.s.sol:ExploitScript --broadcast
```

## Exploitation

`script/Exploit.s.sol` uses the recovered init code and the original salt:

1. Fork the target L2 RPC endpoint.
2. Call the mirrored `Factory.deploy(exactCreationCode, salt)`.
3. Assert that the return value equals the L1 `Saylor` address.
4. Encode `Vault.execute(player, vault.balance, "")`.
5. Ask the newly deployed Saylor contract to call the vault with that payload.

At step 5, the vault sees the copied Saylor address as `msg.sender`, so the ownership check succeeds and all ETH is transferred to the address corresponding to `PRIVATE_KEY`.

## Running the proof of concept

Requirements:

- Foundry, including `forge`;
- Python 3.10+;
- `forge-std` installed at `lib/forge-std`.

```bash
forge install foundry-rs/forge-std --no-commit
cp .env.example .env
```

Set `PRIVATE_KEY` in your environment (do not commit it) and replace the remaining values in `.env` with the values printed by your own instance. Then run:

```bash
forge script script/Exploit.s.sol:ExploitScript --broadcast --via-ir
```

The included `.env.example` intentionally contains no private key. The original challenge endpoint is not treated as a permanent service; use a live instance under your control.

### Captured broadcast output

The following is the translated output from the successful Foundry broadcast:

```text
$ forge script Exploit.s.sol:ExploitScript --broadcast --via-ir
[⠒] Compiling...
No files changed, compilation skipped
Script ran successfully.
Gas used: 508695

##### anvil-hardhat
✅ [Success] Hash: 0x0990bb6d0732e5f4428b4c9d64cad9f4ad048a0ddd26d3ea336cd7d4fd80b746
Function: call(address,bytes)
Block: 11
Paid: 0.00000967367054745 ETH (35385 gas * 0.27338337 gwei)

##### anvil-hardhat
✅ [Success] Hash: 0x6787e8d2e1f558986e3147847857078ade671a225767b92a08fc512ee53a3c82
Function: deploy(bytes,bytes32)
Block: 10
Paid: 0.000135576983942491 ETH (435733 gas * 0.311146927 gwei)

✅ Sequence #1 on anvil-hardhat | Total paid: 0.000145250654489941 ETH
   (471118 gas * average 0.292265148 gwei)

ON-CHAIN EXECUTION COMPLETE AND SUCCESSFUL.
```

## Repository layout

```text
src/                    supplied challenge contracts
script/Exploit.s.sol    Foundry proof of concept
solve.py                L1 creation-bytecode recovery utility
.env.example            required instance configuration, without secrets
foundry.toml            Foundry compiler settings
requirements.txt        Python dependency note for solve.py
```

## Result

The vault balance was reduced to zero and the challenge returned:

```text
DCTF{b4s3_l4y3r_15_4lw4y5_b0r1ng_th4t5_l1f3}
```

## Responsible use

This code is an educational solution for the supplied CTF challenge. Use it only against CTF instances or systems for which you have explicit authorization.
