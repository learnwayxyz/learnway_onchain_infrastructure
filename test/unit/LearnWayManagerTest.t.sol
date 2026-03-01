// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnWayAdmin} from "../../src/LearnWayAdmin.sol";
import {LearnWayManager, ILearnwayXPGemsContract, ILearnWayBadge} from "../../src/LearnWayManager.sol";
import "../utils/BaseTest.t.sol";
import "../utils/ManagerBaseTest.t.sol";

/*
 * @audit require(string) is used in all modifiers (onlyAdmin, onlyAdminOrManager, validAddress,
 *        contractsSet, userRegistered) — should use custom errors.
 * @audit batchRecordTransactionsForUsers skips unregistered users silently but has no guard
 *        against invalid entries in the users array. All other batch functions revert on invalid
 *        input inside the loop — this one does not. Inconsistent defensive behavior.
 * @audit Batch functions (batchRegisterUsers, batchUpdateUserData, batchMintBadges,
 *        batchUpdateKycStatus) have no empty array validation — an empty batch silently succeeds.
 * @audit updateAdminContract emits no event — a security-critical address change with no
 *        on-chain visibility.
 * @audit Manager has no single-user registerUser function. All user registration is routed
 *        through batchRegisterUsers. Confirm this is intentional per spec.
 * @audit View functions inconsistently handle unset contracts: most return zero/empty defaults,
 *        but getUserTransaction reverts when xpGemsContract is not set.
 * @audit batchRegisterUsers emits no per-user event — individual registration cannot be
 *        tracked from Manager events alone.
 * @audit userRegistered modifier fires before contractsSet on updateUserData, batchRecordTransactions,
 *        and batchRecordTransactionsForUsers. xpGemsContract.isRegistered() reverts at EVM level when
 *        xpGemsContract is address(0), making contractsSet unreachable and untestable in isolation.
 *        Fix: move contractsSet before userRegistered in the modifier order.
 */

contract LearnWayManagerTest_Initialize is ManagerBaseTest {
    LearnWayManager uninitializedManager;

    function setUp() public override {
        super.setUp();
        LearnWayManager impl = new LearnWayManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
        uninitializedManager = LearnWayManager(address(proxy));
        vm.label(address(uninitializedManager), "UninitializedManager");
    }

    function test_RevertWhen_AdminAddressIsZero() public {
        vm.expectRevert("Invalid admin contract address");
        uninitializedManager.initialize(address(0));
    }

    function test_RevertWhen_AlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        managerContract.initialize(address(adminContract));
    }

    function test_SetsAdminContractOnInitialize() public {
        assertEq(address(managerContract.adminContract()), address(adminContract));
    }

    function test_InitializerDisabledOnImplementationContract() public {
        LearnWayManager impl = new LearnWayManager();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        impl.initialize(address(adminContract));
    }
}

contract LearnWayManagerTest_SetContracts is ManagerBaseTest {
    event ContractsUpdated(address xpGemsContract, address badgesContract, uint256 timestamp);

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        managerContract.setContracts(address(xpGemsContract), address(badgeContract));
    }

    function test_StoresXpGemsAndBadgeAddresses() public {
        vm.prank(admin);
        managerContract.setContracts(address(xpGemsContract), address(badgeContract));
        (address gemsAddr, address badgesAddr) = managerContract.getContractAddresses();
        assertEq(gemsAddr, address(xpGemsContract));
        assertEq(badgesAddr, address(badgeContract));
    }

    function test_EmitsContractsUpdatedEvent() public {
        vm.expectEmit(false, false, false, true);
        emit ContractsUpdated(address(xpGemsContract), address(badgeContract), block.timestamp);
        vm.prank(admin);
        managerContract.setContracts(address(xpGemsContract), address(badgeContract));
    }
}

contract LearnWayManagerTest_UpdateUserData is ManagerBaseTest {
    event UserDataUpdated(address indexed user, uint256 gems, uint256 xp, uint256 streak, uint256 timestamp);

    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.updateUserData(user1, 100, 50, 5);
    }

    function test_RevertWhen_UserNotRegistered() public {
        vm.prank(manager);
        vm.expectRevert("User not registered");
        managerContract.updateUserData(user2, 100, 50, 5);
    }

    function test_RevertWhen_ContractsNotSet() public {
        // @todo Implement when modifier order is fixed (contractsSet before userRegistered).
        vm.skip(true);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.updateUserData(user1, 100, 50, 5);
    }

    function test_EmitsUserDataUpdatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit UserDataUpdated(user1, 200, 100, 5, block.timestamp);
        vm.prank(manager);
        managerContract.updateUserData(user1, 200, 100, 5);
    }
}

contract LearnWayManagerTest_BatchRecordTransactions is ManagerBaseTest {
    event TransactionRecorded(
        address indexed user,
        uint256 gems,
        uint256 xp,
        ILearnwayXPGemsContract.TransactionType txType,
        uint256 timestamp
    );

    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        (
            uint256[] memory gems,
            uint256[] memory xp,
            uint256[][] memory badges,
            ILearnwayXPGemsContract.TransactionType[] memory txTypes,
            string[] memory descs
        ) = buildTxBatch(1);

        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.batchRecordTransactions(user1, gems, xp, badges, txTypes, descs);
    }

    function test_RevertWhen_UserNotRegistered() public {
        (
            uint256[] memory gems,
            uint256[] memory xp,
            uint256[][] memory badges,
            ILearnwayXPGemsContract.TransactionType[] memory txTypes,
            string[] memory descs
        ) = buildTxBatch(1);

        vm.prank(manager);
        vm.expectRevert("User not registered");
        managerContract.batchRecordTransactions(user2, gems, xp, badges, txTypes, descs);
    }

    function test_RevertWhen_ContractsNotSet() public {
        // @todo Implement when modifier order is fixed (contractsSet before userRegistered).
        vm.skip(true);
    }

    function test_RevertWhen_ContractIsPaused() public {
        (
            uint256[] memory gems,
            uint256[] memory xp,
            uint256[][] memory badges,
            ILearnwayXPGemsContract.TransactionType[] memory txTypes,
            string[] memory descs
        ) = buildTxBatch(1);

        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.batchRecordTransactions(user1, gems, xp, badges, txTypes, descs);
    }

    function test_EmitsTransactionRecordedEventForEach() public {
        (
            uint256[] memory gems,
            uint256[] memory xp,
            uint256[][] memory badges,
            ILearnwayXPGemsContract.TransactionType[] memory txTypes,
            string[] memory descs
        ) = buildTxBatch(2);

        vm.expectEmit(true, false, false, true);
        emit TransactionRecorded(user1, gems[0], xp[0], txTypes[0], block.timestamp);
        vm.prank(manager);
        managerContract.batchRecordTransactions(user1, gems, xp, badges, txTypes, descs);
    }
}

contract LearnWayManagerTest_BatchRecordTransactionsForUsers is ManagerBaseTest {
    event TransactionRecorded(
        address indexed user,
        uint256 gems,
        uint256 xp,
        ILearnwayXPGemsContract.TransactionType txType,
        uint256 timestamp
    );

    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        (
            uint256[][] memory gems,
            uint256[][] memory xp,
            uint256[][][] memory badges,
            ILearnwayXPGemsContract.TransactionType[][] memory txTypes,
            string[][] memory descs
        ) = buildMultiUserTxBatch(1);

        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.batchRecordTransactionsForUsers(users, gems, xp, badges, txTypes, descs);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        (
            uint256[][] memory gems,
            uint256[][] memory xp,
            uint256[][][] memory badges,
            ILearnwayXPGemsContract.TransactionType[][] memory txTypes,
            string[][] memory descs
        ) = buildMultiUserTxBatch(1);

        vm.prank(manager);
        vm.expectRevert("Array length mismatch");
        managerContract.batchRecordTransactionsForUsers(users, gems, xp, badges, txTypes, descs);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        uint256 n = 101;
        address[] memory users = new address[](n);
        for (uint256 i = 0; i < n; i++) users[i] = address(uint160(i + 1));
        (
            uint256[][] memory gems,
            uint256[][] memory xp,
            uint256[][][] memory badges,
            ILearnwayXPGemsContract.TransactionType[][] memory txTypes,
            string[][] memory descs
        ) = buildMultiUserTxBatch(n);

        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        managerContract.batchRecordTransactionsForUsers(users, gems, xp, badges, txTypes, descs);
    }

    function test_RevertWhen_ContractsNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        address[] memory users = new address[](1);
        users[0] = user1;
        (
            uint256[][] memory gems,
            uint256[][] memory xp,
            uint256[][][] memory badges,
            ILearnwayXPGemsContract.TransactionType[][] memory txTypes,
            string[][] memory descs
        ) = buildMultiUserTxBatch(1);

        vm.prank(manager);
        vm.expectRevert("Contracts not set");
        mgr.batchRecordTransactionsForUsers(users, gems, xp, badges, txTypes, descs);
    }

    function test_RevertWhen_ContractIsPaused() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        (
            uint256[][] memory gems,
            uint256[][] memory xp,
            uint256[][][] memory badges,
            ILearnwayXPGemsContract.TransactionType[][] memory txTypes,
            string[][] memory descs
        ) = buildMultiUserTxBatch(1);

        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.batchRecordTransactionsForUsers(users, gems, xp, badges, txTypes, descs);
    }

    function test_EmitsTransactionRecordedEventForEachEntry() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        (
            uint256[][] memory gems,
            uint256[][] memory xp,
            uint256[][][] memory badges,
            ILearnwayXPGemsContract.TransactionType[][] memory txTypes,
            string[][] memory descs
        ) = buildMultiUserTxBatch(1);

        vm.expectEmit(true, false, false, true);
        emit TransactionRecorded(user1, 10, 5, ILearnwayXPGemsContract.TransactionType.Lesson, block.timestamp);
        vm.prank(manager);
        managerContract.batchRecordTransactionsForUsers(users, gems, xp, badges, txTypes, descs);
    }
}

contract LearnWayManagerTest_UpgradeBadgeForUser is ManagerBaseTest {
    event BadgeUpgraded(address indexed user, uint256 badgeId, uint256 timestamp);

    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.upgradeBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.GOLD);
    }

    function test_RevertWhen_UserNotRegistered() public {
        vm.prank(manager);
        vm.expectRevert("User not registered");
        managerContract.upgradeBadgeForUser(user2, 1, ILearnWayBadge.BadgeTier.GOLD);
    }

    function test_RevertWhen_ContractsNotSet() public {
        // @todo Implement when modifier order is fixed (contractsSet before userRegistered).
        vm.skip(true);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.upgradeBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.GOLD);
    }

    function test_BadgeTierUpdated() public {
        vm.prank(manager);
        managerContract.upgradeBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.GOLD);

        (bool hasBadge,, ILearnWayBadge.BadgeTier tier,,) = managerContract.getUserBadgeInfo(user1, 1);
        assertTrue(hasBadge);
        assertEq(uint256(tier), uint256(ILearnWayBadge.BadgeTier.GOLD));
    }

    function test_EmitsBadgeUpgradedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit BadgeUpgraded(user1, 1, block.timestamp);
        vm.prank(manager);
        managerContract.upgradeBadgeForUser(user1, 1, ILearnWayBadge.BadgeTier.GOLD);
    }
}

contract LearnWayManagerTest_BatchRegisterUsers is ManagerBaseTest {
    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory gems = new uint256[](1);
        bool[] memory kyc = new bool[](1);

        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.batchRegisterUsers(users, gems, kyc);
    }

    function test_RevertWhen_ContractsNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory gems = new uint256[](1);
        bool[] memory kyc = new bool[](1);

        vm.prank(manager);
        vm.expectRevert("Contracts not set");
        mgr.batchRegisterUsers(users, gems, kyc);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        uint256[] memory gems = new uint256[](1);
        bool[] memory kyc = new bool[](2);

        vm.prank(manager);
        vm.expectRevert("Array length mismatch");
        managerContract.batchRegisterUsers(users, gems, kyc);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        uint256 n = 101;
        address[] memory users = new address[](n);
        for (uint256 i = 0; i < n; i++) users[i] = address(uint160(i + 1));
        uint256[] memory gems = new uint256[](n);
        bool[] memory kyc = new bool[](n);

        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        managerContract.batchRegisterUsers(users, gems, kyc);
    }

    function test_RevertWhen_ContractIsPaused() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory gems = new uint256[](1);
        bool[] memory kyc = new bool[](1);

        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.batchRegisterUsers(users, gems, kyc);
    }

}

contract LearnWayManagerTest_BatchUpdateUserData is ManagerBaseTest {
    event UserDataUpdated(address indexed user, uint256 gems, uint256 xp, uint256 streak, uint256 timestamp);

    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](1);
        uint256[] memory streaks = new uint256[](1);

        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.batchUpdateUserData(users, gems, xp, streaks);
    }

    function test_RevertWhen_ContractsNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](1);
        uint256[] memory streaks = new uint256[](1);

        vm.prank(manager);
        vm.expectRevert("Contracts not set");
        mgr.batchUpdateUserData(users, gems, xp, streaks);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](2);
        uint256[] memory streaks = new uint256[](2);

        vm.prank(manager);
        vm.expectRevert("Array length mismatch");
        managerContract.batchUpdateUserData(users, gems, xp, streaks);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        uint256 n = 101;
        address[] memory users = new address[](n);
        for (uint256 i = 0; i < n; i++) users[i] = address(uint160(i + 1));
        uint256[] memory gems = new uint256[](n);
        uint256[] memory xp = new uint256[](n);
        uint256[] memory streaks = new uint256[](n);

        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        managerContract.batchUpdateUserData(users, gems, xp, streaks);
    }

    function test_RevertWhen_ContractIsPaused() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](1);
        uint256[] memory streaks = new uint256[](1);

        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.batchUpdateUserData(users, gems, xp, streaks);
    }

    function test_EmitsUserDataUpdatedEventForEachEntry() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory gems = new uint256[](1);
        gems[0] = 200;
        uint256[] memory xp = new uint256[](1);
        xp[0] = 100;
        uint256[] memory streaks = new uint256[](1);
        streaks[0] = 7;

        vm.expectEmit(true, false, false, true);
        emit UserDataUpdated(user1, 200, 100, 7, block.timestamp);
        vm.prank(manager);
        managerContract.batchUpdateUserData(users, gems, xp, streaks);
    }
}

contract LearnWayManagerTest_BatchMintBadges is ManagerBaseTest {
    event BadgeMinted(address indexed user, uint256 badgeId, uint256 timestamp);

    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory badgeIds = new uint256[](1);
        badgeIds[0] = 2;
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](1);

        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.batchMintBadges(users, badgeIds, tiers);
    }

    function test_RevertWhen_ContractsNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory badgeIds = new uint256[](1);
        badgeIds[0] = 2;
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](1);

        vm.prank(manager);
        vm.expectRevert("Contracts not set");
        mgr.batchMintBadges(users, badgeIds, tiers);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        uint256[] memory badgeIds = new uint256[](1);
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](2);

        vm.prank(manager);
        vm.expectRevert("Array length mismatch");
        managerContract.batchMintBadges(users, badgeIds, tiers);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        uint256 n = 51;
        address[] memory users = new address[](n);
        for (uint256 i = 0; i < n; i++) users[i] = address(uint160(i + 1));
        uint256[] memory badgeIds = new uint256[](n);
        for (uint256 i = 0; i < n; i++) badgeIds[i] = 2;
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](n);

        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        managerContract.batchMintBadges(users, badgeIds, tiers);
    }

    function test_RevertWhen_ContractIsPaused() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory badgeIds = new uint256[](1);
        badgeIds[0] = 2;
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](1);

        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.batchMintBadges(users, badgeIds, tiers);
    }

    function test_MintsBadgesForAllRegisteredUsers() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory badgeIds = new uint256[](1);
        badgeIds[0] = 2;
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](1);
        tiers[0] = ILearnWayBadge.BadgeTier.BRONZE;

        vm.prank(manager);
        managerContract.batchMintBadges(users, badgeIds, tiers);

        assertTrue(managerContract.userHasBadge(user1, 2));
    }

    function test_SkipsUnregisteredUserWithoutReverting() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        uint256[] memory badgeIds = new uint256[](2);
        badgeIds[0] = 2;
        badgeIds[1] = 2;
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](2);

        vm.prank(manager);
        managerContract.batchMintBadges(users, badgeIds, tiers);

        assertFalse(managerContract.userHasBadge(user2, 2));
    }

    function test_EmitsBadgeMintedEventForEachEntry() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory badgeIds = new uint256[](1);
        badgeIds[0] = 2;
        ILearnWayBadge.BadgeTier[] memory tiers = new ILearnWayBadge.BadgeTier[](1);
        tiers[0] = ILearnWayBadge.BadgeTier.BRONZE;

        vm.expectEmit(true, false, false, true);
        emit BadgeMinted(user1, 2, block.timestamp);
        vm.prank(manager);
        managerContract.batchMintBadges(users, badgeIds, tiers);
    }
}

contract LearnWayManagerTest_BatchUpdateKycStatus is ManagerBaseTest {
    event KycStatusUpdated(address indexed user, bool kycStatus, uint256 timestamp);

    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.prank(stranger);
        vm.expectRevert("Not Authorized Manager");
        managerContract.batchUpdateKycStatus(users, statuses);
    }

    function test_RevertWhen_ContractsNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        address[] memory users = new address[](1);
        users[0] = user1;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.prank(manager);
        vm.expectRevert("Contracts not set");
        mgr.batchUpdateKycStatus(users, statuses);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        bool[] memory statuses = new bool[](1);

        vm.prank(manager);
        vm.expectRevert("Array length mismatch");
        managerContract.batchUpdateKycStatus(users, statuses);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        uint256 n = 101;
        address[] memory users = new address[](n);
        for (uint256 i = 0; i < n; i++) users[i] = address(uint160(i + 1));
        bool[] memory statuses = new bool[](n);

        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        managerContract.batchUpdateKycStatus(users, statuses);
    }

    function test_RevertWhen_ContractIsPaused() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.prank(admin);
        managerContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.batchUpdateKycStatus(users, statuses);
    }

    function test_UpdatesKycStatusForAllRegisteredUsers() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.prank(manager);
        managerContract.batchUpdateKycStatus(users, statuses);

        (bool kycCompleted,,,,) = managerContract.getUserBadgeData(user1);
        assertTrue(kycCompleted);
    }

    function test_SkipsUnregisteredUserWithoutReverting() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        bool[] memory statuses = new bool[](2);
        statuses[0] = true;
        statuses[1] = true;

        vm.prank(manager);
        managerContract.batchUpdateKycStatus(users, statuses);

        (bool kycCompleted,,,,) = managerContract.getUserBadgeData(user2);
        assertFalse(kycCompleted);
    }

    function test_EmitsKycStatusUpdatedEventForEachEntry() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.expectEmit(true, false, false, true);
        emit KycStatusUpdated(user1, true, block.timestamp);
        vm.prank(manager);
        managerContract.batchUpdateKycStatus(users, statuses);
    }
}

contract LearnWayManagerTest_GetUserCompleteData is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 50, false);
    }

    function test_ReturnsFullDataForRegisteredUser() public {
        (uint256 gems,,,,, uint256[] memory badgesList, uint256 txCount, bool kycCompleted, uint256 totalBadgesEarned,)
            = managerContract.getUserCompleteData(user1);
        assertEq(gems, 50);
        assertEq(badgesList.length, 1);
        assertEq(txCount, 1);
        assertFalse(kycCompleted);
        assertEq(totalBadgesEarned, 1);
    }

    function test_ReturnsDefaultsWhenContractsNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        (uint256 gems, uint256 xp,,,, uint256[] memory badgesList, uint256 txCount,,,)
            = mgr.getUserCompleteData(user1);
        assertEq(gems, 0);
        assertEq(xp, 0);
        assertEq(badgesList.length, 0);
        assertEq(txCount, 0);
    }
}

contract LearnWayManagerTest_GetUserGemsData is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 50, false);
    }

    function test_ReturnsGemsDataFromXpGemsContract() public {
        (uint256 gems,,, bool registered,,) = managerContract.getUserGemsData(user1);
        assertEq(gems, 50);
        assertTrue(registered);
    }

    function test_ReturnsDefaultsWhenContractNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        (uint256 gems,,, bool registered,,) = mgr.getUserGemsData(user1);
        assertEq(gems, 0);
        assertFalse(registered);
    }
}

contract LearnWayManagerTest_GetUserBadgeData is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsBadgeDataFromBadgesContract() public {
        (bool kycCompleted, bool isRegistered, uint256 totalBadgesEarned,,)
            = managerContract.getUserBadgeData(user1);
        assertFalse(kycCompleted);
        assertTrue(isRegistered);
        assertEq(totalBadgesEarned, 1);
    }

    function test_ReturnsDefaultsWhenContractNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        (bool kycCompleted, bool isRegistered,,,) = mgr.getUserBadgeData(user1);
        assertFalse(kycCompleted);
        assertFalse(isRegistered);
    }
}

contract LearnWayManagerTest_GetUserBadgeInfo is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsBadgeInfoFromBadgesContract() public {
        (bool hasBadge,, ILearnWayBadge.BadgeTier tier,,) = managerContract.getUserBadgeInfo(user1, 1);
        assertTrue(hasBadge);
        assertEq(uint256(tier), uint256(ILearnWayBadge.BadgeTier.SILVER));
    }

    function test_ReturnsDefaultsWhenContractNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        (bool hasBadge,,,,) = mgr.getUserBadgeInfo(user1, 1);
        assertFalse(hasBadge);
    }
}

contract LearnWayManagerTest_GetUserGems is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 50, false);
    }

    function test_ReturnsGemsFromXpGemsContract() public {
        assertEq(managerContract.getUserGems(user1), 50);
    }

    function test_ReturnsZeroWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getUserGems(user1), 0);
    }
}

contract LearnWayManagerTest_GetUserXp is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsXpFromXpGemsContract() public {
        vm.prank(manager);
        managerContract.updateUserData(user1, 0, 100, 0);
        assertEq(managerContract.getUserXp(user1), 100);
    }

    function test_ReturnsZeroWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getUserXp(user1), 0);
    }
}

contract LearnWayManagerTest_GetUserStreak is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsStreakFromXpGemsContract() public {
        vm.prank(manager);
        managerContract.updateUserData(user1, 0, 0, 5);
        assertEq(managerContract.getUserStreak(user1), 5);
    }

    function test_ReturnsZeroWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getUserStreak(user1), 0);
    }
}

contract LearnWayManagerTest_GetUserTransactions is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsTransactionsFromXpGemsContract() public {
        assertEq(managerContract.getUserTransactions(user1).length, 1);
    }

    function test_ReturnsEmptyArrayWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getUserTransactions(user1).length, 0);
    }
}

contract LearnWayManagerTest_GetUserTransaction is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_RevertWhen_ContractNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        vm.expectRevert("Gems contract not set");
        mgr.getUserTransaction(user1, 0);
    }

    function test_ReturnsTransactionAtIndex() public {
        ILearnwayXPGemsContract.Transaction memory txRecord = managerContract.getUserTransaction(user1, 0);
        assertEq(txRecord.walletAddress, user1);
    }
}

contract LearnWayManagerTest_GetUserTransactionsByType is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsFilteredTransactions() public {
        ILearnwayXPGemsContract.Transaction[] memory txs =
            managerContract.getUserTransactionsByType(user1, ILearnwayXPGemsContract.TransactionType.RegisterUser);
        assertEq(txs.length, 1);
    }

    function test_ReturnsEmptyArrayWhenContractNotSet() public {
        assertEq(
            deployManagerWithoutContracts().getUserTransactionsByType(user1, ILearnwayXPGemsContract.TransactionType.Lesson).length,
            0
        );
    }
}

contract LearnWayManagerTest_GetUserRecentTransactions is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsRecentTransactions() public {
        assertEq(managerContract.getUserRecentTransactions(user1, 1).length, 1);
    }

    function test_ReturnsEmptyArrayWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getUserRecentTransactions(user1, 1).length, 0);
    }
}

contract LearnWayManagerTest_GetUserTransactionCount is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsCountFromXpGemsContract() public {
        assertEq(managerContract.getUserTransactionCount(user1), 1);
    }

    function test_ReturnsZeroWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getUserTransactionCount(user1), 0);
    }
}

contract LearnWayManagerTest_GetUserBadges is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsBadgesFromBadgesContract() public {
        uint256[] memory badges = managerContract.getUserBadges(user1);
        assertEq(badges.length, 1);
        assertEq(badges[0], 1);
    }

    function test_ReturnsEmptyArrayWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getUserBadges(user1).length, 0);
    }
}

contract LearnWayManagerTest_UserHasBadge is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsTrueWhenUserHasBadge() public {
        assertTrue(managerContract.userHasBadge(user1, 1));
    }

    function test_ReturnsFalseWhenContractNotSet() public {
        assertFalse(deployManagerWithoutContracts().userHasBadge(user1, 1));
    }
}

contract LearnWayManagerTest_IsUserRegistered is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsTrueForRegisteredUser() public {
        assertTrue(managerContract.isUserRegistered(user1));
    }

    function test_ReturnsFalseWhenContractNotSet() public {
        assertFalse(deployManagerWithoutContracts().isUserRegistered(user1));
    }
}

contract LearnWayManagerTest_GetEarlyBirdInfo is ManagerBaseTest {
    function setUp() public override {
        super.setUp();
        registerUser(user1, 0, false);
    }

    function test_ReturnsEarlyBirdInfoFromBadgesContract() public {
        (uint256 registrationOrder,, bool isKycCompleted,,,,) = managerContract.getEarlyBirdInfo(user1);
        assertEq(registrationOrder, 1);
        assertFalse(isKycCompleted);
    }

    function test_ReturnsDefaultsWhenContractNotSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        (uint256 registrationOrder, uint256 kycOrder, bool isKycCompleted,,,,) = mgr.getEarlyBirdInfo(user1);
        assertEq(registrationOrder, 0);
        assertEq(kycOrder, 0);
        assertFalse(isKycCompleted);
    }
}

contract LearnWayManagerTest_GetTotalUsers is ManagerBaseTest {
    function test_ReturnsTotalFromXpGemsContract() public {
        registerUser(user1, 0, false);
        assertEq(managerContract.getTotalUsers(), 1);
    }

    function test_ReturnsZeroWhenContractNotSet() public {
        assertEq(deployManagerWithoutContracts().getTotalUsers(), 0);
    }
}

contract LearnWayManagerTest_GetContractAddresses is ManagerBaseTest {
    function test_ReturnsZeroAddressesBeforeContractsSet() public {
        LearnWayManager mgr = deployManagerWithoutContracts();
        (address gemsAddr, address badgesAddr) = mgr.getContractAddresses();
        assertEq(gemsAddr, address(0));
        assertEq(badgesAddr, address(0));
    }

    function test_ReturnsSetContractAddresses() public {
        (address gemsAddr, address badgesAddr) = managerContract.getContractAddresses();
        assertEq(gemsAddr, address(xpGemsContract));
        assertEq(badgesAddr, address(badgeContract));
    }
}

contract LearnWayManagerTest_Pause is ManagerBaseTest {
    event Paused(address account);

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        managerContract.pause();
    }

    function test_RevertWhen_AlreadyPaused() public {
        vm.prank(admin);
        managerContract.pause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        managerContract.pause();
    }

    function test_ContractIsPaused() public {
        vm.prank(admin);
        managerContract.pause();
        assertTrue(managerContract.paused());
    }

    function test_EmitsPausedEvent() public {
        vm.expectEmit(false, false, false, true);
        emit Paused(admin);
        vm.prank(admin);
        managerContract.pause();
    }
}

contract LearnWayManagerTest_Unpause is ManagerBaseTest {
    event Unpaused(address account);

    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        managerContract.pause();
    }

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        managerContract.unpause();
    }

    function test_RevertWhen_NotPaused() public {
        vm.prank(admin);
        managerContract.unpause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        managerContract.unpause();
    }

    function test_ContractIsUnpaused() public {
        vm.prank(admin);
        managerContract.unpause();
        assertFalse(managerContract.paused());
    }

    function test_EmitsUnpausedEvent() public {
        vm.expectEmit(false, false, false, true);
        emit Unpaused(admin);
        vm.prank(admin);
        managerContract.unpause();
    }
}

contract LearnWayManagerTest_UpdateAdminContract is ManagerBaseTest {
    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        managerContract.updateAdminContract(makeAddr("newAdmin"));
    }

    function test_StoresNewAdminContractAddress() public {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        managerContract.updateAdminContract(newAdmin);
        assertEq(address(managerContract.adminContract()), newAdmin);
    }
}

contract LearnWayManagerTest_Version is ManagerBaseTest {
    function test_ReturnsCurrentVersion() public {
        assertEq(managerContract.version(), "1.0.0");
    }
}

contract LearnWayManagerTest_AuthorizeUpgrade is ManagerBaseTest {
    event Upgraded(address indexed implementation);

    bytes32 internal constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function test_RevertWhen_CallerIsNotAdmin() public {
        LearnWayManager newImpl = new LearnWayManager();
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        managerContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_ImplementationAddressChangesAfterUpgrade() public {
        LearnWayManager newImpl = new LearnWayManager();
        vm.prank(admin);
        managerContract.upgradeToAndCall(address(newImpl), "");

        address stored = address(uint160(uint256(vm.load(address(managerContract), IMPL_SLOT))));
        assertEq(stored, address(newImpl));
    }

    function test_EmitsUpgradedEvent() public {
        LearnWayManager newImpl = new LearnWayManager();
        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(newImpl));
        vm.prank(admin);
        managerContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_StorageLayoutPreservedAfterUpgrade() public {
        address originalAdmin = address(managerContract.adminContract());
        LearnWayManager newImpl = new LearnWayManager();
        vm.prank(admin);
        managerContract.upgradeToAndCall(address(newImpl), "");
        assertEq(address(managerContract.adminContract()), originalAdmin);
    }
}
