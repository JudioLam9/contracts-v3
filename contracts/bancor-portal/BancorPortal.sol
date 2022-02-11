// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.11;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Token } from "../token/Token.sol";
import { TokenLibrary } from "../token/TokenLibrary.sol";
import { Upgradeable } from "../utility/Upgradeable.sol";
import { Utils } from "../utility/Utils.sol";

import { IBancorNetwork } from "../network/interfaces/IBancorNetwork.sol";
import { INetworkSettings } from "../network/interfaces/INetworkSettings.sol";
import { NetworkSettings } from "../network/NetworkSettings.sol";
import { IPoolToken } from "../pools/interfaces/IPoolToken.sol";

import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { IBancorPortal } from "./interfaces/IBancorPortal.sol";

import "./MigrationResult.sol";
import "./UniswapV2PositionMigration.sol";

/**
 * @dev one click liquidity migration between other DEXes into Bancor v3
 */
contract BancorPortal is IBancorPortal, ReentrancyGuardUpgradeable, Utils, Upgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IPoolToken;
    using TokenLibrary for Token;

    // the network contract
    IBancorNetwork private immutable _network;

    // the network settings
    INetworkSettings private immutable _networkSettings;

    // the address of the network token
    IERC20 private immutable _networkToken;

    // uniswap v2 router
    IUniswapV2Router02 private immutable _uniswapV2Router;

    // uniswap v2 factory
    IUniswapV2Factory private immutable _uniswapV2Factory;

    // sushiswap v2 router
    IUniswapV2Router02 private immutable _sushiswapV2Router;

    // sushiswap v2 factory
    IUniswapV2Factory private immutable _sushiswapV2Factory;

    // upgrade forward-compatibility storage gap
    uint256[MAX_GAP - 0] private __gap;

    uint32 private constant THREE_HOURS = 10800;

    /**
     * @dev triggered after a succesful Uniswap V2 migration
     */
    event UniswapV2PositionMigrated(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB
    );

    /**
     * @dev triggered after a succesful Sushiswap V1 migration
     */
    event SushiswapV2PositionMigrated(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB
    );

    error UnsupportedTokens();
    error NoPairForTokens();

    /**
     * @dev a "virtual" constructor that is only used to set immutable state variables
     */
    constructor(
        IBancorNetwork network,
        INetworkSettings networkSettings,
        IERC20 networkToken,
        IUniswapV2Router02 uniswapV2Router,
        IUniswapV2Factory uniswapV2Factory,
        IUniswapV2Router02 sushiswapV2Router,
        IUniswapV2Factory sushiswapV2Factory
    )
        validAddress(address(network))
        validAddress(address(networkSettings))
        validAddress(address(networkToken))
        validAddress(address(uniswapV2Router))
        validAddress(address(uniswapV2Factory))
        validAddress(address(sushiswapV2Router))
        validAddress(address(sushiswapV2Factory))
    {
        _network = network;
        _networkSettings = networkSettings;
        _networkToken = networkToken;
        _uniswapV2Router = uniswapV2Router;
        _uniswapV2Factory = uniswapV2Factory;
        _sushiswapV2Router = sushiswapV2Router;
        _sushiswapV2Factory = sushiswapV2Factory;
    }

    /**
     * @dev returns the current version of the contract
     */
    function version() external pure returns (uint16) {
        return 1;
    }

    /**
     * @dev fully initializes the contract and its parents
     */
    function initialize() external initializer {
        __BancorPortal_init();
    }

    // solhint-disable func-name-mixedcase

    /**
     * @dev initializes the contract and its parents
     */
    function __BancorPortal_init() internal initializer {
        __ReentrancyGuard_init();
        __Upgradeable_init();

        __BancorPortal_init_unchained();
    }

    /**
     * @dev performs contract-specific initialization
     */
    function __BancorPortal_init_unchained() internal initializer {}

    /**
     * @dev ETH receive callback
     */
    receive() external payable {}

    /**
     * @inheritdoc IBancorPortal
     */
    function migrateUniswapV2Position(
        Token token0,
        Token token1,
        uint256 amount
    )
        external
        nonReentrant
        validAddress(address(token0))
        validAddress(address(token1))
        greaterThanZero(amount)
        returns (UniswapV2PositionMigration memory)
    {
        MigrationResult memory res = _migrateUniswapV2Position(
            _uniswapV2Router,
            _uniswapV2Factory,
            token0,
            token1,
            amount
        );

        emit UniswapV2PositionMigrated({
            provider: msg.sender,
            tokenA: res.tokenA,
            tokenB: res.tokenB,
            amountA: res.amountA,
            amountB: res.amountB
        });

        return UniswapV2PositionMigration({ amountA: res.amountA, amountB: res.amountB });
    }

    /**
     * @inheritdoc IBancorPortal
     */
    function migrateSushiswapV1Position(
        Token token0,
        Token token1,
        uint256 amount
    )
        external
        nonReentrant
        validAddress(address(token0))
        validAddress(address(token1))
        greaterThanZero(amount)
        returns (UniswapV2PositionMigration memory)
    {
        MigrationResult memory res = _migrateUniswapV2Position(
            _sushiswapV2Router,
            _sushiswapV2Factory,
            token0,
            token1,
            amount
        );

        emit SushiswapV2PositionMigrated({
            provider: msg.sender,
            tokenA: res.tokenA,
            tokenB: res.tokenB,
            amountA: res.amountA,
            amountB: res.amountB
        });

        return UniswapV2PositionMigration({ amountA: res.amountA, amountB: res.amountB });
    }

    /**
     * @dev migrates funds from a Uniswap V2 pair into a Bancor V3 pool
     * - unsupported tokens will be transferred to the caller
     *
     * requirements:
     *
     * - the caller must have approved the pair to transfer the liquidity on its behalf
     */
    function _migrateUniswapV2Position(
        IUniswapV2Router02 router,
        IUniswapV2Factory factory,
        Token token0,
        Token token1,
        uint256 amount
    ) private returns (MigrationResult memory) {
        // get uniswap's pair
        address pairAddress = factory.getPair(address(token0), address(token1));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        if (address(pair) == address(0)) {
            revert NoPairForTokens();
        }

        // transfer the tokens from the caller
        Token(address(pair)).safeTransferFrom(msg.sender, address(this), amount);

        // arrange tokens in an array
        Token[2] memory tokens = [token0, token1];

        // look for relevant whitelisted pools, revert if there are none
        bool[2] memory whitelist;
        for (uint256 i = 0; i < 2; i++) {
            if (address(tokens[i]) == address(_networkToken)) {
                whitelist[i] = true;
            } else {
                whitelist[i] = _networkSettings.isTokenWhitelisted(tokens[i]);
            }
        }
        if (!whitelist[0] && !whitelist[1]) {
            revert UnsupportedTokens();
        }

        // save state
        uint256[2] memory previousBalances = [tokens[0].balanceOf(address(pair)), tokens[1].balanceOf(address(pair))];

        // remove liquidity from uniswap
        _uniV2RemoveLiquidity(tokens, pair, router, amount);

        // save new state
        uint256[2] memory newBalances = [tokens[0].balanceOf(address(pair)), tokens[1].balanceOf(address(pair))];

        // migrate funds
        uint256[2] memory deposited;

        for (uint256 i = 0; i < 2; i++) {
            uint256 delta = previousBalances[i] - newBalances[i];
            if (whitelist[i]) {
                deposited[i] = delta;
                _deposit(tokens[i], deposited[i]);
            } else {
                deposited[i] = 0;
                _transferToWallet(tokens[i], delta);
            }
        }

        return
            MigrationResult({
                tokenA: address(tokens[0]),
                tokenB: address(tokens[1]),
                amountA: deposited[0],
                amountB: deposited[1]
            });
    }

    /**
     * @dev deposits [amount] into a pool of [token]
     */
    function _deposit(Token token, uint256 amount) private {
        if (token.isNative()) {
            _network.depositFor{ value: amount }(msg.sender, token, amount);
        } else {
            token.toIERC20().safeApprove(address(_network), amount);
            _network.depositFor(msg.sender, token, amount);
        }
    }

    /**
     * @dev transfer [amount] of [token] to the caller
     */
    function _transferToWallet(Token token, uint256 amount) private {
        if (token.isNative()) {
            payable(msg.sender).transfer(amount);
        } else {
            token.toIERC20().safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @dev removes liquidity from Uniswap's pair, transfer funds to self.
     */
    function _uniV2RemoveLiquidity(
        Token[2] memory tokens,
        IUniswapV2Pair pair,
        IUniswapV2Router02 router,
        uint256 amount
    ) private {
        IERC20(address(pair)).safeApprove(address(router), amount);

        uint256 deadline = block.timestamp + THREE_HOURS;
        if (tokens[0].isNative()) {
            router.removeLiquidityETH(address(tokens[1]), amount, 1, 1, address(this), deadline);
        } else if (tokens[1].isNative()) {
            router.removeLiquidityETH(address(tokens[0]), amount, 1, 1, address(this), deadline);
        } else {
            router.removeLiquidity(address(tokens[0]), address(tokens[1]), amount, 1, 1, address(this), deadline);
        }
    }

    /**
     * @dev returns whether the specified token is the network token
     */
    function _isNetworkToken(Token token) private view returns (bool) {
        return token.isEqual(_networkToken);
    }
}
