// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../../src/LearnWayCertificate.sol";

contract MockNonUUPS {}

contract MockLearnWayCertificateV2 is LearnWayCertificate {
    uint256 public newV2Variable;

    function initializeV2(uint256 _val) public reinitializer(2) {
        newV2Variable = _val;
    }
}
