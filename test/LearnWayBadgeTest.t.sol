// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/LearnWayBadge.sol";
import "../src/LearnWayAdmin.sol";

// Mock Admin Contract for testing

contract LearnWayBadgeTest is Test {
    LearnWayBadge public badgeImplementation;
    LearnWayBadge public badge;
    LearnWayAdmin public adminContract;
    LearnWayAdmin public adminContractImplementation;
    ERC1967Proxy public proxy;
    ERC1967Proxy public proxyAdmin;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public unauthorized = address(0x5);

    event BadgeEarned(address indexed user, uint256 indexed badgeId, uint256 tokenId, LearnWayBadge.BadgeTier tier);
    event BadgeUpgraded(
        address indexed user, uint256 indexed badgeId, uint256 tokenId, LearnWayBadge.BadgeTier newTier
    );
    event MetadataUpdate(uint256 tokenId);

    function setUp() public {
        vm.startPrank(admin);

        // Deploy mock admin contract
        adminContractImplementation = new LearnWayAdmin();

        // Deploy implementation
        badgeImplementation = new LearnWayBadge();

        // Deploy Ademin
        bytes memory initDataAdmin = abi.encodeWithSelector(LearnWayAdmin.initialize.selector);
        proxyAdmin = new ERC1967Proxy(address(adminContractImplementation), initDataAdmin);

        adminContract = LearnWayAdmin(address(proxyAdmin));

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(LearnWayBadge.initialize.selector, address(adminContract));

        proxy = new ERC1967Proxy(address(badgeImplementation), initData);
        badge = LearnWayBadge(address(proxy));

        bool isAdmin = adminContract.hasRole(adminContract.ADMIN_ROLE(), admin);
        assert(isAdmin == true);
        adminContract.grantRole(adminContract.ADMIN_ROLE(), address(proxy));
        adminContract.grantRole(adminContract.MANAGER_ROLE(), manager);

        // Set base URI
        badge.setBaseTokenURI("https://api.learnway.io/images/");
        vm.stopPrank();
    }

    // ==================== INITIALIZATION TESTS ====================

    function testInitialization() public view {
        assertEq(badge.name(), "LearnWay Badge");
        assertEq(badge.symbol(), "LWB");
        assertEq(address(badge.adminContract()), address(adminContract));
        assertEq(badge.earlyBirdCount(), 0);
        assertEq(badge.MAX_EARLY_BIRD_SPOTS(), 1000);

        // Check first few badges are initialized correctly
        (
            string memory name,
            LearnWayBadge.BadgeCategory category,
            string memory emoji,
            bool isDynamic,
            uint256 maxSupply,
        ) = badge.badges(0);
        assertEq(name, "Keyholder");
        assertEq(uint256(category), uint256(LearnWayBadge.BadgeCategory.ONBOARDING));
        assertTrue(isDynamic);
        assertEq(maxSupply, 0);
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert();
        badge.initialize(address(adminContract));
    }

    // ==================== ACCESS CONTROL TESTS ====================

    function testOnlyAdminModifier() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        badge.setBaseTokenURI("new-uri");

        vm.prank(admin);
        badge.setBaseTokenURI("new-uri");
        assertEq(badge.baseTokenURI(), "new-uri");
    }

    function testOnlyAdminOrManagerModifier() public {
        vm.prank(unauthorized);
        vm.expectRevert("UnauthorizedAdminOrManager()");
        badge.registerUser(user1, true);

        vm.prank(manager);
        badge.registerUser(user1, true);
        assertTrue(badge.userHasBadge(user1, 0));
    }

    function testUpdateAdminContract() public {
        LearnWayAdmin newAdmin = new LearnWayAdmin();

        vm.prank(unauthorized);
        vm.expectRevert("UnauthorizedAdmin()");
        badge.updateAdminContract(address(newAdmin));

        vm.prank(admin);
        badge.updateAdminContract(address(newAdmin));
        assertEq(address(badge.adminContract()), address(newAdmin));
    }

    // ==================== USER REGISTRATION TESTS ====================

    function testRegisterUserWithKYC() public {
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit BadgeEarned(user1, 0, 1, LearnWayBadge.BadgeTier.GOLD);
        badge.registerUser(user1, true);

        // Check user stats
        (,,,,,,,,,,, bool kycCompleted,,, uint256 totalBadges) = badge.userStats(user1);
        assertTrue(kycCompleted);
        assertEq(totalBadges, 2); // Keyholder + Early Bird

        // Check badges earned
        assertTrue(badge.userHasBadge(user1, 0)); // Keyholder
        assertTrue(badge.userHasBadge(user1, 2)); // Early Bird
        assertEq(badge.earlyBirdCount(), 1);
    }

    function testRegisterUserWithoutKYC() public {
        vm.prank(manager);
        badge.registerUser(user1, false);

        // Check keyholder badge tier is Silver
        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
    }

    function testCannotRegisterUserTwice() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        vm.prank(manager);
        vm.expectRevert("User already registered");
        badge.registerUser(user1, false);
    }

    function testEarlyBirdLimit() public {
        // Register 1000 users to exhaust early bird spots
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(1000 + i));
            vm.prank(manager);
            badge.registerUser(user, false);
        }

        assertEq(badge.earlyBirdCount(), 1000);

        // Next user shouldn't get early bird
        vm.prank(manager);
        badge.registerUser(user1, false);
        assertFalse(badge.userHasBadge(user1, 2)); // No Early Bird
        assertEq(badge.earlyBirdCount(), 1000); // Count unchanged
    }

    // ==================== QUIZ BADGES TESTS ====================

    function testFirstSparkBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](3);
        values[0] = 1; // quizzes completed
        values[1] = 5; // correct answers
        values[2] = 1; // current level

        vm.prank(manager);
        badge.updateUserStats(user1, 0, values); // Quiz stats

        assertTrue(badge.userHasBadge(user1, 1)); // First Spark
    }

    function testQuizExplorerProgression() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Award initial 100 quizzes (Bronze tier)
        uint256[] memory values = new uint256[](3);
        values[0] = 100;
        values[1] = 50;
        values[2] = 5;

        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        assertTrue(badge.userHasBadge(user1, 3)); // Quiz Explorer
        uint256 tokenId = badge.userBadgeTokenId(user1, 3);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.BRONZE));
        assertEq(attrs.progress, 100);

        // Upgrade to Silver tier (500 total quizzes)
        values[0] = 400; // Additional quizzes
        values[1] = 200; // Additional correct answers
        values[2] = 10;

        vm.expectEmit(true, true, true, true);
        emit BadgeUpgraded(user1, 3, tokenId, LearnWayBadge.BadgeTier.SILVER);

        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
        assertEq(attrs.progress, 500);
        assertEq(attrs.maxProgress, 500);
        assertEq(attrs.status, "Advanced Explorer");

        // Upgrade to Gold tier (1000 total quizzes)
        values[0] = 500; // Additional quizzes
        values[1] = 250;
        values[2] = 15;

        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
        assertEq(attrs.progress, 1000);
        assertEq(attrs.status, "Master Explorer");
    }

    function testMasterOfLevelsProgression() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Reach level 10 (Bronze tier)
        uint256[] memory values = new uint256[](3);
        values[0] = 50;
        values[1] = 25;
        values[2] = 10;

        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        assertTrue(badge.userHasBadge(user1, 4)); // Master of Levels
        uint256 tokenId = badge.userBadgeTokenId(user1, 4);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.BRONZE));

        // Upgrade to Silver (level 50)
        values[2] = 50;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));

        // Upgrade to Gold (level 100)
        values[2] = 100;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
    }

    function testQuizTitanProgression() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Award 100 correct answers (Bronze tier)
        uint256[] memory values = new uint256[](3);
        values[0] = 200;
        values[1] = 100;
        values[2] = 5;

        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        assertTrue(badge.userHasBadge(user1, 5)); // Quiz Titan
        uint256 tokenId = badge.userBadgeTokenId(user1, 5);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.BRONZE));

        // Test progression to Silver and Gold
        values[1] = 500; // Total correct answers
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));

        values[1] = 1000;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
    }

    // ==================== STREAK BADGES TESTS ====================

    function testDailyClaimsProgression() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Start 30-day streak (Silver tier)
        uint256[] memory values = new uint256[](1);
        values[0] = 30;

        vm.prank(manager);
        badge.updateUserStats(user1, 1, values); // Streak stats

        assertTrue(badge.userHasBadge(user1, 8)); // Daily Claims
        uint256 tokenId = badge.userBadgeTokenId(user1, 8);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
        assertEq(attrs.progress, 30);
        assertEq(attrs.status, "Active Streak");

        // Upgrade to Gold (90 days)
        values[0] = 90;
        vm.prank(manager);
        badge.updateUserStats(user1, 1, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
        assertEq(attrs.status, "Golden Streak");

        // Upgrade to Diamond (180 days)
        values[0] = 180;
        vm.prank(manager);
        badge.updateUserStats(user1, 1, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.DIAMOND));
        assertEq(attrs.status, "Legendary Streak");
    }

    function testRoutineMasterBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](1);
        values[0] = 30;

        vm.prank(manager);
        badge.updateUserStats(user1, 1, values);

        assertTrue(badge.userHasBadge(user1, 9)); // Routine Master
    }

    function testQuizDevoteeBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](1);
        values[0] = 60; // 30 days x2

        vm.prank(manager);
        badge.updateUserStats(user1, 1, values);

        assertTrue(badge.userHasBadge(user1, 10)); // Quiz Devotee
    }

    // ==================== BATTLE BADGES TESTS ====================

    function testBattleBadges() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Win 15 battles for Duel Champion
        uint256[] memory values = new uint256[](2);
        values[0] = 15; // battles won
        values[1] = 0; // contests won

        vm.prank(manager);
        badge.updateUserStats(user1, 2, values); // Battle stats

        assertTrue(badge.userHasBadge(user1, 12)); // Duel Champion

        // Win 3 contests for Crown Holder
        values[0] = 0;
        values[1] = 3;

        vm.prank(manager);
        badge.updateUserStats(user1, 2, values);

        assertTrue(badge.userHasBadge(user1, 14)); // Crown Holder
    }

    // ==================== FINANCIAL BADGES TESTS ====================

    function testRisingStarBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](2);
        values[0] = 1; // deposits
        values[1] = 0; // transactions

        vm.prank(manager);
        badge.updateUserStats(user1, 3, values); // Financial stats

        assertTrue(badge.userHasBadge(user1, 15)); // Rising Star
        (,,,,,,,,,,, bool hasFirstDeposit,,,) = badge.userStats(user1);
        assertTrue(hasFirstDeposit);
    }

    function testDeFiVoyagerBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](2);
        values[0] = 0; // deposits
        values[1] = 3; // transactions

        vm.prank(manager);
        badge.updateUserStats(user1, 3, values);

        assertTrue(badge.userHasBadge(user1, 16)); // DeFi Voyager
    }

    function testSavingsChampionBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](2);
        values[0] = 1; // deposits
        values[1] = 0; // transactions

        vm.prank(manager);
        badge.updateUserStats(user1, 3, values);

        assertTrue(badge.userHasBadge(user1, 17)); // Savings Champion
    }

    // ==================== COMMUNITY BADGES TESTS ====================

    function testCommunityConnectorBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](3);
        values[0] = 1; // referrals
        values[1] = 0; // shares
        values[2] = 0; // attended event

        vm.prank(manager);
        badge.updateUserStats(user1, 4, values); // Community stats

        assertTrue(badge.userHasBadge(user1, 19)); // Community Connector
    }

    function testEchoSpreaderBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](3);
        values[0] = 0; // referrals
        values[1] = 1; // shares
        values[2] = 0; // attended event

        vm.prank(manager);
        badge.updateUserStats(user1, 4, values);

        assertTrue(badge.userHasBadge(user1, 20)); // Echo Spreader
    }

    function testEventStarBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](3);
        values[0] = 0; // referrals
        values[1] = 0; // shares
        values[2] = 1; // attended event

        vm.prank(manager);
        badge.updateUserStats(user1, 4, values);

        assertTrue(badge.userHasBadge(user1, 21)); // Event Star
    }

    // ==================== GEMS AND ELITE BADGE TESTS ====================

    function testEliteBadgeProgression() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Start with 1000 gems (Silver tier)
        uint256[] memory values = new uint256[](1);
        values[0] = 1000;

        vm.prank(manager);
        badge.updateUserStats(user1, 5, values); // Gems stats

        assertTrue(badge.userHasBadge(user1, 11)); // Elite
        uint256 tokenId = badge.userBadgeTokenId(user1, 11);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));

        // Upgrade through tiers
        values[0] = 2000; // 3000 total (Gold)
        vm.prank(manager);
        badge.updateUserStats(user1, 5, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));

        values[0] = 2000; // 5000 total (Platinum)
        vm.prank(manager);
        badge.updateUserStats(user1, 5, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.PLATINUM));

        values[0] = 5000; // 10000 total (Diamond)
        vm.prank(manager);
        badge.updateUserStats(user1, 5, values);

        attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.DIAMOND));
        assertEq(attrs.status, "Diamond Elite");
    }

    // ==================== POWER ELITE BADGE TESTS ====================

    function testPowerEliteBadge() public {
        vm.prank(manager);
        badge.registerUser(user1, true); // Gets Keyholder + Early Bird = 2 badges

        // Award multiple badges to reach 10 total
        uint256[] memory values;

        // Quiz badges
        values = new uint256[](3);
        values[0] = 100;
        values[1] = 50;
        values[2] = 10;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values); // Gets First Spark, Quiz Explorer, Master of Levels = +3 badges

        // Streak badges
        values = new uint256[](1);
        values[0] = 60;
        vm.prank(manager);
        badge.updateUserStats(user1, 1, values); // Gets Daily Claims, Routine Master, Quiz Devotee = +3 badges

        // Financial badges
        values = new uint256[](2);
        values[0] = 1;
        values[1] = 3;
        vm.prank(manager);
        badge.updateUserStats(user1, 3, values); // Gets Rising Star, DeFi Voyager, Savings Champion = +3 badges

        // Total: 2 + 3 + 3 + 3 = 11 badges, should trigger Power Elite
        assertTrue(badge.userHasBadge(user1, 18)); // Power Elite

        (,,,,,,,,,,,,,, uint256 totalBadges) = badge.userStats(user1);
        assertGe(totalBadges, 10);
    }

    // ==================== METADATA TESTS ====================

    function testTokenURIGeneration() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0); // Keyholder token
        string memory uri = badge.tokenURI(tokenId);

        // Should contain base64 encoded JSON
        assertTrue(bytes(uri).length > 0);
        // assertEq(bytes(uri)[:29], bytes("data:application/json;base64"));
    }

    function testCustomTokenURI() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);

        vm.prank(admin);
        badge.setTokenURI(tokenId, "https://custom-uri.com/token/1");

        string memory uri = badge.tokenURI(tokenId);
        assertEq(uri, "https://api.learnway.io/images/https://custom-uri.com/token/1");
    }

    function testGetTokenAttributes() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);

        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD)); // KYC completed
        assertEq(attrs.progress, 1);
        assertEq(attrs.maxProgress, 1);
        assertEq(attrs.status, "Earned");
        assertGt(attrs.lastUpdated, 0);
    }

    // ==================== VIEW FUNCTIONS TESTS ====================

    function testGetUserBadges() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory userBadges = badge.getUserBadges(user1);
        assertEq(userBadges.length, 2); // Keyholder + Early Bird
        assertEq(userBadges[0], 0); // Keyholder
        assertEq(userBadges[1], 2); // Early Bird
    }

    function testBadgeSupplyTracking() public {
        (,,,, uint256 maxSupply, uint256 currentSupply) = badge.badges(2); // Early Bird
        assertEq(maxSupply, 1000);
        assertEq(currentSupply, 0);

        vm.prank(manager);
        badge.registerUser(user1, true);

        (,,,,, currentSupply) = badge.badges(2);
        assertEq(currentSupply, 1);
    }

    // ==================== UPGRADEABILITY TESTS ====================

    function testUpgradeContract() public {
        // Deploy new implementation
        LearnWayBadge newImplementation = new LearnWayBadge();

        // Only admin can upgrade
        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        badge.upgradeToAndCall(address(newImplementation), "");

        // Admin can upgrade
        vm.prank(admin);
        badge.upgradeToAndCall(address(newImplementation), "");

        // Contract should still work after upgrade
        assertEq(badge.name(), "LearnWay Badge");
        assertEq(address(badge.adminContract()), address(adminContract));
    }

    // ==================== EDGE CASES AND ERROR TESTS ====================

    function testInvalidStatType() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory values = new uint256[](1);
        values[0] = 100;

        // Invalid stat type (>5) should not revert but also not do anything
        vm.prank(manager);
        badge.updateUserStats(user1, 99, values);
    }

    function testTokenURINonexistentToken() public {
        vm.expectRevert();
        badge.tokenURI(999);
    }

    function testBadgeAlreadyOwned() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // User already has Keyholder badge, try to award again
        // This should be handled gracefully in _awardBadge
        uint256 initialBadgeCount = badge.getUserBadges(user1).length;

        // The contract should handle this internally without reverting
        vm.prank(manager);
        badge.registerUser(user2, true); // This should work fine

        assertEq(badge.getUserBadges(user1).length, initialBadgeCount);
    }

    function testMaxSupplyLimits() public {
        // Test ultimate badges with max supply of 1
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Manually set user stats to trigger Grandmaster conditions
        // (This would normally require complex setup, so we'll test the maxSupply logic directly)
        (,,,, uint256 maxSupply,) = badge.badges(22); // Grandmaster
        assertEq(maxSupply, 1);
    }

    // ==================== INTEGRATION TESTS ====================
    function testFullUserJourney() public {
        // Register user
        vm.prank(manager);
        badge.registerUser(user1, false); // Start without KYC

        uint256[] memory userBadges = badge.getUserBadges(user1);
        assertEq(userBadges.length, 2); // Keyholder (Silver) + Early Bird

        // Complete first quiz
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 1;
        values[2] = 1;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        userBadges = badge.getUserBadges(user1);
        assertEq(userBadges.length, 3); // + First Spark

        // Build up quiz progress over time
        values[0] = 99;
        values[1] = 49;
        values[2] = 5;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values); // Total: 100 quizzes, 50 correct, level 5

        userBadges = badge.getUserBadges(user1);
        assertEq(userBadges.length, 4); // + Quiz Explorer (Bronze)

        // Start building streaks
        uint256[] memory streakValues = new uint256[](1);
        streakValues[0] = 30;
        vm.prank(manager);
        badge.updateUserStats(user1, 1, streakValues);

        userBadges = badge.getUserBadges(user1);
        assertEq(userBadges.length, 6); // + Daily Claims (Silver) + Routine Master

        // Make first deposit
        uint256[] memory financialValues = new uint256[](2);
        financialValues[0] = 1;
        financialValues[1] = 0;
        vm.prank(manager);
        badge.updateUserStats(user1, 3, financialValues);

        userBadges = badge.getUserBadges(user1);
        assertEq(userBadges.length, 8); // + Rising Star + Savings Champion

        // Continue progressing to reach Power Elite threshold
        values[0] = 400;
        values[1] = 450;
        values[2] = 50;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values); // More quiz progress

        userBadges = badge.getUserBadges(user1);
        assertTrue(badge.userHasBadge(user1, 4)); // Master of Levels
        assertTrue(badge.userHasBadge(user1, 5)); // Quiz Titan

        // Should have Power Elite now
        assertTrue(badge.userHasBadge(user1, 18)); // Power Elite
        assertGe(userBadges.length, 10);
    }

    // function testMultipleUsersIsolation() public {
    //     // Register multiple users
    //     vm.prank(manager);
    //     badge.registerUser(user1, true);
    //     vm.prank(manager);
    //     badge.registerUser(user2, false);

    //     // Give user1 some progress
    //     uint256[] memory values = new uint256[](3);
    //     values[0] = 100; values[1] = 50; values[2] = 10;
    //     vm.prank(manager);
    //     badge.updateUserStats(user1, 0, values);

    //     // Check user1 has badges but user2 doesn't
    //     assertTrue(badge.userHasBadge(user1, 1)); // First Spark
    //     assertTrue(badge.userHasBadge(user1, 3)); // Quiz Explorer
    //     assertFalse(badge.userHasBadge(user2, 1));
    //     assertFalse(badge.userHasBadge(user2, 3));

    //     // Check user stats are isolated
    //     (uint256 user1Quizzes,,,,,,,,,,,,,) = badge.userStats(user1);
    //     (uint256 user2Quizzes,,,,,,,,,,,,,) = badge.userStats(user2);
    //     assertEq(user1Quizzes, 100);
    //     assertEq(user2Quizzes, 0);
    // }

    // ==================== STRESS TESTS ====================

    // function testLargeStatUpdates() public {
    //     vm.prank(manager);
    //     badge.registerUser(user1, true);

    //     // Test with very large numbers
    //     uint256[] memory values = new uint256[](3);
    //     values[0] = type(uint256).max / 2;
    //     values[1] = type(uint256).max / 3;
    //     values[2] = type(uint256).max / 4;

    //     vm.prank(manager);
    //     badge.updateUserStats(user1, 0, values);

    //     // Should handle large numbers gracefully
    //     (uint256 totalQuizzes,,,,,,,,,,,,,) = badge.userStats(user1);
    //     assertEq(totalQuizzes, type(uint256).max / 2);
    // }

    function testEmptyValuesArray() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256[] memory emptyValues = new uint256[](0);

        // Should not revert with empty array
        vm.prank(manager);
        badge.updateUserStats(user1, 0, emptyValues);
    }

    // ==================== BADGE SPECIFIC EDGE CASES ====================

    // function testBrainiacBadge() public {
    //     vm.prank(manager);
    //     badge.registerUser(user1, true);

    //     // BRAINIAC requires perfect scores, tested through quiz stats
    //     uint256[] memory values = new uint256[](3);
    //     values[0] = 100;
    //     values[1] = 100;
    //     values[2] = 10; // 100% accuracy

    //     vm.prank(manager);
    //     badge.updateUserStats(user1, 0, values);

    //     assertTrue(badge.userHasBadge(user1, 6)); // BRAINIAC
    // }

    // function testLegendBadge() public {
    //     vm.prank(manager);
    //     badge.registerUser(user1, true);

    //     // Legend requires contest wins
    //     uint256[] memory values = new uint256[](2);
    //     values[0] = 0;
    //     values[1] = 5; // 5 contest wins

    //     vm.prank(manager);
    //     badge.updateUserStats(user1, 2, values);

    //     assertTrue(badge.userHasBadge(user1, 7)); // Legend
    // }

    // function testSquadSlayerBadge() public {
    //     vm.prank(manager);
    //     badge.registerUser(user1, true);

    //     // Squad Slayer requires 12 battle wins (same as Duel Champion logic)
    //     uint256[] memory values = new uint256[](2);
    //     values[0] = 12;
    //     values[1] = 0;

    //     vm.prank(manager);
    //     badge.updateUserStats(user1, 2, values);

    //     assertTrue(badge.userHasBadge(user1, 12)); // Duel Champion (15 required)
    //         // Note: Squad Slayer uses same battle count, but contract awards Duel Champion first
    // }

    // ==================== METADATA CONTENT TESTS ====================

    function testMetadataContent() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        // Award Quiz Explorer with Silver tier
        uint256[] memory values = new uint256[](3);
        values[0] = 500;
        values[1] = 250;
        values[2] = 15;
        vm.prank(manager);
        badge.updateUserStats(user1, 0, values);

        uint256 tokenId = badge.userBadgeTokenId(user1, 3);
        string memory uri = badge.tokenURI(tokenId);

        // Decode and verify JSON structure
        // Since it's base64 encoded, we can't easily test content, but we can test attributes
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
        assertEq(attrs.progress, 500);
        assertEq(attrs.maxProgress, 500);
        assertEq(attrs.status, "Advanced Explorer");
    }

    // ==================== ADMIN FUNCTION TESTS ====================

    function testSetBaseTokenURI() public {
        string memory newURI = "https://new-base-uri.com/";

        vm.prank(unauthorized);
        vm.expectRevert("UnauthorizedAdmin()");
        badge.setBaseTokenURI(newURI);

        vm.prank(admin);
        badge.setBaseTokenURI(newURI);
        assertEq(badge.baseTokenURI(), newURI);
    }

    function testSetCustomTokenURI() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        string memory customURI = "https://custom.com/token/1";

        vm.prank(unauthorized);
        vm.expectRevert("UnauthorizedAdmin()");
        badge.setTokenURI(tokenId, customURI);

        vm.prank(admin);
        badge.setTokenURI(tokenId, customURI);

        assertEq(badge.tokenURI(tokenId), "https://api.learnway.io/images/https://custom.com/token/1");
    }

    // ==================== ERC721 COMPLIANCE TESTS ====================

    function testERC721BasicFunctionality() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);

        // Test ownerOf
        assertEq(badge.ownerOf(tokenId), user1);

        // Test balanceOf
        assertEq(badge.balanceOf(user1), 2); // Keyholder + Early Bird

        // Test tokenURI
        string memory uri = badge.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);

        // Test supportsInterface
        assertTrue(badge.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(badge.supportsInterface(0x5b5e139f)); // ERC721Metadata
    }

    function testTransferRestrictions() public {
        vm.prank(manager);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);

        // Badges should be transferable (no restrictions in contract)
        vm.prank(user1);
        badge.transferFrom(user1, user2, tokenId);

        assertEq(badge.ownerOf(tokenId), user2);
        assertEq(badge.balanceOf(user1), 1); // Only Early Bird left
        assertEq(badge.balanceOf(user2), 1);
    }

    // ==================== HELPER FUNCTIONS FOR TESTING ====================

    function _awardAllBasicBadges(address user) internal {
        vm.prank(manager);
        badge.registerUser(user, true);

        // Quiz progress
        uint256[] memory values = new uint256[](3);
        values[0] = 1000;
        values[1] = 1000;
        values[2] = 100;
        vm.prank(manager);
        badge.updateUserStats(user, 0, values);

        // Streak progress
        values = new uint256[](1);
        values[0] = 180;
        vm.prank(manager);
        badge.updateUserStats(user, 1, values);

        // Battle progress
        values = new uint256[](2);
        values[0] = 15;
        values[1] = 5;
        vm.prank(manager);
        badge.updateUserStats(user, 2, values);

        // Financial progress
        values = new uint256[](2);
        values[0] = 50;
        values[1] = 10;
        vm.prank(manager);
        badge.updateUserStats(user, 3, values);

        // Community progress
        values = new uint256[](3);
        values[0] = 10;
        values[1] = 100;
        values[2] = 1;
        vm.prank(manager);
        badge.updateUserStats(user, 4, values);

        // Gems
        values = new uint256[](1);
        values[0] = 10000;
        vm.prank(manager);
        badge.updateUserStats(user, 5, values);
    }

    function testComprehensiveBadgeAwarding() public {
        _awardAllBasicBadges(user1);

        uint256[] memory userBadges = badge.getUserBadges(user1);

        // Verify major badges are earned
        assertTrue(badge.userHasBadge(user1, 0)); // Keyholder
        assertTrue(badge.userHasBadge(user1, 1)); // First Spark
        assertTrue(badge.userHasBadge(user1, 2)); // Early Bird
        assertTrue(badge.userHasBadge(user1, 3)); // Quiz Explorer
        assertTrue(badge.userHasBadge(user1, 4)); // Master of Levels
        assertTrue(badge.userHasBadge(user1, 5)); // Quiz Titan
        assertTrue(badge.userHasBadge(user1, 8)); // Daily Claims
        assertTrue(badge.userHasBadge(user1, 11)); // Elite
        assertTrue(badge.userHasBadge(user1, 15)); // Rising Star
        assertTrue(badge.userHasBadge(user1, 18)); // Power Elite
        assertTrue(badge.userHasBadge(user1, 19)); // Community Connector
        assertTrue(badge.userHasBadge(user1, 21)); // Event Star

        console.log("Total badges earned:", userBadges.length);
        assertGt(userBadges.length, 15); // Should have earned many badges
    }
}
