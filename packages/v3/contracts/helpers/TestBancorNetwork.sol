// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.7.6;
pragma abicoder v2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ITokenGovernance } from "@bancor/token-governance/0.7.6/contracts/TokenGovernance.sol";

import { INetworkSettings } from "../network/interfaces/INetworkSettings.sol";
import { IPendingWithdrawals } from "../network/interfaces/IPendingWithdrawals.sol";
import { BancorNetwork } from "../network/BancorNetwork.sol";

import { IPoolCollection } from "../pools/interfaces/IPoolCollection.sol";
import { INetworkTokenPool, DepositAmounts } from "../pools/interfaces/INetworkTokenPool.sol";

import { IReserveToken } from "../token/interfaces/IReserveToken.sol";

contract TestBancorNetwork is BancorNetwork {
    constructor(
        ITokenGovernance initNetworkTokenGovernance,
        ITokenGovernance initGovTokenGovernance,
        INetworkSettings initSettings
    ) BancorNetwork(initNetworkTokenGovernance, initGovTokenGovernance, initSettings) {}

    function createPoolT(IPoolCollection liquidityPoolCollection, IReserveToken reserveToken) external {
        liquidityPoolCollection.createPool(reserveToken);
    }

    function completeWithdrawalT(
        IPendingWithdrawals pendingWithdrawals,
        bytes32 contextId,
        address provider,
        uint256 id
    ) external returns (uint256) {
        return pendingWithdrawals.completeWithdrawal(contextId, provider, id);
    }

    function depositForT(
        INetworkTokenPool networkTokenPool,
        address provider,
        uint256 networkTokenAmount,
        bool isMigrating,
        uint256 originalPoolTokenAmount
    ) external returns (DepositAmounts memory) {
        return networkTokenPool.depositFor(provider, networkTokenAmount, isMigrating, originalPoolTokenAmount);
    }

    function onNetworkTokenFeesCollectedT(
        INetworkTokenPool networkTokenPool,
        IReserveToken pool,
        uint256 amount,
        uint8 feeType
    ) external {
        networkTokenPool.onFeesCollected(pool, amount, feeType);
    }
}
