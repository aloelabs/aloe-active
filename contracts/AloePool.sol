// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./AloePoolERC20.sol";

contract AloePool is AloePoolERC20 {
    using SafeERC20 for IERC20;

    IUniswapV3Pool public immutable UNI_POOL;

    IERC20 public immutable token0;

    IERC20 public immutable token1;

    int24 public tickLower;

    int24 public tickUpper;

    uint128 public liquidity;

    uint128 public amountOnAuction0;

    uint128 public amountOnAuction1;

    constructor(IUniswapV3Pool _UNI_POOL) {
        UNI_POOL = _UNI_POOL;

        token0 = IERC20(_UNI_POOL.token0());
        token1 = IERC20(_UNI_POOL.token1());
    }

    function mint(address to) external {
        uint256 amountDeposited0 = token0.balanceOf(address(this));
        uint256 amountDeposited1 = token1.balanceOf(address(this));

        UNI_POOL.burn(tickLower, tickUpper, liquidity);

        (uint128 _liquidity, , , uint128 amountOld0, uint128 amountOld1) =
            UNI_POOL.positions(keccak256(abi.encodePacked(address(this), tickLower, tickUpper)));

        require(_liquidity == 0);

        amountOld0 += amountOnAuction0;
        amountOld1 += amountOnAuction1;

        uint256 numLPTokens = min(amountDeposited0, (amountDeposited1 * amountOld0) / amountOld1);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256 c) {
        return a < b ? a : b;
    }
}
