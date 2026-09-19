// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ArbRetryableTx {
    struct Ticket {
        address from;
        address to;
        uint256 callvalue;
        bytes data;
        uint256 expiry;
        bool redeemed;
    }

    address public immutable relayer;
    uint256 public constant LIFETIME = 7 days;

    mapping(uint256 => Ticket) public tickets;

    event TicketSubmitted(uint256 indexed ticketId, address from, address to);
    event TicketRedeemed(uint256 indexed ticketId);

    modifier onlyRelayer() {
        require(msg.sender == relayer, "not the relayer");
        _;
    }

    constructor(address _relayer) {
        relayer = _relayer;
    }

    function submit(uint256 ticketId, address from, address to, uint256 callvalue, bytes calldata data)
        external
        onlyRelayer
    {
        require(tickets[ticketId].expiry == 0, "already submitted");
        tickets[ticketId] = Ticket({
            from: from,
            to: to,
            callvalue: callvalue,
            data: data,
            expiry: block.timestamp + LIFETIME,
            redeemed: false
        });
        emit TicketSubmitted(ticketId, from, to);
    }

    function markRedeemed(uint256 ticketId) external onlyRelayer {
        Ticket storage ticket = tickets[ticketId];
        require(ticket.expiry != 0, "no such ticket");
        require(!ticket.redeemed, "already redeemed");
        require(block.timestamp <= ticket.expiry, "expired");
        ticket.redeemed = true;
        emit TicketRedeemed(ticketId);
    }

    function getTicket(uint256 ticketId) external view returns (Ticket memory) {
        return tickets[ticketId];
    }

    function isExpired(uint256 ticketId) external view returns (bool) {
        Ticket storage ticket = tickets[ticketId];
        return ticket.expiry != 0 && block.timestamp > ticket.expiry;
    }
}
