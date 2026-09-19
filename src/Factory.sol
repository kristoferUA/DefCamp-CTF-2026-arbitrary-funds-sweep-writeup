// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Factory {
    event Deployed(address addr, bool freshlyDeployed);

    function deploy(bytes memory bytecode, bytes32 salt) public returns (address addr) {
        addr = predictAddress(salt, bytecode);

        bool fresh = addr.code.length == 0;
        if (fresh) {
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            }
        }

        emit Deployed(addr, fresh);
    }

    function predictAddress(bytes32 salt, bytes memory bytecode) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }
}
