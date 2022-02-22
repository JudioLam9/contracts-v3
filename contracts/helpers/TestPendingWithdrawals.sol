// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.11;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IBancorNetwork } from "../network/interfaces/IBancorNetwork.sol";
import { PendingWithdrawals } from "../network/PendingWithdrawals.sol";
import { IOmniPool } from "../pools/interfaces/IOmniPool.sol";

import { Time } from "../utility/Time.sol";

import { TestTime } from "./TestTime.sol";

contract TestPendingWithdrawals is PendingWithdrawals, TestTime {
    constructor(
        IBancorNetwork initNetwork,
        IERC20 initBNT,
        IOmniPool initOmniPool
    ) PendingWithdrawals(initNetwork, initBNT, initOmniPool) {}

    function _time() internal view virtual override(Time, TestTime) returns (uint32) {
        return TestTime._time();
    }
}
