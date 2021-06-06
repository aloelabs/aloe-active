// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./libraries/Equations.sol";
import "./libraries/UINT512.sol";

import "./structs/Accumulators.sol";
import "./structs/Proposal.sol";

contract AloeProposalLedger {
    using SafeERC20 for IERC20;

    using UINT512Math for UINT512;

    IERC20 public immutable ALOE;

    mapping(uint40 => Proposal) public proposals;

    Accumulators public accumulators;

    uint40 public nextProposalIdx = 0;

    constructor(IERC20 _ALOE) {
        ALOE = _ALOE;
    }

    /**
     * `lower` and `upper` are Q128.48, uint176
     *
     * This means that (after square-rooting), they produce sqrtPriceX96 values in range
     *      [2 ** +72, 2 ** +160]
     * This corresponds to floating point range
     *      [2 ** -24, 2 ** +64]
     *
     * When scoring a round, this contract will check if the TWAP of sqrtPriceX96 < 2 ** +80.
     * If it is, then proposals' lower & upper bounds in the _next_ round should be submitted
     * as the price of token1 : token0 rather than token0 : token1.
     *
     */
    function _submitProposal(
        uint80 stake,
        uint176 lower,
        uint176 upper,
        uint24 epoch
    ) internal returns (uint40 idx) {
        require(stake != 0, "Aloe: Need stake");
        require(lower < upper, "Aloe: Impossible bounds");

        require(ALOE.transferFrom(msg.sender, address(this), stake), "Aloe: Provide ALOE");

        accumulators.proposalCount++;
        accumulate(stake, lower, upper);

        idx = nextProposalIdx;
        proposals[idx] = Proposal(msg.sender, epoch, lower, upper, stake);
        nextProposalIdx++;
    }

    function _updateProposal(
        uint40 idx,
        uint176 lower,
        uint176 upper,
        uint24 epoch
    ) internal {
        require(lower < upper, "Aloe: Impossible bounds");

        Proposal storage proposal = proposals[idx];
        require(proposal.source == msg.sender, "Aloe: Not yours");
        require(proposal.epoch == epoch, "Aloe: Not fluid");

        unaccumulate(proposal.stake, proposal.lower, proposal.upper);
        accumulate(proposal.stake, lower, upper);

        proposal.lower = lower;
        proposal.upper = upper;
    }

    function accumulate(
        uint80 stake,
        uint176 lower,
        uint176 upper
    ) private {
        unchecked {
            accumulators.stakeTotal += stake;
            accumulators.stake1stMomentRaw += uint256(stake) * ((uint256(lower) + uint256(upper)) >> 1);
            accumulators.sumOfLowerBounds += lower;
            accumulators.sumOfUpperBounds += upper;
            accumulators.sumOfLowerBoundsWeighted += uint256(stake) * uint256(lower);
            accumulators.sumOfUpperBoundsWeighted += uint256(stake) * uint256(upper);

            (uint256 LS0, uint256 MS0, uint256 LS1, uint256 MS1) = Equations.eqn0(stake, lower, upper);

            // update each storage slot only once
            accumulators.sumOfSquaredBounds.iadd(LS0, MS0);
            accumulators.sumOfSquaredBoundsWeighted.iadd(LS1, MS1);
        }
    }

    function unaccumulate(
        uint80 stake,
        uint176 lower,
        uint176 upper
    ) private {
        unchecked {
            accumulators.stakeTotal -= stake;
            accumulators.stake1stMomentRaw -= uint256(stake) * ((uint256(lower) + uint256(upper)) >> 1);
            accumulators.sumOfLowerBounds -= lower;
            accumulators.sumOfUpperBounds -= upper;
            accumulators.sumOfLowerBoundsWeighted -= uint256(stake) * uint256(lower);
            accumulators.sumOfUpperBoundsWeighted -= uint256(stake) * uint256(upper);

            (uint256 LS0, uint256 MS0, uint256 LS1, uint256 MS1) = Equations.eqn0(stake, lower, upper);

            // update each storage slot only once
            accumulators.sumOfSquaredBounds.isub(LS0, MS0);
            accumulators.sumOfSquaredBoundsWeighted.isub(LS1, MS1);
        }
    }
}
