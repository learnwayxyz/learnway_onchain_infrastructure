// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnWayBadge} from "../../src/LearnWayBadge.sol";
import "../utils/BaseTest.t.sol";

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

    function test_RevertWhen_AdminAddressIsZero() public { vm.skip(true); }
    function test_RevertWhen_AlreadyInitialized() public { vm.skip(true); }
    function test_SetsAdminContractOnInitialize() public { vm.skip(true); }
    function test_SetsDefaultEarlyBirdLimitOnInitialize() public { vm.skip(true); }
    function test_AllBadgeTypesInitializedOnDeploy() public { vm.skip(true); }
    function test_InitializerDisabledOnImplementationContract() public { vm.skip(true); }
}

contract LearnWayBadgeTest_RegisterUser is BaseTest {
    function test_RevertWhen_CallerIsNotManager() public { vm.skip(true); }
    function test_RevertWhen_UserAlreadyRegistered() public { vm.skip(true); }
    function test_RevertWhen_ContractIsPaused() public { vm.skip(true); }
    function test_RegistersUserWithKycFalse() public { vm.skip(true); }
    function test_RegistersUserWithKycTrue() public { vm.skip(true); }
    function test_IncrementsRegistrationOrder() public { vm.skip(true); }
    function test_IncrementsTotalKycCompletionsWhenKycTrue() public { vm.skip(true); }
    function test_AssignsKycOrderWhenKycTrue() public { vm.skip(true); }
    function test_DoesNotAssignKycOrderWhenKycFalse() public { vm.skip(true); }
    function test_MintsKeyholderSilverWhenKycFalse() public { vm.skip(true); }
    function test_MintsKeyholderGoldWhenKycTrue() public { vm.skip(true); }
    function test_MultipleUsersGetUniqueRegistrationOrders() public { vm.skip(true); }
    function test_EmitsUserRegisteredEvent() public { vm.skip(true); }
    function test_EmitsBadgeMintedEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_MintBadge is BaseTest {
    function test_RevertWhen_CallerIsNotManager() public { vm.skip(true); }
    function test_RevertWhen_UserNotRegistered() public { vm.skip(true); }
    function test_RevertWhen_ContractIsPaused() public { vm.skip(true); }
    function test_RevertWhen_InvalidBadgeId() public { vm.skip(true); }
    function test_RevertWhen_UserAlreadyHasBadge() public { vm.skip(true); }
    function test_RevertWhen_BadgeMaxSupplyReached() public { vm.skip(true); }
    function test_RevertWhen_EarlyBirdRequiresKyc() public { vm.skip(true); }
    function test_RevertWhen_EarlyBirdKycOrderExceedsLimit() public { vm.skip(true); }
    function test_ManagerCanMintBadgeToRegisteredUser() public { vm.skip(true); }
    function test_UserHasBadgeAfterMint() public { vm.skip(true); }
    function test_BadgeCurrentSupplyIncrementsAfterMint() public { vm.skip(true); }
    function test_UserTotalBadgesEarnedIncrementsAfterMint() public { vm.skip(true); }
    function test_TokenAttributesSetCorrectlyOnMint() public { vm.skip(true); }
    function test_TokenIdIncrementsWithEachMint() public { vm.skip(true); }
    function test_EmitsBadgeMintedEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_UpgradeBadge is BaseTest {
    function test_RevertWhen_CallerIsNotManager() public { vm.skip(true); }
    function test_RevertWhen_UserDoesNotHaveBadge() public { vm.skip(true); }
    function test_RevertWhen_ContractIsPaused() public { vm.skip(true); }
    function test_RevertWhen_BadgeIsNotDynamic() public { vm.skip(true); }
    function test_RevertWhen_NewTierIsNotHigherThanCurrent() public { vm.skip(true); }
    function test_ManagerCanUpgradeDynamicBadge() public { vm.skip(true); }
    function test_TokenAttributesTierUpdatedAfterUpgrade() public { vm.skip(true); }
    function test_TokenAttributesLastUpdatedChangedAfterUpgrade() public { vm.skip(true); }
    function test_EmitsBadgeUpgradedEvent() public { vm.skip(true); }
    function test_EmitsMetadataUpdateEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_UpdateKycStatus is BaseTest {
    function test_RevertWhen_CallerIsNotManager() public { vm.skip(true); }
    function test_RevertWhen_UserNotRegistered() public { vm.skip(true); }
    function test_RevertWhen_ContractIsPaused() public { vm.skip(true); }
    function test_UpdatesKycVerifiedStatus() public { vm.skip(true); }
    function test_AssignsKycOrderOnFirstKycCompletion() public { vm.skip(true); }
    function test_DoesNotOverwriteKycOrderOnSubsequentUpdate() public { vm.skip(true); }
    function test_UpgradesKeyholderToGoldWhenKycTrue() public { vm.skip(true); }
    function test_DowngradesKeyholderToSilverWhenKycRevoked() public { vm.skip(true); }
    function test_MintsEarlyBirdWhenKycCompletedAndEligible() public { vm.skip(true); }
    function test_DoesNotMintEarlyBirdWhenKycOrderExceedsLimit() public { vm.skip(true); }
    function test_DoesNotMintEarlyBirdWhenAlreadyOwned() public { vm.skip(true); }
    function test_EmitsKycStatusUpdatedEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_SetBadgeImageURL is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public { vm.skip(true); }
    function test_RevertWhen_ImageURLIsEmpty() public { vm.skip(true); }
    function test_AdminCanSetImageURL() public { vm.skip(true); }
    function test_ImageURLStoredForCorrectBadgeAndTier() public { vm.skip(true); }
    function test_OverwritingExistingURLUpdatesValue() public { vm.skip(true); }
    function test_EmitsBadgeImageURLSetEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_GetBadgeImageURL is BaseTest {
    function test_ReturnsCustomURLWhenSet() public { vm.skip(true); }
    function test_ReturnsFallbackURLWhenNoCustomURL() public { vm.skip(true); }
}

contract LearnWayBadgeTest_SetMaxEarlyBirdSpots is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public { vm.skip(true); }
    function test_RevertWhen_NewLimitIsZero() public { vm.skip(true); }
    function test_AdminCanUpdateEarlyBirdLimit() public { vm.skip(true); }
    function test_MaxEarlyBirdSpotsUpdatedAfterSet() public { vm.skip(true); }
    function test_EmitsEarlyBirdLimitUpdatedEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_SetBaseTokenURI is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public { vm.skip(true); }
    function test_AdminCanSetBaseTokenURI() public { vm.skip(true); }
    function test_BaseTokenURIUpdatedAfterSet() public { vm.skip(true); }
}

contract LearnWayBadgeTest_UpdateAdminContract is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public { vm.skip(true); }
    function test_RevertWhen_NewAdminIsZeroAddress() public { vm.skip(true); }
    function test_AdminCanUpdateAdminContract() public { vm.skip(true); }
    function test_AdminContractAddressUpdatedAfterSet() public { vm.skip(true); }
}

contract LearnWayBadgeTest_Pause is BaseTest {
    function test_RevertWhen_CallerIsNotAdminOrPauser() public { vm.skip(true); }
    function test_RevertWhen_AlreadyPaused() public { vm.skip(true); }
    function test_PauserCanPauseTheContract() public { vm.skip(true); }
    function test_AdminCanPauseTheContract() public { vm.skip(true); }
    function test_ContractIsPausedAfterPause() public { vm.skip(true); }
    function test_EmitsPausedEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_Unpause is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public { vm.skip(true); }
    function test_RevertWhen_PauserCannotUnpause() public { vm.skip(true); }
    function test_RevertWhen_NotPaused() public { vm.skip(true); }
    function test_AdminCanUnpauseTheContract() public { vm.skip(true); }
    function test_ContractIsUnpausedAfterUnpause() public { vm.skip(true); }
    function test_EmitsUnpausedEvent() public { vm.skip(true); }
}

contract LearnWayBadgeTest_GetEarlyBirdInfo is BaseTest {
    function test_ReturnsCorrectRegistrationOrder() public { vm.skip(true); }
    function test_ReturnsCorrectKycOrder() public { vm.skip(true); }
    function test_ReturnsKycCompletionStatus() public { vm.skip(true); }
    function test_ReturnsHasEarlyBirdBadgeStatus() public { vm.skip(true); }
    function test_ReturnsCorrectEligibilityStatus() public { vm.skip(true); }
    function test_ReturnsCurrentTotalsAndLimits() public { vm.skip(true); }
}

contract LearnWayBadgeTest_GetUserBadges is BaseTest {
    function test_ReturnsEmptyArrayForUnregisteredUser() public { vm.skip(true); }
    function test_ReturnsAllMintedBadgeIds() public { vm.skip(true); }
}

contract LearnWayBadgeTest_GetUserBadgeData is BaseTest {
    function test_ReturnsCorrectUserDataAfterRegistration() public { vm.skip(true); }
    function test_ReflectsKycStatusCorrectly() public { vm.skip(true); }
    function test_TotalBadgesEarnedMatchesMintCount() public { vm.skip(true); }
}

contract LearnWayBadgeTest_GetUserBadgeInfo is BaseTest {
    function test_ReturnsFalseForBadgeNotOwned() public { vm.skip(true); }
    function test_ReturnsCorrectTokenIdAndAttributesForOwnedBadge() public { vm.skip(true); }
}

contract LearnWayBadgeTest_GetTokenAttributes is BaseTest {
    function test_ReturnsCorrectAttributesForMintedToken() public { vm.skip(true); }
    function test_ReturnsUpdatedAttributesAfterUpgrade() public { vm.skip(true); }
}

contract LearnWayBadgeTest_TokenURI is BaseTest {
    function test_RevertWhen_TokenDoesNotExist() public { vm.skip(true); }
    function test_ReturnsOnChainTokenMetadata() public { vm.skip(true); }
    function test_MetadataContainsBadgeName() public { vm.skip(true); }
    function test_MetadataContainsTierAttribute() public { vm.skip(true); }
    function test_MetadataContainsCategoryAttribute() public { vm.skip(true); }
    function test_MetadataUsesCustomImageURLWhenSet() public { vm.skip(true); }
    function test_MetadataUsesFallbackImageURLWhenNotSet() public { vm.skip(true); }
}

contract LearnWayBadgeTest_SupportsInterface is BaseTest {
    function test_SupportsERC721Interface() public { vm.skip(true); }
    function test_SupportsERC165Interface() public { vm.skip(true); }
    function test_SupportsEIP4906Interface() public { vm.skip(true); }
    function test_ReturnsFalseForUnsupportedInterface() public { vm.skip(true); }
}

contract LearnWayBadgeTest_Version is BaseTest {
    function test_ReturnsCurrentVersion() public { vm.skip(true); }
}

contract LearnWayBadgeTest_AuthorizeUpgrade is BaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public { vm.skip(true); }
    function test_AdminCanUpgradeContract() public { vm.skip(true); }
    function test_ImplementationAddressChangesAfterUpgrade() public { vm.skip(true); }
    function test_EmitsUpgradedEvent() public { vm.skip(true); }
    function test_StorageLayoutPreservedAfterUpgrade() public { vm.skip(true); }
}

contract LearnWayBadgeTest_SoulboundEnforcement is BaseTest {
    function test_RevertWhen_TransferAttempted() public { vm.skip(true); }
    function test_RevertWhen_SafeTransferAttempted() public { vm.skip(true); }
    function test_MintSucceeds() public { vm.skip(true); }
}
