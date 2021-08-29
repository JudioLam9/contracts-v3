// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.7.6;
pragma abicoder v2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import { ITokenGovernance } from "@bancor/token-governance/0.7.6/contracts/TokenGovernance.sol";

import { INetworkSettings } from "../network/interfaces/INetworkSettings.sol";
import { IBancorVault } from "../network/interfaces/IBancorVault.sol";
import { IPendingWithdrawals, CompletedWithdrawalRequest } from "../network/interfaces/IPendingWithdrawals.sol";
import { BancorNetwork } from "../network/BancorNetwork.sol";

import { IPoolCollection, WithdrawalAmounts as PoolCollectionWithdrawalAmounts } from "../pools/interfaces/IPoolCollection.sol";
import { IPoolToken } from "../pools/interfaces/IPoolToken.sol";
import { INetworkTokenPool, DepositAmounts, WithdrawalAmounts as NetworkTokenPoolWithdrawalAmounts } from "../pools/interfaces/INetworkTokenPool.sol";

import { IReserveToken } from "../token/interfaces/IReserveToken.sol";

contract TestBancorNetwork is BancorNetwork {
    using SafeERC20 for IERC20;

    constructor(
        ITokenGovernance initNetworkTokenGovernance,
        ITokenGovernance initGovTokenGovernance,
        INetworkSettings initSettings,
        IBancorVault initVault,
        IPoolToken initNetworkPoolToken
    )
        BancorNetwork(initNetworkTokenGovernance, initGovTokenGovernance, initSettings, initVault, initNetworkPoolToken)
    {}

    function createPoolT(IPoolCollection poolCollection, IReserveToken reserveToken) external {
        poolCollection.createPool(reserveToken);
    }

    function completeWithdrawalT(
        bytes32 contextId,
        address provider,
        uint256 id
    ) external returns (CompletedWithdrawalRequest memory) {
        return _pendingWithdrawals.completeWithdrawal(contextId, provider, id);
    }

    function depositToNetworkPoolForT(
        address provider,
        uint256 networkTokenAmount,
        bool isMigrating,
        uint256 originalPoolTokenAmount
    ) external returns (DepositAmounts memory) {
        return _networkTokenPool.depositFor(provider, networkTokenAmount, isMigrating, originalPoolTokenAmount);
    }

    function withdrawFromNetworkPoolT(address provider, uint256 poolTokenAmount)
        external
        returns (NetworkTokenPoolWithdrawalAmounts memory)
    {
        return _networkTokenPool.withdraw(provider, poolTokenAmount);
    }

    function withdrawFromPoolCollectionT(
        IPoolCollection poolCollection,
        IReserveToken baseToken,
        uint256 basePoolTokenAmount,
        uint256 baseTokenVaultBalance,
        uint256 externalProtectionWalletBalance
    ) external returns (PoolCollectionWithdrawalAmounts memory) {
        return
            poolCollection.withdraw(
                baseToken,
                basePoolTokenAmount,
                baseTokenVaultBalance,
                externalProtectionWalletBalance
            );
    }

    function onNetworkTokenFeesCollectedT(
        IReserveToken pool,
        uint256 amount,
        uint8 feeType
    ) external {
        _networkTokenPool.onFeesCollected(pool, amount, feeType);
    }

    function requestLiquidityT(
        bytes32 contextId,
        IReserveToken pool,
        uint256 networkTokenAmount,
        bool skipLimitCheck
    ) external returns (uint256) {
        return _networkTokenPool.requestLiquidity(contextId, pool, networkTokenAmount, skipLimitCheck);
    }

    function renounceLiquidityT(
        bytes32 contextId,
        IReserveToken pool,
        uint256 networkTokenAmount
    ) external {
        _networkTokenPool.renounceLiquidity(contextId, pool, networkTokenAmount);
    }

    function approveT(
        IERC20 token,
        address spender,
        uint256 amount
    ) external {
        token.safeApprove(spender, amount);
    }
}
