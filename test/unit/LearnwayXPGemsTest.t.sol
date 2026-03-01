// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnwayXPGemsContract} from "../../src/LearnwayXPGemsContract.sol";
import "../utils/BaseTest.t.sol";

/*
 * @audit onlyAdmin, onlyAdminOrManager, validAddress, and userExists all use require(string) instead of custom errors.
 * @audit batchRegisterUsers and batchUpdateGemsXpAndStreaks silently skip invalid entries (zero address,
 *        unregistered users) rather than reverting — confirm this is the intended spec behavior.
 * @audit balanceOf is a legacy alias for gemsOf — misleading name that could imply ERC20 compatibility.
 * @audit UserAlreadyRegistered event is emitted with status: false — event name implies a state but
 *        the false flag contradicts it, making the event semantics confusing.
 * @audit No updateAdminContract function — admin reference cannot be changed after deployment.
 * @audit getUserData, getUserInfo, getMultipleUsersInfo, and getMultipleUserData return overlapping
 *        data — candidates for consolidation.
 */

contract LearnwayXPGemsTest_Initialize is BaseTest {
    LearnwayXPGemsContract uninitializedXPGems;

    function setUp() public override {
        super.setUp();
        LearnwayXPGemsContract impl = new LearnwayXPGemsContract();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
        uninitializedXPGems = LearnwayXPGemsContract(address(proxy));
        vm.label(address(uninitializedXPGems), "UninitializedXPGems");
    }

    function test_RevertWhen_AdminAddressIsZero() public {
        vm.expectRevert("Invalid admin contract address");
        uninitializedXPGems.initialize(address(0));
    }

    function test_RevertWhen_AlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        xpGemsContract.initialize(address(adminContract));
    }

    function test_SetsAdminContractOnInitialize() public {
        assertEq(address(xpGemsContract.learnWayAdmin()), address(adminContract));
    }

    function test_InitializerDisabledOnImplementationContract() public {
        LearnwayXPGemsContract impl = new LearnwayXPGemsContract();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        impl.initialize(address(adminContract));
    }
}

contract LearnwayXPGemsTest_RegisterUser is BaseTest {
    event UserRegistered(address indexed user, uint256 gems, uint256 xp, uint256 createdAt, bool status);

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdminOrManager");
        xpGemsContract.registerUser(user1, 100);
    }

    function test_RevertWhen_UserAlreadyRegistered() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);

        vm.prank(manager);
        vm.expectRevert("User already registered");
        xpGemsContract.registerUser(user1, 0);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        xpGemsContract.registerUser(user1, 100);
    }

    function test_RegistersUserWithInitialGems() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);
        assertEq(xpGemsContract.gemsOf(user1), 100);
    }

    function test_IncrementsTotalRegisteredUsers() public {
        uint256 before = xpGemsContract.totalRegisteredUsers();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
        assertEq(xpGemsContract.totalRegisteredUsers(), before + 1);
    }

    function test_RecordsRegistrationTransaction() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
        assertEq(xpGemsContract.transactionCount(user1), 1);
    }

    function test_EmitsUserRegisteredEvent() public {
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(user1, 100, 0, block.timestamp, true);
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);
    }
}

contract LearnwayXPGemsTest_UpdateUserGemsXpAndStreak is BaseTest {
    event UserGemsUpdated(address indexed user, uint256 oldGems, uint256 newGems, uint256 lastUpdated, bool status);
    event UserXpUpdated(address indexed user, uint256 oldXp, uint256 newXp, uint256 lastUpdated, bool status);
    event UserStreakUpdated(address indexed user, uint256 oldStreak, uint256 newStreak, uint256 lastUpdated, bool status);

    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdminOrManager");
        xpGemsContract.updateUserGemsXpAndStreak(user1, 100, 50, 5);
    }

    function test_RevertWhen_UserNotRegistered() public {
        vm.prank(manager);
        vm.expectRevert("User not registered");
        xpGemsContract.updateUserGemsXpAndStreak(user2, 100, 50, 5);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        xpGemsContract.updateUserGemsXpAndStreak(user1, 100, 50, 5);
    }

    function test_UpdatesGemsAndXp() public {
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 500, 100, 0);
        assertEq(xpGemsContract.gemsOf(user1), 500);
        assertEq(xpGemsContract.xpOf(user1), 100);
    }

    function test_UpdatesLongestStreakWhenNewStreakIsHigher() public {
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 0, 0, 10);
        assertEq(xpGemsContract.streakOf(user1), 10);
    }

    function test_DoesNotUpdateLongestStreakWhenNewStreakIsLower() public {
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 0, 0, 10);

        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 0, 0, 5);

        assertEq(xpGemsContract.streakOf(user1), 10);
    }

    function test_EmitsUserGemsUpdatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit UserGemsUpdated(user1, 0, 500, block.timestamp, true);
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 500, 0, 0);
    }

    function test_EmitsUserXpUpdatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit UserXpUpdated(user1, 0, 100, block.timestamp, true);
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 0, 100, 0);
    }

    function test_EmitsUserStreakUpdatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit UserStreakUpdated(user1, 0, 10, block.timestamp, true);
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 0, 0, 10);
    }
}

contract LearnwayXPGemsTest_RecordTransaction is BaseTest {
    event TransactionRecorded(
        address indexed user,
        uint256 indexed txIndex,
        LearnwayXPGemsContract.TransactionType txType,
        uint256 gems,
        uint256 xp,
        uint256 timestamp
    );

    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdminOrManager");
        xpGemsContract.recordTransaction(user1, 50, 10, badges, LearnwayXPGemsContract.TransactionType.Lesson, "test");
    }

    function test_RevertWhen_UserNotRegistered() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        vm.expectRevert("User not registered");
        xpGemsContract.recordTransaction(user2, 50, 10, badges, LearnwayXPGemsContract.TransactionType.Lesson, "test");
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();

        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        xpGemsContract.recordTransaction(user1, 50, 10, badges, LearnwayXPGemsContract.TransactionType.Lesson, "test");
    }

    function test_RecordsTransactionForUser() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 50, 10, badges, LearnwayXPGemsContract.TransactionType.Lesson, "test");

        LearnwayXPGemsContract.Transaction memory tx = xpGemsContract.getUserTransaction(user1, 1);
        assertEq(tx.gems, 50);
        assertEq(tx.xp, 10);
    }

    function test_IncrementsUserTransactionCount() public {
        uint256 before = xpGemsContract.transactionCount(user1);
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "test");
        assertEq(xpGemsContract.transactionCount(user1), before + 1);
    }

    function test_IncrementsGlobalTransactionCountByType() public {
        uint256 before = xpGemsContract.totalLessonTransactions();
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "test");
        assertEq(xpGemsContract.totalLessonTransactions(), before + 1);
    }

    function test_EmitsTransactionRecordedEvent() public {
        uint256 expectedIndex = xpGemsContract.transactionCount(user1);
        uint256[] memory badges = new uint256[](0);
        vm.expectEmit(true, true, false, true);
        emit TransactionRecorded(user1, expectedIndex, LearnwayXPGemsContract.TransactionType.Lesson, 50, 10, block.timestamp);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 50, 10, badges, LearnwayXPGemsContract.TransactionType.Lesson, "test");
    }
}

contract LearnwayXPGemsTest_BatchRecordTransactions is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function _buildBatch(uint256 size)
        internal
        pure
        returns (
            uint256[] memory gems,
            uint256[] memory xp,
            uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types,
            string[] memory descs
        )
    {
        gems = new uint256[](size);
        xp = new uint256[](size);
        badges = new uint256[][](size);
        types = new LearnwayXPGemsContract.TransactionType[](size);
        descs = new string[](size);
        for (uint256 i = 0; i < size; i++) {
            badges[i] = new uint256[](0);
            descs[i] = "t";
        }
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        (uint256[] memory gems, uint256[] memory xp, uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types, string[] memory descs) = _buildBatch(1);
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdminOrManager");
        xpGemsContract.batchRecordTransactions(user1, gems, xp, badges, types, descs);
    }

    function test_RevertWhen_UserNotRegistered() public {
        (uint256[] memory gems, uint256[] memory xp, uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types, string[] memory descs) = _buildBatch(1);
        vm.prank(manager);
        vm.expectRevert("User not registered");
        xpGemsContract.batchRecordTransactions(user2, gems, xp, badges, types, descs);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        uint256[] memory gems = new uint256[](2);
        uint256[] memory xp = new uint256[](1);
        uint256[][] memory badges = new uint256[][](2);
        badges[0] = new uint256[](0); badges[1] = new uint256[](0);
        LearnwayXPGemsContract.TransactionType[] memory types = new LearnwayXPGemsContract.TransactionType[](2);
        string[] memory descs = new string[](2);
        descs[0] = "a"; descs[1] = "b";

        vm.prank(manager);
        vm.expectRevert("Arrays length mismatch");
        xpGemsContract.batchRecordTransactions(user1, gems, xp, badges, types, descs);
    }

    function test_RevertWhen_ArraysAreEmpty() public {
        (uint256[] memory gems, uint256[] memory xp, uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types, string[] memory descs) = _buildBatch(0);
        vm.prank(manager);
        vm.expectRevert("Empty arrays");
        xpGemsContract.batchRecordTransactions(user1, gems, xp, badges, types, descs);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        (uint256[] memory gems, uint256[] memory xp, uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types, string[] memory descs) = _buildBatch(101);
        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        xpGemsContract.batchRecordTransactions(user1, gems, xp, badges, types, descs);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();

        (uint256[] memory gems, uint256[] memory xp, uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types, string[] memory descs) = _buildBatch(1);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        xpGemsContract.batchRecordTransactions(user1, gems, xp, badges, types, descs);
    }

    function test_RecordsAllTransactionsInBatch() public {
        (uint256[] memory gems, uint256[] memory xp, uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types, string[] memory descs) = _buildBatch(2);
        gems[0] = 10; gems[1] = 20;

        uint256 before = xpGemsContract.transactionCount(user1);
        vm.prank(manager);
        xpGemsContract.batchRecordTransactions(user1, gems, xp, badges, types, descs);

        LearnwayXPGemsContract.Transaction memory last = xpGemsContract.getUserTransaction(user1, before + 1);
        assertEq(last.gems, 20);
        assertEq(xpGemsContract.transactionCount(user1), before + 2);
    }

    function test_IncrementsTransactionCountsForEachEntry() public {
        (uint256[] memory gems, uint256[] memory xp, uint256[][] memory badges,
            LearnwayXPGemsContract.TransactionType[] memory types, string[] memory descs) = _buildBatch(3);

        uint256 before = xpGemsContract.transactionCount(user1);
        vm.prank(manager);
        xpGemsContract.batchRecordTransactions(user1, gems, xp, badges, types, descs);
        assertEq(xpGemsContract.transactionCount(user1), before + 3);
    }
}

contract LearnwayXPGemsTest_BatchRegisterUsers is BaseTest {
    event BatchOperationCompleted(string operation, uint256 totalProcessed, uint256 successful, uint256 failed, bool status);

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        address[] memory users = new address[](1);
        uint256[] memory gems = new uint256[](1);
        users[0] = user1;

        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdminOrManager");
        xpGemsContract.batchRegisterUsers(users, gems);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](1);
        users[0] = user1; users[1] = user2;

        vm.prank(manager);
        vm.expectRevert("Arrays length mismatch");
        xpGemsContract.batchRegisterUsers(users, gems);
    }

    function test_RevertWhen_ArraysAreEmpty() public {
        address[] memory users = new address[](0);
        uint256[] memory gems = new uint256[](0);

        vm.prank(manager);
        vm.expectRevert("Empty arrays");
        xpGemsContract.batchRegisterUsers(users, gems);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        address[] memory users = new address[](101);
        uint256[] memory gems = new uint256[](101);

        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        xpGemsContract.batchRegisterUsers(users, gems);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();

        address[] memory users = new address[](1);
        uint256[] memory gems = new uint256[](1);
        users[0] = user1;

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        xpGemsContract.batchRegisterUsers(users, gems);
    }

    function test_RegistersAllValidUsers() public {
        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](2);
        users[0] = user1; users[1] = user2;
        gems[0] = 100; gems[1] = 200;

        vm.prank(manager);
        xpGemsContract.batchRegisterUsers(users, gems);

        assertTrue(xpGemsContract.isRegistered(user1));
        assertTrue(xpGemsContract.isRegistered(user2));
        assertEq(xpGemsContract.gemsOf(user1), 100);
        assertEq(xpGemsContract.gemsOf(user2), 200);
    }

    function test_SkipsAlreadyRegisteredUserWithoutReverting() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 50);

        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](2);
        users[0] = user1; users[1] = user2;
        gems[0] = 999; gems[1] = 100;

        vm.prank(manager);
        xpGemsContract.batchRegisterUsers(users, gems);

        assertEq(xpGemsContract.gemsOf(user1), 50);
        assertTrue(xpGemsContract.isRegistered(user2));
    }

    function test_PartialBatchCompletesRemainingEntries() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);

        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](2);
        users[0] = user1; users[1] = user2;
        gems[1] = 200;

        vm.prank(manager);
        xpGemsContract.batchRegisterUsers(users, gems);

        assertTrue(xpGemsContract.isRegistered(user2));
        assertEq(xpGemsContract.gemsOf(user2), 200);
    }

    function test_EmitsBatchOperationCompletedEvent() public {
        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](2);
        users[0] = user1; users[1] = user2;

        vm.expectEmit(false, false, false, true);
        emit BatchOperationCompleted("batchRegisterUsers", 2, 2, 0, true);
        vm.prank(manager);
        xpGemsContract.batchRegisterUsers(users, gems);
    }
}

contract LearnwayXPGemsTest_BatchUpdateGemsXpAndStreaks is BaseTest {
    event BatchOperationCompleted(string operation, uint256 totalProcessed, uint256 successful, uint256 failed, bool status);

    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_RevertWhen_CallerIsNotAdminOrManager() public {
        address[] memory users = new address[](1);
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](1);
        uint256[] memory streaks = new uint256[](1);
        users[0] = user1;

        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdminOrManager");
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);
    }

    function test_RevertWhen_ArraysLengthMismatch() public {
        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](2);
        uint256[] memory streaks = new uint256[](2);
        users[0] = user1; users[1] = user2;

        vm.prank(manager);
        vm.expectRevert("Users and gems arrays length mismatch");
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);
    }

    function test_RevertWhen_ArraysAreEmpty() public {
        address[] memory users = new address[](0);
        uint256[] memory gems = new uint256[](0);
        uint256[] memory xp = new uint256[](0);
        uint256[] memory streaks = new uint256[](0);

        vm.prank(manager);
        vm.expectRevert("Empty arrays");
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);
    }

    function test_RevertWhen_BatchSizeExceedsLimit() public {
        address[] memory users = new address[](101);
        uint256[] memory gems = new uint256[](101);
        uint256[] memory xp = new uint256[](101);
        uint256[] memory streaks = new uint256[](101);

        vm.prank(manager);
        vm.expectRevert("Batch size too large");
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);
    }

    function test_RevertWhen_ContractIsPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();

        address[] memory users = new address[](1);
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](1);
        uint256[] memory streaks = new uint256[](1);
        users[0] = user1;

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);
    }

    function test_UpdatesAllRegisteredUsers() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user2, 0);

        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](2);
        uint256[] memory xp = new uint256[](2);
        uint256[] memory streaks = new uint256[](2);
        users[0] = user1; users[1] = user2;
        gems[0] = 100; gems[1] = 200;
        xp[0] = 10; xp[1] = 20;

        vm.prank(manager);
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);

        assertEq(xpGemsContract.gemsOf(user1), 100);
        assertEq(xpGemsContract.gemsOf(user2), 200);
        assertEq(xpGemsContract.xpOf(user1), 10);
        assertEq(xpGemsContract.xpOf(user2), 20);
    }

    function test_SkipsUnregisteredUserWithoutReverting() public {
        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](2);
        uint256[] memory xp = new uint256[](2);
        uint256[] memory streaks = new uint256[](2);
        users[0] = user2; users[1] = user1;
        gems[0] = 999; gems[1] = 100;

        vm.prank(manager);
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);

        assertFalse(xpGemsContract.isRegistered(user2));
        assertEq(xpGemsContract.gemsOf(user1), 100);
    }

    function test_PartialBatchCompletesRemainingEntries() public {
        address[] memory users = new address[](2);
        uint256[] memory gems = new uint256[](2);
        uint256[] memory xp = new uint256[](2);
        uint256[] memory streaks = new uint256[](2);
        users[0] = user2; users[1] = user1;
        gems[1] = 500;

        vm.prank(manager);
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);

        assertEq(xpGemsContract.gemsOf(user1), 500);
    }

    function test_EmitsBatchOperationCompletedEvent() public {
        address[] memory users = new address[](1);
        uint256[] memory gems = new uint256[](1);
        uint256[] memory xp = new uint256[](1);
        uint256[] memory streaks = new uint256[](1);
        users[0] = user1;
        gems[0] = 100;

        vm.expectEmit(false, false, false, true);
        emit BatchOperationCompleted("batchUpdateGemsXpAndStreaks", 1, 1, 0, true);
        vm.prank(manager);
        xpGemsContract.batchUpdateGemsXpAndStreaks(users, gems, xp, streaks);
    }
}

contract LearnwayXPGemsTest_GemsOf is BaseTest {
    function test_ReturnsGemsForRegisteredUser() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);
        assertEq(xpGemsContract.gemsOf(user1), 100);
    }

    function test_ReturnsZeroForUnregisteredUser() public {
        assertEq(xpGemsContract.gemsOf(stranger), 0);
    }
}

contract LearnwayXPGemsTest_XpOf is BaseTest {
    function test_ReturnsXpForRegisteredUser() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 0, 50, 0);
        assertEq(xpGemsContract.xpOf(user1), 50);
    }

    function test_ReturnsZeroForUnregisteredUser() public {
        assertEq(xpGemsContract.xpOf(stranger), 0);
    }
}

contract LearnwayXPGemsTest_StreakOf is BaseTest {
    function test_ReturnsStreakForRegisteredUser() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
        vm.prank(manager);
        xpGemsContract.updateUserGemsXpAndStreak(user1, 0, 0, 7);
        assertEq(xpGemsContract.streakOf(user1), 7);
    }

    function test_ReturnsZeroForUnregisteredUser() public {
        assertEq(xpGemsContract.streakOf(stranger), 0);
    }
}

contract LearnwayXPGemsTest_IsRegistered is BaseTest {
    function test_ReturnsTrueForRegisteredUser() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
        assertTrue(xpGemsContract.isRegistered(user1));
    }

    function test_ReturnsFalseForUnregisteredUser() public {
        assertFalse(xpGemsContract.isRegistered(stranger));
    }
}

contract LearnwayXPGemsTest_GetUserData is BaseTest {
    function test_ReturnsFullUserDataForRegisteredUser() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);

        LearnwayXPGemsContract.UserData memory data = xpGemsContract.getUserData(user1);
        assertEq(data.user, user1);
        assertEq(data.gems, 100);
        assertEq(data.xp, 0);
        assertTrue(data.createdAt > 0);
    }

    function test_ReturnsEmptyStructForUnregisteredUser() public {
        LearnwayXPGemsContract.UserData memory data = xpGemsContract.getUserData(stranger);
        assertEq(data.user, address(0));
        assertEq(data.gems, 0);
    }
}

contract LearnwayXPGemsTest_GetUserInfo is BaseTest {
    function test_ReturnsAllUserFieldsForRegisteredUser() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);

        (uint256 gems, uint256 xp, uint256 streak, bool registered, uint256 createdAt,) =
            xpGemsContract.getUserInfo(user1);

        assertEq(gems, 100);
        assertEq(xp, 0);
        assertEq(streak, 0);
        assertTrue(registered);
        assertTrue(createdAt > 0);
    }

    function test_ReturnsRegisteredFalseForUnregisteredUser() public {
        (,,, bool registered,,) = xpGemsContract.getUserInfo(stranger);
        assertFalse(registered);
    }
}

contract LearnwayXPGemsTest_GetUserTransactions is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_ReturnsEmptyArrayWhenNoTransactions() public {
        LearnwayXPGemsContract.Transaction[] memory txs = xpGemsContract.getUserTransactions(stranger);
        assertEq(txs.length, 0);
    }

    function test_ReturnsAllRecordedTransactions() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "t");

        LearnwayXPGemsContract.Transaction[] memory txs = xpGemsContract.getUserTransactions(user1);
        assertEq(txs.length, 2);
    }
}

contract LearnwayXPGemsTest_GetUserTransaction is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_RevertWhen_IndexOutOfBounds() public {
        vm.expectRevert("Transaction index out of bounds");
        xpGemsContract.getUserTransaction(user1, 1);
    }

    function test_ReturnsTransactionAtIndex() public {
        LearnwayXPGemsContract.Transaction memory tx = xpGemsContract.getUserTransaction(user1, 0);
        assertEq(tx.walletAddress, user1);
        assertEq(uint256(tx.txType), uint256(LearnwayXPGemsContract.TransactionType.RegisterUser));
    }
}

contract LearnwayXPGemsTest_GetUserTransactionsByType is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_ReturnsOnlyTransactionsOfSpecifiedType() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "t");

        LearnwayXPGemsContract.Transaction[] memory txs =
            xpGemsContract.getUserTransactionsByType(user1, LearnwayXPGemsContract.TransactionType.Lesson);
        assertEq(txs.length, 1);
        assertEq(uint256(txs[0].txType), uint256(LearnwayXPGemsContract.TransactionType.Lesson));
    }

    function test_ReturnsEmptyArrayWhenNoMatchingTransactions() public {
        LearnwayXPGemsContract.Transaction[] memory txs =
            xpGemsContract.getUserTransactionsByType(user1, LearnwayXPGemsContract.TransactionType.Battle);
        assertEq(txs.length, 0);
    }
}

contract LearnwayXPGemsTest_GetUserRecentTransactions is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_ReturnsLastNTransactions() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 10, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "a");
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 20, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "b");

        LearnwayXPGemsContract.Transaction[] memory txs = xpGemsContract.getUserRecentTransactions(user1, 2);
        assertEq(txs.length, 2);
        assertEq(txs[1].gems, 20);
    }

    function test_ReturnsAllTransactionsWhenCountExceedsTotal() public {
        LearnwayXPGemsContract.Transaction[] memory txs = xpGemsContract.getUserRecentTransactions(user1, 100);
        assertEq(txs.length, 1);
    }

    function test_ReturnsEmptyArrayWhenNoTransactions() public {
        LearnwayXPGemsContract.Transaction[] memory txs = xpGemsContract.getUserRecentTransactions(stranger, 5);
        assertEq(txs.length, 0);
    }
}

contract LearnwayXPGemsTest_GetMultipleGems is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);
        vm.prank(manager);
        xpGemsContract.registerUser(user2, 200);
    }

    function test_ReturnsGemsForMultipleUsers() public {
        address[] memory users = new address[](2);
        users[0] = user1; users[1] = user2;

        uint256[] memory gems = xpGemsContract.getMultipleGems(users);
        assertEq(gems[0], 100);
        assertEq(gems[1], 200);
    }

    function test_ReturnsZeroForUnregisteredUsersInBatch() public {
        address[] memory users = new address[](2);
        users[0] = user1; users[1] = stranger;

        uint256[] memory gems = xpGemsContract.getMultipleGems(users);
        assertEq(gems[0], 100);
        assertEq(gems[1], 0);
    }
}

contract LearnwayXPGemsTest_GetMultipleUsersInfo is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);
        vm.prank(manager);
        xpGemsContract.registerUser(user2, 200);
    }

    function test_ReturnsCorrectDataForAllUsersInBatch() public {
        address[] memory users = new address[](2);
        users[0] = user1; users[1] = user2;

        (uint256[] memory gems,,, bool[] memory registered,,) = xpGemsContract.getMultipleUsersInfo(users);

        assertEq(gems[0], 100);
        assertEq(gems[1], 200);
        assertTrue(registered[0]);
        assertTrue(registered[1]);
    }
}

contract LearnwayXPGemsTest_GetTotalTransactionsCountByType is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_ReturnsCorrectCountForEachTransactionType() public {
        assertEq(xpGemsContract.getTotalTransactionsCountByType(LearnwayXPGemsContract.TransactionType.RegisterUser), 1);
        assertEq(xpGemsContract.getTotalTransactionsCountByType(LearnwayXPGemsContract.TransactionType.Lesson), 0);
    }

    function test_CountIncrementsAfterRecordingTransaction() public {
        uint256 before = xpGemsContract.getTotalTransactionsCountByType(LearnwayXPGemsContract.TransactionType.Lesson);
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "t");
        assertEq(xpGemsContract.getTotalTransactionsCountByType(LearnwayXPGemsContract.TransactionType.Lesson), before + 1);
    }
}

contract LearnwayXPGemsTest_GetUserTransactionsCountByType is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_ReturnsCorrectCountForUserAndType() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "t");
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "t");

        assertEq(xpGemsContract.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.Lesson), 2);
    }

    function test_ReturnsZeroForTypeWithNoTransactions() public {
        assertEq(xpGemsContract.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.Battle), 0);
    }
}

contract LearnwayXPGemsTest_GetAllTransactionTypeCounts is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 0);
    }

    function test_ReturnsCountsForAllTypes() public {
        (uint256 lesson, uint256 quiz, uint256 reg, uint256 kyc, uint256 battle, uint256 contest, uint256 transfer, uint256 deposit) =
            xpGemsContract.getAllTransactionTypeCounts();

        assertEq(reg, 1);
        assertEq(lesson, 0);
        assertEq(quiz, 0);
        assertEq(kyc, 0);
        assertEq(battle, 0);
        assertEq(contest, 0);
        assertEq(transfer, 0);
        assertEq(deposit, 0);
    }

    function test_CountsReflectAllRecordedTransactions() public {
        uint256[] memory badges = new uint256[](0);
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.Lesson, "t");
        vm.prank(manager);
        xpGemsContract.recordTransaction(user1, 0, 0, badges, LearnwayXPGemsContract.TransactionType.DailyQuiz, "t");

        (uint256 lesson, uint256 quiz,,,,,, ) = xpGemsContract.getAllTransactionTypeCounts();
        assertEq(lesson, 1);
        assertEq(quiz, 1);
    }
}

contract LearnwayXPGemsTest_Pause is BaseTest {
    event Paused(address account);

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        xpGemsContract.pause();
    }

    function test_RevertWhen_AlreadyPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        xpGemsContract.pause();
    }

    function test_ContractIsPaused() public {
        vm.prank(admin);
        xpGemsContract.pause();
        assertTrue(xpGemsContract.paused());
    }

    function test_EmitsPausedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Paused(admin);
        vm.prank(admin);
        xpGemsContract.pause();
    }
}

contract LearnwayXPGemsTest_Unpause is BaseTest {
    event Unpaused(address account);

    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        xpGemsContract.pause();
    }

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        xpGemsContract.unpause();
    }

    function test_RevertWhen_NotPaused() public {
        vm.prank(admin);
        xpGemsContract.unpause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        xpGemsContract.unpause();
    }

    function test_ContractIsUnpaused() public {
        vm.prank(admin);
        xpGemsContract.unpause();
        assertFalse(xpGemsContract.paused());
    }

    function test_EmitsUnpausedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Unpaused(admin);
        vm.prank(admin);
        xpGemsContract.unpause();
    }
}

contract LearnwayXPGemsTest_Version is BaseTest {
    function test_ReturnsCurrentVersion() public {
        assertEq(xpGemsContract.version(), "1.0.0");
    }
}

contract LearnwayXPGemsTest_AuthorizeUpgrade is BaseTest {
    event Upgraded(address indexed implementation);

    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function test_RevertWhen_CallerIsNotAdmin() public {
        LearnwayXPGemsContract newImpl = new LearnwayXPGemsContract();
        vm.prank(stranger);
        vm.expectRevert("Not AuthorizedAdmin");
        xpGemsContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_ImplementationAddressChanges() public {
        address implBefore = address(uint160(uint256(vm.load(address(xpGemsContract), IMPL_SLOT))));

        LearnwayXPGemsContract newImpl = new LearnwayXPGemsContract();
        vm.prank(admin);
        xpGemsContract.upgradeToAndCall(address(newImpl), "");

        address implAfter = address(uint160(uint256(vm.load(address(xpGemsContract), IMPL_SLOT))));
        assertNotEq(implBefore, implAfter);
        assertEq(implAfter, address(newImpl));
    }

    function test_EmitsUpgradedEvent() public {
        LearnwayXPGemsContract newImpl = new LearnwayXPGemsContract();
        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(newImpl));
        vm.prank(admin);
        xpGemsContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_StorageLayoutPreserved() public {
        vm.prank(manager);
        xpGemsContract.registerUser(user1, 100);

        LearnwayXPGemsContract newImpl = new LearnwayXPGemsContract();
        vm.prank(admin);
        xpGemsContract.upgradeToAndCall(address(newImpl), "");

        assertTrue(xpGemsContract.isRegistered(user1));
        assertEq(xpGemsContract.gemsOf(user1), 100);
        assertEq(address(xpGemsContract.learnWayAdmin()), address(adminContract));
    }
}
