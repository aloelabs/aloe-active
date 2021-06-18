// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract IncentiveVault {
    address immutable multisig;

    /// @dev A mapping from predictions address to token address to incentive per epoch (amount)
    mapping(address => mapping(address => uint256)) public stakingIncentivesPerEpoch;

    /// @dev A mapping from predictions address to token address to incentive per advance (amount)
    mapping(address => mapping(address => uint256)) public advanceIncentives;

    mapping(bytes32 => bool) public claimed;

    constructor(address _multisig) {
        multisig = _multisig;
    }

    function getClaimHash(
        address market,
        uint40 key,
        address token
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(market, key, token));
    }

    function didClaim(
        address market,
        uint40 key,
        address token
    ) public view returns (bool) {
        return claimed[getClaimHash(market, key, token)];
    }

    function setClaimed(
        address market,
        uint40 key,
        address token
    ) private {
        claimed[getClaimHash(market, key, token)] = true;
    }

    function transfer(address to, address token) external {
        require(msg.sender == multisig, "Not authorized");
        require(IERC20(token).transfer(to, IERC20(token).balanceOf(address(this))), "Failed transfer");
    }

    /**
     * @notice Allows owner to set staking incentive amounts on a per-token per-market basis
     * @param market The predictions market to incentivize
     * @param token The token in which incentives should be denominated
     * @param incentivePerEpoch The maximum number of tokens to give out each epoch
     */
    function setStakingIncentive(
        address market,
        address token,
        uint256 incentivePerEpoch
    ) private {
        require(msg.sender == multisig, "Not authorized");
        stakingIncentivesPerEpoch[market][token] = incentivePerEpoch;
    }

    /**
     * @notice Allows a predictions contract to claim staking incentives on behalf of a user
     * @dev Should only be called once per proposal. And fails if vault has insufficient
     * funds to make good on incentives
     * @param key The key of the proposal for which incentives are being claimed
     * @param tokens An array of tokens for which incentives should be claimed
     * @param to The user to whom incentives should be sent
     * @param reward The preALOE reward earned by the user
     * @param stakeTotal The total amount of preALOE staked in the pertinent epoch
     */
    function claimStakingIncentives(
        uint40 key,
        address[] calldata tokens,
        address to,
        uint80 reward,
        uint80 stakeTotal
    ) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 incentivePerEpoch = stakingIncentivesPerEpoch[msg.sender][tokens[i]];
            if (incentivePerEpoch == 0) continue;

            if (didClaim(msg.sender, key, tokens[i])) continue;
            setClaimed(msg.sender, key, tokens[i]);

            require(
                IERC20(tokens[i]).transfer(to, (incentivePerEpoch * uint256(reward)) / uint256(stakeTotal)),
                "Failed transfer"
            );
        }
    }

    /**
     * @notice Allows owner to set advance incentive amounts on a per-market basis
     * @param market The predictions market to incentivize
     * @param token The token in which incentives should be denominated
     * @param amount The number of tokens to give out on each `advance()`
     */
    function setAdvanceIncentive(
        address market,
        address token,
        uint80 amount
    ) private {
        require(msg.sender == multisig, "Not authorized");
        advanceIncentives[market][token] = amount;
    }

    /**
     * @notice Allows a predictions contract to claim advance incentives on behalf of a user
     * @param token The token for which incentive should be claimed
     * @param to The user to whom incentive should be sent
     */
    function claimAdvanceIncentive(address token, address to) external {
        uint256 amount = advanceIncentives[msg.sender][token];
        if (amount == 0) return;

        require(IERC20(token).transfer(to, amount), "Failed transfer");
    }
}