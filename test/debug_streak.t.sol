// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BadgesNFT.sol";
import "../src/LearnWayManager.sol";
import "../src/GemsContract.sol";
import "../src/XPContract.sol";

contract DebugStreakTest is Test {
    BadgesNFT public badgesContract;
    LearnWayManager public learnWayManager;
    GemsContract public gemsContract;
    XPContract public xpContract;

    address public owner;
    address public user1;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");

        // Deploy contracts
        badgesContract = new BadgesNFT("https://learnway.com/badges/");
        gemsContract = new GemsContract();
        gemsContract.setTestMode(true); // Enable test mode to bypass cooldowns
        xpContract = new XPContract();
        learnWayManager = new LearnWayManager();

        // Set up contract relationships
        learnWayManager.setContracts(
            address(gemsContract),
            address(xpContract),
            address(badgesContract)
        );
        badgesContract.setLearnWayManager(address(learnWayManager));

        // Transfer ownership of subsidiary contracts to LearnWayManager for proper access control
        gemsContract.transferOwnership(address(learnWayManager));
        xpContract.transferOwnership(address(learnWayManager));

        // Register test user
        learnWayManager.registerUser(user1, address(0), "TestUser1");
    }

    function testDebugDailyStreak() public {
        bool[] memory correctAnswers = new bool[](1);
        correctAnswers[0] = true;

        uint256 currentTime = block.timestamp;
        console.log("Starting timestamp:", currentTime);

        // Complete quiz for 5 consecutive days first to see the pattern
        for (uint i = 0; i < 5; i++) {
            uint256 newTime = currentTime + (i * 1 days);
            vm.warp(newTime);

            uint256 dayNumber = newTime / 1 days;
            console.log("=== Day iteration:", i);
            console.log("Timestamp:", newTime);
            console.log("Day number:", dayNumber);

            // Get streak before quiz
            (,,, uint256 streakBefore,) = badgesContract.getUserBadgeStatus(user1);
            console.log("Streak before quiz:", streakBefore);

            learnWayManager.completeQuiz(
                user1,
                80,
                correctAnswers,
                "general",
                30,
                false
            );

            // Get streak after quiz
            (bool[15] memory badges,,, uint256 streakAfter,) = badgesContract.getUserBadgeStatus(user1);
            console.log("Streak after quiz:", streakAfter);
            console.log("---");
        }
    }
}
