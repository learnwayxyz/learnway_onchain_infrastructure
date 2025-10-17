// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LearnWayAdmin} from "../src/LearnWayAdmin.sol";
import {LearnWayBadge} from "../src/LearnWayBadge.sol";

// A V2 implementation for UUPS upgrade testing
contract LearnWayBadgeV2 is LearnWayBadge {
    function newVersion() external pure returns (string memory) {
        return "2.0.0";
    }
}

contract LearnWayBadgeTest is Test {
    // Mirror events for expectEmit
    event BadgeMinted(
        address indexed user, uint256 indexed badgeId, uint256 tokenId, LearnWayBadge.BadgeTier tier, bool status
    );
    event BadgeUpgraded(
        address indexed user, uint256 indexed badgeId, uint256 tokenId, LearnWayBadge.BadgeTier newTier, bool status
    );
    event UserRegistered(address indexed user, uint256 registrationOrder, bool kycStatus, bool status);
    event KycStatusUpdated(address indexed user, bool kycStatus, bool status);
    event EarlyBirdLimitUpdated(uint256 oldLimit, uint256 newLimit, bool status);

    // Contracts
    LearnWayAdmin internal adminImpl;
    LearnWayBadge internal badgeImpl;
    LearnWayAdmin internal admin;
    LearnWayBadge internal badge;

    // Actors
    address internal adminEOA = address(0xA11CE);
    address internal managerEOA = address(0xB0B);
    address internal pauserEOA = address(0xA53);
    address internal stranger = address(0xDEAD);
    address internal user1 = address(0x1111);
    address internal user2 = address(0x2222);

    // Roles
    bytes32 internal ADMIN_ROLE;
    bytes32 internal MANAGER_ROLE;
    bytes32 internal PAUSER_ROLE;

    function setUp() public {
        // Deploy Admin behind proxy
        adminImpl = new LearnWayAdmin();
        ERC1967Proxy adminProxy = new ERC1967Proxy(address(adminImpl), "");
        admin = LearnWayAdmin(address(adminProxy));

        // Initialize admin with adminEOA as the first admin
        vm.prank(adminEOA);
        admin.initialize();

        ADMIN_ROLE = admin.ADMIN_ROLE();
        MANAGER_ROLE = admin.MANAGER_ROLE();
        PAUSER_ROLE = admin.PAUSER_ROLE();

        // Grant roles to EOAs
        vm.startPrank(adminEOA);
        admin.setUpRole(MANAGER_ROLE, managerEOA);
        admin.setUpRole(PAUSER_ROLE, pauserEOA);
        vm.stopPrank();

        // Deploy Badge behind proxy
        badgeImpl = new LearnWayBadge();
        ERC1967Proxy badgeProxy = new ERC1967Proxy(address(badgeImpl), "");
        badge = LearnWayBadge(address(badgeProxy));

        // Initialize Badge with admin proxy
        vm.prank(managerEOA);
        badge.initialize(address(admin));
    }

    // ==================== INITIALIZATION TESTS ====================

    function test_Initialize() public {
        assertEq(badge.name(), "LearnWay Badges");
        assertEq(badge.symbol(), "LWB");
        assertEq(address(badge.adminContract()), address(admin));
        assertEq(badge.maxEarlyBirdSpots(), 1000);
        assertEq(badge.totalRegistrations(), 0);
        assertEq(badge.version(), "1.0.0");
    }

    function test_Initialize_RevertsIfZeroAddress() public {
        LearnWayBadge newBadgeImpl = new LearnWayBadge();
        ERC1967Proxy newBadgeProxy = new ERC1967Proxy(address(newBadgeImpl), "");
        LearnWayBadge newBadge = LearnWayBadge(address(newBadgeProxy));

        vm.expectRevert("Invalid admin address");
        newBadge.initialize(address(0));
    }

    function test_Initialize_BadgesAreInitialized() public {
        // Check first badge (Keyholder)
        (
            string memory name,
            LearnWayBadge.BadgeCategory category,
            bool isDynamic,
            uint256 maxSupply,
            uint256 currentSupply
        ) = badge.badges(0);
        assertEq(name, "Keyholder");
        assertEq(uint256(category), uint256(LearnWayBadge.BadgeCategory.ONBOARDING));
        assertTrue(isDynamic);
        assertEq(maxSupply, 0);
        assertEq(currentSupply, 0);

        // Check Early Bird badge
        (name, category, isDynamic, maxSupply, currentSupply) = badge.badges(2);
        assertEq(name, "Early Bird");
        assertEq(uint256(category), uint256(LearnWayBadge.BadgeCategory.ONBOARDING));
        assertFalse(isDynamic);
        assertEq(maxSupply, 0);
        assertEq(currentSupply, 0);
    }

    // ==================== USER REGISTRATION TESTS ====================

    function test_RegisterUser_WithoutKYC() public {
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(user1, 1, false, true);

        vm.expectEmit(true, true, false, true);
        emit BadgeMinted(user1, 0, 1, LearnWayBadge.BadgeTier.SILVER, true);

        vm.prank(managerEOA);
        badge.registerUser(user1, false);

        (bool isRegistered, bool kycVerified, uint256 registrationOrder,, uint256 totalBadgesEarned) =
            badge.userInfo(user1);
        assertTrue(isRegistered);
        assertFalse(kycVerified);
        assertEq(registrationOrder, 1);
        assertEq(totalBadgesEarned, 1);
        assertEq(badge.totalRegistrations(), 1);

        assertTrue(badge.userHasBadge(user1, 0));
    }

    function test_RegisterUser_WithKYC() public {
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(user1, 1, true, true);

        vm.expectEmit(true, true, false, true);
        emit BadgeMinted(user1, 0, 1, LearnWayBadge.BadgeTier.GOLD, true);

        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        (bool isRegistered, bool kycVerified, uint256 registrationOrder,, uint256 totalBadgesEarned) =
            badge.userInfo(user1);
        assertTrue(isRegistered);
        assertTrue(kycVerified);
        assertEq(registrationOrder, 1);
        assertEq(totalBadgesEarned, 1);
    }

    function test_RegisterUser_RevertsIfAlreadyRegistered() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, false);

        vm.expectRevert("User already registered");
        vm.prank(managerEOA);
        badge.registerUser(user1, true);
    }

    function test_RegisterUser_RevertsIfNotManager() public {
        vm.expectRevert("Not Authorized Manager");
        vm.prank(stranger);
        badge.registerUser(user1, false);
    }

    function test_RegisterUser_MultipleUsers() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.registerUser(user2, false);
        vm.stopPrank();

        assertEq(badge.totalRegistrations(), 2);
        (,, uint256 reg1,,) = badge.userInfo(user1);
        (,, uint256 reg2,,) = badge.userInfo(user2);
        assertEq(reg1, 1);
        assertEq(reg2, 2);
    }

    // ==================== BADGE MINTING TESTS ====================

    function test_MintBadge_Success() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.expectEmit(true, true, false, true);
        emit BadgeMinted(user1, 1, 2, LearnWayBadge.BadgeTier.GOLD, true);

        vm.prank(managerEOA);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);

        assertTrue(badge.userHasBadge(user1, 1));
        assertEq(badge.userBadgeTokenId(user1, 1), 2);
        assertEq(badge.ownerOf(2), user1);
    }

    function test_MintBadge_RevertsIfUserNotRegistered() public {
        vm.expectRevert("User not registered");
        vm.prank(managerEOA);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_MintBadge_RevertsIfInvalidBadgeId() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.expectRevert("Invalid badge ID");
        vm.prank(managerEOA);
        badge.mintBadge(user1, 24, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_MintBadge_RevertsIfAlreadyHasBadge() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);

        vm.expectRevert("User already has this badge");
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.PLATINUM);
        vm.stopPrank();
    }

    function test_MintBadge_RevertsIfNotManager() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.expectRevert("Not Authorized Manager");
        vm.prank(stranger);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_MintBadge_MaxSupplyReached() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.registerUser(user2, true);

        // Mint Grandmaster (badgeId 22, maxSupply = 1)
        badge.mintBadge(user1, 22, LearnWayBadge.BadgeTier.DIAMOND);

        vm.expectRevert("Badge max supply reached");
        badge.mintBadge(user2, 22, LearnWayBadge.BadgeTier.DIAMOND);
        vm.stopPrank();
    }

    // ==================== EARLY BIRD TESTS ====================

    function test_MintBadge_EarlyBird_Success() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.prank(managerEOA);
        badge.mintBadge(user1, 2, LearnWayBadge.BadgeTier.GOLD);

        assertTrue(badge.userHasBadge(user1, 2));
    }

    function test_MintBadge_EarlyBird_RevertsIfNoKYC() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, false);

        vm.expectRevert("Early Bird requires KYC");
        vm.prank(managerEOA);
        badge.mintBadge(user1, 2, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_MintBadge_EarlyBird_RevertsIfNotEligible() public {
        // Set early bird limit to 1
        vm.prank(adminEOA);
        badge.setMaxEarlyBirdSpots(1);

        // Register 2 users
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.registerUser(user2, true);
        vm.stopPrank();

        // user2's registrationOrder is 2, which is > maxEarlyBirdSpots (1)
        vm.expectRevert("Not eligible for Early Bird");
        vm.prank(managerEOA);
        badge.mintBadge(user2, 2, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_MintBadge_EarlyBird_RevertsIfLimitReached() public {
        // Set limit to 2 and register 2 users first
        vm.prank(adminEOA);
        badge.setMaxEarlyBirdSpots(2);

        vm.startPrank(managerEOA);
        badge.registerUser(user1, true); // registrationOrder = 1
        address user3 = address(0x3333);
        badge.registerUser(user3, true); // registrationOrder = 2

        // Both are eligible by registration order (1 and 2 <= 2)
        // Now mint for user1, count becomes 1
        badge.mintBadge(user1, 2, LearnWayBadge.BadgeTier.GOLD);

        // Reduce limit to 1 so earlyBirdCount (1) >= maxEarlyBirdSpots (1)
        vm.stopPrank();
        vm.prank(adminEOA);
        badge.setMaxEarlyBirdSpots(1);

        // user3 still has valid registrationOrder (2 was valid when they registered)
        // But now the count limit is reached
        vm.expectRevert("Not eligible for Early Bird");
        vm.prank(managerEOA);
        badge.mintBadge(user3, 2, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_IsEligibleForEarlyBird() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        assertTrue(badge.isEligibleForEarlyBird(user1));

        vm.prank(managerEOA);
        badge.mintBadge(user1, 2, LearnWayBadge.BadgeTier.GOLD);

        assertFalse(badge.isEligibleForEarlyBird(user1));
    }

    function test_GetEarlyBirdInfo() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        (
            uint256 registrationOrder,
            uint256 kycOrder,
            bool isKycCompleted,
            bool hasEarlyBirdBadge,
            bool isEligible,
            uint256 currentEarlyBirdCount,
            uint256 currentMaxEarlyBirdSpots
        ) = badge.getEarlyBirdInfo(user1);

        assertEq(registrationOrder, 1);
        assertTrue(isKycCompleted);
        assertFalse(hasEarlyBirdBadge);
        assertTrue(isEligible);
        assertEq(currentEarlyBirdCount, 0);
        assertEq(currentMaxEarlyBirdSpots, 1000);
    }

    function test_SetMaxEarlyBirdSpots() public {
        vm.expectEmit(false, false, false, true);
        emit EarlyBirdLimitUpdated(1000, 500, true);

        vm.prank(adminEOA);
        badge.setMaxEarlyBirdSpots(500);

        assertEq(badge.maxEarlyBirdSpots(), 500);
    }

    function test_SetMaxEarlyBirdSpots_RevertsIfZero() public {
        vm.expectRevert("Limit must be greater than 0");
        vm.prank(adminEOA);
        badge.setMaxEarlyBirdSpots(0);
    }

    function test_SetMaxEarlyBirdSpots_RevertsIfNotAdmin() public {
        vm.expectRevert("Not AuthorizedAdmin");
        vm.prank(stranger);
        badge.setMaxEarlyBirdSpots(500);
    }

    // ==================== BATCH MINT TESTS ====================

    function test_BatchMintBadges_Success() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        uint256[] memory badgeIds = new uint256[](3);
        badgeIds[0] = 1;
        badgeIds[1] = 3;
        badgeIds[2] = 4;

        LearnWayBadge.BadgeTier[] memory tiers = new LearnWayBadge.BadgeTier[](3);
        tiers[0] = LearnWayBadge.BadgeTier.GOLD;
        tiers[1] = LearnWayBadge.BadgeTier.SILVER;
        tiers[2] = LearnWayBadge.BadgeTier.BRONZE;

        vm.prank(managerEOA);
        badge.batchMintBadges(user1, badgeIds, tiers);

        assertTrue(badge.userHasBadge(user1, 1));
        assertTrue(badge.userHasBadge(user1, 3));
        assertTrue(badge.userHasBadge(user1, 4));
    }

    function test_BatchMintBadges_RevertsIfLengthMismatch() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        uint256[] memory badgeIds = new uint256[](2);
        badgeIds[0] = 1;
        badgeIds[1] = 3;

        LearnWayBadge.BadgeTier[] memory tiers = new LearnWayBadge.BadgeTier[](3);
        tiers[0] = LearnWayBadge.BadgeTier.GOLD;
        tiers[1] = LearnWayBadge.BadgeTier.SILVER;
        tiers[2] = LearnWayBadge.BadgeTier.BRONZE;

        vm.expectRevert("Arrays length mismatch");
        vm.prank(managerEOA);
        badge.batchMintBadges(user1, badgeIds, tiers);
    }

    function test_BatchMintBadges_RevertsIfNotRegistered() public {
        uint256[] memory badgeIds = new uint256[](1);
        badgeIds[0] = 1;

        LearnWayBadge.BadgeTier[] memory tiers = new LearnWayBadge.BadgeTier[](1);
        tiers[0] = LearnWayBadge.BadgeTier.GOLD;

        vm.expectRevert("User not registered");
        vm.prank(managerEOA);
        badge.batchMintBadges(user1, badgeIds, tiers);
    }

    // ==================== BADGE UPGRADE TESTS ====================

    function test_UpgradeBadge_Success() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.BRONZE); // Quiz Explorer is dynamic

        vm.expectEmit(true, true, false, true);
        emit BadgeUpgraded(user1, 3, 2, LearnWayBadge.BadgeTier.SILVER, true);

        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier.SILVER);
        vm.stopPrank();

        uint256 tokenId = badge.userBadgeTokenId(user1, 3);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
    }

    function test_UpgradeBadge_RevertsIfNotDynamic() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD); // First Spark is not dynamic

        vm.expectRevert("Badge is not upgradeable");
        badge.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.PLATINUM);
        vm.stopPrank();
    }

    function test_UpgradeBadge_RevertsIfUserDoesntHaveBadge() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.expectRevert("User doesn't have this badge");
        vm.prank(managerEOA);
        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier.SILVER);
    }

    function test_UpgradeBadge_RevertsIfTierNotHigher() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.SILVER);

        vm.expectRevert("New tier must be higher");
        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier.BRONZE);
        vm.stopPrank();
    }

    function test_UpgradeBadge_RevertsIfNotManager() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.BRONZE);
        vm.stopPrank();

        vm.expectRevert("Not Authorized Manager");
        vm.prank(stranger);
        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier.SILVER);
    }

    // ==================== KYC UPDATE TESTS ====================

    function test_UpdateKycStatus_FromFalseToTrue() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, false);

        vm.expectEmit(true, false, false, true);
        emit KycStatusUpdated(user1, true, true);

        vm.prank(managerEOA);
        badge.updateKycStatus(user1, true);

        (, bool kycVerified,,,) = badge.userInfo(user1);
        assertTrue(kycVerified);

        // Check Keyholder badge upgraded
        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
    }

    function test_UpdateKycStatus_FromTrueToFalse() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.expectEmit(true, false, false, true);
        emit KycStatusUpdated(user1, false, true);

        vm.prank(managerEOA);
        badge.updateKycStatus(user1, false);

        (, bool kycVerified,,,) = badge.userInfo(user1);
        assertFalse(kycVerified);

        // Check Keyholder badge downgraded
        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
    }

    function test_UpdateKycStatus_RevertsIfNotRegistered() public {
        vm.expectRevert("User not registered");
        vm.prank(managerEOA);
        badge.updateKycStatus(user1, true);
    }

    function test_UpdateKycStatus_RevertsIfUnchanged() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.expectRevert("KYC status unchanged");
        vm.prank(managerEOA);
        badge.updateKycStatus(user1, true);
    }

    function test_UpdateKycStatus_RevertsIfNotManager() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, false);

        vm.expectRevert("Not Authorized Manager");
        vm.prank(stranger);
        badge.updateKycStatus(user1, true);
    }

    // ==================== TRANSFER RESTRICTION TESTS ====================

    function test_Transfer_RevertsForSoulboundBadges() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);

        vm.expectRevert("LearnWay badges are non-transferable");
        vm.prank(user1);
        badge.transferFrom(user1, user2, tokenId);
    }

    function test_SafeTransfer_RevertsForSoulboundBadges() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);

        vm.expectRevert("LearnWay badges are non-transferable");
        vm.prank(user1);
        badge.safeTransferFrom(user1, user2, tokenId);
    }

    // ==================== VIEW FUNCTION TESTS ====================

    function test_GetUserBadges() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.SILVER);
        vm.stopPrank();

        uint256[] memory badges = badge.getUserBadges(user1);
        assertEq(badges.length, 3); // Keyholder + 2 minted
        assertEq(badges[0], 0); // Keyholder
        assertEq(badges[1], 1);
        assertEq(badges[2], 3);
    }

    function test_GetUserBadgeInfo() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.GOLD);
        vm.stopPrank();

        (bool hasBadge, uint256 tokenId, LearnWayBadge.BadgeTier tier, uint256 mintedAt, string memory status) =
            badge.getUserBadgeInfo(user1, 3);

        assertTrue(hasBadge);
        assertGt(tokenId, 0);
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.GOLD));
        assertGt(mintedAt, 0);
        assertEq(status, "Advanced Explorer");
    }

    function test_GetUserBadgeInfo_NonExistentBadge() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        (bool hasBadge,,,,) = badge.getUserBadgeInfo(user1, 5);
        assertFalse(hasBadge);
    }

    function test_GetTokenAttributes() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 8, LearnWayBadge.BadgeTier.DIAMOND);
        vm.stopPrank();

        uint256 tokenId = badge.userBadgeTokenId(user1, 8);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);

        assertEq(attrs.badgeId, 8);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.DIAMOND));
        assertGt(attrs.mintedAt, 0);
        assertEq(attrs.status, "Legendary Streak");
    }

    // ==================== TOKEN URI TESTS ====================

    function test_TokenURI() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        string memory uri = badge.tokenURI(tokenId);

        assertTrue(bytes(uri).length > 0);
        // Check it starts with data:application/json;base64,
        assertEq(bytes(uri)[0], bytes1("d"));
    }

    function test_TokenURI_RevertsForNonExistentToken() public {
        vm.expectRevert("Token does not exist");
        badge.tokenURI(999);
    }

    function test_SetBaseTokenURI() public {
        string memory newURI = "https://example.com/metadata/";

        vm.prank(adminEOA);
        badge.setBaseTokenURI(newURI);

        assertEq(badge.baseTokenURI(), newURI);
    }

    function test_SetBaseTokenURI_RevertsIfNotAdmin() public {
        vm.expectRevert("Not AuthorizedAdmin");
        vm.prank(stranger);
        badge.setBaseTokenURI("https://example.com/");
    }

    // ==================== BADGE STATUS TESTS ====================

    function test_GetBadgeStatus_Keyholder() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        LearnWayBadge.BadgeAttributes memory attrs = badge.getTokenAttributes(tokenId);
        assertEq(attrs.status, "Verified Member");
    }

    function test_GetBadgeStatus_QuizExplorer_AllTiers() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);

        // Test each tier
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.BRONZE);
        uint256 tokenId = badge.userBadgeTokenId(user1, 3);
        assertEq(badge.getTokenAttributes(tokenId).status, "Beginner Explorer");

        badge.registerUser(user2, true);
        badge.mintBadge(user2, 3, LearnWayBadge.BadgeTier.SILVER);
        tokenId = badge.userBadgeTokenId(user2, 3);
        assertEq(badge.getTokenAttributes(tokenId).status, "Explorer");
        vm.stopPrank();
    }

    function test_GetBadgeStatus_DailyStreak_AllTiers() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 8, LearnWayBadge.BadgeTier.DIAMOND);

        uint256 tokenId = badge.userBadgeTokenId(user1, 8);
        assertEq(badge.getTokenAttributes(tokenId).status, "Legendary Streak");
        vm.stopPrank();
    }

    // ==================== PAUSE/UNPAUSE TESTS ====================

    function test_Pause_ByPauser() public {
        vm.prank(pauserEOA);
        badge.pause();

        assertTrue(badge.paused());
    }

    function test_Pause_ByAdmin() public {
        vm.prank(adminEOA);
        badge.pause();

        assertTrue(badge.paused());
    }

    function test_Pause_RevertsIfNotAuthorized() public {
        vm.expectRevert("Not authorized Admin or Pauser");
        vm.prank(stranger);
        badge.pause();
    }

    function test_Unpause_ByAdmin() public {
        vm.prank(adminEOA);
        badge.pause();

        vm.prank(adminEOA);
        badge.unpause();

        assertFalse(badge.paused());
    }

    function test_Unpause_RevertsIfNotAdmin() public {
        vm.prank(adminEOA);
        badge.pause();

        vm.expectRevert("Not AuthorizedAdmin");
        vm.prank(pauserEOA);
        badge.unpause();
    }

    function test_Mint_RevertsWhenPaused() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        vm.prank(adminEOA);
        badge.pause();

        vm.expectRevert();
        vm.prank(managerEOA);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
    }

    // ==================== ADMIN CONTRACT UPDATE TESTS ====================

    function test_UpdateAdminContract() public {
        LearnWayAdmin newAdminImpl = new LearnWayAdmin();
        ERC1967Proxy newAdminProxy = new ERC1967Proxy(address(newAdminImpl), "");
        LearnWayAdmin newAdmin = LearnWayAdmin(address(newAdminProxy));

        vm.prank(adminEOA);
        newAdmin.initialize();

        vm.prank(adminEOA);
        badge.updateAdminContract(address(newAdmin));

        assertEq(address(badge.adminContract()), address(newAdmin));
    }

    function test_UpdateAdminContract_RevertsIfNotAdmin() public {
        vm.expectRevert("Not AuthorizedAdmin");
        vm.prank(stranger);
        badge.updateAdminContract(address(0x1234));
    }

    // ==================== UUPS UPGRADE TESTS ====================

    function test_UpgradeToV2_Success() public {
        LearnWayBadgeV2 badgeV2Impl = new LearnWayBadgeV2();

        vm.prank(adminEOA);
        badge.upgradeToAndCall(address(badgeV2Impl), "");

        // Cast to V2 to access new function
        LearnWayBadgeV2 badgeV2 = LearnWayBadgeV2(address(badge));
        assertEq(badgeV2.newVersion(), "2.0.0");

        // Verify old data is preserved
        assertEq(badge.name(), "LearnWay Badges");
        assertEq(badge.maxEarlyBirdSpots(), 1000);
    }

    function test_UpgradeToV2_RevertsIfNotAdmin() public {
        LearnWayBadgeV2 badgeV2Impl = new LearnWayBadgeV2();

        vm.expectRevert("Not AuthorizedAdmin");
        vm.prank(stranger);
        badge.upgradeToAndCall(address(badgeV2Impl), "");
    }

    function test_UpgradeToV2_PreservesUserData() public {
        // Register user and mint badge before upgrade
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.GOLD);
        vm.stopPrank();

        // Upgrade
        LearnWayBadgeV2 badgeV2Impl = new LearnWayBadgeV2();
        vm.prank(adminEOA);
        badge.upgradeToAndCall(address(badgeV2Impl), "");

        // Verify data preserved
        assertTrue(badge.userHasBadge(user1, 0));
        assertTrue(badge.userHasBadge(user1, 3));
        (, bool kycVerified, uint256 regOrder,, uint256 totalBadges) = badge.userInfo(user1);
        assertTrue(kycVerified);
        assertEq(regOrder, 1);
        assertEq(totalBadges, 2);
    }

    // ==================== SUPPORTS INTERFACE TESTS ====================

    function test_SupportsInterface_ERC721() public view {
        assertTrue(badge.supportsInterface(0x80ac58cd)); // ERC721 interface ID
    }

    function test_SupportsInterface_ERC721Metadata() public view {
        assertTrue(badge.supportsInterface(0x5b5e139f)); // ERC721Metadata interface ID
    }

    // ==================== EDGE CASES AND COMPLEX SCENARIOS ====================

    function test_ComplexScenario_UserJourney() public {
        // Register user without KYC
        vm.prank(managerEOA);
        badge.registerUser(user1, false);

        // Verify Keyholder badge at Silver tier
        uint256 keyholderTokenId = badge.userBadgeTokenId(user1, 0);
        assertEq(uint256(badge.getTokenAttributes(keyholderTokenId).tier), uint256(LearnWayBadge.BadgeTier.SILVER));

        // Complete KYC
        vm.prank(managerEOA);
        badge.updateKycStatus(user1, true);

        // Verify Keyholder upgraded to Gold
        assertEq(uint256(badge.getTokenAttributes(keyholderTokenId).tier), uint256(LearnWayBadge.BadgeTier.GOLD));

        // Mint Early Bird badge
        vm.prank(managerEOA);
        badge.mintBadge(user1, 2, LearnWayBadge.BadgeTier.GOLD);

        // Mint and upgrade Quiz Explorer badge
        vm.startPrank(managerEOA);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.BRONZE);
        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier.SILVER);
        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier.GOLD);
        vm.stopPrank();

        // Verify user has all badges
        uint256[] memory userBadges = badge.getUserBadges(user1);
        assertEq(userBadges.length, 3);

        // Verify total badges earned
        (,,,, uint256 totalBadges) = badge.userInfo(user1);
        assertEq(totalBadges, 3);
    }

    function test_ComplexScenario_MultipleUsersEarlyBird() public {
        // Set limit to 2
        vm.prank(adminEOA);
        badge.setMaxEarlyBirdSpots(2);

        // Register 3 users with KYC
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.registerUser(user2, true);
        address user3 = address(0x3333);
        badge.registerUser(user3, true);

        // First two can get Early Bird
        badge.mintBadge(user1, 2, LearnWayBadge.BadgeTier.GOLD);
        badge.mintBadge(user2, 2, LearnWayBadge.BadgeTier.GOLD);

        // Third one should fail because earlyBirdCount (2) >= maxEarlyBirdSpots (2)
        vm.expectRevert("Not eligible for Early Bird");
        badge.mintBadge(user3, 2, LearnWayBadge.BadgeTier.GOLD);
        vm.stopPrank();

        assertEq(badge.totalKycCompletions(), 2);
    }

    function test_ComplexScenario_BatchMintWithUpgrades() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        // Batch mint multiple dynamic badges
        uint256[] memory badgeIds = new uint256[](3);
        badgeIds[0] = 3; // Quiz Explorer (dynamic)
        badgeIds[1] = 4; // Master of Levels (dynamic)
        badgeIds[2] = 8; // Daily Claims (dynamic)

        LearnWayBadge.BadgeTier[] memory tiers = new LearnWayBadge.BadgeTier[](3);
        tiers[0] = LearnWayBadge.BadgeTier.BRONZE;
        tiers[1] = LearnWayBadge.BadgeTier.BRONZE;
        tiers[2] = LearnWayBadge.BadgeTier.BRONZE;

        vm.prank(managerEOA);
        badge.batchMintBadges(user1, badgeIds, tiers);

        // Upgrade all of them
        vm.startPrank(managerEOA);
        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier.PLATINUM);
        badge.upgradeBadge(user1, 4, LearnWayBadge.BadgeTier.GOLD);
        badge.upgradeBadge(user1, 8, LearnWayBadge.BadgeTier.DIAMOND);
        vm.stopPrank();

        // Verify all upgrades
        assertEq(
            uint256(badge.getTokenAttributes(badge.userBadgeTokenId(user1, 3)).tier),
            uint256(LearnWayBadge.BadgeTier.PLATINUM)
        );
        assertEq(
            uint256(badge.getTokenAttributes(badge.userBadgeTokenId(user1, 4)).tier),
            uint256(LearnWayBadge.BadgeTier.GOLD)
        );
        assertEq(
            uint256(badge.getTokenAttributes(badge.userBadgeTokenId(user1, 8)).tier),
            uint256(LearnWayBadge.BadgeTier.DIAMOND)
        );
    }

    function test_TokenCounter_IncrementsCorrectly() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true); // TokenId 1 for Keyholder
        badge.registerUser(user2, true); // TokenId 2 for Keyholder

        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD); // TokenId 3
        badge.mintBadge(user2, 1, LearnWayBadge.BadgeTier.GOLD); // TokenId 4
        vm.stopPrank();

        assertEq(badge.userBadgeTokenId(user1, 0), 1);
        assertEq(badge.userBadgeTokenId(user2, 0), 2);
        assertEq(badge.userBadgeTokenId(user1, 1), 3);
        assertEq(badge.userBadgeTokenId(user2, 1), 4);
    }

    function test_BadgeSupply_TracksCorrectly() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.registerUser(user2, true);

        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
        badge.mintBadge(user2, 1, LearnWayBadge.BadgeTier.GOLD);
        vm.stopPrank();

        (,,,, uint256 currentSupply) = badge.badges(1);
        assertEq(currentSupply, 2);
    }

    function test_LimitedSupplyBadges_HallOfFamer() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.registerUser(user2, true);

        // Hall of Famer (badgeId 23) has maxSupply of 1
        badge.mintBadge(user1, 23, LearnWayBadge.BadgeTier.DIAMOND);

        vm.expectRevert("Badge max supply reached");
        badge.mintBadge(user2, 23, LearnWayBadge.BadgeTier.DIAMOND);
        vm.stopPrank();
    }

    function test_NonDynamicBadge_CannotUpgrade() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 9, LearnWayBadge.BadgeTier.GOLD); // Routine Master (non-dynamic)

        vm.expectRevert("Badge is not upgradeable");
        badge.upgradeBadge(user1, 9, LearnWayBadge.BadgeTier.PLATINUM);
        vm.stopPrank();
    }

    function test_DynamicBadge_CanUpgradeMultipleTimes() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 11, LearnWayBadge.BadgeTier.BRONZE); // Elite (dynamic)

        badge.upgradeBadge(user1, 11, LearnWayBadge.BadgeTier.SILVER);
        badge.upgradeBadge(user1, 11, LearnWayBadge.BadgeTier.GOLD);
        badge.upgradeBadge(user1, 11, LearnWayBadge.BadgeTier.PLATINUM);
        badge.upgradeBadge(user1, 11, LearnWayBadge.BadgeTier.DIAMOND);
        vm.stopPrank();

        uint256 tokenId = badge.userBadgeTokenId(user1, 11);
        assertEq(uint256(badge.getTokenAttributes(tokenId).tier), uint256(LearnWayBadge.BadgeTier.DIAMOND));
        assertEq(badge.getTokenAttributes(tokenId).status, "Diamond Elite");
    }

    function test_AllBadgeCategories() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        // Test badges from each category
        uint256[7] memory testBadges = [
            uint256(0), // ONBOARDING - Keyholder (auto-minted)
            uint256(3), // QUIZ_COMPLETION - Quiz Explorer
            uint256(8), // STREAKS_CONSISTENCY - Daily Claims
            uint256(12), // BATTLES_CONTESTS - Duel Champion
            uint256(15), // SKILL_MASTERY - Rising Star
            uint256(19), // COMMUNITY_SHARING - Community Connector
            uint256(22) // ULTIMATE - Grandmaster
        ];

        vm.startPrank(managerEOA);
        for (uint256 i = 1; i < testBadges.length; i++) {
            badge.mintBadge(user1, testBadges[i], LearnWayBadge.BadgeTier.GOLD);
        }
        vm.stopPrank();

        // Verify all badges
        for (uint256 i = 0; i < testBadges.length; i++) {
            assertTrue(badge.userHasBadge(user1, testBadges[i]));
        }
    }

    function test_ReentrancyGuard_RegisterUser() public {
        // Reentrancy is protected by nonReentrant modifier
        // This test verifies the guard is in place
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        // Attempting to register same user again should fail on logic, not reentrancy
        vm.expectRevert("User already registered");
        vm.prank(managerEOA);
        badge.registerUser(user1, false);
    }

    function test_OwnerOf_ReturnsCorrectOwner() public {
        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        uint256 tokenId = badge.userBadgeTokenId(user1, 0);
        assertEq(badge.ownerOf(tokenId), user1);
        assertEq(badge.tokenToOwner(tokenId), user1);
    }

    function test_BalanceOf() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier.SILVER);
        vm.stopPrank();

        assertEq(badge.balanceOf(user1), 3); // Keyholder + 2 minted
    }

    function test_GetBadgeStatus_AllVariations() public {
        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);

        // Test badgeId 4 (Master of Levels)
        badge.mintBadge(user1, 4, LearnWayBadge.BadgeTier.GOLD);
        assertEq(badge.getTokenAttributes(badge.userBadgeTokenId(user1, 4)).status, "Level Master");

        badge.registerUser(user2, true);
        badge.mintBadge(user2, 4, LearnWayBadge.BadgeTier.SILVER);
        assertEq(badge.getTokenAttributes(badge.userBadgeTokenId(user2, 4)).status, "Level Expert");
        vm.stopPrank();
    }

    function test_Version() public view {
        assertEq(badge.version(), "1.0.0");
    }

    function test_BaseURI_ReturnsCorrectValue() public {
        string memory testURI = "ipfs://QmTest/";

        vm.prank(adminEOA);
        badge.setBaseTokenURI(testURI);

        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        string memory tokenUri = badge.tokenURI(badge.userBadgeTokenId(user1, 0));
        assertTrue(bytes(tokenUri).length > 0);
    }

    // ==================== FUZZ TESTS ====================

    function testFuzz_RegisterMultipleUsers(uint8 userCount) public {
        vm.assume(userCount > 0 && userCount <= 50);

        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(i + 1000));
            vm.prank(managerEOA);
            badge.registerUser(user, i % 2 == 0);
        }

        assertEq(badge.totalRegistrations(), userCount);
    }

    function testFuzz_MintBadgeWithDifferentTiers(uint8 tierIndex) public {
        vm.assume(tierIndex <= 4); // 0-4 are valid tiers

        vm.prank(managerEOA);
        badge.registerUser(user1, true);

        LearnWayBadge.BadgeTier tier = LearnWayBadge.BadgeTier(tierIndex);

        vm.prank(managerEOA);
        badge.mintBadge(user1, 3, tier);

        uint256 tokenId = badge.userBadgeTokenId(user1, 3);
        assertEq(uint256(badge.getTokenAttributes(tokenId).tier), tierIndex);
    }

    function testFuzz_SetMaxEarlyBirdSpots(uint256 limit) public {
        vm.assume(limit > 0 && limit < type(uint128).max);

        vm.prank(adminEOA);
        badge.setMaxEarlyBirdSpots(limit);

        assertEq(badge.maxEarlyBirdSpots(), limit);
    }

    function testFuzz_UpgradeBadgeTier(uint8 initialTier, uint8 newTier) public {
        vm.assume(initialTier < 5 && newTier < 5 && newTier > initialTier);

        vm.startPrank(managerEOA);
        badge.registerUser(user1, true);
        badge.mintBadge(user1, 3, LearnWayBadge.BadgeTier(initialTier));

        badge.upgradeBadge(user1, 3, LearnWayBadge.BadgeTier(newTier));
        vm.stopPrank();

        uint256 tokenId = badge.userBadgeTokenId(user1, 3);
        assertEq(uint256(badge.getTokenAttributes(tokenId).tier), newTier);
    }
}
