// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILearnWayAdmin {
    function hasRole(bytes32 role, address account) external view returns (bool);
}
