// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LearnWayManager.sol";
import "../src/GemsContract.sol";
import "../src/XPContract.sol";

// Mock BadgesNFT contract for testing
contract MockBadgesNFT {
    mapping(address => bool[15]) public userBadges;
    mapping(address => uint256) public userTotalBadges;
    mapping(address => uint256) public userConsecutiveWins;
    mapping(address => uint256) public userDailyStreak;
    mapping(address => uint256) public userCorrectAnswers;

    function recordQuizCompletion(
        address user,
        string memory quizType,
        uint256 timeTaken,
        bool usedLifeline,
        bool allCorrect,
        uint256 correctCount
    ) external {
        userCorrectAnswers[user] += correctCount;
    }

    function recordBattleCompletion(
        address user,
        string memory battleType,
        bool isWin,
        uint256 points,
        bool isHighestScore
    ) external {
        if (isWin) {
            userConsecutiveWins[user]++;
        }
    }

    function recordContestWin(address user) external {
        userTotalBadges[user]++;
    }

    function updateReferralCount(address user, uint256 count) external {
        // Mock implementation
    }

    function awardEliteBadge(address user) external {
        userBadges[user][14] = true; // Assuming elite badge is at index 14
        userTotalBadges[user]++;
    }

    function getUserBadgeStatus(address user)
        external
        view
        returns (
            bool[15] memory badges,
            uint256 totalBadges,
            uint256 consecutiveWins,
            uint256 dailyStreak,
            uint256 correctAnswers
        )
    {
        return (
            userBadges[user],
            userTotalBadges[user],
            userConsecutiveWins[user],
            userDailyStreak[user],
            userCorrectAnswers[user]
        );
    }
}

contract LearnWayManagerTest is Test {
    LearnWayManager public manager;
    GemsContract public gemsContract;
    XPContract public xpContract;
    MockBadgesNFT public badgesContract;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public referrer;

    event UserRegistered(address indexed user, address indexed referrer, uint256 timestamp);
    event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned, uint256 xpChange);
    event AchievementUnlocked(address indexed user, string achievementId, uint256 gemsReward);
    event ContestCompleted(address indexed user, string contestId, uint256 gemsEarned, uint256 xpEarned);
    event BattleCompleted(address indexed user, string battleType, bool isWin, uint256 gemsEarned, uint256 xpChange);
    event MonthlyRewardsDistributed(uint256 month, uint256 year, address[] topUsers, uint256[] rewards);
    event UserProfileUpdated(address indexed user, string profileData);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        referrer = makeAddr("referrer");

        // Deploy contracts
        gemsContract = new GemsContract();
        gemsContract.setTestMode(true); // Enable test mode to bypass cooldowns
        xpContract = new XPContract();
        badgesContract = new MockBadgesNFT();
        manager = new LearnWayManager();

        // Set contract addresses in manager
        manager.setContracts(address(gemsContract), address(xpContract), address(badgesContract));

        // Transfer ownership to LearnWayManager for both contracts
        gemsContract.transferOwnership(address(manager));
        xpContract.transferOwnership(address(manager));
    }

    // Test contract initialization and setup
    function testContractInitializationAndSetup() public {
        // Verify contracts are set correctly
        assertEq(address(manager.gemsContract()), address(gemsContract));
        assertEq(address(manager.xpContract()), address(xpContract));
        assertEq(address(manager.badgesContract()), address(badgesContract));

        // Test setting invalid contract addresses
        vm.expectRevert("Invalid contract addresses");
        manager.setContracts(address(0), address(xpContract), address(badgesContract));

        // Test that only owner can set contracts
        vm.prank(user1);
        vm.expectRevert();
        manager.setContracts(address(gemsContract), address(xpContract), address(badgesContract));
    }

    // Test user registration flow integration
    function testUserRegistrationFlowIntegration() public {
        // Test registration without referrer
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(user1, address(0), block.timestamp);
        manager.registerUser(user1, address(0), "testuser1");

        // Verify user is registered in both contracts
        assertTrue(gemsContract.isRegistered(user1));
        assertTrue(xpContract.isRegistered(user1));

        // Verify user received signup bonus
        assertEq(gemsContract.balanceOf(user1), 500);
        assertEq(xpContract.getXP(user1), 0);

        // Verify user profile is created
        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.username, "testuser1");
        assertEq(profile.totalQuizzesCompleted, 0);
        assertEq(profile.totalContestsParticipated, 0);
        assertEq(profile.totalBattlesParticipated, 0);
        assertTrue(profile.isActive);

        // Test registration with referrer
        manager.registerUser(referrer, address(0), "referrer");
        manager.registerUser(user2, referrer, "testuser2");

        // Verify referral bonuses
        assertEq(gemsContract.balanceOf(user2), 550); // 500 + 50 referral signup bonus
        assertEq(gemsContract.balanceOf(referrer), 600); // 500 + 100 referral bonus

        // Test double registration
        vm.expectRevert("User already registered");
        manager.registerUser(user1, address(0), "duplicate");

        // Test registration when contracts not set
        LearnWayManager newManager = new LearnWayManager();
        vm.expectRevert("Contracts not set");
        newManager.registerUser(user3, address(0), "test");
    }

    // Test quiz completion workflow
    function testQuizCompletionWorkflow() public {
        manager.registerUser(user1, address(0), "testuser1");

        // Test quiz completion with good score
        bool[] memory correctAnswers = new bool[](5);
        correctAnswers[0] = true;
        correctAnswers[1] = true;
        correctAnswers[2] = false;
        correctAnswers[3] = true;
        correctAnswers[4] = true;

        uint256 initialGems = gemsContract.balanceOf(user1);
        uint256 initialXP = xpContract.getXP(user1);

        vm.expectEmit(true, false, false, true);
        emit QuizCompleted(user1, 85, 30, 14); // (85-70)*2 gems, 4*4-1*2 XP (correct-incorrect)
        manager.completeQuiz(user1, 85, correctAnswers, "guess_word", 120, false);

        // Verify gems and XP awarded correctly
        assertEq(gemsContract.balanceOf(user1), initialGems + 30 + 100); // Dynamic reward + achievement reward
        assertEq(xpContract.getXP(user1), initialXP + 14); // 4 correct * 4 XP - 1 incorrect * 2 XP

        // Verify user profile updated
        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.totalQuizzesCompleted, 1);

        // Verify badges contract called
        assertEq(badgesContract.userCorrectAnswers(user1), 4);

        // Test quiz with score below minimum
        bool[] memory allWrong = new bool[](3);
        allWrong[0] = false;
        allWrong[1] = false;
        allWrong[2] = false;

        uint256 gemsBeforeLowScore = gemsContract.balanceOf(user1);
        uint256 xpBeforeLowScore = xpContract.getXP(user1);

        manager.completeQuiz(user1, 60, allWrong, "fun_learn", 180, true);

        // Should get 0 gems (below 70%) but XP should decrease for wrong answers
        assertEq(gemsContract.balanceOf(user1), gemsBeforeLowScore); // No gems for score < 70%
        assertEq(xpContract.getXP(user1), xpBeforeLowScore - 6); // 3 wrong * 2 XP each deducted

        // Test with unregistered user
        vm.expectRevert("User not registered");
        manager.completeQuiz(user2, 85, correctAnswers, "test", 100, false);
    }

    // Test achievement system functionality
    function testAchievementSystemFunctionality() public {
        manager.registerUser(user1, address(0), "testuser1");

        // Add a test achievement
        manager.addAchievement("test_achievement", "Test Achievement", "Complete your first quiz", 100, 1, "quizzes");

        // Complete a quiz to trigger achievement check
        bool[] memory correctAnswers = new bool[](3);
        correctAnswers[0] = true;
        correctAnswers[1] = true;
        correctAnswers[2] = true;

        uint256 initialGems = gemsContract.balanceOf(user1);

        // This should trigger the achievement
        manager.completeQuiz(user1, 85, correctAnswers, "test", 100, false);

        // Check if achievement was unlocked (this would emit an event in a full implementation)
        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.totalQuizzesCompleted, 1);

        // Test achievement management
        assertTrue(manager.isAchievementActive("test_achievement"));

        // Test deactivating achievement
        manager.deactivateAchievement("test_achievement");
        assertFalse(manager.isAchievementActive("test_achievement"));

        // Test only owner can manage achievements
        vm.prank(user1);
        vm.expectRevert();
        manager.addAchievement("test", "Test", "Test", 50, 1, "quizzes");
    }

    // Test user profile management
    function testUserProfileManagement() public {
        manager.registerUser(user1, address(0), "testuser1");

        // Test updating profile
        vm.expectEmit(true, false, false, true);
        emit UserProfileUpdated(user1, "Updated profile data");
        manager.updateUserProfile(user1, "newusername", "QmNewImageHash", "Updated profile data");

        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.username, "newusername");
        assertEq(profile.profileImageHash, "QmNewImageHash");

        // Test deactivating user
        manager.deactivateUser(user1);
        profile = manager.getUserProfile(user1);
        assertFalse(profile.isActive);

        // Test reactivating user
        manager.reactivateUser(user1);
        profile = manager.getUserProfile(user1);
        assertTrue(profile.isActive);

        // Test only owner can manage profiles
        vm.prank(user2);
        vm.expectRevert();
        manager.updateUserProfile(user1, "hacker", "hack", "hacked");
    }

    // Test contest and battle integration
    function testContestAndBattleIntegration() public {
        manager.registerUser(user1, address(0), "testuser1");

        // Test contest participation
        uint256 initialGems = gemsContract.balanceOf(user1);
        uint256 initialXP = xpContract.getXP(user1);

        vm.expectEmit(true, false, false, true);
        emit ContestCompleted(user1, "weekly_challenge", 200, 100);
        manager.participateInContest(user1, "weekly_challenge", 200, 100);

        assertEq(gemsContract.balanceOf(user1), initialGems + 200 + 150); // Contest reward + contest_participant achievement
        assertEq(xpContract.getXP(user1), initialXP + 100);

        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.totalContestsParticipated, 1);

        // Test battle completion
        initialGems = gemsContract.balanceOf(user1);
        initialXP = xpContract.getXP(user1);

        vm.expectEmit(true, false, false, true);
        emit BattleCompleted(user1, "1v1", true, 150, 50);
        manager.completeBattle(user1, "1v1", true, 150, 50, false);

        assertEq(gemsContract.balanceOf(user1), initialGems + 150 + 200); // Battle reward + first_battle achievement
        assertEq(xpContract.getXP(user1), initialXP + 50);

        profile = manager.getUserProfile(user1);
        assertEq(profile.totalBattlesParticipated, 1);

        // Verify badges contract integration
        assertEq(badgesContract.userConsecutiveWins(user1), 1);

        // Test battle loss
        manager.completeBattle(user1, "group", false, 0, 0, false);
        profile = manager.getUserProfile(user1);
        assertEq(profile.totalBattlesParticipated, 2);
    }

    // Test monthly reward distribution
    function testMonthlyRewardDistribution() public {
        manager.registerUser(user1, address(0), "user1");
        manager.registerUser(user2, address(0), "user2");
        manager.registerUser(user3, address(0), "user3");

        // Set up monthly top users
        address[] memory topUsers = new address[](3);
        uint256[] memory rewards = new uint256[](3);
        topUsers[0] = user1;
        topUsers[1] = user2;
        topUsers[2] = user3;
        rewards[0] = 1000;
        rewards[1] = 500;
        rewards[2] = 250;

        uint256[] memory initialBalances = new uint256[](3);
        initialBalances[0] = gemsContract.balanceOf(user1);
        initialBalances[1] = gemsContract.balanceOf(user2);
        initialBalances[2] = gemsContract.balanceOf(user3);

        vm.expectEmit(true, false, false, true);
        emit MonthlyRewardsDistributed(9, 2025, topUsers, rewards);
        manager.distributeMonthlyRewards(9, 2025, topUsers, rewards);

        // Verify rewards distributed
        assertEq(gemsContract.balanceOf(user1), initialBalances[0] + 1000);
        assertEq(gemsContract.balanceOf(user2), initialBalances[1] + 500);
        assertEq(gemsContract.balanceOf(user3), initialBalances[2] + 250);

        // Test that rewards are tracked
        assertTrue(manager.isMonthlyRewardDistributed(9, 2025));

        // Test can't distribute twice for same month
        vm.expectRevert("Rewards already distributed for this month");
        manager.distributeMonthlyRewards(9, 2025, topUsers, rewards);

        // Test invalid arrays
        address[] memory invalidUsers = new address[](2);
        vm.expectRevert("Arrays length mismatch");
        manager.distributeMonthlyRewards(10, 2025, invalidUsers, rewards);
    }

    // Test achievement unlocking mechanisms
    function testAchievementUnlockingMechanisms() public {
        manager.registerUser(user1, address(0), "testuser1");

        // Add various achievements
        manager.addAchievement("test_quiz_master", "Test Quiz Master", "Complete 5 quizzes", 200, 5, "quizzes");
        manager.addAchievement("test_xp_champion", "Test XP Champion", "Reach 1000 XP", 500, 1000, "xp");
        manager.addAchievement(
            "test_contest_warrior", "Test Contest Warrior", "Participate in 3 contests", 300, 3, "contests"
        );

        // Complete activities to unlock achievements
        bool[] memory correctAnswers = new bool[](3);
        correctAnswers[0] = true;
        correctAnswers[1] = true;
        correctAnswers[2] = true;

        // Complete 5 quizzes
        for (uint256 i = 0; i < 5; i++) {
            manager.completeQuiz(user1, 85, correctAnswers, "test", 100, false);
        }

        // Participate in 3 contests
        for (uint256 i = 0; i < 3; i++) {
            string memory contestId = string(abi.encodePacked("contest_", vm.toString(i)));
            manager.participateInContest(user1, contestId, 100, 200);
        }

        // Award additional XP to reach 1000 through manager
        uint256 currentXP = xpContract.getXP(user1);
        // Since we can't directly award XP, we'll complete more activities to reach 1000 XP
        // Current XP should be around 700-800 from the activities above, so this is mainly for verification

        // Check achievements (in a full implementation, these would be automatically checked)
        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.totalQuizzesCompleted, 5);
        assertEq(profile.totalContestsParticipated, 3);
        // Verify XP was earned from activities (5 quizzes * 12 XP + 3 contests * 200 XP = 660 XP)
        assertEq(xpContract.getXP(user1), 660);
    }

    // Test multi-contract integration scenarios
    function testMultiContractIntegrationScenarios() public {
        manager.registerUser(user1, address(0), "testuser1");

        // Test scenario: Complete quiz, participate in contest, complete battle
        bool[] memory correctAnswers = new bool[](4);
        correctAnswers[0] = true;
        correctAnswers[1] = false;
        correctAnswers[2] = true;
        correctAnswers[3] = true;

        uint256 initialGems = gemsContract.balanceOf(user1);
        uint256 initialXP = xpContract.getXP(user1);

        // Quiz completion
        manager.completeQuiz(user1, 90, correctAnswers, "integration_test", 90, false);

        uint256 expectedGems = initialGems + 40 + 100; // (90-70)*2 + achievement reward
        uint256 expectedXP = initialXP + 10; // 3 correct (12) - 1 incorrect (2) = 10

        assertEq(gemsContract.balanceOf(user1), expectedGems);
        assertEq(xpContract.getXP(user1), expectedXP);

        // Contest participation
        manager.participateInContest(user1, "integration_contest", 300, 150);
        expectedGems += 300 + 150; // Contest reward + contest_participant achievement
        expectedXP += 150;

        assertEq(gemsContract.balanceOf(user1), expectedGems);
        assertEq(xpContract.getXP(user1), expectedXP);

        // Battle completion
        manager.completeBattle(user1, "integration_battle", true, 200, 100, true);
        expectedGems += 200 + 200; // Battle reward + first_battle achievement
        expectedXP += 100;

        assertEq(gemsContract.balanceOf(user1), expectedGems);
        assertEq(xpContract.getXP(user1), expectedXP);

        // Verify all profile counters updated
        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.totalQuizzesCompleted, 1);
        assertEq(profile.totalContestsParticipated, 1);
        assertEq(profile.totalBattlesParticipated, 1);

        // Verify badges contract received all calls
        assertEq(badgesContract.userCorrectAnswers(user1), 3);
        assertEq(badgesContract.userConsecutiveWins(user1), 1);
    }

    // Test error handling and edge cases
    function testErrorHandlingAndEdgeCases() public {
        // Test operations without contract setup
        LearnWayManager newManager = new LearnWayManager();

        vm.expectRevert("Contracts not set");
        newManager.registerUser(user1, address(0), "test");

        // Test with registered user
        manager.registerUser(user1, address(0), "testuser1");

        // Test quiz with invalid score
        bool[] memory answers = new bool[](1);
        answers[0] = true;

        vm.expectRevert("Invalid score");
        manager.completeQuiz(user1, 101, answers, "test", 100, false);

        // Test empty username
        vm.expectRevert("Username cannot be empty");
        manager.registerUser(user2, address(0), "");

        // Test invalid addresses
        vm.expectRevert("Invalid address");
        manager.registerUser(address(0), address(0), "test");

        // Test operations when paused
        manager.pause();

        vm.expectRevert();
        manager.registerUser(user3, address(0), "pausedtest");

        vm.expectRevert();
        manager.completeQuiz(user1, 85, answers, "test", 100, false);

        // Unpause and test operations work again
        manager.unpause();
        manager.registerUser(user3, address(0), "resumedtest");
        assertTrue(gemsContract.isRegistered(user3));

        // Test access control
        vm.prank(user1);
        vm.expectRevert();
        manager.registerUser(user2, address(0), "unauthorized");

        vm.prank(user1);
        vm.expectRevert();
        manager.pause();
    }

    // Test gas optimization scenarios
    function testGasOptimizationScenarios() public {
        manager.registerUser(user1, address(0), "testuser1");

        // Test batch operations would be more gas efficient
        // This test ensures individual operations work correctly

        bool[] memory correctAnswers = new bool[](10);
        for (uint256 i = 0; i < 10; i++) {
            correctAnswers[i] = i % 2 == 0; // Alternate correct/incorrect
        }

        uint256 gasBefore = gasleft();
        manager.completeQuiz(user1, 85, correctAnswers, "gas_test", 120, false);
        uint256 gasUsed = gasBefore - gasleft();

        // Ensure gas usage is reasonable (this is a basic check)
        assertLt(gasUsed, 1000000); // Should use less than 1M gas

        // Test multiple operations
        gasBefore = gasleft();
        manager.participateInContest(user1, "gas_contest", 100, 50);
        manager.completeBattle(user1, "gas_battle", true, 75, 25, false);
        gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 1500000); // Should use reasonable gas for multiple operations
    }

    // Test data consistency across contracts
    function testDataConsistencyAcrossContracts() public {
        manager.registerUser(user1, address(0), "consistency_test");

        // Verify user is consistently registered across all contracts
        assertTrue(gemsContract.isRegistered(user1));
        assertTrue(xpContract.isRegistered(user1));

        // Perform operations and verify consistency
        bool[] memory answers = new bool[](5);
        for (uint256 i = 0; i < 5; i++) {
            answers[i] = true;
        }

        manager.completeQuiz(user1, 95, answers, "consistency_quiz", 60, false);

        // Verify data is consistent
        uint256 expectedGems = 500 + 50 + 100; // signup + (95-70)*2 + first_quiz achievement
        uint256 expectedXP = 20; // 5 correct * 4 XP each

        assertEq(gemsContract.balanceOf(user1), expectedGems);
        assertEq(xpContract.getXP(user1), expectedXP);

        LearnWayManager.UserProfile memory profile = manager.getUserProfile(user1);
        assertEq(profile.totalQuizzesCompleted, 1);

        // Test contest consistency
        manager.participateInContest(user1, "consistency_contest", 200, 100);

        assertEq(gemsContract.balanceOf(user1), expectedGems + 200 + 150); // Contest reward + contest_participant achievement
        assertEq(xpContract.getXP(user1), expectedXP + 100);

        profile = manager.getUserProfile(user1);
        assertEq(profile.totalContestsParticipated, 1);
    }
}
