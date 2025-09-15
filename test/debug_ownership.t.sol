// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LearnWayManager.sol";
import "../src/GemsContract.sol";
import "../src/XPContract.sol";

contract MockBadgesNFT {
    function recordQuizCompletion(address, string memory, uint256, bool, bool, uint256) external {}
    function recordBattleCompletion(address, string memory, bool, uint256, bool) external {}
    function recordContestWin(address) external {}
    function updateReferralCount(address, uint256) external {}
    function awardEliteBadge(address) external {}

    function getUserBadgeStatus(address) external view returns (bool[15] memory, uint256, uint256, uint256, uint256) {
        bool[15] memory badges;
        return (badges, 0, 0, 0, 0);
    }
}

contract DebugOwnershipTest is Test {
    LearnWayManager public manager;
    GemsContract public gemsContract;
    XPContract public xpContract;
    MockBadgesNFT public badgesContract;

    address public testUser;

    function setUp() public {
        testUser = makeAddr("testUser");

        // Deploy contracts
        gemsContract = new GemsContract();
        xpContract = new XPContract();
        badgesContract = new MockBadgesNFT();
        manager = new LearnWayManager();

        console.log("Test contract address:", address(this));
        console.log("Manager owner:", manager.owner());
        console.log("GemsContract owner:", gemsContract.owner());
        console.log("XPContract owner:", xpContract.owner());
    }

    function testOwnershipDebug() public {
        // Check who owns what
        assertEq(manager.owner(), address(this), "Manager should be owned by test contract");
        assertEq(gemsContract.owner(), address(this), "GemsContract should be owned by test contract");
        assertEq(xpContract.owner(), address(this), "XPContract should be owned by test contract");

        // Set up contracts
        manager.setContracts(address(gemsContract), address(xpContract), address(badgesContract));

        // Grant roles
        gemsContract.grantRole(gemsContract.MANAGER_ROLE(), address(manager));
        xpContract.transferOwnership(address(manager));

        console.log("After setup - XPContract owner:", xpContract.owner());

        // Try to register user - this should work
        manager.registerUser(testUser, address(0), "testUser");

        assertTrue(gemsContract.isRegistered(testUser), "User should be registered");
    }
}
