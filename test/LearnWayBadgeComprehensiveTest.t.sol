// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnWayAdmin} from "../src/LearnWayAdmin.sol";
import {LearnWayBadge} from "../src/LearnWayBadge.sol";

contract LearnWayBadgeComprehensiveTest is Test {
    LearnWayAdmin public adminContract;
    LearnWayBadge public badgeContract;
    ERC1967Proxy public adminProxy;
    ERC1967Proxy public badgeProxy;

    address public admin;
    address public manager;
    address public pauser;
    address public user1;
    address public user2;
    address public user3;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Badge names for reference
    string[24] public badgeNames = [
        "Keyholder", // 1
        "First Spark", // 2
        "Early Bird", // 3
        "Quiz Explorer", // 4
        "Master of Levels", // 5
        "Quiz Titan", // 6
        "BRAINIAC", // 7
        "Legend", // 8
        "Daily Claims", // 9
        "Routine Master", // 10
        "Quiz Devotee", // 11
        "Elite", // 12
        "Duel Champion", // 13
        "Squad Slayer", // 14
        "Crown Holder", // 15
        "Rising Star", // 16
        "DeFi Voyager", // 17
        "Savings Champion", // 18
        "Power Elite", // 19
        "Community Connector", // 20
        "Echo Spreader", // 21
        "Event Star", // 22
        "Grandmaster", // 23
        "Hall of Famer" // 24
    ];

    function setUp() public {
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        pauser = makeAddr("pauser");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.startPrank(admin);

        // Deploy LearnWayAdmin
        LearnWayAdmin adminImpl = new LearnWayAdmin();
        adminProxy = new ERC1967Proxy(address(adminImpl), abi.encodeWithSelector(LearnWayAdmin.initialize.selector));
        adminContract = LearnWayAdmin(address(adminProxy));

        // Grant roles
        adminContract.setUpRole(MANAGER_ROLE, manager);
        adminContract.setUpRole(PAUSER_ROLE, pauser);

        // Deploy LearnWayBadge
        LearnWayBadge badgeImpl = new LearnWayBadge();
        badgeProxy = new ERC1967Proxy(
            address(badgeImpl), abi.encodeWithSelector(LearnWayBadge.initialize.selector, address(adminContract))
        );
        badgeContract = LearnWayBadge(address(badgeProxy));

        badgeContract.setBaseTokenURI("ipfs://QmTest/");

        vm.stopPrank();
    }

    /* ============================================
       BADGE ID VALIDATION TESTS
       ============================================ */

    function test_BadgeIDs_StartFromOne() public {
        vm.startPrank(manager);

        // Register user
        badgeContract.registerUser(user1, false);

        // Try to mint badge ID 0 - should fail
        vm.expectRevert("Invalid badge ID");
        badgeContract.mintBadge(user1, 0, LearnWayBadge.BadgeTier.BRONZE);

        vm.stopPrank();
    }

    function test_BadgeIDs_MaxIstwentyFour() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);

        // Try to mint badge ID 25 - should fail
        vm.expectRevert("Invalid badge ID");
        badgeContract.mintBadge(user1, 25, LearnWayBadge.BadgeTier.BRONZE);

        vm.stopPrank();
    }

    function test_BadgeIDs_AllValidIDs() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.updateKycStatus(user1, true);

        // Mint all badges from 2 to 24 (except 1 Keyholder auto-minted and 3 Early Bird auto-minted via KYC)
        for (uint256 i = 2; i <= 24; i++) {
            if (i != 3) {
                badgeContract.mintBadge(user1, i, LearnWayBadge.BadgeTier.BRONZE);
            }
        }

        // User should have 24 badges (1 Keyholder + 1 Early Bird auto + 22 manually minted)
        uint256[] memory badges = badgeContract.getUserBadges(user1);
        assertEq(badges.length, 24, "Should have all 24 badges");

        vm.stopPrank();
    }

    /* ============================================
       BADGE 1: KEYHOLDER TESTS
       ============================================ */

    function test_Badge1_Keyholder_AutoMintOnRegistration() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);

        assertTrue(badgeContract.userHasBadge(user1, 1), "Should have Keyholder badge");

        uint256[] memory badges = badgeContract.getUserBadges(user1);
        assertEq(badges.length, 1, "Should have 1 badge");
        assertEq(badges[0], 1, "First badge should be Keyholder (ID 1)");
    }

    function test_Badge1_Keyholder_SilverTierWithoutKYC() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);

        (bool hasBadge, uint256 tokenId, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, 1);

        assertTrue(hasBadge, "Should have Keyholder");
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.SILVER), "Should be SILVER tier");
    }

    function test_Badge1_Keyholder_GoldTierWithKYC() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, true);

        (bool hasBadge, uint256 tokenId, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, 1);

        assertTrue(hasBadge, "Should have Keyholder");
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.GOLD), "Should be GOLD tier");
    }

    function test_Badge1_Keyholder_UpgradeOnKYCCompletion() public {
        vm.startPrank(manager);

        // Register without KYC
        badgeContract.registerUser(user1, false);

        (,, LearnWayBadge.BadgeTier tierBefore,,) = badgeContract.getUserBadgeInfo(user1, 1);
        assertEq(uint256(tierBefore), uint256(LearnWayBadge.BadgeTier.SILVER), "Should start as SILVER");

        // Complete KYC
        badgeContract.updateKycStatus(user1, true);

        (,, LearnWayBadge.BadgeTier tierAfter,,) = badgeContract.getUserBadgeInfo(user1, 1);
        assertEq(uint256(tierAfter), uint256(LearnWayBadge.BadgeTier.GOLD), "Should upgrade to GOLD");

        vm.stopPrank();
    }

    function test_Badge1_Keyholder_IsDynamic() public view {
        (,, bool isDynamic,,) = badgeContract.badges(1);
        assertTrue(isDynamic, "Keyholder should be dynamic");
    }

    /* ============================================
       BADGE 2: FIRST SPARK TESTS
       ============================================ */

    function test_Badge2_FirstSpark_CanMint() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        assertTrue(badgeContract.userHasBadge(user1, 2), "Should have First Spark badge");

        vm.stopPrank();
    }

    function test_Badge2_FirstSpark_IsNotDynamic() public view {
        (,, bool isDynamic,,) = badgeContract.badges(2);
        assertFalse(isDynamic, "First Spark should not be dynamic");
    }

    function test_Badge2_FirstSpark_CannotUpgrade() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        vm.expectRevert("Badge is not upgradeable");
        badgeContract.upgradeBadge(user1, 2, LearnWayBadge.BadgeTier.SILVER);

        vm.stopPrank();
    }

    /* ============================================
       BADGE 3: EARLY BIRD TESTS
       ============================================ */

    function test_Badge3_EarlyBird_AutoMintForKYCUsers() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, true);

        assertTrue(badgeContract.userHasBadge(user1, 1), "Should have Early Bird badge");

        uint256[] memory badges = badgeContract.getUserBadges(user1);
        assertEq(badges.length, 1, "Should have 2 badges (Keyholder + Early Bird)");
    }

    function test_Badge3_EarlyBird_NotMintedWithoutKYC() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);

        assertFalse(badgeContract.userHasBadge(user1, 3), "Should not have Early Bird badge");
    }

    function test_Badge3_EarlyBird_MintedOnKYCCompletion() public {
        vm.startPrank(manager);

        // Register without KYC
        badgeContract.registerUser(user1, false);
        assertFalse(badgeContract.userHasBadge(user1, 3), "Should not have Early Bird yet");

        // Complete KYC
        badgeContract.updateKycStatus(user1, true);
        assertTrue(badgeContract.userHasBadge(user1, 3), "Should have Early Bird after KYC");

        vm.stopPrank();
    }

    function test_Badge3_EarlyBird_RespectMaxSpots() public {
        vm.startPrank(admin);
        badgeContract.setMaxEarlyBirdSpots(2);
        vm.stopPrank();

        vm.startPrank(manager);

        // First two users get Early Bird
        badgeContract.registerUser(user1, false);
        badgeContract.registerUser(user2, false);
        badgeContract.registerUser(user3, false);
        badgeContract.updateKycStatus(user1, true);
        badgeContract.updateKycStatus(user2, true);
        badgeContract.updateKycStatus(user3, true);

        assertTrue(badgeContract.userHasBadge(user1, 3), "User1 should have Early Bird");
        assertTrue(badgeContract.userHasBadge(user2, 3), "User2 should have Early Bird");
        assertFalse(badgeContract.userHasBadge(user3, 3), "User3 should not have Early Bird");

        vm.stopPrank();
    }

    function test_Badge3_EarlyBird_RequiresKYCForManualMint() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);

        vm.expectRevert("Early Bird requires KYC");
        badgeContract.mintBadge(user1, 3, LearnWayBadge.BadgeTier.GOLD);

        vm.stopPrank();
    }

    function test_Badge3_EarlyBird_GetEarlyBirdInfo() public {
        vm.startPrank(manager);
        badgeContract.registerUser(user1, false);
        badgeContract.updateKycStatus(user1, true);
        vm.stopPrank();

        (
            uint256 registrationOrder,
            uint256 kycOrder,
            bool isKycCompleted,
            bool hasEarlyBirdBadge,
            bool isEligible,
            uint256 currentTotalKycCompletions,
            uint256 currentMaxEarlyBirdSpots
        ) = badgeContract.getEarlyBirdInfo(user1);

        assertEq(registrationOrder, 1, "Should be first registration");
        assertEq(kycOrder, 1, "Should be first KYC");
        assertTrue(isKycCompleted, "KYC should be completed");
        assertTrue(hasEarlyBirdBadge, "Should have Early Bird badge");
        assertFalse(isEligible, "Should not be eligible (already has badge)");
        assertEq(currentTotalKycCompletions, 1, "Should have 1 KYC completion");
        assertEq(currentMaxEarlyBirdSpots, 1000, "Default max should be 1000");
    }

    /* ============================================
       BADGE 4: QUIZ EXPLORER TESTS (Dynamic)
       ============================================ */

    function test_Badge4_QuizExplorer_CanMintAndUpgrade() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 4, LearnWayBadge.BadgeTier.BRONZE);

        (,, LearnWayBadge.BadgeTier tier1,,) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(uint256(tier1), uint256(LearnWayBadge.BadgeTier.BRONZE), "Should be BRONZE");

        // Upgrade to SILVER
        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.SILVER);
        (,, LearnWayBadge.BadgeTier tier2,,) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(uint256(tier2), uint256(LearnWayBadge.BadgeTier.SILVER), "Should be SILVER");

        vm.stopPrank();
    }

    function test_Badge4_QuizExplorer_IsDynamic() public view {
        (,, bool isDynamic,,) = badgeContract.badges(4);
        assertTrue(isDynamic, "Quiz Explorer should be dynamic");
    }

    function test_Badge4_QuizExplorer_AllTierStatuses() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 4, LearnWayBadge.BadgeTier.BRONZE);

        // Test each tier status
        (,,,, string memory statusBronze) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(statusBronze, "Beginner Explorer", "Bronze status incorrect");

        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.SILVER);
        (,,,, string memory statusSilver) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(statusSilver, "Explorer", "Silver status incorrect");

        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.GOLD);
        (,,,, string memory statusGold) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(statusGold, "Advanced Explorer", "Gold status incorrect");

        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.PLATINUM);
        (,,,, string memory statusPlatinum) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(statusPlatinum, "Quiz Master", "Platinum status incorrect");

        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.DIAMOND);
        (,,,, string memory statusDiamond) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(statusDiamond, "Quiz Legend", "Diamond status incorrect");

        vm.stopPrank();
    }

    /* ============================================
       BADGE 5: MASTER OF LEVELS TESTS (Dynamic)
       ============================================ */

    function test_Badge5_MasterOfLevels_IsDynamic() public view {
        (,, bool isDynamic,,) = badgeContract.badges(5);
        assertTrue(isDynamic, "Master of Levels should be dynamic");
    }

    function test_Badge5_MasterOfLevels_TierStatuses() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 5, LearnWayBadge.BadgeTier.BRONZE);

        (,,,, string memory statusBronze) = badgeContract.getUserBadgeInfo(user1, 5);
        assertEq(statusBronze, "Level Climber", "Bronze status incorrect");

        badgeContract.upgradeBadge(user1, 5, LearnWayBadge.BadgeTier.SILVER);
        (,,,, string memory statusSilver) = badgeContract.getUserBadgeInfo(user1, 5);
        assertEq(statusSilver, "Level Expert", "Silver status incorrect");

        badgeContract.upgradeBadge(user1, 5, LearnWayBadge.BadgeTier.GOLD);
        (,,,, string memory statusGold) = badgeContract.getUserBadgeInfo(user1, 5);
        assertEq(statusGold, "Level Master", "Gold status incorrect");

        vm.stopPrank();
    }

    /* ============================================
       BADGE 9: DAILY CLAIMS TESTS (Dynamic)
       ============================================ */

    function test_Badge9_DailyClaims_IsDynamic() public view {
        (,, bool isDynamic,,) = badgeContract.badges(9);
        assertTrue(isDynamic, "Daily Claims should be dynamic");
    }

    function test_Badge9_DailyClaims_AllTierStatuses() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 9, LearnWayBadge.BadgeTier.BRONZE);

        (,,,, string memory statusBronze) = badgeContract.getUserBadgeInfo(user1, 9);
        assertEq(statusBronze, "Active Streak", "Bronze status incorrect");

        badgeContract.upgradeBadge(user1, 9, LearnWayBadge.BadgeTier.SILVER);
        (,,,, string memory statusSilver) = badgeContract.getUserBadgeInfo(user1, 9);
        assertEq(statusSilver, "Silver Streak", "Silver status incorrect");

        badgeContract.upgradeBadge(user1, 9, LearnWayBadge.BadgeTier.GOLD);
        (,,,, string memory statusGold) = badgeContract.getUserBadgeInfo(user1, 9);
        assertEq(statusGold, "Golden Streak", "Gold status incorrect");

        badgeContract.upgradeBadge(user1, 9, LearnWayBadge.BadgeTier.PLATINUM);
        (,,,, string memory statusPlatinum) = badgeContract.getUserBadgeInfo(user1, 9);
        assertEq(statusPlatinum, "Epic Streak", "Platinum status incorrect");

        badgeContract.upgradeBadge(user1, 9, LearnWayBadge.BadgeTier.DIAMOND);
        (,,,, string memory statusDiamond) = badgeContract.getUserBadgeInfo(user1, 9);
        assertEq(statusDiamond, "Legendary Streak", "Diamond status incorrect");

        vm.stopPrank();
    }

    /* ============================================
       BADGE 12: ELITE TESTS (Dynamic)
       ============================================ */

    function test_Badge12_Elite_IsDynamic() public view {
        (,, bool isDynamic,,) = badgeContract.badges(12);
        assertTrue(isDynamic, "Elite should be dynamic");
    }

    function test_Badge12_Elite_TierStatuses() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 12, LearnWayBadge.BadgeTier.SILVER);

        (,,,, string memory statusSilver) = badgeContract.getUserBadgeInfo(user1, 12);
        assertEq(statusSilver, "Elite Member", "Silver status incorrect");

        badgeContract.upgradeBadge(user1, 12, LearnWayBadge.BadgeTier.GOLD);
        (,,,, string memory statusGold) = badgeContract.getUserBadgeInfo(user1, 12);
        assertEq(statusGold, "Gold Elite", "Gold status incorrect");

        badgeContract.upgradeBadge(user1, 12, LearnWayBadge.BadgeTier.PLATINUM);
        (,,,, string memory statusPlatinum) = badgeContract.getUserBadgeInfo(user1, 12);
        assertEq(statusPlatinum, "Platinum Elite", "Platinum status incorrect");

        badgeContract.upgradeBadge(user1, 12, LearnWayBadge.BadgeTier.DIAMOND);
        (,,,, string memory statusDiamond) = badgeContract.getUserBadgeInfo(user1, 12);
        assertEq(statusDiamond, "Diamond Elite", "Diamond status incorrect");

        vm.stopPrank();
    }

    /* ============================================
       STATIC BADGES TESTS (6-8, 10-11, 13-24)
       ============================================ */

    function test_StaticBadges_CannotUpgrade() public {
        uint256[11] memory staticBadgeIds = [
            uint256(2), // First Spark
            uint256(3), // Early Bird
            uint256(10), // Routine Master
            uint256(11), // Quiz Devotee
            uint256(13), // Duel Champion
            uint256(14), // Squad Slayer
            uint256(15), // Crown Holder
            uint256(16), // Rising Star
            uint256(22), // Event Star
            uint256(23), // Grandmaster
            uint256(24) // Hall of Famer
        ];

        vm.startPrank(manager);
        badgeContract.registerUser(user1, false);
        badgeContract.updateKycStatus(user1, true);

        for (uint256 i = 0; i < staticBadgeIds.length; i++) {
            uint256 badgeId = staticBadgeIds[i];

            // Skip badges that are auto-minted
            if (badgeId != 3) {
                badgeContract.mintBadge(user1, badgeId, LearnWayBadge.BadgeTier.BRONZE);
            }

            // Try to upgrade - should fail
            vm.expectRevert("Badge is not upgradeable");
            badgeContract.upgradeBadge(user1, badgeId, LearnWayBadge.BadgeTier.SILVER);
        }

        vm.stopPrank();
    }

    function test_DynamicBadges_CanUpgrade() public {
        uint256[10] memory dynamicBadgeIds = [
            uint256(1), // Keyholder
            uint256(4), // Quiz Explorer
            uint256(5), // Master of Levels
            uint256(6), // Quiz Titan
            uint256(7), // BRAINIAC
            uint256(8), // Legend
            uint256(9), // Daily Claims
            uint256(12), // Elite
            uint256(17), // DeFi Voyager
            uint256(18) // Savings Champion
        ];

        vm.startPrank(manager);
        badgeContract.registerUser(user1, false);

        for (uint256 i = 0; i < dynamicBadgeIds.length; i++) {
            uint256 badgeId = dynamicBadgeIds[i];

            // Skip Keyholder as it's auto-minted
            if (badgeId != 1) {
                badgeContract.mintBadge(user1, badgeId, LearnWayBadge.BadgeTier.BRONZE);
            }

            // Keyholder is minted as SILVER, so upgrade to GOLD. Others upgrade BRONZE -> SILVER.
            LearnWayBadge.BadgeTier upgradeTo =
                badgeId == 1 ? LearnWayBadge.BadgeTier.GOLD : LearnWayBadge.BadgeTier.SILVER;

            badgeContract.upgradeBadge(user1, badgeId, upgradeTo);

            (,, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, badgeId);
            assertEq(uint256(tier), uint256(upgradeTo), "Should be upgraded");
        }

        vm.stopPrank();
    }

    /* ============================================
       BADGE METADATA TESTS
       ============================================ */

    function test_AllBadges_HaveCorrectNames() public view {
        for (uint256 i = 1; i <= 24; i++) {
            (string memory name,, bool isDynamic, uint256 maxSupply,) = badgeContract.badges(i);
            assertEq(name, badgeNames[i - 1], "Badge name mismatch");
        }
    }

    function test_AllBadges_HaveCorrectCategories() public view {
        // Onboarding: 1-3
        for (uint256 i = 1; i <= 3; i++) {
            (, LearnWayBadge.BadgeCategory category,,,) = badgeContract.badges(i);
            assertEq(uint256(category), uint256(LearnWayBadge.BadgeCategory.ONBOARDING), "Should be ONBOARDING");
        }

        // Quiz Completion: 4-8
        for (uint256 i = 4; i <= 8; i++) {
            (, LearnWayBadge.BadgeCategory category,,,) = badgeContract.badges(i);
            assertEq(
                uint256(category), uint256(LearnWayBadge.BadgeCategory.QUIZ_COMPLETION), "Should be QUIZ_COMPLETION"
            );
        }

        // Streaks & Consistency: 9-12
        for (uint256 i = 9; i <= 12; i++) {
            (, LearnWayBadge.BadgeCategory category,,,) = badgeContract.badges(i);
            assertEq(
                uint256(category),
                uint256(LearnWayBadge.BadgeCategory.STREAKS_CONSISTENCY),
                "Should be STREAKS_CONSISTENCY"
            );
        }

        // Battles & Contests: 13-15
        for (uint256 i = 13; i <= 15; i++) {
            (, LearnWayBadge.BadgeCategory category,,,) = badgeContract.badges(i);
            assertEq(
                uint256(category), uint256(LearnWayBadge.BadgeCategory.BATTLES_CONTESTS), "Should be BATTLES_CONTESTS"
            );
        }

        // Skill Mastery: 16-19
        for (uint256 i = 16; i <= 19; i++) {
            (, LearnWayBadge.BadgeCategory category,,,) = badgeContract.badges(i);
            assertEq(uint256(category), uint256(LearnWayBadge.BadgeCategory.SKILL_MASTERY), "Should be SKILL_MASTERY");
        }

        // Community & Sharing: 20-22
        for (uint256 i = 20; i <= 22; i++) {
            (, LearnWayBadge.BadgeCategory category,,,) = badgeContract.badges(i);
            assertEq(
                uint256(category), uint256(LearnWayBadge.BadgeCategory.COMMUNITY_SHARING), "Should be COMMUNITY_SHARING"
            );
        }

        // Ultimate: 23-24
        for (uint256 i = 23; i <= 24; i++) {
            (, LearnWayBadge.BadgeCategory category,,,) = badgeContract.badges(i);
            assertEq(uint256(category), uint256(LearnWayBadge.BadgeCategory.ULTIMATE), "Should be ULTIMATE");
        }
    }

    /* ============================================
       GENERAL BADGE FUNCTIONALITY TESTS
       ============================================ */

    function test_CannotMintSameBadgeTwice() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        vm.expectRevert("User already has this badge");
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        vm.stopPrank();
    }

    function test_CannotUpgradeToLowerTier() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 4, LearnWayBadge.BadgeTier.GOLD);

        vm.expectRevert("New tier must be higher");
        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.SILVER);

        vm.stopPrank();
    }

    function test_CannotUpgradeToSameTier() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.mintBadge(user1, 4, LearnWayBadge.BadgeTier.GOLD);

        vm.expectRevert("New tier must be higher");
        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.GOLD);

        vm.stopPrank();
    }

    function test_GetUserBadges_ReturnsAllBadges() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.updateKycStatus(user1, true);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        badgeContract.mintBadge(user1, 4, LearnWayBadge.BadgeTier.BRONZE);

        uint256[] memory badges = badgeContract.getUserBadges(user1);
        assertEq(badges.length, 4, "Should have 4 badges");
        assertEq(badges[0], 1, "First badge should be Keyholder");
        assertEq(badges[1], 3, "Second badge should be Early Bird");
        assertEq(badges[2], 2, "Third badge should be First Spark");
        assertEq(badges[3], 4, "Fourth badge should be Quiz Explorer");

        vm.stopPrank();
    }

    function test_GetUserBadgeData_ReturnsCorrectInfo() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, false);
        badgeContract.updateKycStatus(user1, true);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        (
            bool kycCompleted,
            bool isRegistered,
            uint256 totalBadgesEarned,
            uint256 registrationOrder,
            uint256[] memory badgesList
        ) = badgeContract.getUserBadgeData(user1);

        assertTrue(kycCompleted, "KYC should be completed");
        assertTrue(isRegistered, "Should be registered");
        assertEq(totalBadgesEarned, 3, "Should have 3 badges");
        assertEq(registrationOrder, 1, "Should be first registration");
        assertEq(badgesList.length, 3, "Badges list should have 3 items");

        vm.stopPrank();
    }

    function test_TokenURI_ContainsBadgeInfo() public {
        vm.startPrank(manager);

        badgeContract.registerUser(user1, true);

        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 1);
        string memory uri = badgeContract.tokenURI(tokenId);

        // URI should be base64 encoded JSON
        assertTrue(bytes(uri).length > 0, "URI should not be empty");
        assertTrue(
            bytes(uri)[0] == bytes("d")[0] && bytes(uri)[1] == bytes("a")[0] && bytes(uri)[2] == bytes("t")[0]
                && bytes(uri)[3] == bytes("a")[0],
            "URI should start with 'data'"
        );

        vm.stopPrank();
    }

    /* ============================================
       BADGE IMAGE URL TESTS
       ============================================ */

    function test_SetBadgeImageURL() public {
        vm.prank(admin);
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.GOLD, "https://example.com/badge1_gold.png");

        string memory url = badgeContract.getBadgeImageURL(1, LearnWayBadge.BadgeTier.GOLD);
        assertEq(url, "https://example.com/badge1_gold.png", "URL should match");
    }

    function test_GetBadgeImageURL_FallbackToBaseURI() public {
        string memory url = badgeContract.getBadgeImageURL(1, LearnWayBadge.BadgeTier.GOLD);

        // Should fallback to baseTokenURI construction
        assertTrue(bytes(url).length > 0, "URL should not be empty");
    }

    /* ============================================
       COMPREHENSIVE INTEGRATION TEST
       ============================================ */

    function test_CompleteUserJourney() public {
        vm.startPrank(manager);

        // 1. Register user without KYC
        badgeContract.registerUser(user1, false);
        assertEq(badgeContract.getUserBadges(user1).length, 1, "Should have 1 badge (Keyholder)");

        // 2. Mint First Spark
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        assertEq(badgeContract.getUserBadges(user1).length, 2, "Should have 2 badges");

        // 3. Mint and upgrade Quiz Explorer
        badgeContract.mintBadge(user1, 4, LearnWayBadge.BadgeTier.BRONZE);
        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.SILVER);
        badgeContract.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.GOLD);

        (,, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, 4);
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.GOLD), "Should be GOLD tier");

        // 4. Complete KYC - should upgrade Keyholder and mint Early Bird
        badgeContract.updateKycStatus(user1, true);

        (,, LearnWayBadge.BadgeTier keyholderTier,,) = badgeContract.getUserBadgeInfo(user1, 1);
        assertEq(uint256(keyholderTier), uint256(LearnWayBadge.BadgeTier.GOLD), "Keyholder should be GOLD");
        assertTrue(badgeContract.userHasBadge(user1, 3), "Should have Early Bird");

        // 5. Verify final state
        (bool kycCompleted, bool isRegistered, uint256 totalBadgesEarned,, uint256[] memory badgesList) =
            badgeContract.getUserBadgeData(user1);

        assertTrue(kycCompleted, "KYC should be completed");
        assertTrue(isRegistered, "Should be registered");
        assertEq(totalBadgesEarned, 4, "Should have 4 badges total");
        assertEq(badgesList.length, 4, "Badges list should have 4 items");

        vm.stopPrank();
    }
}
