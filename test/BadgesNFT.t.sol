// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BadgesNFT.sol";
import "../src/LearnWayManager.sol";
import "../src/GemsContract.sol";
import "../src/XPContract.sol";

contract BadgesNFTTest is Test {
    BadgesNFT public badgesContract;
    LearnWayManager public learnWayManager;
    GemsContract public gemsContract;
    XPContract public xpContract;

    address public owner;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy contracts
        badgesContract = new BadgesNFT("https://learnway.com/badges/");
        gemsContract = new GemsContract();
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

        // Register test users (LearnWayManager.registerUser handles both gems and XP registration)
        learnWayManager.registerUser(user1, address(0), "TestUser1");
        learnWayManager.registerUser(user2, user1, "TestUser2");
        learnWayManager.registerUser(user3, user1, "TestUser3");
    }

    function testFirstSparkBadge() public {
        // Test First Spark badge - first quiz completion
        bool[] memory correctAnswers = new bool[](5);
        correctAnswers[0] = true;
        correctAnswers[1] = false;
        correctAnswers[2] = true;
        correctAnswers[3] = true;
        correctAnswers[4] = true;

        // Complete first quiz
        learnWayManager.completeQuiz(
            user1,
            80,
            correctAnswers,
            "fun_learn",
            30,
            false
        );

        // Check if First Spark badge was awarded
        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[0]); // FIRST_SPARK is index 0

        // Check NFT was minted
        assertEq(badgesContract.balanceOf(user1), 1);
    }

    function testDuelChampionBadge() public {
        // Test Duel Champion badge - won 1v1 battle
        learnWayManager.completeBattle(
            user1,
            "1v1",
            true,  // isWin
            100,   // gemsEarned
            0,     // customXP
            150,   // points
            false  // isHighestScore
        );

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[1]); // DUEL_CHAMPION is index 1
    }

    function testSquadSlayerBadge() public {
        // Test Squad Slayer badge - won group battle
        learnWayManager.completeBattle(
            user1,
            "group",
            true,  // isWin
            150,   // gemsEarned
            0,     // customXP
            200,   // points
            false  // isHighestScore
        );

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[2]); // SQUAD_SLAYER is index 2
    }

    function testCrownHolderBadge() public {
        // Test Crown Holder badge - won contest
        learnWayManager.completeContest(
            user1,
            "contest_001",
            200,  // gemsEarned
            100,  // xpEarned
            true  // isWin
        );

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[3]); // CROWN_HOLDER is index 3
    }

    function testLightningAceBadge() public {
        // Test Lightning Ace badge - highest score in 1v1
        learnWayManager.completeBattle(
            user1,
            "1v1",
            true,  // isWin
            100,   // gemsEarned
            0,     // customXP
            300,   // points
            true   // isHighestScore
        );

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[4]); // LIGHTNING_ACE is index 4
    }

    function testQuizWarriorBadge() public {
        // Test Quiz Warrior badge - 3 consecutive wins
        for (uint i = 0; i < 3; i++) {
            learnWayManager.completeBattle(
                user1,
                "1v1",
                true,  // isWin
                50,    // gemsEarned
                0,     // customXP
                100,   // points
                false  // isHighestScore
            );
        }

        (bool[15] memory badges, uint256 totalBadges, uint256 consecutiveWins,,) = badgesContract.getUserBadgeStatus(user1);

        // Should have Quiz Warrior badge due to 3 consecutive wins
        assertTrue(badges[5]); // QUIZ_WARRIOR is index 5
        assertEq(consecutiveWins, 3);

        // Should also have Duel Champion from first win
        assertTrue(badges[1]); // DUEL_CHAMPION is index 1
    }

    function testSupersonicBadge() public {
        // Test Supersonic badge - average 25s or less for guess_word, min 5 questions
        bool[] memory correctAnswers = new bool[](3);
        correctAnswers[0] = true;
        correctAnswers[1] = true;
        correctAnswers[2] = true;

        // Complete 5 guess_word quizzes with good timing
        for (uint i = 0; i < 5; i++) {
            learnWayManager.completeQuiz(
                user1,
                100,
                correctAnswers,
                "guess_word",
                20, // 20 seconds - under 25s threshold
                false
            );
        }

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[6]); // SUPERSONIC is index 6
    }

    function testSpeedScholarBadge() public {
        // Test Speed Scholar badge - average 8s or less for fun_learn, min 5 questions
        bool[] memory correctAnswers = new bool[](2);
        correctAnswers[0] = true;
        correctAnswers[1] = true;

        // Complete 5 fun_learn quizzes with excellent timing
        for (uint i = 0; i < 5; i++) {
            learnWayManager.completeQuiz(
                user1,
                100,
                correctAnswers,
                "fun_learn",
                7, // 7 seconds - under 8s threshold
                false
            );
        }

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[7]); // SPEED_SCHOLAR is index 7
    }

    function testBrainiacBadge() public {
        // Test Brainiac badge - 100% quiz without lifeline, min 5 times
        bool[] memory correctAnswers = new bool[](4);
        correctAnswers[0] = true;
        correctAnswers[1] = true;
        correctAnswers[2] = true;
        correctAnswers[3] = true;

        // Complete 5 perfect quizzes without lifeline
        for (uint i = 0; i < 5; i++) {
            learnWayManager.completeQuiz(
                user1,
                100,
                correctAnswers,
                "general",
                60,
                false // no lifeline used
            );
        }

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[8]); // BRAINIAC is index 8
    }

    function testQuizTitanBadge() public {
        // Test Quiz Titan badge - 5000 correct answers
        // This would take too long to test with individual calls, so we'll test the logic

        // Record a large number of correct answers directly through the badge contract
        bool[] memory correctAnswers = new bool[](100);
        for (uint i = 0; i < 100; i++) {
            correctAnswers[i] = true;
        }

        // Complete 50 quizzes with 100 correct answers each = 5000 total
        for (uint i = 0; i < 50; i++) {
            learnWayManager.completeQuiz(
                user1,
                100,
                correctAnswers,
                "general",
                60,
                false
            );
        }

        (bool[15] memory badges,,,, uint256 correctCount) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[9]); // QUIZ_TITAN is index 9
        assertEq(correctCount, 5000);
    }

    function testEliteBadge() public {
        // Test Elite badge - 5k coins in wallet
        // Award enough gems to reach 5000 through contest completion
        learnWayManager.completeContest(
            user1,
            "elite_test_contest",
            5000, // gemsEarned - enough to reach 5k coins
            100,  // xpEarned
            true  // isWin
        );

        // Trigger additional badge check by completing any activity
        bool[] memory correctAnswers = new bool[](1);
        correctAnswers[0] = true;

        learnWayManager.completeQuiz(
            user1,
            80,
            correctAnswers,
            "general",
            30,
            false
        );

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[10]); // ELITE is index 10

        // Verify gems balance
        assertGe(gemsContract.balanceOf(user1), 5000);
    }

    function testQuizDevoteeBadge() public {
        // Test Quiz Devotee badge - 30 days daily quiz play
        // We'll simulate 30 days of quiz completion

        bool[] memory correctAnswers = new bool[](1);
        correctAnswers[0] = true;

        uint256 currentTime = block.timestamp;

        // Complete quiz for 30 consecutive days
        for (uint i = 0; i < 30; i++) {
            vm.warp(currentTime + (i * 1 days));

            learnWayManager.completeQuiz(
                user1,
                80,
                correctAnswers,
                "general",
                30,
                false
            );
        }

        (bool[15] memory badges,,, uint256 dailyStreak,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[11]); // QUIZ_DEVOTEE is index 11
        assertEq(dailyStreak, 30);
    }

    function testEchoSpreaderBadge() public {
        // Test Echo Spreader badge - 50+ referrals
        learnWayManager.updateReferralCount(user1, 51);

        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[13]); // ECHO_SPREADER is index 13
    }

    function testRoutineMasterBadge() public {
        // Test Routine Master badge - 30 day streak (same as Quiz Devotee in this implementation)
        bool[] memory correctAnswers = new bool[](1);
        correctAnswers[0] = true;

        uint256 currentTime = block.timestamp;

        // Complete quiz for 30 consecutive days
        for (uint i = 0; i < 30; i++) {
            vm.warp(currentTime + (i * 1 days));

            learnWayManager.completeQuiz(
                user1,
                80,
                correctAnswers,
                "general",
                30,
                false
            );
        }

        (bool[15] memory badges,,, uint256 dailyStreak,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[14]); // ROUTINE_MASTER is index 14
        assertEq(dailyStreak, 30);
    }

    function testPowerEliteBadge() public {
        // Test Power Elite badge - 10+ badges
        // We need to earn 10 different badges first

        bool[] memory correctAnswers = new bool[](10);
        for (uint i = 0; i < 10; i++) {
            correctAnswers[i] = true;
        }

        // 1. First Spark - first quiz
        learnWayManager.completeQuiz(user1, 80, correctAnswers, "general", 30, false);

        // 2. Duel Champion - 1v1 win
        learnWayManager.completeBattle(user1, "1v1", true, 100, 0, 150, false);

        // 3. Squad Slayer - group win
        learnWayManager.completeBattle(user1, "group", true, 150, 0, 200, false);

        // 4. Crown Holder - contest win
        learnWayManager.completeContest(user1, "contest_001", 200, 100, true);

        // 5. Lightning Ace - highest score in 1v1
        learnWayManager.completeBattle(user1, "1v1", true, 100, 0, 300, true);

        // 6. Quiz Warrior - 3 consecutive wins (already have some wins, need 1 more)
        learnWayManager.completeBattle(user1, "1v1", true, 50, 0, 100, false);

        // 7. Supersonic - 5 fast guess_word quizzes
        bool[] memory shortAnswers = new bool[](1);
        shortAnswers[0] = true;
        for (uint i = 0; i < 5; i++) {
            learnWayManager.completeQuiz(user1, 100, shortAnswers, "guess_word", 20, false);
        }

        // 8. Speed Scholar - 5 fast fun_learn quizzes
        for (uint i = 0; i < 5; i++) {
            learnWayManager.completeQuiz(user1, 100, shortAnswers, "fun_learn", 7, false);
        }

        // 9. Brainiac - 5 perfect quizzes
        bool[] memory perfectAnswers = new bool[](3);
        perfectAnswers[0] = true;
        perfectAnswers[1] = true;
        perfectAnswers[2] = true;
        for (uint i = 0; i < 5; i++) {
            learnWayManager.completeQuiz(user1, 100, perfectAnswers, "general", 60, false);
        }

        // 10. Elite - 5k coins (award through contest completion)
        learnWayManager.completeContest(
            user1,
            "power_elite_contest",
            5000, // gemsEarned - enough to reach 5k coins
            100,  // xpEarned
            true  // isWin
        );

        // Now check if Power Elite badge was awarded (should trigger automatically when 10th badge is earned)
        (bool[15] memory badges, uint256 totalBadges,,,) = badgesContract.getUserBadgeStatus(user1);

        assertGe(totalBadges, 10);
        assertTrue(badges[12]); // POWER_ELITE is index 12
    }

    function testBadgeNonTransferability() public {
        // Test that badges are soulbound (non-transferable)

        // Award a badge first
        bool[] memory correctAnswers = new bool[](1);
        correctAnswers[0] = true;

        learnWayManager.completeQuiz(user1, 80, correctAnswers, "general", 30, false);

        assertEq(badgesContract.balanceOf(user1), 1);
        assertEq(badgesContract.balanceOf(user2), 0);

        uint256 tokenId = badgesContract.getUserBadges(user1)[0];

        // Try to transfer - should fail
        vm.startPrank(user1);
        vm.expectRevert("Badges are non-transferable");
        badgesContract.transferFrom(user1, user2, tokenId);
        vm.stopPrank();

        // Badge should still belong to user1
        assertEq(badgesContract.balanceOf(user1), 1);
        assertEq(badgesContract.balanceOf(user2), 0);
    }

    function testBadgeMetadata() public {
        // Test badge metadata functionality
        BadgesNFT.BadgeInfo memory firstSparkInfo = badgesContract.getBadgeInfo(BadgesNFT.BadgeType.FIRST_SPARK);

        assertEq(firstSparkInfo.name, "First Spark");
        assertTrue(bytes(firstSparkInfo.description).length > 0);
        assertTrue(firstSparkInfo.isActive);

        // Award a badge and check tokenURI
        bool[] memory correctAnswers = new bool[](1);
        correctAnswers[0] = true;

        learnWayManager.completeQuiz(user1, 80, correctAnswers, "general", 30, false);

        uint256 tokenId = badgesContract.getUserBadges(user1)[0];
        string memory tokenURI = badgesContract.tokenURI(tokenId);

        // Should contain base URI + badge image URI
        assertTrue(bytes(tokenURI).length > 0);
    }

    function testConsecutiveWinReset() public {
        // Test that consecutive wins reset on loss

        // Win 2 battles
        learnWayManager.completeBattle(user1, "1v1", true, 50, 0, 100, false);
        learnWayManager.completeBattle(user1, "1v1", true, 50, 0, 100, false);

        (, uint256 totalBadges1, uint256 consecutiveWins1,,) = badgesContract.getUserBadgeStatus(user1);
        assertEq(consecutiveWins1, 2);

        // Lose a battle - should reset consecutive wins
        learnWayManager.completeBattle(user1, "1v1", false, 0, 0, 50, false);

        (, uint256 totalBadges2, uint256 consecutiveWins2,,) = badgesContract.getUserBadgeStatus(user1);
        assertEq(consecutiveWins2, 0);

        // Win again - should start from 1
        learnWayManager.completeBattle(user1, "1v1", true, 50, 0, 100, false);

        (, uint256 totalBadges3, uint256 consecutiveWins3,,) = badgesContract.getUserBadgeStatus(user1);
        assertEq(consecutiveWins3, 1);
    }

    function testIntegrationWithExistingContracts() public {
        // Test that the badge system works alongside existing achievement system

        // Complete a quiz - should award both badge and trigger existing achievements
        bool[] memory correctAnswers = new bool[](5);
        for (uint i = 0; i < 5; i++) {
            correctAnswers[i] = true;
        }

        learnWayManager.completeQuiz(user1, 80, correctAnswers, "general", 30, false);

        // Check badge was awarded
        (bool[15] memory badges,,,,) = badgesContract.getUserBadgeStatus(user1);
        assertTrue(badges[0]); // FIRST_SPARK

        // Check gems were awarded
        assertGt(gemsContract.balanceOf(user1), 0);

        // Check XP was recorded
        assertGt(xpContract.getXP(user1), 0);

        // Check user profile was updated
        (
            LearnWayManager.UserProfile memory profile,
            uint256 gemsBalance,
            uint256 xpBalance,
            uint256 userRank,
            bool[15] memory badgesFromManager,
            uint256 totalBadges,,,
        ) = learnWayManager.getUserData(user1);

        assertEq(profile.totalQuizzesCompleted, 1);
        assertTrue(badgesFromManager[0]); // First Spark badge
        assertEq(totalBadges, 1);
        assertGt(gemsBalance, 0);
        assertGt(xpBalance, 0);
    }
}
