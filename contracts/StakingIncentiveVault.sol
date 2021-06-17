// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./AloePredictionsState.sol";

contract StakingIncentiveVault {
    address immutable multisig;

    struct Config {
        uint256 incentivePerEpoch;
        uint24 lastIncentivizedEpoch;
    }

    /// @dev A mapping from predictions address to token address to incentive config
    mapping(address => mapping(address => Config)) public configs;

    mapping(bytes32 => bool) public claimed;

    constructor(address _multisig) {
        multisig = _multisig;
    }

    function getClaimHash(address market, uint40 key, address token) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(market, key, token));
    }

    function didClaim(address market, uint40 key, address token) public view returns (bool) {
        return claimed[getClaimHash(market, key, token)];
    }

    function setClaimed(address market, uint40 key, address token) private {
        claimed[getClaimHash(market, key, token)] = true;
    }

    /**
     * @notice Allows owner to set incentive amounts on a per-token per-market basis
     * @param market The predictions market to incentivize
     * @param token The token in which incentives should be denominated
     * @param incentivePerEpoch The maximum number of tokens to give out each epoch
     * @param lastIncentivizedEpoch The last epoch for which these incentives apply
     */
    function setIncentive(
        address market,
        address token,
        uint256 incentivePerEpoch,
        uint24 lastIncentivizedEpoch
    ) private {
        require(msg.sender == multisig, "Not authorized");
        configs[market][token] = Config(incentivePerEpoch, lastIncentivizedEpoch);
    }

    /**
     * @notice Allows anyone to claim incentives for a proposal. Note that the baseline
     * proposal reward needs to have been claimed first (`market.claimReward(key)`)
     * @param market The predictions market containing the proposal in question
     * @param key The key of the proposal for which incentives should be claimed
     * @param tokens An array of tokens to claim
     */
    function claimIncentives(
        address market,
        uint40 key,
        address[] calldata tokens
    ) external {
        (
            address source,
            uint24 epoch,
            ,
            uint176 upper,
            uint80 stake
        ) = AloePredictionsState(market).proposals(key);
        require(stake != 0, "No stake");
        require(upper == 0, "Claim reward first");

        (, , Accumulators memory accumulators) = AloePredictionsState(market).summaries(epoch);
        uint256 stakeTotal = accumulators.stakeTotal;

        for (uint256 i = 0; i < tokens.length; i++) {
            Config storage config = configs[market][tokens[i]];
            if (config.lastIncentivizedEpoch < epoch) continue;
            if (didClaim(market, key, tokens[i])) continue;
            setClaimed(market, key, tokens[i]);

            require(
                IERC20(tokens[i]).transfer(
                    source,
                    (config.incentivePerEpoch * uint256(stake)) / stakeTotal
                ),
                "Failed transfer"
            );
        }
    }
}
