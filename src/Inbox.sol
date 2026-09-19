// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Inbox {
    struct Ticket {
        address from;
        bool fromIsContract;
        address to;
        uint256 l2CallValue;
        uint256 maxSubmissionCost;
        uint256 gasLimit;
        uint256 maxFeePerGas;
        bytes data;
    }

    uint256 public nextTicketId;
    mapping(uint256 => Ticket) public tickets;

    event TicketCreated(uint256 indexed ticketId);

    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256 ticketId) {
        uint256 totalCost = l2CallValue + maxSubmissionCost + gasLimit * maxFeePerGas;
        require(msg.value >= totalCost, "insufficient L1 fee");

        ticketId = nextTicketId++;
        tickets[ticketId] = Ticket({
            from: msg.sender,
            fromIsContract: msg.sender != tx.origin,
            to: to,
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            data: data
        });
        emit TicketCreated(ticketId);
    }
}
