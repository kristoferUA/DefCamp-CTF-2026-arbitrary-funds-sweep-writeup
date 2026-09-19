// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Vault {
    address public immutable owner;

    constructor(address _owner) payable {
        owner = _owner;
    }

    function execute(address to, uint256 value, bytes calldata data) external returns (bytes memory ret) {
        require(msg.sender == owner, "not the owner");
        bool ok;
        (ok, ret) = to.call{value: value}(data);
        require(ok, "call failed");
    }

    receive() external payable {}
}
