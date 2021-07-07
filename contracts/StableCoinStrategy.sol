// SPDX-License-Identifier: MIT
pragma solidity ^0.6.11;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/ModelInterface.sol";
import "../interfaces/ModelStorage.sol";
import "../interfaces/curve/ICurveExchange.sol";
import "../interfaces/curve/IRewardsOnlyGauge.sol";

// deposit()
// deposit DAI into CURVE SUSD Pool
// get back LP Tokens
// deposit LP Tokens into Reward Receiver


// harvest()
// claim CRV & SNX rewards
// convert CRV To DAI
// convert SNX to DAI

// tend()
// deposit idle DAI back into strategy

// withdraw()
// remove LP Tokens from reward receiver
// put LP tokens into CURVE SUSD Pool and take back DAI

contract StableCoinStrategy is ModelInterface, ModelStorage {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;


    // address public constant SUSD_POOL = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD;
    address public constant SUSD_POOL = 0xFCBa3E75865d2d561BE8D220616520c171F12851;
    address public constant CURVE_REWARDS_GAUGE = 0xA90996896660DEcC6E997655E065b23788857849;
    address public constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant LP = 0xC25a3A3b969415c80451098fa907EC722572917F;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    address public dai =  0x6B175474E89094C44Da98b954EedeAC495271d0F;

    function initialize() public {

        /// @dev do one off approvals here
        IERC20Upgradeable(dai).safeApprove(SUSD_POOL, type(uint256).max);
        IERC20Upgradeable(LP).safeApprove(CURVE_REWARDS_GAUGE, type(uint256).max);
    }

    /**
     * @dev Returns the balance held by the model without investing.
     */
    function underlyingBalanceInModel() public override view returns ( uint256 ) {
        return IERC20Upgradeable(dai).balanceOf(address(this));
    }

    /**
     * @dev Returns the sum of the invested amount and the amount held by the model without investing.
     */
    function underlyingBalanceWithInvestment() public override view returns ( uint256 ) {
        return underlyingBalanceInModel().add(IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).balanceOf(address(this)));
    }

    /**
     * @dev Invest uninvested amounts according to your strategy.
     *
     * Emits a {Invest} event.
     */
    function invest() public override {
        // deposit dai to curve pool
        ICurveExchange(SUSD_POOL).add_liquidity([underlyingBalanceInModel(), 0, 0, 0], 0);

        // stake the LP Tokens for CRV & SNX rewards
        IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).deposit(IERC20Upgradeable(LP).balanceOf(address(this)), address(this));
    }

    /**
     * @dev After withdrawing all the invested amount, all the balance is transferred to 'Forge'.
     *
     * IMPORTANT: Must use the "OnlyForge" Modifier from "ModelStorage.sol". 
     * 
     * Emits a {Withdraw} event.
     */
    function withdrawAllToForge() public OnlyForge override {

    }

    /**
     * @dev After withdrawing 'amount', send it to 'Forge'.
     *
     * IMPORTANT: Must use the "OnlyForge" Modifier from "ModelStorage.sol". 
     * 
     * Emits a {Withdraw} event.
     */
    function withdrawToForge( uint256 amount ) public OnlyForge override {

    }
    /**
     * @dev After withdrawing 'amount', send it to 'to'.
     *
     * IMPORTANT: Must use the "OnlyForge" Modifier from "ModelStorage.sol". 
     * 
     * Emits a {Withdraw} event.
     */
    function withdrawTo( uint256 amount, address to )  public OnlyForge override {

    }
}