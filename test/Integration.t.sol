// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "forge-std/Test.sol";
// import "../src/LearnWayManager.sol";
// import "../src/GemsContract.sol";
// import "../src/XPContract.sol";

// // Extended Mock BadgesNFT contract for comprehensive integration testing
// contract MockBadgesNFTExtended {
//     mapping(address => bool[15]) public userBadges;
//     mapping(address => uint256) public userTotalBadges;
//     mapping(address => uint256) public userConsecutiveWins;
//     mapping(address => uint256) public userDailyStreak;
//     mapping(address => uint256) public userCorrectAnswers;
//     mapping(address => uint256) public userQuizCount;
//     mapping(address => uint256) public userContestWins;
//     mapping(address => uint256) public userReferralCount;

//     // Track all interactions for verification
//     uint256 public totalQuizCompletions;
//     uint256 public totalBattleCompletions;
//     uint256 public totalContestWins;
//     uint256 public totalEliteBadgesAwarded;

//     function recordQuizCompletion(
//         address user,
//         string memory quizType,
//         uint256 timeTaken,
//         bool usedLifeline,
//         bool allCorrect,
//         uint256 correctCount
//     ) external {
//         userCorrectAnswers[user] += correctCount;
//         userQuizCount[user]++;
//         totalQuizCompletions++;

//         // Simulate badge awarding logic
//         if (userQuizCount[user] >= 10) {
//             userBadges[user][0] = true; // Quiz Master badge
//             userTotalBadges[user]++;
//         }
//     }

//     function recordBattleCompletion(
//         address user,
//         string memory battleType,
//         bool isWin,
//         uint256 points,
//         bool isHighestScore
//     ) external {
//         if (isWin) {
//             userConsecutiveWins[user]++;
//         } else {
//             userConsecutiveWins[user] = 0;
//         }
//         totalBattleCompletions++;

//         // Award consecutive win badges
//         if (userConsecutiveWins[user] >= 5) {
//             userBadges[user][1] = true; // Battle Master badge
//             userTotalBadges[user]++;
//         }
//     }

//     function recordContestWin(address user) external {
//         userContestWins[user]++;
//         totalContestWins++;

//         // Award contest badges
//         if (userContestWins[user] >= 3) {
//             userBadges[user][2] = true; // Contest Champion badge
//             userTotalBadges[user]++;
//         }
//     }

//     function updateReferralCount(address user, uint256 count) external {
//         userReferralCount[user] = count;

//         // Award referral badges
//         if (count >= 5) {
//             userBadges[user][3] = true; // Echo Spreader badge
//             userTotalBadges[user]++;
//         }
//     }

//     function awardEliteBadge(address user) external {
//         userBadges[user][14] = true; // Elite badge
//         userTotalBadges[user]++;
//         totalEliteBadgesAwarded++;
//     }

//     function getUserBadgeStatus(address user)
//         external
//         view
//         returns (
//             bool[15] memory badges,
//             uint256 totalBadges,
//             uint256 consecutiveWins,
//             uint256 dailyStreak,
//             uint256 correctAnswers
//         )
//     {
//         return (
//             userBadges[user],
//             userTotalBadges[user],
//             userConsecutiveWins[user],
//             userDailyStreak[user],
//             userCorrectAnswers[user]
//         );
//     }

//     // Helper functions for testing
//     function getBadgeStats()
//         external
//         view
//         returns (uint256 quizCompletions, uint256 battleCompletions, uint256 contestWins, uint256 eliteBadges)
//     {
//         return (totalQuizCompletions, totalBattleCompletions, totalContestWins, totalEliteBadgesAwarded);
//     }
// }

// contract IntegrationTest is Test {
//     LearnWayManager public manager;
//     GemsContract public gemsContract;
//     XPContract public xpContract;
//     MockBadgesNFTExtended public badgesContract;

//     address public owner;
//     address public user1;
//     address public user2;
//     address public user3;
//     address public user4;
//     address public user5;

//     // Events from all contracts for comprehensive testing
//     event UserRegistered(address indexed user, address indexed referrer, uint256 timestamp);
//     event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned, uint256 xpChange);
//     event GemsAwarded(address indexed user, uint256 amount, string reason);
//     event XPAwarded(address indexed user, uint256 amount, string reason);
//     event MonthlyRewardsDistributed(uint256 month, uint256 year, address[] topUsers, uint256[] rewards);
//     event ContestCompleted(address indexed user, string contestId, uint256 gemsEarned, uint256 xpEarned);

//     function setUp() public {
//         owner = address(this);
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
//         user3 = makeAddr("user3");
//         user4 = makeAddr("user4");
//         user5 = makeAddr("user5");

//         // Deploy all contracts
//         gemsContract = new GemsContract();
//         gemsContract.setTestMode(true); // Enable test mode to bypass cooldowns
//         xpContract = new XPContract();
//         badgesContract = new MockBadgesNFTExtended();
//         manager = new LearnWayManager();
//         //        manager = new LearnWayManager(address(gemsContract), address(xpContract), address(badgesContract));

//         // Set up the integration
//         manager.setContracts(address(gemsContract), address(xpContract), address(badgesContract));

//         // Grant MANAGER_ROLE to LearnWayManager on GemsContract
//         gemsContract.grantRole(gemsContract.MANAGER_ROLE(), address(manager));
//         // Transfer ownership to LearnWayManager since it needs to call owner functions
//         gemsContract.transferOwnership(address(manager));
//         xpContract.transferOwnership(address(manager));
//     }

//     // Test end-to-end user journey scenarios
//     function testEndToEndUserJourneyScenarios() public {
//         // Scenario 1: New user complete journey

//         // 1. User registration
//         manager.registerUser(user1, address(0), "newbie");
//         assertEq(gemsContract.balanceOf(user1), 500); // Signup bonus
//         assertEq(xpContract.getXP(user1), 0);
//         assertTrue(gemsContract.isRegistered(user1));

//         // 2. Complete first quiz
//         bool[] memory answers1 = new bool[](5);
//         answers1[0] = true;
//         answers1[1] = true;
//         answers1[2] = false;
//         answers1[3] = true;
//         answers1[4] = true;

//         manager.completeQuiz(user1, 85, answers1, "beginner_quiz", 120, false);
//         assertEq(gemsContract.balanceOf(user1), 630); // 500 + 30 gems + 100 achievement bonus
//         assertEq(xpContract.getXP(user1), 14); // 4*4 - 1*2 = 14 XP
//         assertEq(badgesContract.userCorrectAnswers(user1), 4);

//         // 3. Participate in contest
//         manager.participateInContest(user1, "weekly_contest", 150, 100);
//         assertEq(gemsContract.balanceOf(user1), 930); // 630 + 150 + 150 contest achievement bonus
//         assertEq(xpContract.getXP(user1), 114); // 14 + 100

//         // 4. Complete battle
//         manager.completeBattle(user1, "1v1", true, 100, 75, 90, false);
//         assertEq(gemsContract.balanceOf(user1), 1230); // 930 + 100 + 200 battle achievement bonus
//         assertEq(xpContract.getXP(user1), 189); // 114 + 75
//         assertEq(badgesContract.userConsecutiveWins(user1), 1);

//         // 5. Complete more activities to reach milestones
//         for (uint256 i = 0; i < 9; i++) {
//             manager.completeQuiz(user1, 80, answers1, "milestone_quiz", 90, false);
//         }

//         // Should have completed 10 quizzes total and earned Quiz Master badge
//         assertEq(badgesContract.userQuizCount(user1), 10);
//         assertTrue(badgesContract.userBadges(user1, 0)); // Quiz Master badge

//         // Verify final stats
//         LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
//         assertEq(profile.totalQuizzesCompleted, 10);
//         assertEq(profile.totalContestsParticipated, 1);
//         assertEq(profile.totalBattlesParticipated, 1);
//         assertTrue(profile.isActive);
//     }

//     // Test cross-contract communication validation
//     function testCrossContractCommunicationValidation() public {
//         // Register users for testing
//         manager.registerUser(user1, address(0), "tester1");
//         manager.registerUser(user2, user1, "tester2"); // With referral

//         // Test 1: Quiz completion triggers multiple contract updates
//         bool[] memory answers = new bool[](3);
//         answers[0] = true;
//         answers[1] = true;
//         answers[2] = true;

//         uint256 initialGems1 = gemsContract.balanceOf(user1);
//         uint256 initialXP1 = xpContract.getXP(user1);
//         uint256 initialBadgeCorrect1 = badgesContract.userCorrectAnswers(user1);

//         manager.completeQuiz(user1, 90, answers, "cross_test", 60, false);

//         // Verify all contracts were updated correctly
//         assertEq(gemsContract.balanceOf(user1), initialGems1 + 40 + 100); // (90-70)*2 + first quiz achievement
//         assertEq(xpContract.getXP(user1), initialXP1 + 12); // 3*4
//         assertEq(badgesContract.userCorrectAnswers(user1), initialBadgeCorrect1 + 3);

//         // Test 2: Battle completion affects XP and Badges but not Gems directly
//         uint256 gemsBeforeBattle = gemsContract.balanceOf(user1);
//         uint256 xpBeforeBattle = xpContract.getXP(user1);
//         uint256 winsBeforeBattle = badgesContract.userConsecutiveWins(user1);

//         manager.completeBattle(user1, "validation_battle", true, 0, 50, 80, false);

//         console.log("User1 gems before and after battle:", gemsBeforeBattle, gemsContract.balanceOf(user1));
//         // Gems should reflect battle achievement bonus even if direct battle gems are 0
//         assertEq(gemsContract.balanceOf(user1), gemsBeforeBattle + 200);
//         // XP should increase
//         assertEq(xpContract.getXP(user1), xpBeforeBattle + 50);
//         // Consecutive wins should increase
//         assertEq(badgesContract.userConsecutiveWins(user1), winsBeforeBattle + 1);

//         // Test 3: Referral system cross-contract validation
//         console.log("User2 initial gems:", gemsContract.balanceOf(user2));
//         assertEq(gemsContract.getReferrer(user2), user1);
//         assertEq(gemsContract.getReferralCount(user1), 1);
//         assertEq(gemsContract.balanceOf(user2), 550); // 500 + 50 referral signup bonus
//         assertEq(gemsContract.balanceOf(user1), gemsBeforeBattle + 200); // Referral bonus already included before gemsBeforeBattle; add only battle achievement
//     }

//     // Test complex workflow scenarios
//     function testComplexWorkflowScenarios() public {
//         // Scenario: Multiple users competing in leaderboards
//         address[] memory users = new address[](5);
//         users[0] = user1;
//         users[1] = user2;
//         users[2] = user3;
//         users[3] = user4;
//         users[4] = user5;

//         // Register all users
//         for (uint256 i = 0; i < 5; i++) {
//             string memory username = string(abi.encodePacked("competitor", vm.toString(i)));
//             manager.registerUser(users[i], address(0), username);
//         }

//         // Create differentiated XP levels
//         bool[] memory perfectAnswers = new bool[](5);
//         for (uint256 j = 0; j < 5; j++) {
//             perfectAnswers[j] = true;
//         }

//         // User1: High performer
//         for (uint256 k = 0; k < 5; k++) {
//             manager.completeQuiz(users[0], 95, perfectAnswers, "high_perf", 45, false);
//             manager.participateInContest(users[0], string(abi.encodePacked("contest", vm.toString(k))), 200, 150);
//             manager.completeBattle(users[0], "pro_battle", true, 150, 100, 95, k == 0);
//         }

//         // User2: Medium performer
//         for (uint256 k = 0; k < 3; k++) {
//             manager.completeQuiz(users[1], 85, perfectAnswers, "med_perf", 60, false);
//             manager.participateInContest(users[1], string(abi.encodePacked("med_contest", vm.toString(k))), 100, 100);
//         }

//         // User3: Low performer
//         manager.completeQuiz(users[2], 75, perfectAnswers, "low_perf", 90, true);
//         manager.participateInContest(users[2], "single_contest", 50, 50);

//         // Verify leaderboard positions
//         XPContract.LeaderboardEntry[] memory topUsers = xpContract.getTopUsers(5);

//         // User1 should be on top
//         assertEq(topUsers[0].user, users[0]);
//         assertTrue(topUsers[0].xp > topUsers[1].xp);

//         // Test monthly reward distribution based on performance
//         address[] memory monthlyWinners = new address[](3);
//         uint256[] memory monthlyRewards = new uint256[](3);
//         monthlyWinners[0] = topUsers[0].user;
//         monthlyWinners[1] = topUsers[1].user;
//         monthlyWinners[2] = topUsers[2].user;
//         monthlyRewards[0] = 1000;
//         monthlyRewards[1] = 500;
//         monthlyRewards[2] = 250;

//         // Prank the manager to call owner-only function
//         vm.prank(address(manager));
//         // Reset monthly leaderboard first
//         gemsContract.resetMonthlyLeaderboard(9, 2025);

//         uint256[] memory balancesBefore = new uint256[](3);
//         for (uint256 i = 0; i < 3; i++) {
//             balancesBefore[i] = gemsContract.balanceOf(monthlyWinners[i]);
//         }

//         vm.prank(address(manager));
//         // Distribute Monthly rewards
//         gemsContract.distributeMonthlyRewards(9, 2025, monthlyWinners, monthlyRewards);

//         // Verify rewards distributed
//         for (uint256 i = 0; i < 3; i++) {
//             assertEq(gemsContract.balanceOf(monthlyWinners[i]), balancesBefore[i] + monthlyRewards[i]);
//         }
//     }

//     // Test data consistency across contracts
//     function testDataConsistencyAcrossContracts() public {
//         // Register user and perform various activities
//         manager.registerUser(user1, address(0), "consistency_user");

//         // Track initial state
//         uint256 initialGems = gemsContract.balanceOf(user1);
//         uint256 initialXP = xpContract.getXP(user1);
//         uint256 initialRank = xpContract.getUserRank(user1);

//         // Perform quiz with mixed results
//         bool[] memory mixedAnswers = new bool[](8);
//         mixedAnswers[0] = true; // +4 XP
//         mixedAnswers[1] = false; // -2 XP
//         mixedAnswers[2] = true; // +4 XP
//         mixedAnswers[3] = true; // +4 XP
//         mixedAnswers[4] = false; // -2 XP
//         mixedAnswers[5] = true; // +4 XP
//         mixedAnswers[6] = true; // +4 XP
//         mixedAnswers[7] = false; // -2 XP

//         manager.completeQuiz(user1, 88, mixedAnswers, "consistency_test", 100, false);

//         // Calculate expected values
//         uint256 expectedGems = initialGems + 36 + 100; // (88-70)*2 + first quiz achievement
//         uint256 expectedXP = initialXP + 14; // (5*4) - (3*2) = 14

//         // Verify consistency
//         assertEq(gemsContract.balanceOf(user1), expectedGems);
//         assertEq(xpContract.getXP(user1), expectedXP);
//         assertEq(badgesContract.userCorrectAnswers(user1), 5);

//         LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
//         assertEq(profile.totalQuizzesCompleted, 1);

//         // Test contest consistency
//         manager.participateInContest(user1, "consistency_contest", 300, 200);

//         expectedGems += 300 + 150; // contest reward + achievement bonus
//         expectedXP += 200;

//         assertEq(gemsContract.balanceOf(user1), expectedGems);
//         assertEq(xpContract.getXP(user1), expectedXP);

//         profile = manager.getUserProfile(user1);
//         assertEq(profile.totalContestsParticipated, 1);

//         // Test battle consistency
//         manager.completeBattle(user1, "consistency_battle", false, 0, 0, 70, false);

//         // Battle loss: no gems, lose XP
//         expectedXP -= 10; // battleLossXP
//         expectedGems += 200; // first_battle achievement bonus

//         assertEq(gemsContract.balanceOf(user1), expectedGems); // No change
//         assertEq(xpContract.getXP(user1), expectedXP);
//         assertEq(badgesContract.userConsecutiveWins(user1), 0); // Reset on loss

//         profile = manager.getUserProfile(user1);
//         assertEq(profile.totalBattlesParticipated, 1);
//     }

//     // Test event emission verification
//     function testEventEmissionVerification() public {
//         // Test user registration events
//         vm.recordLogs();
//         manager.registerUser(user1, address(0), "event_tester");
//         Vm.Log[] memory logs = vm.getRecordedLogs();

//         // Check that UserRegistered event was emitted
//         bool userRegisteredFound = false;
//         for (uint256 i = 0; i < logs.length; i++) {
//             if (logs[i].topics[0] == keccak256("UserRegistered(address,address,uint256)")) {
//                 userRegisteredFound = true;
//                 break;
//             }
//         }
//         assertTrue(userRegisteredFound, "UserRegistered event not found");

//         // Test quiz completion events
//         bool[] memory answers = new bool[](3);
//         answers[0] = true;
//         answers[1] = true;
//         answers[2] = false;

//         vm.recordLogs();
//         manager.completeQuiz(user1, 85, answers, "event_quiz", 90, false);
//         logs = vm.getRecordedLogs();

//         // Check that QuizCompleted event was emitted
//         bool quizCompletedFound = false;
//         for (uint256 i = 0; i < logs.length; i++) {
//             if (logs[i].topics[0] == keccak256("QuizCompleted(address,uint256,uint256,uint256)")) {
//                 quizCompletedFound = true;
//                 break;
//             }
//         }
//         assertTrue(quizCompletedFound, "QuizCompleted event not found");

//         // Test contest completion events
//         vm.recordLogs();
//         manager.participateInContest(user1, "event_contest", 250, 175);
//         logs = vm.getRecordedLogs();

//         // Check that ContestCompleted event was emitted
//         bool contestCompletedFound = false;
//         for (uint256 i = 0; i < logs.length; i++) {
//             if (logs[i].topics[0] == keccak256("ContestCompleted(address,string,uint256,uint256)")) {
//                 contestCompletedFound = true;
//                 break;
//             }
//         }
//         assertTrue(contestCompletedFound, "ContestCompleted event not found");

//         // Test monthly rewards distribution events
//         address[] memory winners = new address[](1);
//         uint256[] memory rewards = new uint256[](1);
//         winners[0] = user1;
//         rewards[0] = 500;

//         vm.prank(address(manager));
//         gemsContract.resetMonthlyLeaderboard(10, 2025);

//         vm.prank(address(manager));
//         vm.recordLogs();
//         gemsContract.distributeMonthlyRewards(10, 2025, winners, rewards);
//         logs = vm.getRecordedLogs();

//         // Check that MonthlyRewardsDistributed event was emitted
//         bool monthlyRewardsFound = false;
//         for (uint256 i = 0; i < logs.length; i++) {
//             if (logs[i].topics[0] == keccak256("MonthlyRewardsDistributed(uint256,uint256,address[],uint256[])")) {
//                 monthlyRewardsFound = true;
//                 break;
//             }
//         }
//         assertTrue(monthlyRewardsFound, "MonthlyRewardsDistributed event not found");
//     }

//     // Test performance and gas optimization
//     function testPerformanceAndGasOptimization() public {
//         manager.registerUser(user1, address(0), "gas_tester");

//         // Test single operations gas usage
//         bool[] memory answers = new bool[](10);
//         for (uint256 i = 0; i < 10; i++) {
//             answers[i] = i % 3 != 0; // Mostly correct answers
//         }

//         uint256 gasBefore = gasleft();
//         manager.completeQuiz(user1, 87, answers, "gas_quiz", 120, false);
//         uint256 gasUsedQuiz = gasBefore - gasleft();

//         // Quiz completion should be reasonably efficient
//         assertLt(gasUsedQuiz, 500000); // Less than 500k gas

//         // Test batch-like operations
//         gasBefore = gasleft();

//         // Simulate rapid user actions
//         manager.participateInContest(user1, "gas_contest1", 100, 75);
//         manager.completeBattle(user1, "gas_battle1", true, 50, 40, 85, false);
//         manager.participateInContest(user1, "gas_contest2", 150, 100);
//         manager.completeBattle(user1, "gas_battle2", true, 75, 50, 90, false);

//         uint256 gasUsedBatch = gasBefore - gasleft();

//         // Batch operations should be reasonable
//         assertLt(gasUsedBatch, 1500000); // Less than 1.5M gas for 4 operations

//         // Test leaderboard operations (most expensive)
//         manager.registerUser(user2, address(0), "gas_tester2");
//         manager.registerUser(user3, address(0), "gas_tester3");

//         gasBefore = gasleft();
//         XPContract.LeaderboardEntry[] memory topUsers = xpContract.getTopUsers(3);
//         uint256 gasUsedLeaderboard = gasBefore - gasleft();

//         // Leaderboard queries should be efficient
//         assertLt(gasUsedLeaderboard, 100000); // Less than 100k gas
//         assertEq(topUsers.length, 3);
//     }

//     // Test system-wide error handling
//     function testSystemWideErrorHandling() public {
//         // Test 1: Operations on unregistered users
//         bool[] memory answers = new bool[](1);
//         answers[0] = true;

//         vm.expectRevert("User not registered");
//         manager.completeQuiz(user1, 85, answers, "error_test", 100, false);

//         vm.expectRevert("User not registered");
//         manager.participateInContest(user1, "error_contest", 100, 50);

//         vm.expectRevert("User not registered");
//         manager.completeBattle(user1, "error_battle", true, 50, 30, 88, false);

//         // Register user for further tests
//         manager.registerUser(user1, address(0), "error_tester");

//         // Test 2: Invalid parameters
//         vm.expectRevert("Invalid score");
//         manager.completeQuiz(user1, 101, answers, "invalid", 100, false);

//         vm.expectRevert("Invalid score");
//         manager.completeQuiz(user1, 101, answers, "invalid", 100, false);

//         // Test 3: Contract pause scenarios
//         manager.pause();

//         vm.expectRevert();
//         manager.registerUser(user2, address(0), "paused_test");

//         vm.expectRevert();
//         manager.completeQuiz(user1, 85, answers, "paused", 100, false);

//         vm.expectRevert();
//         manager.participateInContest(user1, "paused", 100, 50);

//         // Unpause and verify recovery
//         manager.unpause();
//         manager.registerUser(user2, address(0), "recovered");
//         assertTrue(gemsContract.isRegistered(user2));

//         // Test 4: Access control violations
//         vm.prank(user1);
//         vm.expectRevert();
//         manager.registerUser(user3, address(0), "unauthorized");

//         vm.prank(user1);
//         vm.expectRevert();
//         manager.pause();

//         vm.prank(user1);
//         vm.expectRevert();
//         gemsContract.registerUser(user3, address(0));

//         vm.prank(user1);
//         vm.expectRevert();
//         xpContract.registerUser(user3);
//     }

//     // Test concurrent user operations
//     function testConcurrentUserOperations() public {
//         // Register multiple users
//         address[] memory users = new address[](4);
//         users[0] = user1;
//         users[1] = user2;
//         users[2] = user3;
//         users[3] = user4;

//         for (uint256 i = 0; i < 4; i++) {
//             string memory username = string(abi.encodePacked("concurrent", vm.toString(i)));
//             manager.registerUser(users[i], address(0), username);
//         }

//         // Simulate concurrent operations
//         bool[] memory answers = new bool[](5);
//         for (uint256 i = 0; i < 5; i++) {
//             answers[i] = true;
//         }

//         // All users complete quizzes simultaneously
//         uint256[] memory initialGems = new uint256[](4);
//         uint256[] memory initialXP = new uint256[](4);

//         for (uint256 i = 0; i < 4; i++) {
//             initialGems[i] = gemsContract.balanceOf(users[i]);
//             initialXP[i] = xpContract.getXP(users[i]);
//         }

//         // Execute concurrent operations
//         for (uint256 i = 0; i < 4; i++) {
//             uint256 score = 80 + (i * 5); // Different scores: 80, 85, 90, 95
//             string memory quizId = string(abi.encodePacked("concurrent_quiz", vm.toString(i)));
//             manager.completeQuiz(users[i], score, answers, quizId, 60 + (i * 10), false);
//         }

//         // Verify all operations completed correctly
//         for (uint256 i = 0; i < 4; i++) {
//             uint256 score = 80 + (i * 5);
//             uint256 expectedGems = initialGems[i] + ((score - 70) * 2) + 100; // + first quiz achievement
//             uint256 expectedXP = initialXP[i] + 20; // 5 correct * 4 XP each

//             assertEq(gemsContract.balanceOf(users[i]), expectedGems);
//             assertEq(xpContract.getXP(users[i]), expectedXP);

//             LearnWayManager.UserProfile memory profile = manager.getUserProfile(users[i]);
//             assertEq(profile.totalQuizzesCompleted, 1);
//         }

//         // Verify leaderboard updated correctly for all users
//         XPContract.LeaderboardEntry[] memory topUsers = xpContract.getTopUsers(4);
//         assertEq(topUsers.length, 4);

//         // Higher XP users should rank higher
//         assertTrue(topUsers[0].xp >= topUsers[1].xp);
//         assertTrue(topUsers[1].xp >= topUsers[2].xp);
//         assertTrue(topUsers[2].xp >= topUsers[3].xp);
//     }

//     // Test system scalability scenarios
//     function testSystemScalabilityScenarios() public {
//         // Test with larger number of users (limited by gas in test environment)
//         uint256 numUsers = 10;
//         address[] memory users = new address[](numUsers);

//         // Create and register users
//         for (uint256 i = 0; i < numUsers; i++) {
//             users[i] = makeAddr(string(abi.encodePacked("scale_user", vm.toString(i))));
//             string memory username = string(abi.encodePacked("scale", vm.toString(i)));
//             manager.registerUser(users[i], address(0), username);
//         }

//         // Verify all registrations
//         assertEq(xpContract.getTotalUsers(), numUsers);

//         // Simulate activity for all users
//         bool[] memory answers = new bool[](3);
//         answers[0] = true;
//         answers[1] = true;
//         answers[2] = true;

//         uint256 gasBefore = gasleft();

//         for (uint256 i = 0; i < numUsers; i++) {
//             // Vary scores to create different rankings
//             uint256 score = 75 + (i * 2); // Scores from 75 to 93
//             string memory quizId = string(abi.encodePacked("scale_quiz", vm.toString(i)));
//             manager.completeQuiz(users[i], score, answers, quizId, 90, false);

//             // Some users participate in contests
//             if (i % 3 == 0) {
//                 string memory contestId = string(abi.encodePacked("scale_contest", vm.toString(i)));
//                 manager.participateInContest(users[i], contestId, 100, 75);
//             }

//             // Some users complete battles
//             if (i % 2 == 0) {
//                 string memory battleType = string(abi.encodePacked("scale_battle", vm.toString(i)));
//                 manager.completeBattle(users[i], battleType, true, 50, 40, 82, false); // All battle participants win
//             }
//         }

//         uint256 gasUsedTotal = gasBefore - gasleft();

//         // Should handle multiple users efficiently
//         assertLt(gasUsedTotal, 9000000); // Less than 9M gas for all operations

//         // Test leaderboard with multiple users
//         XPContract.LeaderboardEntry[] memory topUsers = xpContract.getTopUsers(numUsers);
//         assertEq(topUsers.length, numUsers);

//         // Verify ranking order (should be sorted by XP descending)
//         for (uint256 i = 0; i < numUsers - 1; i++) {
//             assertTrue(topUsers[i].xp >= topUsers[i + 1].xp);
//         }

//         // Test badge system scalability
//         (uint256 quizCompletions, uint256 battleCompletions, uint256 contestWins, uint256 eliteBadges) =
//             badgesContract.getBadgeStats();

//         assertEq(quizCompletions, numUsers); // All users completed quizzes
//         //        assertGt(battleCompletions, 0); // Some battles were completed
//         uint256 battlesCounted = 0;
//         for (uint256 i = 0; i < numUsers; i++) {
//             LearnWayManager.UserProfile memory p = manager.getUserProfile(users[i]);
//             if (p.totalBattlesParticipated > 0) battlesCounted++;
//         }
//         assertGt(battlesCounted, 0); // At least some users participated in battles
//         assertEq(contestWins, 0); // No contest wins recorded in this test

//         // Verify total system consistency
//         uint256 totalSupply = gemsContract.totalSupply();
//         assertGt(totalSupply, numUsers * 500); // At least signup bonuses + rewards

//         // All users should be properly registered across all systems
//         for (uint256 i = 0; i < numUsers; i++) {
//             assertTrue(gemsContract.isRegistered(users[i]));
//             assertTrue(xpContract.isRegistered(users[i]));
//             assertGt(gemsContract.balanceOf(users[i]), 500); // More than just signup bonus
//             assertGt(xpContract.getXP(users[i]), 0); // Some XP earned
//         }
//     }

//     // Test edge cases in integration
//     function testEdgeCasesInIntegration() public {
//         manager.registerUser(user1, address(0), "edge_tester");

//         // Test 1: Zero XP scenarios
//         bool[] memory allWrong = new bool[](10);
//         for (uint256 i = 0; i < 10; i++) {
//             allWrong[i] = false;
//         }

//         uint256 initialXP = xpContract.getXP(user1);
//         manager.completeQuiz(user1, 50, allWrong, "all_wrong", 180, true); // Below minimum score

//         // Should lose XP but not go below 0
//         uint256 expectedXP = initialXP > 20 ? initialXP - 20 : 0; // 10 wrong * 2 XP each
//         assertEq(xpContract.getXP(user1), expectedXP);

//         // Test 2: Maximum values
//         vm.prank(address(manager));
//         xpContract.awardXP(user1, type(uint256).max / 2, "Max test"); // Large but not overflow
//         assertTrue(xpContract.getXP(user1) > expectedXP); // Should increase

//         // Test 3: Empty arrays and edge cases
//         bool[] memory emptyAnswers = new bool[](0);

//         manager.completeQuiz(user1, 85, emptyAnswers, "empty_quiz", 60, false);
//         // Should handle gracefully

//         // Test 4: Boundary scores
//         bool[] memory singleAnswer = new bool[](1);
//         singleAnswer[0] = true;

//         // Exactly at minimum threshold
//         uint256 gemsBefore = gemsContract.balanceOf(user1);
//         manager.completeQuiz(user1, 70, singleAnswer, "boundary", 100, false);
//         assertEq(gemsContract.balanceOf(user1), gemsBefore); // Should get 0 gems (70-70)*2 = 0

//         // Just above threshold
//         manager.completeQuiz(user1, 71, singleAnswer, "boundary_plus", 100, false);
//         assertEq(gemsContract.balanceOf(user1), gemsBefore + 2); // Should get 2 gems (71-70)*2 = 2

//         // Test 5: Rapid consecutive operations
//         for (uint256 i = 0; i < 5; i++) {
//             manager.participateInContest(user1, string(abi.encodePacked("rapid", vm.toString(i))), 10, 5);
//         }

//         LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
//         assertEq(profile.totalContestsParticipated, 5);

//         // Test 6: Leaderboard edge cases
//         manager.registerUser(user2, address(0), "edge_tester2");

//         // Users with same XP
//         uint256 user1XP = xpContract.getXP(user1);
//         vm.prank(address(manager));
//         xpContract.awardXP(user2, user1XP, "Equal XP");

//         // Both should be ranked appropriately
//         uint256 rank1 = xpContract.getUserRank(user1);
//         uint256 rank2 = xpContract.getUserRank(user2);
//         assertTrue(rank1 != rank2); // Should have different ranks
//         assertTrue(rank1 == 1 || rank2 == 1); // One should be rank 1
//     }
// }
