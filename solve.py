#!/usr/bin/env python3
"""Recover the exact Saylor creation bytecode from an L1 deployment transaction."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


DEFAULT_TARGET = "0x8054b6A618636CC6F877ec97381b5778f055ff9f"
SOLIDITY_INIT_PREFIX = "60806040"


def rpc_call(rpc_url: str, method: str, params: list[Any]) -> Any:
    """Send one JSON-RPC request and return its result or raise a useful error."""
    request = Request(
        rpc_url,
        data=json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=20) as response:
            payload = json.loads(response.read())
    except HTTPError as error:
        raise RuntimeError(f"{method} returned HTTP {error.code}") from error
    except URLError as error:
        raise RuntimeError(f"Could not reach {rpc_url}: {error.reason}") from error

    if "error" in payload:
        raise RuntimeError(f"{method} failed: {payload['error']}")
    return payload["result"]


def recover_creation_code(rpc_url: str, target: str, max_block: int) -> str:
    """Locate the creation code by matching deployed runtime code in transaction input."""
    runtime_code = rpc_call(rpc_url, "eth_getCode", [target, "latest"])
    if runtime_code in (None, "0x"):
        raise RuntimeError(f"No runtime bytecode found at {target}")
    runtime_code = runtime_code.removeprefix("0x").lower()
    print("[1/3] Retrieved Saylor runtime bytecode from L1.")

    print(f"[2/3] Searching deployment transactions in blocks 0 through {max_block}...")
    for block_number in range(max_block + 1):
        block = rpc_call(rpc_url, "eth_getBlockByNumber", [hex(block_number), True])
        if block is None:
            continue

        for transaction in block.get("transactions", []):
            tx_input = transaction.get("input", "0x").removeprefix("0x").lower()
            runtime_index = tx_input.find(runtime_code)
            if runtime_index < 0:
                continue

            init_index = tx_input.rfind(SOLIDITY_INIT_PREFIX, 0, runtime_index)
            if init_index < 0:
                continue

            creation_code = tx_input[init_index : runtime_index + len(runtime_code)]
            print(f"    Found a matching deployment in block {block_number}: {transaction['hash']}")
            return "0x" + creation_code

    raise RuntimeError("Could not find the original creation bytecode in the scanned blocks.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rpc-url", required=True, help="L1 JSON-RPC endpoint")
    parser.add_argument("--target", default=DEFAULT_TARGET, help="L1 Saylor contract address")
    parser.add_argument("--max-block", type=int, default=14, help="Last block to scan, inclusive")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("artifacts/saylor-creation-code.hex"),
        help="File that will receive the recovered 0x-prefixed creation bytecode",
    )
    args = parser.parse_args()

    if args.max_block < 0:
        parser.error("--max-block must be non-negative")

    creation_code = recover_creation_code(args.rpc_url, args.target, args.max_block)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(creation_code + "\n", encoding="ascii")
    print(f"[3/3] Saved {len(creation_code) // 2 - 1} bytes to {args.output}")


if __name__ == "__main__":
    main()
