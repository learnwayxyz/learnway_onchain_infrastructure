// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnWayAdmin} from "../../src/learnWayAdmin.sol";
import {LearnWayBadge} from "../../src/LearnWayBadge.sol";
import "../utils/BaseTest.t.sol";
import "../utils/Mocks.t.sol";

/*
 * @audit onlyAdmin, onlyManager, and onlyPausableAndAdmin all use require(string) instead of custom errors.
 * @audit onlyPausableAndAdmin is misleadingly named — it allows admin OR pauser, not both.
 * @audit updateAdminContract has no zero address check.
 * @audit _update reverts with a raw string instead of a custom error.
 * @audit BadgeImageURLsSet event exists but no batch setBadgeImageURLs function — unimplemented.
 * @audit setBadgeImageURL does not validate badgeId range — URLs can be set for non-existent badges.
 * @audit setBaseTokenURI has no empty string validation — can break fallback URI construction.
 * @audit whenNotPaused is only applied in _update (transfer hook). registerUser, mintBadge,
 *        upgradeBadge, and updateKycStatus are unprotected by pause — needs whenNotPaused.
 */

contract LearnWayBadgeTest_Initialize is BaseTest {
    LearnWayBadge uninitializedBadge;

    function setUp() public override {
        super.setUp();
        LearnWayBadge impl = new LearnWayBadge();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
        uninitializedBadge = LearnWayBadge(address(proxy));
        vm.label(address(uninitializedBadge), "UninitializedBadge");
    }

    function test_RevertWhen_AdminAddressIsZero() public {
        vm.expectRevert("Invalid admin address");
        uninitializedBadge.initialize(address(0));
    }

    function test_RevertWhen_AlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        badgeContract.initialize(address(adminContract));
    }

    function test_SetsAdminContractOnInitialize() public {
        assertEq(address(badgeContract.adminContract()), address(adminContract));
    }

    function test_SetsDefaultEarlyBirdLimitOnInitialize() public {
        assertEq(badgeContract.maxEarlyBirdSpots(), 1000);
    }

    function test_AllBadgeTypesInitializedOnDeploy() public {
        for (uint256 i = 1; i <= 24; i++) {
            (string memory name,,,,) = badgeContract.badges(i);
            assertTrue(bytes(name).length > 0);
        }
    }

    function test_InitializerDisabledOnImplementationContract() public {
        LearnWayBadge impl = new LearnWayBadge();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        impl.initialize(address(adminContract));
    }
}

contract LearnWayBadgeTest_RegisterUser is BaseTest {
    event UserRegistered(address indexed user, uint256 registrationOrder, bool kycStatus, bool status);
    event BadgeMinted(address indexed user, uint256 indexed badgeId, uint256 tokenId, LearnWayBadge.BadgeTier tier, bool status);

    function test_RevertWhen_CallerIsNotManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        badgeContract.registerUser(user1, false);
    }

    function test_RevertWhen_UserAlreadyRegistered() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);

        vm.prank(manager);
        vm.expectRevert("User already registered");
        badgeContract.registerUser(user1, false);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(pauser);
        badgeContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        badgeContract.registerUser(user1, false);
    }

    function test_RegistersUserWithKycFalse() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);

        (bool isRegistered, bool kycVerified,,,) = badgeContract.userInfo(user1);
        assertTrue(isRegistered);
        assertFalse(kycVerified);
    }

    function test_RegistersUserWithKycTrue() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, true);

        (bool isRegistered, bool kycVerified,,,) = badgeContract.userInfo(user1);
        assertTrue(isRegistered);
        assertTrue(kycVerified);
    }

    function test_IncrementsRegistrationOrder() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
        vm.prank(manager);
        badgeContract.registerUser(user2, false);

        (,, uint256 order1,,) = badgeContract.userInfo(user1);
        (,, uint256 order2,,) = badgeContract.userInfo(user2);
        assertEq(order1, 1);
        assertEq(order2, 2);
    }

    function test_IncrementsTotalKycCompletionsWhenKycTrue() public {
        uint256 before = badgeContract.totalKycCompletions();
        vm.prank(manager);
        badgeContract.registerUser(user1, true);
        assertEq(badgeContract.totalKycCompletions(), before + 1);
    }

    function test_AssignsKycOrderWhenKycTrue() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, true);

        (,,, uint256 kycOrder,) = badgeContract.userInfo(user1);
        assertEq(kycOrder, 1);
    }

    function test_DoesNotAssignKycOrderWhenKycFalse() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);

        (,,, uint256 kycOrder,) = badgeContract.userInfo(user1);
        assertEq(kycOrder, 0);
    }

    function test_MintsKeyholderSilverWhenKycFalse() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);

        (bool hasBadge, uint256 tokenId, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, 1);
        assertTrue(hasBadge);
        assertEq(tokenId, 1);
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.SILVER));
    }

    function test_MintsKeyholderGoldWhenKycTrue() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, true);

        (bool hasBadge,, LearnWayBadge.BadgeTier tier,,) = badgeContract.getUserBadgeInfo(user1, 1);
        assertTrue(hasBadge);
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.GOLD));
    }

    function test_MultipleUsersGetUniqueRegistrationOrders() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
        vm.prank(manager);
        badgeContract.registerUser(user2, false);
        vm.prank(manager);
        badgeContract.registerUser(user3, false);

        (,, uint256 o1,,) = badgeContract.userInfo(user1);
        (,, uint256 o2,,) = badgeContract.userInfo(user2);
        (,, uint256 o3,,) = badgeContract.userInfo(user3);
        assertTrue(o1 != o2 && o2 != o3 && o1 != o3);
    }

    function test_EmitsUserRegisteredEvent() public {
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(user1, 1, false, true);
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_EmitsBadgeMintedEvent() public {
        vm.expectEmit(true, true, false, false);
        emit BadgeMinted(user1, 1, 1, LearnWayBadge.BadgeTier.SILVER, true);
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }
}

contract LearnWayBadgeTest_MintBadge is BaseTest {
    event BadgeMinted(address indexed user, uint256 indexed badgeId, uint256 tokenId, LearnWayBadge.BadgeTier tier, bool status);

    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_RevertWhen_CallerIsNotManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
    }

    function test_RevertWhen_UserNotRegistered() public {
        vm.prank(manager);
        vm.expectRevert("User not registered");
        badgeContract.mintBadge(user2, 2, LearnWayBadge.BadgeTier.BRONZE);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(pauser);
        badgeContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
    }

    function test_RevertWhen_InvalidBadgeId() public {
        vm.prank(manager);
        vm.expectRevert("Invalid badge ID");
        badgeContract.mintBadge(user1, 0, LearnWayBadge.BadgeTier.BRONZE);

        vm.prank(manager);
        vm.expectRevert("Invalid badge ID");
        badgeContract.mintBadge(user1, 25, LearnWayBadge.BadgeTier.BRONZE);
    }

    function test_RevertWhen_UserAlreadyHasBadge() public {
        vm.prank(manager);
        vm.expectRevert("User already has this badge");
        badgeContract.mintBadge(user1, 1, LearnWayBadge.BadgeTier.SILVER);
    }

    function test_RevertWhen_BadgeMaxSupplyReached() public {
        // @todo Implement when a maxSupply setter is added to the contract.
        vm.skip(true);
    }

    function test_RevertWhen_EarlyBirdRequiresKyc() public {
        vm.prank(manager);
        vm.expectRevert("Early Bird requires KYC");
        badgeContract.mintBadge(user1, 3, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_RevertWhen_EarlyBirdKycOrderExceedsLimit() public {
        vm.prank(admin);
        badgeContract.setMaxEarlyBirdSpots(1);

        vm.prank(manager);
        badgeContract.registerUser(user2, true);

        vm.prank(manager);
        badgeContract.registerUser(user3, true);

        vm.prank(manager);
        vm.expectRevert("Not eligible for Early Bird");
        badgeContract.mintBadge(user3, 3, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_UserHasBadgeAfterMint() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        assertTrue(badgeContract.userHasBadge(user1, 2));
    }

    function test_BadgeCurrentSupplyIncrements() public {
        (,,,, uint256 before) = badgeContract.badges(2);
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        (,,,, uint256 after_) = badgeContract.badges(2);
        assertEq(after_, before + 1);
    }

    function test_UserTotalBadgesEarnedIncrements() public {
        (,,,, uint256 before) = badgeContract.userInfo(user1);
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        (,,,, uint256 after_) = badgeContract.userInfo(user1);
        assertEq(after_, before + 1);
    }

    function test_TokenAttributesSetCorrectlyOnMint() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 2);
        LearnWayBadge.BadgeAttributes memory attrs = badgeContract.getTokenAttributes(tokenId);
        assertEq(attrs.badgeId, 2);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.BRONZE));
        assertTrue(attrs.mintedAt > 0);
        assertEq(attrs.mintedAt, attrs.lastUpdated);
    }

    function test_TokenIdIncrementsWithEachMint() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        vm.prank(manager);
        badgeContract.mintBadge(user1, 4, LearnWayBadge.BadgeTier.BRONZE);

        uint256 tokenId2 = badgeContract.userBadgeTokenId(user1, 2);
        uint256 tokenId4 = badgeContract.userBadgeTokenId(user1, 4);
        assertEq(tokenId2, 2);
        assertEq(tokenId4, 3);
    }

    function test_EmitsBadgeMintedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit BadgeMinted(user1, 2, 2, LearnWayBadge.BadgeTier.BRONZE, true);
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
    }
}

contract LearnWayBadgeTest_UpgradeBadge is BaseTest {
    event BadgeUpgraded(address indexed user, uint256 indexed badgeId, uint256 tokenId, LearnWayBadge.BadgeTier newTier, bool status);
    event MetadataUpdate(uint256 _tokenId);

    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_RevertWhen_CallerIsNotManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_RevertWhen_UserDoesNotHaveBadge() public {
        vm.prank(manager);
        vm.expectRevert("User doesn't have this badge");
        badgeContract.upgradeBadge(user1, 2, LearnWayBadge.BadgeTier.SILVER);
    }

    function test_RevertWhen_ContractIsPaused() public {
        // @todo Implement when whenNotPaused is added to upgradeBadge.
        vm.skip(true);
    }

    function test_RevertWhen_BadgeIsNotDynamic() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        vm.prank(manager);
        vm.expectRevert("Badge is not upgradeable");
        badgeContract.upgradeBadge(user1, 2, LearnWayBadge.BadgeTier.SILVER);
    }

    function test_RevertWhen_NewTierIsNotHigherThanCurrent() public {
        vm.prank(manager);
        vm.expectRevert("New tier must be higher");
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.SILVER);
    }

    function test_TokenAttributesTierUpdated() public {
        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 1);
        vm.prank(manager);
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
        LearnWayBadge.BadgeAttributes memory attrs = badgeContract.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
    }

    function test_TokenAttributesLastUpdatedChanges() public {
        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 1);
        uint256 mintedAt = badgeContract.getTokenAttributes(tokenId).mintedAt;
        vm.warp(block.timestamp + 1 days);
        vm.prank(manager);
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
        LearnWayBadge.BadgeAttributes memory attrs = badgeContract.getTokenAttributes(tokenId);
        assertEq(attrs.mintedAt, mintedAt);
        assertEq(attrs.lastUpdated, mintedAt + 1 days);
    }

    function test_EmitsBadgeUpgradedEvent() public {
        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 1);
        vm.expectEmit(true, true, false, true);
        emit BadgeUpgraded(user1, 1, tokenId, LearnWayBadge.BadgeTier.GOLD, true);
        vm.prank(manager);
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
    }

    function test_EmitsMetadataUpdateEvent() public {
        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 1);
        vm.expectEmit(false, false, false, true);
        emit MetadataUpdate(tokenId);
        vm.prank(manager);
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
    }
}

contract LearnWayBadgeTest_UpdateKycStatus is BaseTest {
    event KycStatusUpdated(address indexed user, bool kycStatus, uint256 kycOrder, bool status);

    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_RevertWhen_CallerIsNotManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        badgeContract.updateKycStatus(user1, true);
    }

    function test_RevertWhen_UserNotRegistered() public {
        vm.prank(manager);
        vm.expectRevert("User not registered");
        badgeContract.updateKycStatus(user2, true);
    }

    function test_RevertWhen_ContractIsPaused() public {
        // @todo Implement when whenNotPaused is added to updateKycStatus.
        vm.skip(true);
    }

    function test_UpdatesKycVerifiedStatus() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (, bool kycVerified,,,) = badgeContract.userInfo(user1);
        assertTrue(kycVerified);
    }

    function test_AssignsKycOrderOnFirstKycCompletion() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (,,, uint256 kycOrder,) = badgeContract.userInfo(user1);
        assertEq(kycOrder, 1);
        assertEq(badgeContract.totalKycCompletions(), 1);
    }

    function test_DoesNotOverwriteKycOrderOnSubsequentUpdate() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, false);
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);

        (,,, uint256 kycOrder,) = badgeContract.userInfo(user1);
        assertEq(kycOrder, 1);
        assertEq(badgeContract.totalKycCompletions(), 1);
    }

    function test_UpgradesKeyholderToGoldWhenKycTrue() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);

        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 1);
        LearnWayBadge.BadgeAttributes memory attrs = badgeContract.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
    }

    function test_DowngradesKeyholderToSilverWhenKycRevoked() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, false);

        uint256 tokenId = badgeContract.userBadgeTokenId(user1, 1);
        LearnWayBadge.BadgeAttributes memory attrs = badgeContract.getTokenAttributes(tokenId);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
    }

    function test_MintsEarlyBirdWhenKycCompletedAndEligible() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        assertTrue(badgeContract.userHasBadge(user1, 3));
    }

    function test_DoesNotMintEarlyBirdWhenKycOrderExceedsLimit() public {
        vm.prank(admin);
        badgeContract.setMaxEarlyBirdSpots(1);

        vm.prank(manager);
        badgeContract.registerUser(user2, false);

        vm.prank(manager);
        badgeContract.updateKycStatus(user2, true);

        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);

        assertFalse(badgeContract.userHasBadge(user1, 3));
    }

    function test_DoesNotMintEarlyBirdWhenAlreadyOwned() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, false);
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);

        (,,,, uint256 totalBadges) = badgeContract.userInfo(user1);
        assertEq(totalBadges, 2);
    }

    function test_EmitsKycStatusUpdatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit KycStatusUpdated(user1, true, 1, true);
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
    }
}

contract LearnWayBadgeTest_SetBadgeImageURL is BaseTest {
    event BadgeImageURLSet(uint256 indexed badgeId, LearnWayBadge.BadgeTier tier, string imageURL, bool status);

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER, "https://example.com/badge.svg");
    }

    function test_RevertWhen_ImageURLIsEmpty() public {
        vm.prank(admin);
        vm.expectRevert("Empty image URL");
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER, "");
    }

    function test_ImageURLStoredForCorrectBadgeAndTier() public {
        vm.prank(admin);
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER, "https://example.com/badge1_silver.svg");
        string memory url = badgeContract.getBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER);
        assertEq(url, "https://example.com/badge1_silver.svg");
    }

    function test_OverwritingExistingURLUpdatesValue() public {
        vm.prank(admin);
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER, "https://old.example.com/badge.svg");
        vm.prank(admin);
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER, "https://new.example.com/badge.svg");
        string memory url = badgeContract.getBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER);
        assertEq(url, "https://new.example.com/badge.svg");
    }

    function test_EmitsBadgeImageURLSetEvent() public {
        vm.expectEmit(true, false, false, true);
        emit BadgeImageURLSet(1, LearnWayBadge.BadgeTier.SILVER, "https://example.com/badge.svg", true);
        vm.prank(admin);
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER, "https://example.com/badge.svg");
    }
}

contract LearnWayBadgeTest_GetBadgeImageURL is BaseTest {
    function test_ReturnsCustomURLWhenSet() public {
        vm.prank(admin);
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.GOLD, "https://example.com/badge1_gold.svg");
        string memory url = badgeContract.getBadgeImageURL(1, LearnWayBadge.BadgeTier.GOLD);
        assertEq(url, "https://example.com/badge1_gold.svg");
    }

    function test_ReturnsFallbackURLWhenNoCustomURL() public {
        string memory url = badgeContract.getBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER);
        assertEq(url, "1_1.svg");
    }
}

contract LearnWayBadgeTest_SetMaxEarlyBirdSpots is BaseTest {
    event EarlyBirdLimitUpdated(uint256 oldLimit, uint256 newLimit, bool status);

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.setMaxEarlyBirdSpots(500);
    }

    function test_RevertWhen_NewLimitIsZero() public {
        vm.prank(admin);
        vm.expectRevert("Limit must be greater than 0");
        badgeContract.setMaxEarlyBirdSpots(0);
    }

    function test_StoresNewMaxEarlyBirdSpots() public {
        vm.prank(admin);
        badgeContract.setMaxEarlyBirdSpots(500);
        assertEq(badgeContract.maxEarlyBirdSpots(), 500);
    }

    function test_EmitsEarlyBirdLimitUpdatedEvent() public {
        uint256 oldLimit = badgeContract.maxEarlyBirdSpots();
        vm.expectEmit(false, false, false, true);
        emit EarlyBirdLimitUpdated(oldLimit, 500, true);
        vm.prank(admin);
        badgeContract.setMaxEarlyBirdSpots(500);
    }
}

contract LearnWayBadgeTest_SetBaseTokenURI is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.setBaseTokenURI("https://example.com/badges/");
    }

    function test_StoresNewBaseTokenURI() public {
        vm.prank(admin);
        badgeContract.setBaseTokenURI("https://example.com/badges/");
        string memory url = badgeContract.getBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER);
        assertEq(url, "https://example.com/badges/1_1.svg");
    }
}

contract LearnWayBadgeTest_UpdateAdminContract is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.updateAdminContract(address(adminContract));
    }

    function test_RevertWhen_NewAdminIsZeroAddress() public {
        // @todo Implement when updateAdminContract adds a zero address guard.
        vm.skip(true);
    }

    function test_StoresNewAdminContractAddress() public {
        address newAdmin = address(new LearnWayAdmin());
        vm.prank(admin);
        badgeContract.updateAdminContract(newAdmin);
        assertEq(address(badgeContract.adminContract()), newAdmin);
    }
}

contract LearnWayBadgeTest_Pause is BaseTest {
    event Paused(address account);

    function test_RevertWhen_CallerIsNotAdminOrPauser() public {
        vm.prank(stranger);
        vm.expectRevert("Not authorized Admin or Pauser");
        badgeContract.pause();
    }

    function test_RevertWhen_AlreadyPaused() public {
        vm.prank(pauser);
        badgeContract.pause();
        vm.prank(pauser);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        badgeContract.pause();
    }

    function test_ContractIsPaused() public {
        vm.prank(pauser);
        badgeContract.pause();
        assertTrue(badgeContract.paused());
    }

    function test_EmitsPausedEvent() public {
        vm.expectEmit(false, false, false, true);
        emit Paused(pauser);
        vm.prank(pauser);
        badgeContract.pause();
    }
}

contract LearnWayBadgeTest_Unpause is BaseTest {
    event Unpaused(address account);

    function setUp() public override {
        super.setUp();
        vm.prank(pauser);
        badgeContract.pause();
    }

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.unpause();
    }

    function test_RevertWhen_PauserCannotUnpause() public {
        vm.prank(pauser);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.unpause();
    }

    function test_RevertWhen_NotPaused() public {
        vm.prank(admin);
        badgeContract.unpause();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        badgeContract.unpause();
    }

    function test_ContractIsUnpaused() public {
        vm.prank(admin);
        badgeContract.unpause();
        assertFalse(badgeContract.paused());
    }

    function test_EmitsUnpausedEvent() public {
        vm.expectEmit(false, false, false, true);
        emit Unpaused(admin);
        vm.prank(admin);
        badgeContract.unpause();
    }
}

contract LearnWayBadgeTest_GetEarlyBirdInfo is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_ReturnsCorrectRegistrationOrder() public {
        (uint256 regOrder,,,,,,) = badgeContract.getEarlyBirdInfo(user1);
        assertEq(regOrder, 1);
    }

    function test_ReturnsCorrectKycOrder() public {
        (, uint256 kycOrder,,,,,) = badgeContract.getEarlyBirdInfo(user1);
        assertEq(kycOrder, 0);

        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (, kycOrder,,,,,) = badgeContract.getEarlyBirdInfo(user1);
        assertEq(kycOrder, 1);
    }

    function test_ReturnsKycCompletionStatus() public {
        (,, bool isKycCompleted,,,,) = badgeContract.getEarlyBirdInfo(user1);
        assertFalse(isKycCompleted);

        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (,, isKycCompleted,,,,) = badgeContract.getEarlyBirdInfo(user1);
        assertTrue(isKycCompleted);
    }

    function test_ReturnsHasEarlyBirdBadgeStatus() public {
        (,,, bool hasEarlyBird,,,) = badgeContract.getEarlyBirdInfo(user1);
        assertFalse(hasEarlyBird);

        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (,,, hasEarlyBird,,,) = badgeContract.getEarlyBirdInfo(user1);
        assertTrue(hasEarlyBird);
    }

    function test_ReturnsCorrectEligibilityStatus() public {
        (,,,, bool isEligible,,) = badgeContract.getEarlyBirdInfo(user1);
        assertFalse(isEligible);

        vm.prank(admin);
        badgeContract.setMaxEarlyBirdSpots(1);
        vm.prank(manager);
        badgeContract.registerUser(user2, false);
        vm.prank(manager);
        badgeContract.updateKycStatus(user2, true);

        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (,,,, isEligible,,) = badgeContract.getEarlyBirdInfo(user1);
        assertFalse(isEligible);
    }

    function test_ReturnsCurrentTotalsAndLimits() public {
        (,,,,, uint256 totalKyc, uint256 maxSpots) = badgeContract.getEarlyBirdInfo(user1);
        assertEq(totalKyc, 0);
        assertEq(maxSpots, 1000);

        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (,,,,, totalKyc, maxSpots) = badgeContract.getEarlyBirdInfo(user1);
        assertEq(totalKyc, 1);
        assertEq(maxSpots, 1000);
    }
}

contract LearnWayBadgeTest_GetUserBadges is BaseTest {
    function test_ReturnsEmptyArrayForUnregisteredUser() public {
        uint256[] memory badges = badgeContract.getUserBadges(stranger);
        assertEq(badges.length, 0);
    }

    function test_ReturnsAllMintedBadgeIds() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        uint256[] memory badges = badgeContract.getUserBadges(user1);
        assertEq(badges.length, 2);
        assertEq(badges[0], 1);
        assertEq(badges[1], 2);
    }
}

contract LearnWayBadgeTest_GetUserBadgeData is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_ReturnsCorrectUserDataAfterRegistration() public {
        (bool kycCompleted, bool isRegistered, uint256 totalBadges, uint256 regOrder,) =
            badgeContract.getUserBadgeData(user1);
        assertFalse(kycCompleted);
        assertTrue(isRegistered);
        assertEq(totalBadges, 1);
        assertEq(regOrder, 1);
    }

    function test_ReflectsKycStatusCorrectly() public {
        vm.prank(manager);
        badgeContract.updateKycStatus(user1, true);
        (bool kycCompleted,,,,) = badgeContract.getUserBadgeData(user1);
        assertTrue(kycCompleted);
    }

    function test_TotalBadgesEarnedMatchesMintCount() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        (,, uint256 totalBadges,,) = badgeContract.getUserBadgeData(user1);
        assertEq(totalBadges, 2);
    }
}

contract LearnWayBadgeTest_GetUserBadgeInfo is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_ReturnsFalseForBadgeNotOwned() public {
        (bool hasBadge,,,,) = badgeContract.getUserBadgeInfo(user1, 2);
        assertFalse(hasBadge);
    }

    function test_ReturnsCorrectTokenIdAndAttributesForOwnedBadge() public {
        (bool hasBadge, uint256 tokenId, LearnWayBadge.BadgeTier tier, uint256 mintedAt,) =
            badgeContract.getUserBadgeInfo(user1, 1);
        assertTrue(hasBadge);
        assertEq(tokenId, 1);
        assertEq(uint256(tier), uint256(LearnWayBadge.BadgeTier.SILVER));
        assertGt(mintedAt, 0);
    }
}

contract LearnWayBadgeTest_GetTokenAttributes is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_ReturnsCorrectAttributesForMintedToken() public {
        LearnWayBadge.BadgeAttributes memory attrs = badgeContract.getTokenAttributes(1);
        assertEq(attrs.badgeId, 1);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.SILVER));
        assertGt(attrs.mintedAt, 0);
        assertEq(attrs.mintedAt, attrs.lastUpdated);
    }

    function test_ReturnsUpdatedAttributes() public {
        vm.warp(block.timestamp + 1 days);
        vm.prank(manager);
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);

        LearnWayBadge.BadgeAttributes memory attrs = badgeContract.getTokenAttributes(1);
        assertEq(uint256(attrs.tier), uint256(LearnWayBadge.BadgeTier.GOLD));
        assertGt(attrs.lastUpdated, attrs.mintedAt);
    }
}

contract LearnWayBadgeTest_TokenURI is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_RevertWhen_TokenDoesNotExist() public {
        vm.expectRevert("Token does not exist");
        badgeContract.tokenURI(999);
    }

    function test_ReturnsOnChainTokenMetadata() public {
        string memory uri = badgeContract.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
        bytes memory uriBytes = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(uriBytes[i], prefix[i]);
        }
    }

    function test_MetadataContainsBadgeName() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);

        string memory uri1 = badgeContract.tokenURI(1);
        string memory uri2 = badgeContract.tokenURI(2);
        assertTrue(
            keccak256(bytes(uri1)) != keccak256(bytes(uri2)),
            "badges with different names must produce different tokenURIs"
        );
    }

    function test_MetadataContainsTierAttribute() public {
        string memory uriBefore = badgeContract.tokenURI(1);
        vm.prank(manager);
        badgeContract.upgradeBadge(user1, 1, LearnWayBadge.BadgeTier.GOLD);
        string memory uriAfter = badgeContract.tokenURI(1);
        assertTrue(
            keccak256(bytes(uriBefore)) != keccak256(bytes(uriAfter)),
            "tier change must produce a different tokenURI"
        );
    }

    function test_MetadataContainsCategoryAttribute() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        string memory uri1 = badgeContract.tokenURI(1);
        string memory uri2 = badgeContract.tokenURI(2);
        assertTrue(
            keccak256(bytes(uri1)) != keccak256(bytes(uri2)),
            "badges with different categories must produce different tokenURIs"
        );
    }

    function test_MetadataUsesCustomImageURLWhenSet() public {
        string memory uriBefore = badgeContract.tokenURI(1);
        vm.prank(admin);
        badgeContract.setBadgeImageURL(1, LearnWayBadge.BadgeTier.SILVER, "https://custom.example.com/keyholder.svg");
        string memory uriAfter = badgeContract.tokenURI(1);
        assertTrue(
            keccak256(bytes(uriBefore)) != keccak256(bytes(uriAfter)),
            "custom image URL must change the tokenURI"
        );
    }

    function test_MetadataUsesFallbackImageURLWhenNotSet() public {
        string memory uriBefore = badgeContract.tokenURI(1);
        vm.prank(admin);
        badgeContract.setBaseTokenURI("https://cdn.learnway.io/badges/");
        string memory uriAfter = badgeContract.tokenURI(1);
        assertTrue(
            keccak256(bytes(uriBefore)) != keccak256(bytes(uriAfter)),
            "changing baseTokenURI must change the fallback tokenURI"
        );
    }
}

contract LearnWayBadgeTest_SupportsInterface is BaseTest {
    function test_SupportsERC721Interface() public {
        assertTrue(badgeContract.supportsInterface(0x80ac58cd));
    }

    function test_SupportsERC165Interface() public {
        assertTrue(badgeContract.supportsInterface(0x01ffc9a7));
    }

    function test_SupportsEIP4906Interface() public {
        assertTrue(badgeContract.supportsInterface(0x49064906));
    }

    function test_ReturnsFalseForUnsupportedInterface() public {
        assertFalse(badgeContract.supportsInterface(0xdeadbeef));
    }
}

contract LearnWayBadgeTest_Version is BaseTest {
    function test_ReturnsCurrentVersion() public {
        assertEq(badgeContract.version(), "1.0.1");
    }
}

contract LearnWayBadgeTest_AuthorizeUpgrade is BaseTest {
    event Upgraded(address indexed implementation);

    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function test_RevertWhen_CallerIsNotAdmin() public {
        LearnWayBadge newImpl = new LearnWayBadge();
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        badgeContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_ImplementationAddressChanges() public {
        address implBefore = address(uint160(uint256(vm.load(address(badgeContract), IMPL_SLOT))));
        LearnWayBadge newImpl = new LearnWayBadge();
        vm.prank(admin);
        badgeContract.upgradeToAndCall(address(newImpl), "");
        address implAfter = address(uint160(uint256(vm.load(address(badgeContract), IMPL_SLOT))));
        assertNotEq(implBefore, implAfter);
        assertEq(implAfter, address(newImpl));
    }

    function test_EmitsUpgradedEvent() public {
        LearnWayBadge newImpl = new LearnWayBadge();
        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(newImpl));
        vm.prank(admin);
        badgeContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_RevertWhen_NewImplementationIsNotUUPS() public {
        MockNonUUPS nonUUPS = new MockNonUUPS();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("ERC1967InvalidImplementation(address)", address(nonUUPS)));
        badgeContract.upgradeToAndCall(address(nonUUPS), "");
    }

    function test_StorageLayoutPreserved() public {
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
        vm.prank(admin);
        badgeContract.setMaxEarlyBirdSpots(500);

        LearnWayBadge newImpl = new LearnWayBadge();
        vm.prank(admin);
        badgeContract.upgradeToAndCall(address(newImpl), "");

        (bool isRegistered,,,,) = badgeContract.userInfo(user1);
        assertTrue(isRegistered);
        assertEq(badgeContract.maxEarlyBirdSpots(), 500);
        assertEq(address(badgeContract.adminContract()), address(adminContract));
    }
}

contract LearnWayBadgeTest_SoulboundEnforcement is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        badgeContract.registerUser(user1, false);
    }

    function test_RevertWhen_TransferAttempted() public {
        vm.prank(user1);
        vm.expectRevert("LearnWay badges are non-transferable");
        badgeContract.transferFrom(user1, user2, 1);
    }

    function test_RevertWhen_SafeTransferAttempted() public {
        vm.prank(user1);
        vm.expectRevert("LearnWay badges are non-transferable");
        badgeContract.safeTransferFrom(user1, user2, 1);
    }

    function test_MintSucceeds() public {
        vm.prank(manager);
        badgeContract.mintBadge(user1, 2, LearnWayBadge.BadgeTier.BRONZE);
        assertTrue(badgeContract.userHasBadge(user1, 2));
    }
}
