// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/XPContract.sol";

contract XPContractTest is Test {
    XPContract public xpContract;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    event XPAwarded(address indexed user, uint256 amount, string reason);
    event XPDeducted(address indexed user, uint256 amount, string reason);
    event QuizAnswered(address indexed user, bool isCorrect, uint256 xpChange);
    event ContestParticipation(address indexed user, uint256 xpEarned, string contestType);
    event BattleResult(address indexed user, uint256 xpChange, string battleType, bool isWin);
    event LeaderboardUpdated(address indexed user, uint256 newXP, uint256 newRank);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        xpContract = new XPContract();
    }

    // Test user registration and XP initialization
    function testUserRegistrationAndXPInitialization() public {
        xpContract.registerUser(user1);

        assertTrue(xpContract.isRegistered(user1));
        assertEq(xpContract.getXP(user1), 0);
        assertEq(xpContract.getUserRank(user1), 1); // First user gets rank 1

        XPContract.UserStats memory stats = xpContract.getUserStats(user1);
        assertEq(stats.totalXP, 0);
        assertEq(stats.correctAnswers, 0);
        assertEq(stats.incorrectAnswers, 0);
        assertEq(stats.contestsParticipated, 0);
        assertEq(stats.battlesWon, 0);
        assertEq(stats.battlesLost, 0);
        assertEq(stats.currentRank, 1);
        assertTrue(stats.lastActivityTimestamp > 0);

        assertEq(xpContract.getTotalUsers(), 1);

        // Test double registration
        vm.expectRevert("User already registered");
        xpContract.registerUser(user1);
    }

    // Test quiz answer recording (correct/incorrect)
    function testQuizAnswerRecording() public {
        xpContract.registerUser(user1);

        // Test correct answer
        vm.expectEmit(true, false, false, true);
        emit QuizAnswered(user1, true, 4);
        xpContract.recordQuizAnswer(user1, true);

        assertEq(xpContract.getXP(user1), 4); // correctAnswerXP = 4
        XPContract.UserStats memory stats = xpContract.getUserStats(user1);
        assertEq(stats.correctAnswers, 1);
        assertEq(stats.incorrectAnswers, 0);

        // Test incorrect answer
        vm.expectEmit(true, false, false, true);
        emit QuizAnswered(user1, false, 2);
        xpContract.recordQuizAnswer(user1, false);

        assertEq(xpContract.getXP(user1), 2); // 4 - 2 = 2
        stats = xpContract.getUserStats(user1);
        assertEq(stats.correctAnswers, 1);
        assertEq(stats.incorrectAnswers, 1);

        // Test incorrect answer when XP would go below 0
        xpContract.recordQuizAnswer(user1, false); // XP = 0 (2 - 2)
        xpContract.recordQuizAnswer(user1, false); // XP stays 0 (can't go negative)
        assertEq(xpContract.getXP(user1), 0);

        // Test with unregistered user
        vm.expectRevert("User not registered");
        xpContract.recordQuizAnswer(user2, true);
    }

    // Test contest participation XP awards
    function testContestParticipationXPAwards() public {
        xpContract.registerUser(user1);

        // Test contest participation
        vm.expectEmit(true, false, false, true);
        emit ContestParticipation(user1, 100, "weekly_challenge");
        xpContract.recordContestParticipation(user1, "weekly_challenge", 100);

        assertEq(xpContract.getXP(user1), 100);
        XPContract.UserStats memory stats = xpContract.getUserStats(user1);
        assertEq(stats.contestsParticipated, 1);

        // Test multiple contests
        xpContract.recordContestParticipation(user1, "monthly_contest", 200);
        assertEq(xpContract.getXP(user1), 300);
        stats = xpContract.getUserStats(user1);
        assertEq(stats.contestsParticipated, 2);

        // Test same contest multiple times
        xpContract.recordContestParticipation(user1, "weekly_challenge", 50);
        assertEq(xpContract.getXP(user1), 350);

        // Test contest leaderboard
        (address[] memory participants, uint256[] memory xpScores) =
            xpContract.getContestLeaderboard("weekly_challenge");
        assertEq(participants.length, 1);
        assertEq(participants[0], user1);
        assertEq(xpScores[0], 150); // 100 + 50 from weekly_challenge

        // Test with unregistered user
        vm.expectRevert("User not registered");
        xpContract.recordContestParticipation(user2, "test", 100);
    }

    // Test battle result recording and XP changes
    function testBattleResultRecording() public {
        xpContract.registerUser(user1);

        // Test battle win with default XP
        vm.expectEmit(true, false, false, true);
        emit BattleResult(user1, 50, "1v1", true);
        xpContract.recordBattleResult(user1, "1v1", true, 0);

        assertEq(xpContract.getXP(user1), 50); // battleWinXP = 50
        XPContract.UserStats memory stats = xpContract.getUserStats(user1);
        assertEq(stats.battlesWon, 1);
        assertEq(stats.battlesLost, 0);

        // Test battle loss with default XP
        vm.expectEmit(true, false, false, true);
        emit BattleResult(user1, 10, "group", false);
        xpContract.recordBattleResult(user1, "group", false, 0);

        assertEq(xpContract.getXP(user1), 40); // 50 - 10 = 40
        stats = xpContract.getUserStats(user1);
        assertEq(stats.battlesWon, 1);
        assertEq(stats.battlesLost, 1);

        // Test battle with custom XP
        xpContract.recordBattleResult(user1, "tournament", true, 100);
        assertEq(xpContract.getXP(user1), 140); // 40 + 100
        stats = xpContract.getUserStats(user1);
        assertEq(stats.battlesWon, 2);

        // Test battle loss when XP would go below 0
        xpContract.recordBattleResult(user1, "test", false, 200);
        assertEq(xpContract.getXP(user1), 0); // Can't go below 0

        // Test with unregistered user
        vm.expectRevert("User not registered");
        xpContract.recordBattleResult(user2, "1v1", true, 0);
    }

    // Test leaderboard management and ranking
    function testLeaderboardManagementAndRanking() public {
        // Register multiple users
        xpContract.registerUser(user1);
        xpContract.registerUser(user2);
        xpContract.registerUser(user3);

        // Initial ranks should be in registration order
        assertEq(xpContract.getUserRank(user1), 1);
        assertEq(xpContract.getUserRank(user2), 2);
        assertEq(xpContract.getUserRank(user3), 3);

        // Award XP to change rankings
        xpContract.awardXP(user2, 100, "Test award");
        xpContract.awardXP(user3, 50, "Test award");
        xpContract.awardXP(user1, 25, "Test award");

        // Check new rankings (user2 should be first, user3 second, user1 third)
        assertEq(xpContract.getUserRank(user2), 1);
        assertEq(xpContract.getUserRank(user3), 2);
        assertEq(xpContract.getUserRank(user1), 3);

        // Test getTopUsers function
        XPContract.LeaderboardEntry[] memory topUsers = xpContract.getTopUsers(2);
        assertEq(topUsers.length, 2);
        assertEq(topUsers[0].user, user2);
        assertEq(topUsers[0].xp, 100);
        assertEq(topUsers[0].rank, 1);
        assertEq(topUsers[1].user, user3);
        assertEq(topUsers[1].xp, 50);
        assertEq(topUsers[1].rank, 2);

        // Test getting more users than registered
        topUsers = xpContract.getTopUsers(10);
        assertEq(topUsers.length, 3); // Should only return 3 users

        // Test dynamic ranking updates
        xpContract.awardXP(user1, 200, "Big award");
        assertEq(xpContract.getUserRank(user1), 1); // Should move to first
        assertEq(xpContract.getUserRank(user2), 2);
        assertEq(xpContract.getUserRank(user3), 3);
    }

    // Test contest-specific leaderboards
    function testContestSpecificLeaderboards() public {
        xpContract.registerUser(user1);
        xpContract.registerUser(user2);
        xpContract.registerUser(user3);

        // User1 and User2 participate in Contest A
        xpContract.recordContestParticipation(user1, "contest_a", 100);
        xpContract.recordContestParticipation(user2, "contest_a", 150);

        // User1 and User3 participate in Contest B
        xpContract.recordContestParticipation(user1, "contest_b", 80);
        xpContract.recordContestParticipation(user3, "contest_b", 120);

        // Test Contest A leaderboard
        (address[] memory participantsA, uint256[] memory scoresA) = xpContract.getContestLeaderboard("contest_a");
        assertEq(participantsA.length, 2);

        // Find user1 and user2 in the results
        bool foundUser1 = false;
        bool foundUser2 = false;
        for (uint256 i = 0; i < participantsA.length; i++) {
            if (participantsA[i] == user1) {
                assertEq(scoresA[i], 100);
                foundUser1 = true;
            }
            if (participantsA[i] == user2) {
                assertEq(scoresA[i], 150);
                foundUser2 = true;
            }
        }
        assertTrue(foundUser1 && foundUser2);

        // Test Contest B leaderboard
        (address[] memory participantsB, uint256[] memory scoresB) = xpContract.getContestLeaderboard("contest_b");
        assertEq(participantsB.length, 2);

        // Test empty contest leaderboard
        (address[] memory emptyParticipants, uint256[] memory emptyScores) =
            xpContract.getContestLeaderboard("empty_contest");
        assertEq(emptyParticipants.length, 0);
        assertEq(emptyScores.length, 0);

        // User1 participates in Contest A again (should accumulate)
        xpContract.recordContestParticipation(user1, "contest_a", 50);
        (participantsA, scoresA) = xpContract.getContestLeaderboard("contest_a");

        // Find user1's updated score
        for (uint256 i = 0; i < participantsA.length; i++) {
            if (participantsA[i] == user1) {
                assertEq(scoresA[i], 150); // 100 + 50
                break;
            }
        }
    }

    // Test user statistics tracking
    function testUserStatisticsTracking() public {
        xpContract.registerUser(user1);

        // Perform various activities
        xpContract.recordQuizAnswer(user1, true); // +4 XP, correct++
        xpContract.recordQuizAnswer(user1, false); // -2 XP, incorrect++
        xpContract.recordQuizAnswer(user1, true); // +4 XP, correct++

        xpContract.recordContestParticipation(user1, "contest1", 50); // +50 XP, contests++
        xpContract.recordContestParticipation(user1, "contest2", 30); // +30 XP, contests++

        xpContract.recordBattleResult(user1, "1v1", true, 0); // +50 XP, battlesWon++
        xpContract.recordBattleResult(user1, "group", false, 0); // -10 XP, battlesLost++
        xpContract.recordBattleResult(user1, "tournament", true, 100); // +100 XP, battlesWon++

        XPContract.UserStats memory stats = xpContract.getUserStats(user1);

        // Check XP calculation: 4 - 2 + 4 + 50 + 30 + 50 - 10 + 100 = 226
        assertEq(stats.totalXP, 226);
        assertEq(stats.correctAnswers, 2);
        assertEq(stats.incorrectAnswers, 1);
        assertEq(stats.contestsParticipated, 2);
        assertEq(stats.battlesWon, 2);
        assertEq(stats.battlesLost, 1);
        assertEq(stats.currentRank, 1);
        assertTrue(stats.lastActivityTimestamp > 0);

        // Verify with direct getter functions
        assertEq(xpContract.getXP(user1), 226);
        assertEq(xpContract.getUserRank(user1), 1);
    }

    // Test XP configuration updates
    function testXPConfigurationUpdates() public {
        // Update XP configuration
        xpContract.updateXPConfig(10, 5, 50, 100, 25);

        xpContract.registerUser(user1);

        // Test with new configuration
        xpContract.recordQuizAnswer(user1, true);
        assertEq(xpContract.getXP(user1), 10); // New correctAnswerXP

        xpContract.recordQuizAnswer(user1, false);
        assertEq(xpContract.getXP(user1), 5); // 10 - 5 (new incorrectAnswerXP)

        xpContract.recordBattleResult(user1, "test", true, 0);
        assertEq(xpContract.getXP(user1), 105); // 5 + 100 (new battleWinXP)

        xpContract.recordBattleResult(user1, "test", false, 0);
        assertEq(xpContract.getXP(user1), 80); // 105 - 25 (new battleLossXP)

        // Test only owner can update config
        vm.prank(user1);
        vm.expectRevert();
        xpContract.updateXPConfig(1, 1, 1, 1, 1);
    }

    // Test access control and permissions
    function testAccessControlAndPermissions() public {
        // Test only owner can register users
        vm.prank(user1);
        vm.expectRevert();
        xpContract.registerUser(user2);

        // Test only owner can record quiz answers
        xpContract.registerUser(user1);
        vm.prank(user2);
        vm.expectRevert();
        xpContract.recordQuizAnswer(user1, true);

        // Test only owner can record contest participation
        vm.prank(user2);
        vm.expectRevert();
        xpContract.recordContestParticipation(user1, "test", 100);

        // Test only owner can record battle results
        vm.prank(user2);
        vm.expectRevert();
        xpContract.recordBattleResult(user1, "1v1", true, 0);

        // Test only owner can manually award XP
        vm.prank(user2);
        vm.expectRevert();
        xpContract.awardXP(user1, 100, "test");

        // Test only owner can manually deduct XP
        vm.prank(user2);
        vm.expectRevert();
        xpContract.deductXP(user1, 50, "test");
    }

    // Test manual XP award and deduction
    function testManualXPAwardAndDeduction() public {
        xpContract.registerUser(user1);

        // Test manual XP award
        vm.expectEmit(true, false, false, true);
        emit XPAwarded(user1, 100, "Manual award");
        xpContract.awardXP(user1, 100, "Manual award");
        assertEq(xpContract.getXP(user1), 100);

        // Test manual XP deduction
        vm.expectEmit(true, false, false, true);
        emit XPDeducted(user1, 30, "Manual deduction");
        xpContract.deductXP(user1, 30, "Manual deduction");
        assertEq(xpContract.getXP(user1), 70);

        // Test deduction more than available (should go to 0)
        xpContract.deductXP(user1, 100, "Large deduction");
        assertEq(xpContract.getXP(user1), 0);

        // Test zero amount awards/deductions
        vm.expectRevert("Amount must be greater than 0");
        xpContract.awardXP(user1, 0, "Zero award");

        vm.expectRevert("Amount must be greater than 0");
        xpContract.deductXP(user1, 0, "Zero deduction");

        // Test with unregistered user
        vm.expectRevert("User not registered");
        xpContract.awardXP(user2, 100, "Unregistered");

        vm.expectRevert("User not registered");
        xpContract.deductXP(user2, 50, "Unregistered");
    }

    // Test pause functionality
    function testPauseFunctionality() public {
        xpContract.registerUser(user1);

        // Pause the contract (XPContract doesn't have pause in the current implementation)
        // This test would be relevant if pause functionality is added

        // For now, test that all functions work normally
        xpContract.recordQuizAnswer(user1, true);
        assertEq(xpContract.getXP(user1), 4);

        xpContract.awardXP(user1, 50, "Test");
        assertEq(xpContract.getXP(user1), 54);
    }

    // Test edge cases and error conditions
    function testEdgeCasesAndErrorConditions() public {
        // Test invalid address
        vm.expectRevert("Invalid address");
        xpContract.registerUser(address(0));

        // Test getting stats for unregistered user
        XPContract.UserStats memory stats = xpContract.getUserStats(user1);
        assertEq(stats.totalXP, 0); // Should return empty stats

        // Test getting XP for unregistered user
        assertEq(xpContract.getXP(user1), 0);

        // Test getting rank for unregistered user
        assertEq(xpContract.getUserRank(user1), 0);

        // Test empty leaderboard
        XPContract.LeaderboardEntry[] memory topUsers = xpContract.getTopUsers(5);
        assertEq(topUsers.length, 0);

        // Test getting 0 top users
        topUsers = xpContract.getTopUsers(0);
        assertEq(topUsers.length, 0);

        // Test total users count
        assertEq(xpContract.getTotalUsers(), 0);

        xpContract.registerUser(user1);
        assertEq(xpContract.getTotalUsers(), 1);

        xpContract.registerUser(user2);
        assertEq(xpContract.getTotalUsers(), 2);
    }

    // Test complex leaderboard scenarios
    function testComplexLeaderboardScenarios() public {
        // Register users
        xpContract.registerUser(user1);
        xpContract.registerUser(user2);
        xpContract.registerUser(user3);

        // Create complex XP distribution
        xpContract.awardXP(user1, 100, "Initial");
        xpContract.awardXP(user2, 200, "Initial");
        xpContract.awardXP(user3, 150, "Initial");

        // Rankings should be: user2(200), user3(150), user1(100)
        assertEq(xpContract.getUserRank(user2), 1);
        assertEq(xpContract.getUserRank(user3), 2);
        assertEq(xpContract.getUserRank(user1), 3);

        // Make user1 jump to first place
        xpContract.awardXP(user1, 150, "Big jump"); // Now 250 total
        assertEq(xpContract.getUserRank(user1), 1);
        assertEq(xpContract.getUserRank(user2), 2);
        assertEq(xpContract.getUserRank(user3), 3);

        // Make user3 equal to user1
        xpContract.awardXP(user3, 100, "Catch up"); // Now 250 total

        // User1 should still be rank 1 (was there first), user3 rank 2
        assertEq(xpContract.getUserRank(user1), 1);
        assertEq(xpContract.getUserRank(user3), 2);
        assertEq(xpContract.getUserRank(user2), 3);

        // Deduct XP and test ranking changes
        xpContract.deductXP(user1, 100, "Penalty"); // Now 150

        // Rankings should be: user3(250), user2(200), user1(150)
        assertEq(xpContract.getUserRank(user3), 1);
        assertEq(xpContract.getUserRank(user2), 2);
        assertEq(xpContract.getUserRank(user1), 3);
    }
}
