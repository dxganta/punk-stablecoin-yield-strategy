//  SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface ICurveExchange {
    function add_liquidity(uint256[4] calldata uamounts, uint256 min_mint_amount) external;
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_uamount, bool donate_dust) external;
}