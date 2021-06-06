// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAloePredictionEvents {
    event ProposalSubmitted(
        address indexed source,
        uint24 indexed epoch,
        uint40 idx,
        uint176 lower,
        uint176 upper,
        uint80 stake
    );

    event ProposalUpdated(
        address indexed source,
        uint24 indexed epoch,
        uint40 idx,
        uint176 lower,
        uint176 upper
    );

    event FetchedGroundTruth(uint176 lower, uint176 upper, bool shouldUseReciprocalNextRound);

    event Advanced(uint24 epoch, uint32 epochStartTime);

    event ClaimedReward(address indexed recipient, uint24 indexed epoch, uint40 idx, uint80 amount);
}
