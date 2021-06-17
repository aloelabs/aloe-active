// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingIncentiveVault {
    address immutable multisig;

    /// @dev A mapping from predictions address to token address to incentive per epoch (amount)
    mapping(address => mapping(address => uint256)) public incentivesPerEpoch;

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
     * @notice Allows owner to set incentive amounts on a per-token per-market basis
     * @param market The predictions market to incentivize
     * @param token The token in which incentives should be denominated
     * @param incentivePerEpoch The maximum number of tokens to give out each epoch
     */
    function setIncentive(
        address market,
        address token,
        uint256 incentivePerEpoch
    ) private {
        require(msg.sender == multisig, "Not authorized");
        incentivesPerEpoch[market][token] = incentivePerEpoch;
    }

    /**
     * @notice Allows a predictions contract to claim incentives on behalf of a user
     * @dev Should only be called once per proposal. And fails if vault has insufficient
     * funds to make good on incentives
     * @param key The key of the proposal for which incentives are being claimed
     * @param tokens An array of tokens for which incentives should be claimed
     * @param to The user to whom incentives should be sent
     * @param reward The preALOE reward earned by the user
     * @param stakeTotal The total amount of preALOE staked in the pertinent epoch
     */
    function claimIncentives(
        uint40 key,
        address[] calldata tokens,
        address to,
        uint80 reward,
        uint80 stakeTotal
    ) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 incentivePerEpoch = incentivesPerEpoch[msg.sender][tokens[i]];
            if (incentivePerEpoch == 0) continue;

            if (didClaim(msg.sender, key, tokens[i])) continue;
            setClaimed(msg.sender, key, tokens[i]);

            require(
                IERC20(tokens[i]).transfer(to, (incentivePerEpoch * uint256(reward)) / uint256(stakeTotal)),
                "Failed transfer"
            );
        }
    }
}
