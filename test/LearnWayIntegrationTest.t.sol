// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/LearnWayAdmin.sol";
import "../src/LearnWayBadge.sol";
import "../src/LearnWayManager.sol";
import "../src/GemsContract.sol";
import "../src/XPContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LearnWayIntegrationTest is Test {
    // Contracts
    LearnWayAdmin public admin;
    LearnWayBadge public badges;
    LearnWayManager public manager;
    GemsContract public gems;
    XPContract public xp;

    // Proxies for upgradeable contracts
    ERC1967Proxy public adminProxy;
    ERC1967Proxy public gemsProxy;

    // Test users
    address public owner = address(0x1);
    address public adminUser = address(0x2);
    address public managerUser = address(0x3);
    address public alice = address(0x100);
    address public bob = address(0x200);
    address public charlie = address(0x300);
    address public referrer = address(0x400);

    // Events to test
    event UserRegistered(address indexed user, address indexed referrer, uint256 timestamp);
    event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned, uint256 xpChange);
    event BadgeEarned(address indexed user, uint256 indexed badgeId, uint256 tokenId, uint8 tier);
    event GemsAwarded(address indexed user, uint256 amount, string reason);
    event XPAwarded(address indexed user, uint256 amount, string reason);
    event ContestCompleted(address indexed user, string contestId, uint256 gemsEarned, uint256 xpEarned);

     function setUp() public {
        vm.startPrank(owner);

        // Deploy LearnWayAdmin with proxy
        LearnWayAdmin adminImpl = new LearnWayAdmin();
        bytes memory adminInitData = abi.encodeWithSelector(LearnWayAdmin.initialize.selector);
        adminProxy = new ERC1967Proxy(address(adminImpl), adminInitData);
        admin = LearnWayAdmin(address(adminProxy));

        // Set up roles
       

        // Deploy GemsContract with proxy
        GemsContract gemsImpl = new GemsContract();
        bytes memory gemsInitData = abi.encodeWithSelector(
            GemsContract.initialize.selector,
            address(admin)
        );
        gemsProxy = new ERC1967Proxy(address(gemsImpl), gemsInitData);
        gems = GemsContract(address(gemsProxy));

        // Deploy XPContract
        xp = new XPContract(address(admin));

        // Deploy LearnWayBadge
        badges = new LearnWayBadge(address(admin));

        // Deploy LearnWayManager
        manager = new LearnWayManager(address(admin));
        //  use a for loop to grant managers role to all the contracts
        address[] memory contracts = new address[](4);
        contracts[0] = address(gems);
        contracts[1] = address(xp);
        contracts[2] = address(badges);
        contracts[3] = address(manager);
        for (uint256 i = 0; i < contracts.length; i++) {
            admin.grantRole(admin.ADMIN_ROLE(), contracts[i]);
            admin.grantRole(admin.MANAGER_ROLE(), contracts[i]);
        }
         admin.grantRole(admin.ADMIN_ROLE(), adminUser);
        admin.grantRole(admin.MANAGER_ROLE(), managerUser);
        // Set contracts in manager
        manager.setContracts(address(gems), address(xp), address(badges));

        vm.stopPrank();
    }

    // Test 1: Complete user registration flow
    function testCompleteUserRegistration() public {
        vm.startPrank(managerUser);

        // Register Alice without referral
        vm.expectEmit(true, true, false, true);
        emit UserRegistered(alice, address(0), block.timestamp);
        
        manager.registerUser(alice, address(0), "Alice", true);

        // Verify Alice is registered in all contracts
        assertTrue(gems.isRegistered(alice));
        assertTrue(xp.isRegistered(alice));
        (,,,,,,,,, ,,bool kycStatus,,, uint256 totalBadgesEarned, ) = badges.userStats(alice);
        assertEq(totalBadgesEarned, 2); // Keyholder + Early Bird

        // Check initial balances
        assertEq(gems.balanceOf(alice), 500); // Signup bonus
        assertEq(xp.getXP(alice), 0);

        // Verify badges awarded
        assertTrue(badges.userHasBadge(alice, 0)); // Keyholder badge
        assertTrue(badges.userHasBadge(alice, 2)); // Early Bird badge (first 1000 KYC users)

        vm.stopPrank();
    }

    // Test 2: Referral system integration
    function testReferralSystem() public {
        vm.startPrank(managerUser);

        // Register referrer first
        manager.registerUser(referrer, address(0), "Referrer", true);

        // Register Bob with referral
        manager.registerUser(bob, referrer, "Bob", false);

        // Check Bob's gems (signup bonus + referral bonus)
        assertEq(gems.balanceOf(bob), 550); // 500 signup + 50 referral bonus

        // Check referrer's gems (signup bonus + referral reward)
        assertEq(gems.balanceOf(referrer), 600); // 500 signup + 100 referral reward

        // Check referral data
        assertEq(gems.getReferrer(bob), referrer);
        assertEq(gems.getReferralCount(referrer), 1);

        vm.stopPrank();
    }

    // Test 3: Quiz completion flow
    function testQuizCompletion() public {
        vm.startPrank(managerUser);

        // Register user first
        manager.registerUser(alice, address(0), "Alice", true);
        uint256 initialGems = gems.balanceOf(alice);

        // Complete a quiz with 85% score
        uint256 score = 85;
        bool[] memory correctAnswers = new bool[](10);
        for (uint256 i = 0; i < 8; i++) {
            correctAnswers[i] = true; // 8 correct
        }
        correctAnswers[8] = false; // 2 incorrect
        correctAnswers[9] = false;

        manager.completeQuiz(alice, score, correctAnswers);

        // Verify gems awarded: (85 - 70) * 2 = 30
        assertEq(gems.balanceOf(alice), initialGems + 30);

        // Verify XP: 8 correct * 4 - 2 incorrect * 2 = 32 - 4 = 28
        assertEq(xp.getXP(alice), 28);

        // Check quiz stats
        (uint256 totalQuizzes, uint256 correctCount,,,,,,,,,,,,,,) = badges.userStats(alice);
        assertEq(totalQuizzes, 1);
        assertEq(correctCount, 8);

        // Check First Spark badge awarded
        assertTrue(badges.userHasBadge(alice, 1)); // First Spark badge

        vm.stopPrank();
    }

    // Test 4: Contest and Battle flow
    function testContestAndBattle() public {
        vm.startPrank(managerUser);

        // Register users
        manager.registerUser(alice, address(0), "Alice", true);
        manager.registerUser(bob, address(0), "Bob", false);

        // Alice wins a contest
        manager.completeContest(alice, "weekly_contest_1", 100, 50, true);
        
        // Bob participates but doesn't win
        manager.completeContest(bob, "weekly_contest_1", 25, 25, false);

        // Verify gems and XP
        assertEq(gems.balanceOf(alice), 500 + 100); // Initial + contest reward
        assertEq(xp.getXP(alice), 50);

        // Alice wins a battle
        manager.completeBattle(alice, "1v1", true, 50, 0);
        assertEq(gems.balanceOf(alice), 600 + 50); // Previous + battle reward
        assertEq(xp.getXP(alice), 50 + 50); // Default battle win XP

        // Check battle stats in badges
        (,,,, uint256 contestsWon, uint256 battlesWon,,,,,,,,,,) = badges.userStats(alice);
        assertEq(contestsWon, 1);
        assertEq(battlesWon, 1);

        vm.stopPrank();
    }

    // Test 5: Dynamic badge upgrades
    function testDynamicBadgeUpgrades() public {
        vm.startPrank(managerUser);

        // Register Alice with KYC
        manager.registerUser(alice, address(0), "Alice", true);

        // Complete multiple quizzes to trigger badge upgrades
        bool[] memory allCorrect = new bool[](10);
        for (uint256 i = 0; i < 10; i++) {
            allCorrect[i] = true;
        }

        // Complete 100 quizzes
        for (uint256 i = 0; i < 100; i++) {
            manager.completeQuiz(alice, 100, allCorrect);
        }

        // Check quiz badges
        assertTrue(badges.userHasBadge(alice, 3)); // Quiz Explorer badge
        
        // Get token ID for Quiz Explorer badge
        uint256 tokenId = badges.userBadgeTokenId(alice, 3);
        LearnWayBadge.BadgeAttributes memory attrs = badges.getTokenAttributes(tokenId);
        
        // Should be Bronze tier after 100 quizzes
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.BRONZE));

        vm.stopPrank();
    }

    // Test 6: Monthly rewards distribution
    function testMonthlyRewardsDistribution() public {
        vm.startPrank(managerUser);

        // Register multiple users
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;

        for (uint256 i = 0; i < users.length; i++) {
            manager.registerUser(users[i], address(0), string(abi.encodePacked("User", i)), true);
        }

        // Simulate activities to create leaderboard
        bool[] memory answers = new bool[](5);
        for (uint256 i = 0; i < 5; i++) {
            answers[i] = true;
        }

        // Alice completes 10 quizzes
        for (uint256 i = 0; i < 10; i++) {
            manager.completeQuiz(alice, 90, answers);
        }

        // Bob completes 5 quizzes
        for (uint256 i = 0; i < 5; i++) {
            manager.completeQuiz(bob, 85, answers);
        }

        // Charlie completes 3 quizzes
        for (uint256 i = 0; i < 3; i++) {
            manager.completeQuiz(charlie, 80, answers);
        }

        vm.stopPrank();

        // Admin distributes monthly rewards
        vm.startPrank(adminUser);
        
        address[] memory topUsers = new address[](3);
        topUsers[0] = alice;
        topUsers[1] = bob; 
        topUsers[2] = charlie;

        manager.distributeMonthlyRewards(1, 2024, topUsers);

        // Verify rewards distributed
        address[] memory rewardedUsers = manager.getMonthlyTopUsers(2024, 1);
        assertEq(rewardedUsers.length, 3);
        assertEq(rewardedUsers[0], alice);

        vm.stopPrank();
    }

    // Test 7: Achievement system
    function testAchievementSystem() public {
        vm.startPrank(managerUser);

        // Register user
        manager.registerUser(alice, address(0), "Alice", true);

        // Complete first quiz to unlock achievement
        bool[] memory answers = new bool[](5);
        for (uint256 i = 0; i < 5; i++) {
            answers[i] = true;
        }

        uint256 gemsBefore = gems.balanceOf(alice);
        manager.completeQuiz(alice, 80, answers);

        // Check achievement unlocked
        assertTrue(manager.hasAchievement(alice, "first_quiz"));

        // Verify achievement reward (100 gems for first quiz)
        uint256 quizGems = (80 - 70) * 2; // 20 gems from quiz
        uint256 achievementGems = 100; // 100 gems from achievement
        assertEq(gems.balanceOf(alice), gemsBefore + quizGems + achievementGems);

        vm.stopPrank();
    }

    // Test 8: KYC status update and Early Bird eligibility
    function testKYCStatusUpdate() public {
        vm.startPrank(managerUser);

        // Register Bob without KYC
        manager.registerUser(bob, address(0), "Bob", false);

        // Bob should have Keyholder badge (Silver tier without KYC)
        assertTrue(badges.userHasBadge(bob, 0));
        uint256 keyholderTokenId = badges.userBadgeTokenId(bob, 0);
        LearnWayBadge.BadgeAttributes memory attrs = badges.getTokenAttributes(keyholderTokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));

        // Bob shouldn't have Early Bird badge
        assertFalse(badges.userHasBadge(bob, 2));

        // Update Bob's KYC status
        badges.updateKycStatus(bob, true);

        // Check Keyholder badge upgraded to Gold
        attrs = badges.getTokenAttributes(keyholderTokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));

        // Check Early Bird badge awarded (if within first 1000)
        (uint256 registrationOrder,,, bool isEligible,,) = badges.getEarlyBirdInfo(bob);
        if (registrationOrder <= 1000) {
            assertTrue(badges.userHasBadge(bob, 2));
        }

        vm.stopPrank();
    }

    // Test 9: Pause and unpause functionality
    function testPauseUnpause() public {
        vm.startPrank(owner);
        admin.grantRole(admin.PAUSER_ROLE(), adminUser);
        vm.stopPrank();

        vm.startPrank(adminUser);
        
        // Pause contracts
        gems.pause();
        xp.pause();
        manager.pause();

        vm.stopPrank();

        // Try to register user while paused (should fail)
        vm.startPrank(managerUser);
        vm.expectRevert("Pausable: paused");
        manager.registerUser(alice, address(0), "Alice", true);
        vm.stopPrank();

        // Unpause contracts
        vm.startPrank(adminUser);
        gems.unpause();
        xp.unpause();
        manager.unpause();
        vm.stopPrank();

        // Now registration should work
        vm.startPrank(managerUser);
        manager.registerUser(alice, address(0), "Alice", true);
        assertTrue(gems.isRegistered(alice));
        vm.stopPrank();
    }

    // Test 10: Access control
    function testAccessControl() public {
        // Non-manager tries to register user (should fail)
        vm.startPrank(alice);
        vm.expectRevert();
        manager.registerUser(bob, address(0), "Bob", true);
        vm.stopPrank();

        // Manager can register user
        vm.startPrank(managerUser);
        manager.registerUser(bob, address(0), "Bob", true);
        assertTrue(gems.isRegistered(bob));
        vm.stopPrank();

        // Only admin can set contracts
        vm.startPrank(managerUser);
        vm.expectRevert();
        manager.setContracts(address(gems), address(xp), address(badges));
        vm.stopPrank();

        vm.startPrank(adminUser);
        manager.setContracts(address(gems), address(xp), address(badges));
        vm.stopPrank();
    }

    // Test 11: Streak tracking and consistency badges
    function testStreakTrackingAndBadges() public {
        vm.startPrank(managerUser);

        // Register user
        manager.registerUser(alice, address(0), "Alice", true);

        // Simulate daily streak activities
        uint256[] memory streakValues = new uint256[](1);
        
        // Update to 30-day streak
        streakValues[0] = 30;
        badges.updateUserStats(alice, 1, streakValues); // statType 1 = streak

        // Check Daily Claims badge (30-day streak)
        assertTrue(badges.userHasBadge(alice, 8)); // Daily Claims badge
        assertTrue(badges.userHasBadge(alice, 9)); // Routine Master badge (30+ days)

        // Update to 60-day streak
        streakValues[0] = 60;
        badges.updateUserStats(alice, 1, streakValues);
        
        // Check Quiz Devotee badge (60+ days)
        assertTrue(badges.userHasBadge(alice, 10)); // Quiz Devotee badge

        // Verify dynamic badge tier upgrade
        uint256 tokenId = badges.userBadgeTokenId(alice, 8);
        LearnWayBadge.BadgeAttributes memory attrs = badges.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER)); // 60 days = Silver

        vm.stopPrank();
    }

    // Test 12: Leaderboard mechanics with multiple users
    function testLeaderboardMechanics() public {
        vm.startPrank(managerUser);

        // Register 5 users
        address[] memory users = new address[](5);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;
        users[3] = address(0x500);
        users[4] = address(0x600);

        for (uint256 i = 0; i < users.length; i++) {
            manager.registerUser(users[i], address(0), string(abi.encodePacked("User", i)), true);
        }

        // Create different XP levels through quiz completions
        bool[] memory answers = new bool[](10);
        for (uint256 i = 0; i < 10; i++) {
            answers[i] = i < 8; // 80% correct
        }

        // Different activity levels for each user
        uint256[] memory quizCounts = new uint256[](5);
        quizCounts[0] = 15; // Alice - most active
        quizCounts[1] = 12; // Bob
        quizCounts[2] = 8;  // Charlie
        quizCounts[3] = 5;  // User 4
        quizCounts[4] = 2;  // User 5 - least active

        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < quizCounts[i]; j++) {
                manager.completeQuiz(users[i], 85, answers);
            }
        }

        // Check leaderboard ordering
        XPContract.LeaderboardEntry[] memory top3 = xp.getTopUsers(3);
        assertEq(top3[0].user, alice); // Most XP
        assertEq(top3[1].user, bob);    // Second most
        assertEq(top3[2].user, charlie); // Third

        // Verify ranks are correct
        assertEq(xp.getUserRank(alice), 1);
        assertEq(xp.getUserRank(bob), 2);
        assertEq(xp.getUserRank(charlie), 3);

        vm.stopPrank();
    }

    // Test 13: Gem spending and economy
    function testGemEconomy() public {
        vm.startPrank(managerUser);

        // Register user
        manager.registerUser(alice, address(0), "Alice", true);
        uint256 initialGems = gems.balanceOf(alice);

        // Earn gems through various activities
        // Quiz completion
        bool[] memory perfectAnswers = new bool[](10);
        for (uint256 i = 0; i < 10; i++) {
            perfectAnswers[i] = true;
        }
        manager.completeQuiz(alice, 100, perfectAnswers); // Earns 60 gems

        // Contest win
        manager.completeContest(alice, "daily_contest", 200, 100, true);

        uint256 earnedGems = gems.balanceOf(alice);
        assertEq(earnedGems, initialGems + 60 + 200);

        vm.stopPrank();

        // Admin spends gems for user (marketplace purchase)
        vm.startPrank(adminUser);
        uint256 spendAmount = 150;
        gems.spendGems(alice, spendAmount, "Marketplace purchase");
        
        assertEq(gems.balanceOf(alice), earnedGems - spendAmount);
        vm.stopPrank();
    }

    // Test 14: Weekly and monthly reward cycles
    function testRewardCycles() public {
        vm.startPrank(adminUser);

        // Register users
        vm.stopPrank();
        vm.startPrank(managerUser);
        
        manager.registerUser(alice, address(0), "Alice", true);
        manager.registerUser(bob, address(0), "Bob", true);
        manager.registerUser(charlie, address(0), "Charlie", true);

        vm.stopPrank();
        vm.startPrank(adminUser);

        // Reset weekly leaderboard
        gems.resetWeeklyLeaderboard(1, 2024);
        assertTrue(gems.isWeeklyLeaderboardReset(1, 2024));

        // Distribute weekly rewards
        address[] memory weeklyTop = new address[](3);
        weeklyTop[0] = alice;
        weeklyTop[1] = bob;
        weeklyTop[2] = charlie;

        uint256[] memory weeklyRewards = new uint256[](3);
        weeklyRewards[0] = 200; // 1st place
        weeklyRewards[1] = 100; // 2nd place
        weeklyRewards[2] = 50;  // 3rd place

        gems.distributeWeeklyRewards(1, 2024, weeklyTop, weeklyRewards);

        // Verify weekly rewards
        address[] memory weeklyWinners = gems.getWeeklyRewardHistory(1, 2024);
        assertEq(weeklyWinners.length, 3);
        assertEq(weeklyWinners[0], alice);

        // Reset monthly leaderboard
        gems.resetMonthlyLeaderboard(1, 2024);
        assertTrue(gems.isMonthlyLeaderboardReset(1, 2024));

        // Distribute monthly rewards
        uint256[] memory monthlyRewards = new uint256[](3);
        monthlyRewards[0] = 1000; // 1st place
        monthlyRewards[1] = 500;  // 2nd place
        monthlyRewards[2] = 250;  // 3rd place

        gems.distributeMonthlyRewards(1, 2024, weeklyTop, monthlyRewards);

        // Verify monthly rewards
        address[] memory monthlyWinners = gems.getMonthlyRewardHistory(1, 2024);
        assertEq(monthlyWinners.length, 3);

        // Verify can't distribute twice
        vm.expectRevert("Rewards already distributed");
        gems.distributeMonthlyRewards(1, 2024, weeklyTop, monthlyRewards);

        vm.stopPrank();
    }

    // Test 15: Badge collection and ultimate badges
    function testBadgeCollection() public {
        vm.startPrank(managerUser);

        // Register user with KYC
        manager.registerUser(alice, address(0), "Alice", true);

        // Simulate earning multiple badges to trigger Power Elite
        // Complete quizzes for quiz badges
        bool[] memory answers = new bool[](10);
        for (uint256 i = 0; i < 10; i++) {
            answers[i] = true;
        }

        // Complete 100 quizzes for Quiz Explorer
        for (uint256 i = 0; i < 100; i++) {
            manager.completeQuiz(alice, 95, answers);
        }

        // Update stats for various badges
        uint256[] memory battleStats = new uint256[](2);
        battleStats[0] = 15; // battles won for Duel Champion
        battleStats[1] = 3;  // contests won for Crown Holder
        badges.updateUserStats(alice, 2, battleStats);

        uint256[] memory financialStats = new uint256[](2);
        financialStats[0] = 1; // first deposit
        financialStats[1] = 3; // transactions for DeFi Voyager
        badges.updateUserStats(alice, 3, financialStats);

        uint256[] memory communityStats = new uint256[](3);
        communityStats[0] = 2; // referrals for Community Connector
        communityStats[1] = 1; // shares for Echo Spreader
        communityStats[2] = 1; // event attendance for Event Star
        badges.updateUserStats(alice, 4, communityStats);

        // Check total badges earned
        (,,,,,,,,, ,,,,, uint256 totalBadges, ) = badges.userStats(alice);

        
        // Power Elite badge should be awarded when user has 10+ badges
        if (totalBadges >= 10) {
            assertTrue(badges.userHasBadge(alice, 18)); // Power Elite badge
        }

        vm.stopPrank();
    }

    // Test 16: XP deduction and negative scenarios
    function testXPDeductionScenarios() public {
        vm.startPrank(managerUser);

        // Register user
        manager.registerUser(alice, address(0), "Alice", true);

        // Complete quiz with mixed results
        bool[] memory mixedAnswers = new bool[](10);
        // 5 correct, 5 incorrect
        for (uint256 i = 0; i < 5; i++) {
            mixedAnswers[i] = true;
        }

        manager.completeQuiz(alice, 75, mixedAnswers);
        
        // XP calculation: 5 correct * 4 - 5 incorrect * 2 = 20 - 10 = 10
        assertEq(xp.getXP(alice), 10);

        // Complete quiz with mostly wrong answers
        bool[] memory wrongAnswers = new bool[](10);
        wrongAnswers[0] = true; // Only 1 correct
        
        manager.completeQuiz(alice, 70, wrongAnswers);
        
        // XP calculation: Previous 10 + (1 * 4 - 9 * 2) = 10 + 4 - 18 = 0 (can't go negative)
        assertEq(xp.getXP(alice), 0);

        vm.stopPrank();
    }

    // Test 17: Profile management and updates
    function testProfileManagement() public {
        vm.startPrank(managerUser);

        // Register user
        manager.registerUser(alice, address(0), "Alice", true);

        // Update profile
        string memory newUsername = "AliceUpdated";
        string memory profileImage = "ipfs://QmXxx";
        manager.updateUserProfile(alice, newUsername, profileImage);

        // Get user data
        (
            LearnWayManager.UserProfile memory profile,
            uint256 gemsBalance,
            uint256 xpBalance,
            uint256 userRank,
            uint256[] memory badgesList,
            uint256 totalBadgesEarned
        ) = manager.getUserData(alice);

        assertEq(profile.username, newUsername);
        assertEq(profile.profileImageHash, profileImage);
        assertTrue(profile.isActive);
        assertEq(gemsBalance, 500); // Initial bonus
        assertEq(totalBadgesEarned, 2); // Keyholder + Early Bird

        vm.stopPrank();

        // Admin deactivates user
        vm.startPrank(adminUser);
        manager.deactivateUser(alice);
        
        (profile,,,,,) = manager.getUserData(alice);
        assertFalse(profile.isActive);

        // Reactivate user
        manager.reactivateUser(alice);
        (profile,,,,,) = manager.getUserData(alice);
        assertTrue(profile.isActive);

        vm.stopPrank();
    }

    // Test 18: Batch operations
    function testBatchOperations() public {
        vm.startPrank(managerUser);

        // Register multiple users
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;

        for (uint256 i = 0; i < users.length; i++) {
            manager.registerUser(users[i], address(0), string(abi.encodePacked("User", i)), true);
        }

        vm.stopPrank();
        vm.startPrank(adminUser);

        // Batch award gems
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 150;
        amounts[2] = 200;

        gems.batchAwardGems(users, amounts, "Batch reward");

        // Verify balances
        assertEq(gems.balanceOf(alice), 600); // 500 initial + 100
        assertEq(gems.balanceOf(bob), 650);   // 500 initial + 150
        assertEq(gems.balanceOf(charlie), 700); // 500 initial + 200

        // Batch update XP
        int256[] memory xpChanges = new int256[](3);
        xpChanges[0] = 50;
        xpChanges[1] = -20;
        xpChanges[2] = 100;

        xp.batchUpdateXP(users, xpChanges, "Batch XP update");

        assertEq(xp.getXP(alice), 50);
        assertEq(xp.getXP(bob), 0); // Can't go negative
        assertEq(xp.getXP(charlie), 100);

        vm.stopPrank();
    }

    // Test 19: Security and blacklist functionality
    function testSecurityFeatures() public {
        vm.startPrank(adminUser);

        // Add user to blacklist
        gems.addToBlacklist(alice);
        assertTrue(gems.isBlacklisted(alice));

        vm.stopPrank();
        vm.startPrank(managerUser);

        // Try to register blacklisted user (should fail)
        vm.expectRevert("Address is blacklisted");
        gems.registerUser(alice, address(0));

        vm.stopPrank();
        vm.startPrank(adminUser);

        // Remove from blacklist
        gems.removeFromBlacklist(alice);
        assertFalse(gems.isBlacklisted(alice));

        // Batch blacklist update
        address[] memory blacklistUsers = new address[](2);
        blacklistUsers[0] = bob;
        blacklistUsers[1] = charlie;
        
        bool[] memory blacklistStatuses = new bool[](2);
        blacklistStatuses[0] = true;
        blacklistStatuses[1] = true;

        gems.batchUpdateBlacklist(blacklistUsers, blacklistStatuses);

        assertTrue(gems.isBlacklisted(bob));
        assertTrue(gems.isBlacklisted(charlie));

        vm.stopPrank();
    }

    // Test 20: Edge cases and limits
    function testEdgeCasesAndLimits() public {
        vm.startPrank(managerUser);

        // Test Early Bird limit (only first 1000 KYC users)
        uint256 startingEarlyBirds = badges.earlyBirdCount();
        
        // Register users up to the limit
        for (uint256 i = startingEarlyBirds; i < 1000 && i < startingEarlyBirds + 10; i++) {
            address user = address(uint160(0x1000 + i));
            manager.registerUser(user, address(0), "User", true);
            
            if (i < 1000) {
                assertTrue(badges.userHasBadge(user, 2)); // Should have Early Bird
            }
        }

        // Register user after limit
        address lateUser = address(0x9999);
        if (badges.earlyBirdCount() >= 1000) {
            manager.registerUser(lateUser, address(0), "LateUser", true);
            assertFalse(badges.userHasBadge(lateUser, 2)); // No Early Bird badge
        }

        // Test quiz score boundaries
        manager.registerUser(alice, address(0), "Alice", true);
        
        // Score below threshold (no gems)
        bool[] memory answers = new bool[](1);
        answers[0] = false;
        manager.completeQuiz(alice, 69, answers);
        assertEq(gems.balanceOf(alice), 500); // Only initial bonus

        // Score at threshold
        manager.completeQuiz(alice, 70, answers);
        assertEq(gems.balanceOf(alice), 500); // Still no gems (70-70)*2 = 0

        // Perfect score
        answers[0] = true;
        manager.completeQuiz(alice, 100, answers);
        assertEq(gems.balanceOf(alice), 560); // 500 + 60 gems

        vm.stopPrank();
    }

    // Test 21: Contract upgrade scenarios
    function testContractUpgrades() public {
        vm.startPrank(owner);

        // Deploy new implementation
        GemsContract newGemsImpl = new GemsContract();
        
        // Upgrade gems contract
        GemsContract(address(gemsProxy)).upgradeToAndCall(address(newGemsImpl), "");

        // Verify upgrade successful and state preserved
        vm.stopPrank();
        vm.startPrank(managerUser);
        
        manager.registerUser(alice, address(0), "Alice", true);
        assertTrue(gems.isRegistered(alice));
        assertEq(gems.balanceOf(alice), 500);

        vm.stopPrank();
    }

    // Test 22: Complex referral chains
    function testComplexReferralChains() public {
        vm.startPrank(managerUser);

        // Create referral chain: referrer -> alice -> bob -> charlie
        manager.registerUser(referrer, address(0), "Referrer", true);
        manager.registerUser(alice, referrer, "Alice", true);
        manager.registerUser(bob, alice, "Bob", true);
        manager.registerUser(charlie, bob, "Charlie", false);

        // Verify referral relationships
        assertEq(gems.getReferrer(alice), referrer);
        assertEq(gems.getReferrer(bob), alice);
        assertEq(gems.getReferrer(charlie), bob);

        // Verify referral counts
        assertEq(gems.getReferralCount(referrer), 1);
        assertEq(gems.getReferralCount(alice), 1);
        assertEq(gems.getReferralCount(bob), 1);
        assertEq(gems.getReferralCount(charlie), 0);

        // Update referral count in badges
        manager.updateReferralCount(referrer, gems.getReferralCount(referrer));
        manager.updateReferralCount(alice, gems.getReferralCount(alice));

        // Check Community Connector badge
        assertTrue(badges.userHasBadge(referrer, 19)); // Community Connector
        assertTrue(badges.userHasBadge(alice, 19));

        vm.stopPrank();
    }

    // Test 23: Achievement progression
    function testAchievementProgression() public {
        vm.startPrank(adminUser);

        // Add custom achievement
        manager.addCustomAchievement(
            "speedrun_master",
            "Speedrun Master",
            "Complete 10 quizzes with 100% score",
            1000,
            10,
            "perfect_quizzes"
        );

        vm.stopPrank();
        vm.startPrank(managerUser);

        // Register user
        manager.registerUser(alice, address(0), "Alice", true);

        // Complete multiple quizzes to unlock achievements
        bool[] memory perfectAnswers = new bool[](10);
        for (uint256 i = 0; i < 10; i++) {
            perfectAnswers[i] = true;
        }

        // Track gem balance to verify achievement rewards
        uint256 gemsBefore = gems.balanceOf(alice);

        // Complete 50 quizzes for "quiz_master" achievement
        for (uint256 i = 0; i < 50; i++) {
            manager.completeQuiz(alice, 100, perfectAnswers);
        }

        // Check achievements unlocked
        assertTrue(manager.hasAchievement(alice, "first_quiz"));
        assertTrue(manager.hasAchievement(alice, "quiz_master"));

        // Verify gem rewards from achievements
        uint256 gemsAfter = gems.balanceOf(alice);
        uint256 quizGems = 60 * 50; // 60 gems per perfect quiz * 50 quizzes
        uint256 achievementGems = 100 + 500; // first_quiz + quiz_master
        assertEq(gemsAfter, gemsBefore + quizGems + achievementGems);

        vm.stopPrank();
    }
}