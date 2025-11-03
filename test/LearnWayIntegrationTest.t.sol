// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LearnWayAdmin} from "../src/LearnWayAdmin.sol";
import {LearnWayBadge} from "../src/LearnWayBadge.sol";
import {LearnwayXPGemsContract} from "../src/LearnwayXPGemsContract.sol";
// Import interfaces from manager where they are declared
import {LearnWayManager, ILearnWayBadge, ILearnwayXPGemsContract} from "../src/LearnWayManager.sol";

contract LearnWayIntegrationTest is Test {
    // Contract instances
    LearnWayAdmin public adminContract;
    LearnWayBadge public badgeContract;
    LearnwayXPGemsContract public gemsContract;
    LearnWayManager public managerContract;

    // Proxies
    ERC1967Proxy public adminProxy;
    ERC1967Proxy public badgeProxy;
    ERC1967Proxy public gemsProxy;
    ERC1967Proxy public managerProxy;

    // Test accounts
    address public admin;
    address public manager;
    address public pauser;

    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;

    // Role constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        // Create test accounts
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        pauser = makeAddr("pauser");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");

        vm.startPrank(admin);

        // 1. Deploy and initialize LearnWayAdmin
        LearnWayAdmin adminImpl = new LearnWayAdmin();
        adminProxy = new ERC1967Proxy(address(adminImpl), abi.encodeWithSelector(LearnWayAdmin.initialize.selector));
        adminContract = LearnWayAdmin(address(adminProxy));

        // Grant roles
        adminContract.setUpRole(MANAGER_ROLE, manager);
        adminContract.setUpRole(PAUSER_ROLE, pauser);

        // 2. Deploy and initialize LearnwayXPGemsContract
        LearnwayXPGemsContract gemsImpl = new LearnwayXPGemsContract();
        gemsProxy = new ERC1967Proxy(
            address(gemsImpl),
            abi.encodeWithSelector(LearnwayXPGemsContract.initialize.selector, address(adminContract))
        );
        gemsContract = LearnwayXPGemsContract(address(gemsProxy));

        // 3. Deploy and initialize LearnWayBadge
        LearnWayBadge badgeImpl = new LearnWayBadge();
        badgeProxy = new ERC1967Proxy(
            address(badgeImpl), abi.encodeWithSelector(LearnWayBadge.initialize.selector, address(adminContract))
        );
        badgeContract = LearnWayBadge(address(badgeProxy));

        // 4. Deploy and initialize LearnWayManager
        LearnWayManager managerImpl = new LearnWayManager();
        managerProxy = new ERC1967Proxy(
            address(managerImpl), abi.encodeWithSelector(LearnWayManager.initialize.selector, address(adminContract))
        );
        managerContract = LearnWayManager(address(managerProxy));

        // give all the contracts admin priviledges

        adminContract.setUpRole(ADMIN_ROLE, address(managerContract));
        adminContract.setUpRole(MANAGER_ROLE, address(managerContract));
        adminContract.setUpRole(ADMIN_ROLE, address(gemsContract));
        adminContract.setUpRole(ADMIN_ROLE, address(badgeContract));
        // 5. Set contracts in manager
        managerContract.setContracts(address(gemsContract), address(badgeContract));

        // Set base token URI for badges
        badgeContract.setBaseTokenURI("ipfs://QmTest/");

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: USER REGISTRATION
         ======================================== */

    function test_Integration_RegisterUserWithKYC() public {
        vm.startPrank(manager);

        // Register user with KYC
        managerContract.registerUser(user1, 100, true);

        // Verify in GemsContract
        assertTrue(gemsContract.isRegistered(user1));
        assertEq(gemsContract.gemsOf(user1), 100);
        assertEq(gemsContract.xpOf(user1), 0);

        // Verify in BadgeContract
        (bool isRegistered, bool kycVerified, uint256 regOrder, uint256 kycOrder, uint256 totalBadges) =
            badgeContract.userInfo(user1);

        assertTrue(isRegistered);
        assertTrue(kycVerified);
        assertEq(regOrder, 1);
        assertEq(kycOrder, 1); // First KYC completion
        assertEq(totalBadges, 1); // Keyholder badge

        // Verify Keyholder badge (badgeId 0) was minted
        assertTrue(badgeContract.userHasBadge(user1, 0));

        // Verify Keyholder is GOLD tier for KYC users
        (bool hasBadge, uint256 tokenId, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, 0);
        assertTrue(hasBadge);
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.GOLD));

        vm.stopPrank();
    }

    function test_Integration_RegisterUserWithoutKYC() public {
        vm.startPrank(manager);

        // Register user without KYC
        managerContract.registerUser(user1, 50, false);

        // Verify in GemsContract
        assertTrue(gemsContract.isRegistered(user1));
        assertEq(gemsContract.gemsOf(user1), 50);

        // Verify in BadgeContract
        (bool isRegistered, bool kycVerified, uint256 regOrder, uint256 kycOrder, uint256 totalBadges) =
            badgeContract.userInfo(user1);

        assertTrue(isRegistered);
        assertFalse(kycVerified);
        assertEq(regOrder, 1);
        assertEq(kycOrder, 0); // No KYC completion yet
        assertEq(totalBadges, 1);

        // Verify Keyholder is SILVER tier for non-KYC users
        (bool hasBadge,, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, 0);
        assertTrue(hasBadge);
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.SILVER));

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: EARLY BIRD BADGE
         ======================================== */

    function test_Integration_EarlyBird_FirstKYCUsersGetBadge() public {
        vm.startPrank(manager);

        // Register 3 users WITH KYC (they should get early bird eligibility)
        managerContract.registerUser(user1, 100, true); // kycOrder = 1
        managerContract.registerUser(user2, 100, true); // kycOrder = 2
        managerContract.registerUser(user3, 100, false); // No KYC, kycOrder = 0

        // User3 completes KYC later
        managerContract.updateUserKycStatus(user3, true); // kycOrder = 3

        // Mint Early Bird badges
        managerContract.mintBadgeForUser(user1, 2, ILearnWayBadge.BadgeTier.BRONZE);
        managerContract.mintBadgeForUser(user2, 2, ILearnWayBadge.BadgeTier.BRONZE);
        managerContract.mintBadgeForUser(user3, 2, ILearnWayBadge.BadgeTier.BRONZE);

        // All should have Early Bird since they are in first 1000 KYC completions
        assertTrue(badgeContract.userHasBadge(user1, 2));
        assertTrue(badgeContract.userHasBadge(user2, 2));
        assertTrue(badgeContract.userHasBadge(user3, 2));

        vm.stopPrank();
    }

    function test_Integration_EarlyBird_RegistrationOrderDoesNotMatter() public {
        vm.startPrank(manager);

        // User2 registers first WITHOUT KYC
        managerContract.registerUser(user2, 100, false); // regOrder=1, kycOrder=0

        // User1 registers WITH KYC
        managerContract.registerUser(user1, 100, true); // regOrder=2, kycOrder=1

        // User2 completes KYC later
        managerContract.updateUserKycStatus(user2, true); // kycOrder=2

        // Check eligibility - user1 should be eligible (first KYC)
        assertTrue(badgeContract.isEligibleForEarlyBird(user1));
        assertTrue(badgeContract.isEligibleForEarlyBird(user2));

        // Mint badges
        managerContract.mintBadgeForUser(user1, 2, ILearnWayBadge.BadgeTier.BRONZE);
        managerContract.mintBadgeForUser(user2, 2, ILearnWayBadge.BadgeTier.BRONZE);

        assertTrue(badgeContract.userHasBadge(user1, 2));
        assertTrue(badgeContract.userHasBadge(user2, 2));

        vm.stopPrank();
    }

    function test_Integration_EarlyBird_RequiresKYC() public {
        vm.startPrank(manager);

        // Register user without KYC
        managerContract.registerUser(user1, 100, false);

        // Try to mint Early Bird badge - should fail
        vm.expectRevert("Early Bird requires KYC");
        managerContract.mintBadgeForUser(user1, 2, ILearnWayBadge.BadgeTier.BRONZE);

        vm.stopPrank();
    }

    function test_Integration_EarlyBird_MaxSpotsAdjustable() public {
        vm.prank(admin);
        badgeContract.setMaxEarlyBirdSpots(2); // Lower limit to 2

        vm.startPrank(manager);

        // Register 3 users with KYC
        managerContract.registerUser(user1, 100, true); // kycOrder = 1 ✓
        managerContract.registerUser(user2, 100, true); // kycOrder = 2 ✓
        managerContract.registerUser(user3, 100, true); // kycOrder = 3 ✗

        // First 2 should be eligible
        assertTrue(badgeContract.isEligibleForEarlyBird(user1));
        assertTrue(badgeContract.isEligibleForEarlyBird(user2));
        assertFalse(badgeContract.isEligibleForEarlyBird(user3));

        // Mint badges
        managerContract.mintBadgeForUser(user1, 2, ILearnWayBadge.BadgeTier.BRONZE);
        managerContract.mintBadgeForUser(user2, 2, ILearnWayBadge.BadgeTier.BRONZE);

        // User3 should fail
        vm.expectRevert("Not eligible for Early Bird");
        managerContract.mintBadgeForUser(user3, 2, ILearnWayBadge.BadgeTier.BRONZE);

        vm.stopPrank();
    }

    function test_Integration_EarlyBird_GetEarlyBirdInfo() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true); // kycOrder = 1
        managerContract.registerUser(user2, 100, false); // kycOrder = 0

        // Check user1's early bird info
        (
            uint256 regOrder1,
            uint256 kycOrder1,
            bool isKycCompleted1,
            bool hasEarlyBird1,
            bool isEligible1,
            uint256 totalKyc1,
            uint256 maxSpots1
        ) = badgeContract.getEarlyBirdInfo(user1);

        assertEq(regOrder1, 1);
        assertEq(kycOrder1, 1);
        assertTrue(isKycCompleted1);
        assertFalse(hasEarlyBird1);
        assertTrue(isEligible1);
        assertEq(totalKyc1, 1);
        assertEq(maxSpots1, 1000);

        // Check user2's early bird info
        (uint256 regOrder2, uint256 kycOrder2, bool isKycCompleted2, bool hasEarlyBird2, bool isEligible2,,) =
            badgeContract.getEarlyBirdInfo(user2);

        assertEq(regOrder2, 2);
        assertEq(kycOrder2, 0);
        assertFalse(isKycCompleted2);
        assertFalse(hasEarlyBird2);
        assertFalse(isEligible2);

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: KYC STATUS UPDATES
         ======================================== */

    function test_Integration_UpdateKYCStatus_UpgradesKeyholder() public {
        vm.startPrank(manager);

        // Register without KYC
        managerContract.registerUser(user1, 100, false);

        // Verify SILVER Keyholder
        (,, LearnWayBadge.BadgeTier tierBefore,,) = badgeContract.getUserBadgeInfo(user1, 0);
        assertEq(uint256(tierBefore), uint256(LearnWayBadge.BadgeTier.SILVER));

        // Update KYC status
        managerContract.updateUserKycStatus(user1, true);

        // Verify GOLD Keyholder
        (,, LearnWayBadge.BadgeTier tierAfter,,) = badgeContract.getUserBadgeInfo(user1, 0);
        assertEq(uint256(tierAfter), uint256(LearnWayBadge.BadgeTier.GOLD));

        // Verify kycOrder was assigned
        (,,, uint256 kycOrder,) = badgeContract.userInfo(user1);
        assertEq(kycOrder, 1);

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: BADGE MANAGEMENT
         ======================================== */

    function test_Integration_MintMultipleBadges() public {
        vm.startPrank(manager);

        // Register user
        managerContract.registerUser(user1, 100, true);

        // Mint multiple badges
        uint256[] memory badgeIds = new uint256[](3);
        badgeIds[0] = 1; // First Spark
        badgeIds[1] = 2; // Early Bird
        badgeIds[2] = 3; // Quiz Explorer

        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](3);
        tiers[0] = ILearnWayBadge.BadgeTier.BRONZE;
        tiers[1] = ILearnWayBadge.BadgeTier.BRONZE;
        tiers[2] = ILearnWayBadge.BadgeTier.SILVER;

        managerContract.batchMintBadgesForUser(user1, badgeIds, tiers);

        // Verify all badges
        assertTrue(badgeContract.userHasBadge(user1, 1));
        assertTrue(badgeContract.userHasBadge(user1, 2));
        assertTrue(badgeContract.userHasBadge(user1, 3));

        // Verify total badges (4: Keyholder + 3 new)
        (,,,, uint256 totalBadges) = badgeContract.userInfo(user1);
        assertEq(totalBadges, 4);

        vm.stopPrank();
    }

    function test_Integration_UpgradeDynamicBadge() public {
        vm.startPrank(manager);

        // Register user
        managerContract.registerUser(user1, 100, true);

        // Mint Quiz Explorer badge (badgeId 3, dynamic)
        managerContract.mintBadgeForUser(user1, 3, ILearnWayBadge.BadgeTier.BRONZE);

        // Verify initial tier
        (,, LearnWayBadge.BadgeTier tierBefore,,) = badgeContract.getUserBadgeInfo(user1, 3);
        assertEq(uint256(tierBefore), uint256(LearnWayBadge.BadgeTier.BRONZE));

        // Upgrade badge
        managerContract.upgradeBadgeForUser(user1, 3, ILearnWayBadge.BadgeTier.SILVER);

        // Verify upgraded tier
        (,, LearnWayBadge.BadgeTier tierAfter,,) = badgeContract.getUserBadgeInfo(user1, 3);
        assertEq(uint256(tierAfter), uint256(LearnWayBadge.BadgeTier.SILVER));

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: XP & GEMS
         ======================================== */

    function test_Integration_UpdateUserData() public {
        vm.startPrank(manager);

        // Register user
        managerContract.registerUser(user1, 100, true);

        // Update gems, XP, and streak
        managerContract.updateUserData(user1, 200, 500, 10);

        // Verify updates
        assertEq(gemsContract.gemsOf(user1), 200);
        assertEq(gemsContract.xpOf(user1), 500);
        assertEq(gemsContract.streakOf(user1), 10);

        vm.stopPrank();
    }

    function test_Integration_RecordTransaction() public {
        vm.startPrank(manager);

        // Register user
        managerContract.registerUser(user1, 100, true);

        // Record a quiz transaction
        uint256[] memory badges = new uint256[](1);
        badges[0] = 1; // First Spark badge

        managerContract.recordTransaction(
            user1, 50, 100, badges, ILearnwayXPGemsContract.TransactionType.DailyQuiz, "Completed first quiz"
        );

        // Verify transaction was recorded
        assertEq(gemsContract.transactionCount(user1), 2); // 1 registration + 1 quiz

        // Get transaction details
        LearnwayXPGemsContract.Transaction memory txn = gemsContract.getUserTransaction(user1, 1);
        assertEq(txn.gems, 50);
        assertEq(txn.xp, 100);
        assertEq(uint256(txn.txType), uint256(LearnwayXPGemsContract.TransactionType.DailyQuiz));

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: BATCH OPERATIONS
         ======================================== */

    function test_Integration_BatchRegisterUsers() public {
        vm.startPrank(manager);

        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        uint256[] memory initialGems = new uint256[](3);
        initialGems[0] = 100;
        initialGems[1] = 200;
        initialGems[2] = 300;

        bool[] memory kycStatuses = new bool[](3);
        kycStatuses[0] = true;
        kycStatuses[1] = false;
        kycStatuses[2] = true;

        managerContract.batchRegisterUsers(users, initialGems, kycStatuses);

        // Verify all users
        assertTrue(gemsContract.isRegistered(user1));
        assertTrue(gemsContract.isRegistered(user2));
        assertTrue(gemsContract.isRegistered(user3));

        assertEq(gemsContract.gemsOf(user1), 100);
        assertEq(gemsContract.gemsOf(user2), 200);
        assertEq(gemsContract.gemsOf(user3), 300);

        // Verify KYC orders
        (,,, uint256 kycOrder1,) = badgeContract.userInfo(user1);
        (,,, uint256 kycOrder2,) = badgeContract.userInfo(user2);
        (,,, uint256 kycOrder3,) = badgeContract.userInfo(user3);

        assertEq(kycOrder1, 1); // First KYC
        assertEq(kycOrder2, 0); // No KYC
        assertEq(kycOrder3, 2); // Second KYC

        vm.stopPrank();
    }

    function test_Integration_BatchUpdateUserData() public {
        vm.startPrank(manager);

        // Register users
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        uint256[] memory initialGems = new uint256[](2);
        initialGems[0] = 100;
        initialGems[1] = 100;

        bool[] memory kycStatuses = new bool[](2);
        kycStatuses[0] = true;
        kycStatuses[1] = true;

        managerContract.batchRegisterUsers(users, initialGems, kycStatuses);

        // Batch update
        uint256[] memory newGems = new uint256[](2);
        newGems[0] = 200;
        newGems[1] = 300;

        uint256[] memory newXp = new uint256[](2);
        newXp[0] = 500;
        newXp[1] = 600;

        uint256[] memory newStreaks = new uint256[](2);
        newStreaks[0] = 10;
        newStreaks[1] = 15;

        managerContract.batchUpdateUserData(users, newGems, newXp, newStreaks);

        // Verify updates
        assertEq(gemsContract.gemsOf(user1), 200);
        assertEq(gemsContract.xpOf(user1), 500);
        assertEq(gemsContract.streakOf(user1), 10);

        assertEq(gemsContract.gemsOf(user2), 300);
        assertEq(gemsContract.xpOf(user2), 600);
        assertEq(gemsContract.streakOf(user2), 15);

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: VIEW FUNCTIONS
         ======================================== */

    function test_Integration_GetUserCompleteData() public {
        vm.startPrank(manager);

        // Register user with KYC
        managerContract.registerUser(user1, 100, true);

        // Update data
        managerContract.updateUserData(user1, 200, 500, 10);

        // Mint badge
        managerContract.mintBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.BRONZE);

        // Get complete data
        (
            uint256 gems,
            uint256 xp,
            uint256 longestStreak,
            uint256 createdAt,
            uint256 lastUpdated,
            uint256[] memory badgesList,
            uint256 txCount,
            bool kycCompleted,
            uint256 totalBadgesEarned,
            uint256 registrationOrder
        ) = managerContract.getUserCompleteData(user1);

        assertEq(gems, 200);
        assertEq(xp, 500);
        assertEq(longestStreak, 10);
        assertTrue(createdAt > 0);
        assertTrue(lastUpdated > 0);
        assertEq(badgesList.length, 2); // Keyholder + First Spark
        assertEq(txCount, 1); // Registration transaction
        assertTrue(kycCompleted);
        assertEq(totalBadgesEarned, 1);
        assertEq(registrationOrder, 1);

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: ACCESS CONTROL
         ======================================== */

    function test_Integration_OnlyManagerCanRegister() public {
        vm.prank(user1);
        vm.expectRevert();
        managerContract.registerUser(user2, 100, true);
    }

    function test_Integration_OnlyAdminCanSetContracts() public {
        vm.prank(manager);
        vm.expectRevert();
        managerContract.setContracts(address(gemsContract), address(badgeContract));
    }

    function test_Integration_OnlyAdminCanSetMaxEarlyBirdSpots() public {
        vm.prank(manager);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.setMaxEarlyBirdSpots(500);
    }

    /* ========================================
         INTEGRATION TESTS: PAUSE FUNCTIONALITY
         ======================================== */

    function test_Integration_PausePreventsMinting() public {
        vm.startPrank(manager);
        managerContract.registerUser(user1, 100, true);
        vm.stopPrank();

        // Pause badge contract
        vm.prank(pauser);
        badgeContract.pause();

        // Try to mint badge - should fail
        vm.prank(manager);
        vm.expectRevert();
        managerContract.mintBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.BRONZE);

        // Unpause
        vm.prank(admin);
        badgeContract.unpause();

        // Now minting should work
        vm.prank(manager);
        managerContract.mintBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.BRONZE);
        assertTrue(badgeContract.userHasBadge(user1, 1));
    }

    /* ========================================
         INTEGRATION TESTS: EDGE CASES
         ======================================== */

    function test_Integration_CannotRegisterSameUserTwice() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);

        vm.expectRevert("User already registered");
        managerContract.registerUser(user1, 200, false);

        vm.stopPrank();
    }

    function test_Integration_CannotMintSameBadgeTwice() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);
        managerContract.mintBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.BRONZE);

        vm.expectRevert("User already has this badge");
        managerContract.mintBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.SILVER);

        vm.stopPrank();
    }

    function test_Integration_CannotUpgradeNonDynamicBadge() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);
        managerContract.mintBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.BRONZE); // First Spark (non-dynamic)

        vm.expectRevert("Badge is not upgradeable");
        managerContract.upgradeBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.SILVER);

        vm.stopPrank();
    }

    /* ========================================
         INTEGRATION TESTS: TOKEN URI
         ======================================== */

    function test_Integration_BadgeTokenURI() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);

        // Get Keyholder badge token ID
        (, uint256 tokenId,,,) = badgeContract.getUserBadgeInfo(user1, 0);

        // Get token URI
        string memory uri = badgeContract.tokenURI(tokenId);

        // Should start with data:application/json;base64,
        assertTrue(bytes(uri).length > 0);

        vm.stopPrank();
    }
    /* ========================================
     INTEGRATION TESTS: BATCH RECORD TRANSACTIONS
     ======================================== */

    function test_Integration_BatchRecordTransactionsForSingleUser() public {
        vm.startPrank(manager);

        // Register user
        managerContract.registerUser(user1, 100, true);

        // Prepare batch transaction data
        uint256[] memory gemsAmounts = new uint256[](3);
        gemsAmounts[0] = 50;
        gemsAmounts[1] = 75;
        gemsAmounts[2] = 100;

        uint256[] memory xpAmounts = new uint256[](3);
        xpAmounts[0] = 100;
        xpAmounts[1] = 150;
        xpAmounts[2] = 200;

        uint256[][] memory badgesLists = new uint256[][](3);
        badgesLists[0] = new uint256[](0);
        badgesLists[1] = new uint256[](1);
        badgesLists[1][0] = 1;
        badgesLists[2] = new uint256[](0);

        ILearnwayXPGemsContract.TransactionType[] memory txTypes = new ILearnwayXPGemsContract.TransactionType[](3);
        txTypes[0] = ILearnwayXPGemsContract.TransactionType.DailyQuiz;
        txTypes[1] = ILearnwayXPGemsContract.TransactionType.DailyQuiz;
        txTypes[2] = ILearnwayXPGemsContract.TransactionType.Battle;

        string[] memory descriptions = new string[](3);
        descriptions[0] = "Quiz 1";
        descriptions[1] = "Quiz 2";
        descriptions[2] = "Battle 1";

        // Record batch transactions
        managerContract.batchRecordTransactions(user1, gemsAmounts, xpAmounts, badgesLists, txTypes, descriptions);

        // Verify transactions were recorded (1 registration + 3 new)
        assertEq(gemsContract.transactionCount(user1), 4);

        // Verify individual transactions
        LearnwayXPGemsContract.Transaction memory tx1 = gemsContract.getUserTransaction(user1, 1);
        assertEq(tx1.gems, 50);
        assertEq(tx1.xp, 100);

        LearnwayXPGemsContract.Transaction memory tx2 = gemsContract.getUserTransaction(user1, 2);
        assertEq(tx2.gems, 75);
        assertEq(tx2.xp, 150);
        assertEq(tx2.badgesList[0], 1);

        vm.stopPrank();
    }

    function test_Integration_BatchRecordTransactionsForMultipleUsers() public {
        vm.startPrank(manager);

        // Register users
        managerContract.registerUser(user1, 100, true);
        managerContract.registerUser(user2, 100, true);

        // Prepare data for user1
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        uint256[][] memory gemsAmounts = new uint256[][](2);
        gemsAmounts[0] = new uint256[](2);
        gemsAmounts[0][0] = 50;
        gemsAmounts[0][1] = 75;
        gemsAmounts[1] = new uint256[](2);
        gemsAmounts[1][0] = 60;
        gemsAmounts[1][1] = 80;

        uint256[][] memory xpAmounts = new uint256[][](2);
        xpAmounts[0] = new uint256[](2);
        xpAmounts[0][0] = 100;
        xpAmounts[0][1] = 150;
        xpAmounts[1] = new uint256[](2);
        xpAmounts[1][0] = 120;
        xpAmounts[1][1] = 160;

        uint256[][][] memory badgesLists = new uint256[][][](2);
        badgesLists[0] = new uint256[][](2);
        badgesLists[0][0] = new uint256[](0);
        badgesLists[0][1] = new uint256[](0);
        badgesLists[1] = new uint256[][](2);
        badgesLists[1][0] = new uint256[](0);
        badgesLists[1][1] = new uint256[](0);

        ILearnwayXPGemsContract.TransactionType[][] memory txTypes = new ILearnwayXPGemsContract.TransactionType[][](2);
        txTypes[0] = new ILearnwayXPGemsContract.TransactionType[](2);
        txTypes[0][0] = ILearnwayXPGemsContract.TransactionType.DailyQuiz;
        txTypes[0][1] = ILearnwayXPGemsContract.TransactionType.Battle;
        txTypes[1] = new ILearnwayXPGemsContract.TransactionType[](2);
        txTypes[1][0] = ILearnwayXPGemsContract.TransactionType.DailyQuiz;
        txTypes[1][1] = ILearnwayXPGemsContract.TransactionType.Contest;

        string[][] memory descriptions = new string[][](2);
        descriptions[0] = new string[](2);
        descriptions[0][0] = "User1 Quiz";
        descriptions[0][1] = "User1 Battle";
        descriptions[1] = new string[](2);
        descriptions[1][0] = "User2 Quiz";
        descriptions[1][1] = "User2 Contest";

        // Execute batch operation
        managerContract.batchRecordTransactionsForUsers(
            users, gemsAmounts, xpAmounts, badgesLists, txTypes, descriptions
        );

        // Verify user1 transactions (1 registration + 2 new)
        assertEq(gemsContract.transactionCount(user1), 3);
        // Verify user2 transactions (1 registration + 2 new)
        assertEq(gemsContract.transactionCount(user2), 3);

        vm.stopPrank();
    }

    function test_Integration_BatchRecordTransactions_RevertsOnArrayMismatch() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);

        uint256[] memory gemsAmounts = new uint256[](2);
        uint256[] memory xpAmounts = new uint256[](3); // Mismatched length

        vm.expectRevert("Arrays length mismatch");
        managerContract.batchRecordTransactions(
            user1,
            gemsAmounts,
            xpAmounts,
            new uint256[][](2),
            new ILearnwayXPGemsContract.TransactionType[](2),
            new string[](2)
        );

        vm.stopPrank();
    }

    function test_Integration_BatchRecordTransactionsForUsers_SkipsUnregistered() public {
        vm.startPrank(manager);

        // Register only user1
        managerContract.registerUser(user1, 100, true);

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2; // Not registered

        uint256[][] memory gemsAmounts = new uint256[][](2);
        gemsAmounts[0] = new uint256[](1);
        gemsAmounts[0][0] = 50;
        gemsAmounts[1] = new uint256[](1);
        gemsAmounts[1][0] = 60;

        uint256[][] memory xpAmounts = new uint256[][](2);
        xpAmounts[0] = new uint256[](1);
        xpAmounts[0][0] = 100;
        xpAmounts[1] = new uint256[](1);
        xpAmounts[1][0] = 120;

        uint256[][][] memory badgesLists = new uint256[][][](2);
        badgesLists[0] = new uint256[][](1);
        badgesLists[0][0] = new uint256[](0);
        badgesLists[1] = new uint256[][](1);
        badgesLists[1][0] = new uint256[](0);

        ILearnwayXPGemsContract.TransactionType[][] memory txTypes = new ILearnwayXPGemsContract.TransactionType[][](2);
        txTypes[0] = new ILearnwayXPGemsContract.TransactionType[](1);
        txTypes[0][0] = ILearnwayXPGemsContract.TransactionType.DailyQuiz;
        txTypes[1] = new ILearnwayXPGemsContract.TransactionType[](1);
        txTypes[1][0] = ILearnwayXPGemsContract.TransactionType.DailyQuiz;

        string[][] memory descriptions = new string[][](2);
        descriptions[0] = new string[](1);
        descriptions[0][0] = "User1 Quiz";
        descriptions[1] = new string[](1);
        descriptions[1][0] = "User2 Quiz";

        // Should not revert, just skip user2
        managerContract.batchRecordTransactionsForUsers(
            users, gemsAmounts, xpAmounts, badgesLists, txTypes, descriptions
        );

        // User1 should have transaction
        assertEq(gemsContract.transactionCount(user1), 2); // 1 registration + 1 new
        // User2 should not be registered
        assertFalse(gemsContract.isRegistered(user2));

        vm.stopPrank();
    }

    /* ========================================
     INTEGRATION TESTS: BATCH MINT BADGES FOR MULTIPLE USERS
     ======================================== */

    function test_Integration_BatchMintBadgesForMultipleUsers() public {
        vm.startPrank(manager);

        // Register users
        managerContract.registerUser(user1, 100, true);
        managerContract.registerUser(user2, 100, true);
        managerContract.registerUser(user3, 100, false);

        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        uint256[][] memory badgeIds = new uint256[][](3);
        badgeIds[0] = new uint256[](2);
        badgeIds[0][0] = 1; // First Spark
        badgeIds[0][1] = 2; // Early Bird

        badgeIds[1] = new uint256[](1);
        badgeIds[1][0] = 1; // First Spark

        badgeIds[2] = new uint256[](1);
        badgeIds[2][0] = 1; // First Spark

        ILearnWayBadge.BadgeTier[][] memory tiers = new ILearnWayBadge.BadgeTier[][](3);
        tiers[0] = new ILearnWayBadge.BadgeTier[](2);
        tiers[0][0] = ILearnWayBadge.BadgeTier.BRONZE;
        tiers[0][1] = ILearnWayBadge.BadgeTier.BRONZE;

        tiers[1] = new ILearnWayBadge.BadgeTier[](1);
        tiers[1][0] = ILearnWayBadge.BadgeTier.BRONZE;

        tiers[2] = new ILearnWayBadge.BadgeTier[](1);
        tiers[2][0] = ILearnWayBadge.BadgeTier.BRONZE;

        managerContract.batchMintBadgesForMultipleUsers(users, badgeIds, tiers);

        // Verify user1 badges
        assertTrue(badgeContract.userHasBadge(user1, 1));
        assertTrue(badgeContract.userHasBadge(user1, 2));

        // Verify user2 badges
        assertTrue(badgeContract.userHasBadge(user2, 1));

        // Verify user3 badges
        assertTrue(badgeContract.userHasBadge(user3, 1));

        vm.stopPrank();
    }

    function test_Integration_BatchMintBadgesForMultipleUsers_SkipsUnregistered() public {
        vm.startPrank(manager);

        // Register only user1
        managerContract.registerUser(user1, 100, true);

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2; // Not registered

        uint256[][] memory badgeIds = new uint256[][](2);
        badgeIds[0] = new uint256[](1);
        badgeIds[0][0] = 1;
        badgeIds[1] = new uint256[](1);
        badgeIds[1][0] = 1;

        ILearnWayBadge.BadgeTier[][] memory tiers = new ILearnWayBadge.BadgeTier[][](2);
        tiers[0] = new ILearnWayBadge.BadgeTier[](1);
        tiers[0][0] = ILearnWayBadge.BadgeTier.BRONZE;
        tiers[1] = new ILearnWayBadge.BadgeTier[](1);
        tiers[1][0] = ILearnWayBadge.BadgeTier.BRONZE;

        // Should not revert, just skip user2
        managerContract.batchMintBadgesForMultipleUsers(users, badgeIds, tiers);

        // Verify user1 got badge
        assertTrue(badgeContract.userHasBadge(user1, 1));
        // Verify user2 was skipped
        assertFalse(gemsContract.isRegistered(user2));

        vm.stopPrank();
    }

    function test_Integration_BatchMintBadgesForMultipleUsers_RevertsOnArrayMismatch() public {
        vm.startPrank(manager);

        address[] memory users = new address[](2);
        uint256[][] memory badgeIds = new uint256[][](3); // Mismatched
        ILearnWayBadge.BadgeTier[][] memory tiers = new ILearnWayBadge.BadgeTier[][](2);

        vm.expectRevert("Array length mismatch");
        managerContract.batchMintBadgesForMultipleUsers(users, badgeIds, tiers);

        vm.stopPrank();
    }

    function test_Integration_BatchMintBadgesForMultipleUsers_RevertsOnBatchTooLarge() public {
        vm.startPrank(manager);

        address[] memory users = new address[](101); // Exceeds limit
        uint256[][] memory badgeIds = new uint256[][](101);
        ILearnWayBadge.BadgeTier[][] memory tiers = new ILearnWayBadge.BadgeTier[][](101);

        vm.expectRevert("Batch size too large");
        managerContract.batchMintBadgesForMultipleUsers(users, badgeIds, tiers);

        vm.stopPrank();
    }

    /* ========================================
     INTEGRATION TESTS: BATCH UPDATE KYC STATUS
     ======================================== */

    function test_Integration_BatchUpdateKycStatus() public {
        vm.startPrank(manager);

        // Register users without KYC
        managerContract.registerUser(user1, 100, false);
        managerContract.registerUser(user2, 100, false);
        managerContract.registerUser(user3, 100, false);

        // Verify initial KYC status - userInfo returns 5 values: (isRegistered, kycVerified, regOrder, kycOrder, totalBadges)
        (,,, uint256 kycOrder1Before,) = badgeContract.userInfo(user1);
        assertEq(kycOrder1Before, 0);

        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        bool[] memory kycStatuses = new bool[](3);
        kycStatuses[0] = true;
        kycStatuses[1] = true;
        kycStatuses[2] = false; // Keep false

        managerContract.batchUpdateKycStatus(users, kycStatuses);

        // Verify KYC orders were assigned
        (,,, uint256 kycOrder1,) = badgeContract.userInfo(user1);
        (,,, uint256 kycOrder2,) = badgeContract.userInfo(user2);
        (,,, uint256 kycOrder3,) = badgeContract.userInfo(user3);

        assertEq(kycOrder1, 1);
        assertEq(kycOrder2, 2);
        assertEq(kycOrder3, 0); // Still no KYC

        // Verify Keyholder badges were upgraded
        (,, LearnWayBadge.BadgeTier tier1,,) = badgeContract.getUserBadgeInfo(user1, 0);
        (,, LearnWayBadge.BadgeTier tier2,,) = badgeContract.getUserBadgeInfo(user2, 0);
        (,, LearnWayBadge.BadgeTier tier3,,) = badgeContract.getUserBadgeInfo(user3, 0);

        assertEq(uint256(tier1), uint256(LearnWayBadge.BadgeTier.GOLD));
        assertEq(uint256(tier2), uint256(LearnWayBadge.BadgeTier.GOLD));
        assertEq(uint256(tier3), uint256(LearnWayBadge.BadgeTier.SILVER));

        vm.stopPrank();
    }

    function test_Integration_BatchUpdateKycStatus_SkipsUnregistered() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, false);

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2; // Not registered

        bool[] memory kycStatuses = new bool[](2);
        kycStatuses[0] = true;
        kycStatuses[1] = true;

        // Should not revert
        managerContract.batchUpdateKycStatus(users, kycStatuses);

        // User1 should be KYC'd
        (,,, uint256 kycOrder1,) = badgeContract.userInfo(user1);
        assertEq(kycOrder1, 1);

        // User2 should not be registered
        assertFalse(gemsContract.isRegistered(user2));

        vm.stopPrank();
    }

    /* ========================================
     INTEGRATION TESTS: VIEW FUNCTIONS
     ======================================== */

    function test_Integration_GetUserGemsData() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);
        managerContract.updateUserData(user1, 200, 500, 10);

        (uint256 gems, uint256 xp, uint256 longestStreak, bool registered, uint256 createdAt, uint256 lastUpdated) =
            managerContract.getUserGemsData(user1);

        assertEq(gems, 200);
        assertEq(xp, 500);
        assertEq(longestStreak, 10);
        assertTrue(registered);
        assertTrue(createdAt > 0);
        assertTrue(lastUpdated > 0);

        vm.stopPrank();
    }

    function test_Integration_GetUserBadgeData() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);
        managerContract.mintBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.BRONZE);

        (
            bool kycCompleted,
            bool isRegistered,
            uint256 totalBadgesEarned,
            uint256 registrationOrder,
            uint256[] memory badgesList
        ) = managerContract.getUserBadgeData(user1);

        assertTrue(kycCompleted);
        assertTrue(isRegistered);
        assertEq(totalBadgesEarned, 2); // Keyholder is auto-minted but counts in totalBadgesEarned
        assertEq(registrationOrder, 1);
        assertEq(badgesList.length, 2);

        vm.stopPrank();
    }

    function test_Integration_GetUserTransactionsByType() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);

        // Record different transaction types
        managerContract.recordTransaction(
            user1, 50, 100, new uint256[](0), ILearnwayXPGemsContract.TransactionType.DailyQuiz, "Quiz 1"
        );

        managerContract.recordTransaction(
            user1, 75, 150, new uint256[](0), ILearnwayXPGemsContract.TransactionType.Battle, "Battle 1"
        );

        managerContract.recordTransaction(
            user1, 60, 120, new uint256[](0), ILearnwayXPGemsContract.TransactionType.DailyQuiz, "Quiz 2"
        );

        // Get quiz transactions only
        ILearnwayXPGemsContract.Transaction[] memory quizTxs =
            managerContract.getUserTransactionsByType(user1, ILearnwayXPGemsContract.TransactionType.DailyQuiz);

        assertEq(quizTxs.length, 2);
        assertEq(quizTxs[0].gems, 50);
        assertEq(quizTxs[1].gems, 60);

        vm.stopPrank();
    }

    function test_Integration_GetUserRecentTransactions() public {
        vm.startPrank(manager);

        managerContract.registerUser(user1, 100, true);

        // Record multiple transactions
        for (uint256 i = 0; i < 5; i++) {
            managerContract.recordTransaction(
                user1, 50 + i, 100 + i, new uint256[](0), ILearnwayXPGemsContract.TransactionType.DailyQuiz, "Quiz"
            );
        }

        // Get last 3 transactions
        ILearnwayXPGemsContract.Transaction[] memory recentTxs = managerContract.getUserRecentTransactions(user1, 3);

        assertEq(recentTxs.length, 3);
        // Should get the most recent ones (gems: 54, 53, 52 in order)
        assertEq(recentTxs[2].gems, 54); // Most recent

        vm.stopPrank();
    }

    function test_Integration_GetContractAddresses() public view {
        (address gemsAddr, address badgesAddr) = managerContract.getContractAddresses();

        assertEq(gemsAddr, address(gemsContract));
        assertEq(badgesAddr, address(badgeContract));
    }

    function test_Integration_GetTotalUsers() public {
        vm.startPrank(manager);

        assertEq(managerContract.getTotalUsers(), 0);

        managerContract.registerUser(user1, 100, true);
        assertEq(managerContract.getTotalUsers(), 1);

        managerContract.registerUser(user2, 100, true);
        assertEq(managerContract.getTotalUsers(), 2);

        vm.stopPrank();
    }

    /* ========================================
     INTEGRATION TESTS: ADMIN FUNCTIONS
     ======================================== */

    function test_Integration_UpdateAdminContract() public {
        vm.startPrank(admin);

        // Deploy new admin contract
        LearnWayAdmin newAdminImpl = new LearnWayAdmin();
        ERC1967Proxy newAdminProxy =
            new ERC1967Proxy(address(newAdminImpl), abi.encodeWithSelector(LearnWayAdmin.initialize.selector));
        LearnWayAdmin newAdmin = LearnWayAdmin(address(newAdminProxy));

        // Update manager's admin contract
        managerContract.updateAdminContract(address(newAdmin));

        // Verify update
        assertEq(address(managerContract.adminContract()), address(newAdmin));

        vm.stopPrank();
    }

    function test_Integration_UpdateAdminContract_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid admin contract address");
        managerContract.updateAdminContract(address(0));
    }

    function test_Integration_UpdateAdminContract_OnlyAdmin() public {
        vm.prank(manager);
        vm.expectRevert("Not AuthorizedAdmin");
        managerContract.updateAdminContract(address(0x123));
    }

    function test_Integration_Version() public view {
        assertEq(managerContract.version(), "1.0.0");
    }
}
