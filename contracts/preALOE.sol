// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Deployer.sol";

contract preALOE is ERC20 {
    Deployer DEPLOYER;

    address public multisig;

    address public merkleDistributor;

    bool public transfersAreLimited = true;

    constructor(
        Deployer _DEPLOYER,
        address _multisig,
        address _merkleDistributor
    ) ERC20("Pre-Aloe", "preALOE") {
        DEPLOYER = _DEPLOYER;
        multisig = _multisig;
        merkleDistributor = _merkleDistributor;

        // For community staking bot
        _mint(_multisig, 50_000 ether);
        // For boosted staking incentive
        _mint(_multisig, 22_000 ether);
        // For hackathon & quiz winners
        _mint(merkleDistributor, 10_000 ether);
    }

    function disableTransferLimits() external {
        require(msg.sender == multisig, "Not authorized");
        transfersAreLimited = false;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount); // Call parent hook

        if (transfersAreLimited && from != address(0) && to != address(0)) {
            require(
                from == multisig ||
                    from == merkleDistributor ||
                    DEPLOYER.doesMarketExist(from) ||
                    DEPLOYER.doesMarketExist(to),
                "Transfer blocked"
            );
        }
    }
}
