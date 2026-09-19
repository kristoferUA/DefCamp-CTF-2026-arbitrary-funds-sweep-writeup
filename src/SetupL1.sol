// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Factory} from "./Factory.sol";
import {Saylor} from "./Saylor.sol";
import {Inbox} from "./Inbox.sol";

contract SetupL1 {
    Factory public immutable factory;
    Inbox public immutable inbox;
    Saylor public immutable saylor;
    bytes32 public immutable salt;

    constructor(Factory _factory, bytes32 _salt) {
        factory = _factory;
        inbox = new Inbox();
        salt = _salt;
        saylor = Saylor(factory.deploy(type(Saylor).creationCode, salt));
    }
}
