// SPDX-License-Identifier: MIT
pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/ModelInterface.sol";
import "../interfaces/ModelStorage.sol";
import "../interfaces/curve/ICurveExchange.sol";
import "../interfaces/curve/IRewardsOnlyGauge.sol";
import "../interfaces/uniswap/ISwapRouter.sol";

contract StableCoinStrategy is ModelInterface, ModelStorage {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;


    address public constant SUSD_POOL = 0xFCBa3E75865d2d561BE8D220616520c171F12851;
    address public constant CURVE_REWARDS_GAUGE = 0xA90996896660DEcC6E997655E065b23788857849;
    address public constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant LP = 0xC25a3A3b969415c80451098fa907EC722572917F;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public constant SNX = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function initialize(
        address _token,
        address _forge
    ) public {

        addToken(_token);
        setForge(_forge);

        /// @dev do one off approvals here
        IERC20Upgradeable(token(0)).safeApprove(SUSD_POOL, type(uint256).max);
        IERC20Upgradeable(LP).safeApprove(SUSD_POOL, type(uint256).max);
        IERC20Upgradeable(LP).safeApprove(CURVE_REWARDS_GAUGE, type(uint256).max);

        IERC20Upgradeable(CRV).safeApprove(ROUTER, type(uint256).max);
        IERC20Upgradeable(SNX).safeApprove(ROUTER, type(uint256).max);
        IERC20Upgradeable(WETH).safeApprove(ROUTER, type(uint256).max);
    }

    /**
     * @dev Returns the balance held by the model without investing.
     */
    function underlyingBalanceInModel() public override view returns ( uint256 ) {
        return IERC20Upgradeable(token(0)).balanceOf(address(this));
    }

    /**
     * @dev Returns the sum of the invested amount and the amount held by the model without investing.
     */
    function underlyingBalanceWithInvestment() public override view returns ( uint256 ) {
        return underlyingBalanceInModel().add(IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).balanceOf(address(this)));
    }

    /// @dev Returns the total amount of LP tokens held by strategy
    function balanceOfPool() public view returns (uint256) {
        return IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).balanceOf(address(this));
    }

    /**
     * @dev Invest uninvested amounts according to your strategy.
     *
     * Emits a {Invest} event.
     */
    function invest() public override {
        uint256 _amount = underlyingBalanceInModel();
        // deposit token(0) to curve pool
        ICurveExchange(SUSD_POOL).add_liquidity([_amount, 0, 0, 0], 0);

        // stake the LP Tokens for CRV & SNX rewards
        IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).deposit(IERC20Upgradeable(LP).balanceOf(address(this)), address(this));

        emit Invest(_amount, block.timestamp);
    }

    /**
     * @dev After withdrawing all the invested amount, all the balance is transferred to 'Forge'.
     *
     * IMPORTANT: Must use the "OnlyForge" Modifier from "ModelStorage.sol". 
     * 
     * Emits a {Withdraw} event.
     */
    function withdrawAllToForge() public OnlyForge override {
        _claimRewards();
        _swapRewardsToDai();

        uint256 lpAmount = balanceOfPool();

        // first withdraw lp tokens from the rewards contract
        IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).withdraw(lpAmount, false);

        // then swap lp tokens to token(0)
        ICurveExchange(SUSD_POOL).remove_liquidity_one_coin(lpAmount, 0, 0, false);

        // transfer
        IERC20Upgradeable(token(0)).transfer(forge(), underlyingBalanceInModel());

        emit Withdraw(underlyingBalanceInModel(), forge(), block.timestamp);
    }

    /**
     * @dev After withdrawing 'amount', send it to 'Forge'.
     *
     * IMPORTANT: Must use the "OnlyForge" Modifier from "ModelStorage.sol". 
     * 
     * Emits a {Withdraw} event.
     */
    function withdrawToForge( uint256 amount ) public OnlyForge override {
        withdrawTo(amount, forge());
    }

    /**
     * @dev After withdrawing 'amount', send it to 'to'.
     *
     * IMPORTANT: Must use the "OnlyForge" Modifier from "ModelStorage.sol". 
     * 
     * Emits a {Withdraw} event.
     */
    function withdrawTo( uint256 amount, address to )  public OnlyForge  override {
        uint256 _pool = balanceOfPool();

        require (_pool > 0);

        if (amount > _pool) {
            amount = _pool;
        }

        uint256 prevBalance = IERC20Upgradeable(token(0)).balanceOf(address(this));

        // first withdraw lp tokens from the rewards contract
        IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).withdraw(amount, false);

        // then swap lp tokens to token(0)
        ICurveExchange(SUSD_POOL).remove_liquidity_one_coin(amount, 0, 0, false);

        uint256 newBalance = IERC20Upgradeable(token(0)).balanceOf(address(this));

        uint256 withdrawn= newBalance.sub(prevBalance);

        // transfer
        IERC20Upgradeable(token(0)).transfer(to, withdrawn);

        emit Withdraw(withdrawn, to, block.timestamp);
    }

    function reInvest() public {
        _claimRewards();
        _swapRewardsToDai();
        invest();
    }

    function _claimRewards() internal {
        IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).claim_rewards(address(this));
    }

    function _swapRewardsToDai() internal {
        uint256 crvRewards = IERC20Upgradeable(CRV).balanceOf(address(this));
        uint256 snxRewards = IERC20Upgradeable(SNX).balanceOf(address(this));

        if (crvRewards > 0) {
             // CRV => WETH => DAI
        bytes memory crvToDaiPath =
            abi.encodePacked(
                CRV,
                uint24(10000),
                WETH,
                uint24(10000),
                token(0)
            );

        ISwapRouter.ExactInputParams memory _crvToDaiParams =
            ISwapRouter.ExactInputParams(
                crvToDaiPath,
                address(this),
                now,
                crvRewards,
                0
            );
        ISwapRouter(ROUTER).exactInput(_crvToDaiParams);
        }

        if (snxRewards > 0) {
             // SNX => WETH => DAI
        bytes memory crvToSnxPath =
            abi.encodePacked(
                SNX,
                uint24(10000),
                WETH,
                uint24(10000),
                token(0)
            );

        ISwapRouter.ExactInputParams memory _crvToSnxParams =
            ISwapRouter.ExactInputParams(
                crvToSnxPath,
                address(this),
                now,
                snxRewards,
                0
            );
        ISwapRouter(ROUTER).exactInput(_crvToSnxParams);
        }
    }
}