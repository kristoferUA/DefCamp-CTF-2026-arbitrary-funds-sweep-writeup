// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Inbox} from "./Inbox.sol";

contract Saylor {
    function relay(
        Inbox inbox,
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256 ticketId) {
        return inbox.createRetryableTicket{value: msg.value}(
            to, l2CallValue, maxSubmissionCost, gasLimit, maxFeePerGas, data
        );
    }

    function call(address to, bytes calldata data) external payable returns (bytes memory ret) {
        bool ok;
        (ok, ret) = to.call{value: msg.value}(data);
        require(ok, "call failed");
    }
}
