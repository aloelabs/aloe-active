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
        // 1. Validate inputs
        ensureValidProposal(stake, lower, upper);

        // 2. Get proposal from storage
        // Doesn't exist yet

        // 3. Handle transfers
        require(ALOE.transferFrom(msg.sender, address(this), stake), "Aloe: Provide ALOE");

        // 4. Update accumulators
        accumulators.proposalCount++;
        accumulate(stake, lower, upper);

        // 5. Update proposals
        idx = nextProposalIdx;
        require(idx < type(uint40).max, "Aloe: Contract full");
        proposals[idx] = Proposal(msg.sender, epoch, lower, upper, stake);
        nextProposalIdx++;
    }

    function _updateProposal(
        uint80 stake,
        uint176 lower,
        uint176 upper,
        uint24 epoch,
        uint40 idx
    ) internal {
        // 1. Validate inputs
        ensureValidProposal(stake, lower, upper);

        // 2. Get proposal from storage
        Proposal storage proposal = proposals[idx];
        ensurePermissionToChange(proposal, epoch);

        // 3. Handle transfers
        if (stake > proposal.stake) {
            require(ALOE.transferFrom(msg.sender, address(this), stake - proposal.stake), "Aloe: Provide ALOE");
        } else if (stake < proposal.stake) {
            require(ALOE.transfer(msg.sender, proposal.stake - stake), "Aloe: Failed ALOE refund");
        }

        // 4. Update accumulators
        unaccumulate(proposal.stake, proposal.lower, proposal.upper);
        accumulate(stake, lower, upper);

        // 5. Update proposals
        proposal.stake = stake;
        proposal.lower = lower;
        proposal.upper = upper;
    }

    function _removeProposal(uint24 epoch, uint40 idx) internal {
        // 1. Validate inputs
        // No new stake/lower/upper to validate

        // 2. Get proposal from storage
        Proposal storage proposal = proposals[idx];
        ensurePermissionToChange(proposal, epoch);

        // 3. Handle transfers
        require(ALOE.transfer(msg.sender, proposal.stake), "Aloe: Failed ALOE refund");

        // 4. Update accumulators
        accumulators.proposalCount--;
        unaccumulate(proposal.stake, proposal.lower, proposal.upper);

        // 5. Update proposals
        delete proposals[idx];
    }

    function ensureValidProposal(
        uint80 stake,
        uint176 lower,
        uint176 upper
    ) private pure {
        require(stake != 0, "Aloe: Need stake");
        require(lower < upper, "Aloe: Impossible bounds");
    }

    function ensurePermissionToChange(Proposal storage proposal, uint24 epoch) private view {
        require(proposal.source == msg.sender, "Aloe: Not yours");
        require(proposal.epoch == epoch, "Aloe: Not fluid");
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
