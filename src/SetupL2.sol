// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ArbRetryableTx} from "./ArbRetryableTx.sol";

contract SetupL2 {
    ArbRetryableTx public immutable retryableTx;

    constructor(address relayer) {
        retryableTx = new ArbRetryableTx(relayer);
    }
}
