// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/GemsContract.sol";

contract GemsContractTest is Test {
    GemsContract public gemsContract;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public referrer;

    event GemsAwarded(address indexed user, uint256 amount, string reason);
    event GemsSpent(address indexed user, uint256 amount, string reason);
    event ReferralRegistered(address indexed referrer, address indexed referee, uint256 bonus);
    event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned);
    event ContestReward(address indexed user, uint256 amount, string contestType);
    event MonthlyLeaderboardReward(address indexed user, uint256 position, uint256 amount);
    event MonthlyLeaderboardReset(uint256 indexed month, uint256 indexed year, uint256 timestamp);
    event MonthlyRewardsDistributed(uint256 indexed month, uint256 indexed year, address[] topUsers, uint256[] rewards);
    event WeeklyLeaderboardReward(address indexed user, uint256 position, uint256 amount);
    event WeeklyLeaderboardReset(uint256 indexed week, uint256 indexed year, uint256 timestamp);
    event WeeklyRewardsDistributed(uint256 indexed week, uint256 indexed year, address[] topUsers, uint256[] rewards);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        referrer = makeAddr("referrer");

        gemsContract = new GemsContract();
        gemsContract.setTestMode(true); // Enable test mode to bypass cooldowns
    }

    // Test user registration with referral codes
    function testUserRegistrationWithReferralCode() public {
        // First register the referrer
        gemsContract.registerUser(referrer, address(0));

        // Check referrer received signup bonus
        assertEq(gemsContract.balanceOf(referrer), 500); // NEW_USER_SIGNUP_BONUS
        assertTrue(gemsContract.isRegistered(referrer));

        // Register user1 with referrer
        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(referrer, user1, 100);

        gemsContract.registerUser(user1, referrer);

        // Check user1 received signup bonus + referral bonus
        assertEq(gemsContract.balanceOf(user1), 550); // NEW_USER_SIGNUP_BONUS + REFERRAL_SIGNUP_BONUS

        // Check referrer received additional referral bonus
        assertEq(gemsContract.balanceOf(referrer), 600); // 500 + REFERRAL_BONUS

        // Check referral relationship
        assertEq(gemsContract.getReferrer(user1), referrer);
        assertEq(gemsContract.getReferralCount(referrer), 1);
    }

    // Test user registration without referral codes
    function testUserRegistrationWithoutReferralCode() public {
        vm.expectEmit(true, false, false, true);
        emit GemsAwarded(user1, 500, "New user signup bonus");

        gemsContract.registerUser(user1, address(0));

        assertEq(gemsContract.balanceOf(user1), 500); // NEW_USER_SIGNUP_BONUS only
        assertTrue(gemsContract.isRegistered(user1));
        assertTrue(gemsContract.hasReceivedSignupBonus(user1));
        assertEq(gemsContract.getReferrer(user1), address(0));
    }

    // Test dynamic quiz reward calculations with various scores
    function testDynamicQuizRewardCalculation() public {
        gemsContract.registerUser(user1, address(0));

        // Skip cooldown period before first quiz gems award
        vm.warp(block.timestamp + 61); // Skip 61 seconds to avoid cooldown

        // Test score below minimum (70%)
        vm.expectEmit(true, false, false, true);
        emit QuizCompleted(user1, 69, 0);
        gemsContract.awardQuizGems(user1, 69);
        assertEq(gemsContract.balanceOf(user1), 500); // Only signup bonus

        // Skip cooldown period before next award
        vm.warp(block.timestamp + 61);

        // Test score at minimum (70%)
        gemsContract.awardQuizGems(user1, 70);
        assertEq(gemsContract.balanceOf(user1), 500); // 70 - 70 = 0 gems

        // Skip cooldown period before next award
        vm.warp(block.timestamp + 61);

        // Test score above minimum (85%)
        vm.expectEmit(true, false, false, true);
        emit QuizCompleted(user1, 85, 30); // (85 - 70) * 2 = 30
        gemsContract.awardQuizGems(user1, 85);
        assertEq(gemsContract.balanceOf(user1), 530); // 500 + 30

        // Skip cooldown period before next award
        vm.warp(block.timestamp + 61);

        // Test maximum score (100%)
        gemsContract.awardQuizGems(user1, 100);
        assertEq(gemsContract.balanceOf(user1), 590); // 530 + 60 gems (100-70)*2

        // Skip cooldown period before next award
        vm.warp(block.timestamp + 61);

        // Test invalid score
        vm.expectRevert("Invalid score");
        gemsContract.awardQuizGems(user1, 101);
    }

    // Test contest and battle gem awards
    function testContestAndBattleGemAwards() public {
        gemsContract.registerUser(user1, address(0));

        // Test contest reward
        vm.expectEmit(true, false, false, true);
        emit ContestReward(user1, 100, "weekly_challenge");
        gemsContract.awardContestGems(user1, 100, "weekly_challenge");
        assertEq(gemsContract.balanceOf(user1), 600); // 500 + 100

        // Test zero amount should revert
        vm.expectRevert("Amount must be greater than 0");
        gemsContract.awardContestGems(user1, 0, "test");
    }

    // Test monthly leaderboard reward distribution
    function testMonthlyLeaderboardRewardDistribution() public {
        gemsContract.registerUser(user1, address(0));
        gemsContract.registerUser(user2, address(0));
        gemsContract.registerUser(user3, address(0));

        // Test individual monthly leaderboard reward
        vm.expectEmit(true, false, false, true);
        emit MonthlyLeaderboardReward(user1, 1, 1000);
        gemsContract.awardMonthlyLeaderboardReward(user1, 1);
        assertEq(gemsContract.balanceOf(user1), 1500); // 500 + 1000

        // Test invalid position
        vm.expectRevert("Invalid leaderboard position");
        gemsContract.awardMonthlyLeaderboardReward(user1, 0);

        vm.expectRevert("Invalid leaderboard position");
        gemsContract.awardMonthlyLeaderboardReward(user1, 4);

        // Test monthly leaderboard reset
        vm.expectEmit(true, true, false, true);
        emit MonthlyLeaderboardReset(9, 2025, block.timestamp);
        gemsContract.resetMonthlyLeaderboard(9, 2025);

        assertTrue(gemsContract.isMonthlyLeaderboardReset(9, 2025));

        // Test can't reset same month twice
        vm.expectRevert("Already reset for this month");
        gemsContract.resetMonthlyLeaderboard(9, 2025);

        // Test batch monthly reward distribution
        address[] memory topUsers = new address[](3);
        uint256[] memory rewards = new uint256[](3);
        topUsers[0] = user1;
        topUsers[1] = user2;
        topUsers[2] = user3;
        rewards[0] = 1000;
        rewards[1] = 500;
        rewards[2] = 250;

        vm.expectEmit(true, true, false, true);
        emit MonthlyRewardsDistributed(9, 2025, topUsers, rewards);
        gemsContract.distributeMonthlyRewards(9, 2025, topUsers, rewards);

        // Check balances updated
        assertEq(gemsContract.balanceOf(user1), 2500); // 1500 + 1000
        assertEq(gemsContract.balanceOf(user2), 1000); // 500 + 500
        assertEq(gemsContract.balanceOf(user3), 750); // 500 + 250

        // Check reward history
        address[] memory history = gemsContract.getMonthlyRewardHistory(9, 2025);
        assertEq(history.length, 3);
        assertEq(history[0], user1);
        assertEq(history[1], user2);
        assertEq(history[2], user3);
    }

    // Test gem spending functionality
    function testGemSpendingFunctionality() public {
        gemsContract.registerUser(user1, address(0));

        // Test spending gems
        vm.expectEmit(true, false, false, true);
        emit GemsSpent(user1, 100, "Purchase item");
        gemsContract.spendGems(user1, 100, "Purchase item");
        assertEq(gemsContract.balanceOf(user1), 400); // 500 - 100

        // Test insufficient balance
        vm.expectRevert("Insufficient gem balance");
        gemsContract.spendGems(user1, 500, "Too much");
    }

    // Test access control and ownership functions
    function testAccessControlAndOwnership() public {
        // Test only owner can register users
        vm.prank(user1);
        vm.expectRevert();
        gemsContract.registerUser(user2, address(0));

        // Test only owner can award gems
        vm.prank(user1);
        vm.expectRevert();
        gemsContract.awardQuizGems(user1, 85);

        // Test only owner can spend gems
        vm.prank(user1);
        vm.expectRevert();
        gemsContract.spendGems(user1, 100, "test");
    }

    // Test pause/unpause functionality
    function testPauseUnpauseFunctionality() public {
        gemsContract.registerUser(user1, address(0));

        // Pause contract
        gemsContract.pause();

        // Test operations fail when paused
        vm.expectRevert();
        gemsContract.registerUser(user2, address(0));

        vm.expectRevert();
        gemsContract.awardQuizGems(user1, 85);

        vm.expectRevert();
        gemsContract.spendGems(user1, 100, "test");

        // Unpause contract
        gemsContract.unpause();

        // Test operations work after unpause
        gemsContract.registerUser(user2, address(0));
        assertEq(gemsContract.balanceOf(user2), 500);
    }

    // Test lesson reward system
    function testLessonRewardSystem() public {
        gemsContract.registerUser(user1, address(0));

        // Set lesson rewards
        gemsContract.setLessonReward("video", 20, 60);
        gemsContract.setLessonReward("reading", 15, 70);
        gemsContract.setLessonReward("exercise", 25, 80);

        // Check lesson rewards are set
        assertEq(gemsContract.lessonRewards("video"), 20);
        assertEq(gemsContract.lessonMinScores("video"), 60);

        // Award lesson gems above minimum score
        gemsContract.awardLessonGems(user1, "video", 75);
        assertEq(gemsContract.balanceOf(user1), 520); // 500 + 20

        // Award lesson gems below minimum score (should not award)
        uint256 balanceBefore = gemsContract.balanceOf(user1);
        gemsContract.awardLessonGems(user1, "reading", 65); // Below 70 minimum
        assertEq(gemsContract.balanceOf(user1), balanceBefore); // No change

        // Test unconfigured lesson type
        vm.expectRevert("Lesson type not configured");
        gemsContract.awardLessonGems(user1, "unknown", 100);

        // Test batch lesson reward configuration
        string[] memory lessonTypes = new string[](2);
        uint256[] memory rewards = new uint256[](2);
        uint256[] memory minScores = new uint256[](2);

        lessonTypes[0] = "quiz";
        lessonTypes[1] = "project";
        rewards[0] = 30;
        rewards[1] = 50;
        minScores[0] = 75;
        minScores[1] = 85;

        gemsContract.batchSetLessonRewards(lessonTypes, rewards, minScores);

        assertEq(gemsContract.lessonRewards("quiz"), 30);
        assertEq(gemsContract.lessonMinScores("project"), 85);
    }

    // Test weekly leaderboard functionality
    function testWeeklyLeaderboardFunctionality() public {
        gemsContract.registerUser(user1, address(0));

        // Test weekly leaderboard reset
        gemsContract.resetWeeklyLeaderboard(36, 2025);
        assertTrue(gemsContract.isWeeklyLeaderboardReset(36, 2025));

        // Test weekly reward distribution
        address[] memory topUsers = new address[](1);
        uint256[] memory rewards = new uint256[](1);
        topUsers[0] = user1;
        rewards[0] = 200;

        gemsContract.distributeWeeklyRewards(36, 2025, topUsers, rewards);

        assertEq(gemsContract.balanceOf(user1), 700); // 500 + 200

        // Test individual weekly reward
        gemsContract.awardWeeklyLeaderboardReward(user1, 2);
        assertEq(gemsContract.balanceOf(user1), 800); // 700 + 100 (2nd place)
    }

    // Test batch operations functionality
    function testBatchOperationsFunctionality() public {
        gemsContract.registerUser(user1, address(0));
        gemsContract.registerUser(user2, address(0));
        gemsContract.registerUser(user3, address(0));

        address[] memory users = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        amounts[0] = 100;
        amounts[1] = 150;
        amounts[2] = 200;

        gemsContract.batchAwardGems(users, amounts, "Batch reward");

        assertEq(gemsContract.balanceOf(user1), 600); // 500 + 100
        assertEq(gemsContract.balanceOf(user2), 650); // 500 + 150
        assertEq(gemsContract.balanceOf(user3), 700); // 500 + 200
    }

    // Test edge cases and error conditions
    function testEdgeCasesAndErrorConditions() public {
        // Test registering with invalid address
        vm.expectRevert("Invalid address");
        gemsContract.registerUser(address(0), address(0));

        // Test awarding gems to unregistered user
        vm.warp(block.timestamp + 61); // Skip cooldown period to reach user validation
        vm.expectRevert("User not registered");
        gemsContract.awardQuizGems(user1, 85);

        // Test double registration
        gemsContract.registerUser(user1, address(0));
        vm.expectRevert("User already registered");
        gemsContract.registerUser(user1, address(0));

        // Test self-referral
        gemsContract.registerUser(user2, user2); // Should not give referral bonus to self
        assertEq(gemsContract.balanceOf(user2), 500); // Only signup bonus

        // Test invalid month/year for leaderboard
        vm.expectRevert("Invalid month");
        gemsContract.resetMonthlyLeaderboard(0, 2025);

        vm.expectRevert("Invalid month");
        gemsContract.resetMonthlyLeaderboard(13, 2025);

        vm.expectRevert("Invalid year");
        gemsContract.resetMonthlyLeaderboard(9, 2023);

        // Test invalid week for weekly leaderboard
        vm.expectRevert("Invalid week");
        gemsContract.resetWeeklyLeaderboard(0, 2025);

        vm.expectRevert("Invalid week");
        gemsContract.resetWeeklyLeaderboard(53, 2025);
    }

    // Test total supply tracking
    function testTotalSupplyTracking() public {
        uint256 initialSupply = gemsContract.totalSupply();
        assertEq(initialSupply, 0);

        // Register users and check supply increases
        gemsContract.registerUser(user1, address(0));
        assertEq(gemsContract.totalSupply(), 500);

        gemsContract.registerUser(user2, user1);
        assertEq(gemsContract.totalSupply(), 1150); // 500 + 500 + 50 + 100

        // Award gems and check supply increases
        vm.warp(block.timestamp + 61); // Skip cooldown period
        gemsContract.awardQuizGems(user1, 85);
        assertEq(gemsContract.totalSupply(), 1180); // 1150 + 30

        // Spend gems and check supply decreases
        gemsContract.spendGems(user1, 100, "Purchase");
        assertEq(gemsContract.totalSupply(), 1080); // 1180 - 100
    }
}
