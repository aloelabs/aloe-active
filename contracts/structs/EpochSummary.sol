// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./Accumulators.sol";
import "./Bounds.sol";

struct EpochSummary {
    Bounds groundTruth;
    Bounds aggregate;
    Accumulators accumulators;
}
