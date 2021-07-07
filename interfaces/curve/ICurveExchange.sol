//  SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface ICurveExchange {
    function add_liquidity(uint256[4] calldata uamounts, uint256 min_mint_amount) external;
}

interface ICurveRegistryAddressProvider {
    function get_address(uint256 id) external returns (address);
}

interface ICurveRegistryExchange {
    function get_best_rate(
        address from,
        address to,
        uint256 amount
    ) external view returns (address, uint256);

    function exchange(
        address pool,
        address from,
        address to,
        uint256 amount,
        uint256 expected,
        address receiver
    ) external payable returns (uint256);
}