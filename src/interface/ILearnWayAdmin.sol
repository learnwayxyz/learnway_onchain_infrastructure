// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILearnWayAdmin {
    function checkAdmin() external view;
    function checkAdminOrManager() external view;
    function checkModerator() external view;
    function checkEmergency() external view;
}
