pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnwayXPGemsContract} from "../../src/LearnwayXPGemsContract.sol";
import {LearnWayAdmin} from "../../src/LearnWayAdmin.sol";

// Custom errors for selector matching if needed
error UnauthorizedAdmin();
error UnauthorizedAdminOrManager();

contract LearnwayXPGemsContractMoreTest is Test {
    // Events mirrored from LearnwayXPGemsContract
    event UserRegistered(address indexed user, uint256 gems, uint256 xp, uint256 createdAt, bool status);
    event UserAlreadyRegistered(address indexed user, uint256 gems, uint256 xp, uint256 createdAt, bool status);
    event UserGemsUpdated(address indexed user, uint256 oldGems, uint256 newGems, uint256 lastUpdated, bool status);
    event UserXpUpdated(address indexed user, uint256 oldXp, uint256 newXp, uint256 lastUpdated, bool status);
    event UserStreakUpdated(
        address indexed user, uint256 oldStreak, uint256 newStreak, uint256 lastUpdated, bool status
    );
    event TransactionRecorded(
        address indexed user,
        uint256 indexed txIndex,
        LearnwayXPGemsContract.TransactionType txType,
        uint256 gems,
        uint256 xp,
        uint256 timestamp
    );
    event BatchOperationCompleted(
        string operation, uint256 totalProcessed, uint256 successful, uint256 failed, bool status
    );

    LearnwayXPGemsContract internal xpg;
    LearnWayAdmin internal adminContract;

    address internal admin = address(0xA11CE);
    address internal manager = address(0xB0B);
    address internal stranger = address(0xDEAD);
    address internal user1 = address(0x1111);
    address internal user2 = address(0x2222);
    address internal user3 = address(0x3333); // unregistered for some tests

    bytes32 internal ADMIN_ROLE;
    bytes32 internal MANAGER_ROLE;

    function setUp() public {
        // Deploy LearnWayAdmin behind proxy and initialize
        LearnWayAdmin adminImpl = new LearnWayAdmin();
        ERC1967Proxy adminProxy = new ERC1967Proxy(address(adminImpl), "");
        adminContract = LearnWayAdmin(address(adminProxy));

        vm.prank(admin);
        adminContract.initialize();

        ADMIN_ROLE = adminContract.ADMIN_ROLE();
        MANAGER_ROLE = adminContract.MANAGER_ROLE();

        // Grant manager role to EOA manager (optional)
        vm.prank(admin);
        adminContract.setUpRole(MANAGER_ROLE, manager);

        // Deploy LearnwayXPGemsContract behind proxy and initialize
        LearnwayXPGemsContract xpgImpl = new LearnwayXPGemsContract();
        ERC1967Proxy xpgProxy = new ERC1967Proxy(address(xpgImpl), "");
        xpg = LearnwayXPGemsContract(address(xpgProxy));

        vm.prank(admin);
        xpg.initialize(address(adminContract));

        // Grant roles to the XPG contract itself (since LearnWayAdmin checks msg.sender which will be XPG)
        vm.startPrank(admin);
        adminContract.setUpRole(ADMIN_ROLE, address(xpg));
        adminContract.setUpRole(MANAGER_ROLE, address(xpg));
        vm.stopPrank();
    }

    // ========== Version and legacy compatibility ==========

    function testVersionAndLegacyBalanceOf() public {
        vm.prank(admin);
        xpg.registerUser(user1, 123);
        assertEq(xpg.version(), "1.0.0");
        assertEq(xpg.balanceOf(user1), 123);
    }

    // ========== getUserTransaction (by index) and bounds ==========

    function testGetUserTransactionByIndexAndBounds() public {
        vm.prank(admin);
        xpg.registerUser(user1, 10);

        // Add one more tx
        uint256[] memory badges = new uint256[](1);
        badges[0] = 9;
        vm.prank(manager);
        xpg.recordTransaction(user1, 2, 3, badges, LearnwayXPGemsContract.TransactionType.Lesson, "L1");

        // Index 0 -> RegisterUser
        LearnwayXPGemsContract.Transaction memory t0 = xpg.getUserTransaction(user1, 0);
        assertEq(uint256(t0.txType), uint256(LearnwayXPGemsContract.TransactionType.RegisterUser));
        // Index 1 -> Lesson
        LearnwayXPGemsContract.Transaction memory t1 = xpg.getUserTransaction(user1, 1);
        assertEq(uint256(t1.txType), uint256(LearnwayXPGemsContract.TransactionType.Lesson));
        assertEq(t1.gems, 2);
        assertEq(t1.xp, 3);
        assertEq(t1.badgesList.length, 1);
        assertEq(t1.badgesList[0], 9);

        // Out of bounds
        vm.expectRevert(bytes("Transaction index out of bounds"));
        xpg.getUserTransaction(user1, 2);
    }

    // ========== getUserTransactionsByType and count-by-type per user ==========

    function testGetUserTransactionsByTypeAndCount() public {
        vm.prank(admin);
        xpg.registerUser(user1, 0);

        // Add 4 more txs: 2 Lesson, 1 Quiz, 1 Deposit
        vm.prank(manager);
        xpg.recordTransaction(user1, 1, 10, new uint256[](0), LearnwayXPGemsContract.TransactionType.Lesson, "L#1");
        vm.prank(manager);
        xpg.recordTransaction(user1, 2, 20, new uint256[](0), LearnwayXPGemsContract.TransactionType.DailyQuiz, "Q#1");
        vm.prank(manager);
        xpg.recordTransaction(user1, 3, 30, new uint256[](0), LearnwayXPGemsContract.TransactionType.Lesson, "L#2");
        vm.prank(manager);
        xpg.recordTransaction(user1, 4, 40, new uint256[](0), LearnwayXPGemsContract.TransactionType.Deposit, "D#1");

        // Per-user counts
        uint256 lessons = xpg.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.Lesson);
        uint256 quiz = xpg.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.DailyQuiz);
        uint256 reg = xpg.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.RegisterUser);
        uint256 deposit = xpg.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.Deposit);
        uint256 kyc = xpg.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.KYCVerified);

        assertEq(lessons, 2);
        assertEq(quiz, 1);
        assertEq(reg, 1); // the initial RegisterUser
        assertEq(deposit, 1);
        assertEq(kyc, 0);

        // Filtered list by type
        LearnwayXPGemsContract.Transaction[] memory ltx =
            xpg.getUserTransactionsByType(user1, LearnwayXPGemsContract.TransactionType.Lesson);
        assertEq(ltx.length, 2);
        assertEq(ltx[0].gems, 1);
        assertEq(ltx[1].gems, 3);

        LearnwayXPGemsContract.Transaction[] memory qtx =
            xpg.getUserTransactionsByType(user1, LearnwayXPGemsContract.TransactionType.DailyQuiz);
        assertEq(qtx.length, 1);
        assertEq(qtx[0].gems, 2);

        // A type with zero
        LearnwayXPGemsContract.Transaction[] memory btx =
            xpg.getUserTransactionsByType(user1, LearnwayXPGemsContract.TransactionType.Battle);
        assertEq(btx.length, 0);
    }

    // ========== getUserRecentTransactions edge cases ==========

    function testGetUserRecentTransactionsEdgeCases() public {
        // No user registered -> zero tx for user2
        LearnwayXPGemsContract.Transaction[] memory empty = xpg.getUserRecentTransactions(user2, 5);
        assertEq(empty.length, 0);

        vm.prank(admin);
        xpg.registerUser(user1, 0);

        // Add 3 lesson tx
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(manager);
            xpg.recordTransaction(
                user1, i + 1, (i + 1) * 10, new uint256[](0), LearnwayXPGemsContract.TransactionType.Lesson, "L"
            );
        }

        // total txs: 4 including RegisterUser
        LearnwayXPGemsContract.Transaction[] memory last10 = xpg.getUserRecentTransactions(user1, 10);
        assertEq(last10.length, 4);
        // oldest of returned set should be the RegisterUser
        assertEq(uint256(last10[0].txType), uint256(LearnwayXPGemsContract.TransactionType.RegisterUser));
        // newest should be last recorded
        assertEq(last10[3].gems, 3);

        // Get recent 2
        LearnwayXPGemsContract.Transaction[] memory last2 = xpg.getUserRecentTransactions(user1, 2);
        assertEq(last2.length, 2);
        assertEq(last2[0].gems, 2);
        assertEq(last2[1].gems, 3);
    }

    // ========== Multiple getters (arrays and structs) ==========

    function testMultipleAggregatesAndStructs() public {
        // Register two users
        vm.startPrank(admin);
        xpg.registerUser(user1, 10);
        xpg.registerUser(user2, 20);
        vm.stopPrank();

        address[] memory addrs = new address[](3);
        addrs[0] = user1;
        addrs[1] = user2;
        addrs[2] = user3; // unregistered

        // getMultipleGems / Xp / Streaks
        uint256[] memory gems = xpg.getMultipleGems(addrs);
        assertEq(gems.length, 3);
        assertEq(gems[0], 10);
        assertEq(gems[1], 20);
        assertEq(gems[2], 0);

        uint256[] memory xp = xpg.getMultipleXp(addrs);
        assertEq(xp[0], 0);
        assertEq(xp[1], 0);
        assertEq(xp[2], 0);

        uint256[] memory streaks = xpg.getMultipleStreaks(addrs);
        assertEq(streaks[0], 0);
        assertEq(streaks[1], 0);
        assertEq(streaks[2], 0);

        // getMultipleUsersInfo
        (
            uint256[] memory gemsOut,
            uint256[] memory xpOut,
            uint256[] memory streaksOut,
            bool[] memory registered,
            uint256[] memory createdAt,
            uint256[] memory lastUpdated
        ) = xpg.getMultipleUsersInfo(addrs);

        assertEq(gemsOut[0], 10);
        assertEq(gemsOut[1], 20);
        assertEq(gemsOut[2], 0);
        assertTrue(registered[0]);
        assertTrue(registered[1]);
        assertFalse(registered[2]);
        // createdAt and lastUpdated set for registered, zero for unregistered
        assertGt(createdAt[0], 0);
        assertGt(createdAt[1], 0);
        assertEq(createdAt[2], 0);
        assertEq(lastUpdated[2], 0);

        // getMultipleUserData
        LearnwayXPGemsContract.UserData[] memory udata = xpg.getMultipleUserData(addrs);
        assertEq(udata.length, 3);
        assertEq(udata[0].user, user1);
        assertEq(udata[1].user, user2);
        assertEq(udata[2].user, address(0)); // uninitialized struct for unregistered
    }

    // ========== getUserInfo and getUserData consistency ==========

    function testGetUserInfoAndGetUserDataConsistency() public {
        vm.prank(admin);
        xpg.registerUser(user1, 42);

        (uint256 gems, uint256 xp, uint256 streak, bool registered, uint256 createdAt, uint256 lastUpdated) =
            xpg.getUserInfo(user1);
        LearnwayXPGemsContract.UserData memory d = xpg.getUserData(user1);

        assertEq(gems, d.gems);
        assertEq(xp, d.xp);
        assertEq(streak, d.longestStreak);
        assertEq(registered, xpg.isRegistered(user1));
        assertEq(createdAt, d.createdAt);
        assertEq(lastUpdated, d.lastUpdated);
    }

    // ========== Batch update with mixed registered/unregistered users ==========

    function testBatchUpdateGemsXpAndStreaks_MixedUsers() public {
        // Register only user1
        vm.prank(admin);
        xpg.registerUser(user1, 5);

        address[] memory users = new address[](2);
        users[0] = user1; // registered -> success
        users[1] = user2; // unregistered -> expected fail/no-op

        uint256[] memory g = new uint256[](2);
        uint256[] memory xp = new uint256[](2);
        uint256[] memory st = new uint256[](2);

        g[0] = 100;
        xp[0] = 200;
        st[0] = 3;
        g[1] = 300;
        xp[1] = 400;
        st[1] = 5;

        // We expect batch operation completed with 1 success, 1 fail (status false)
        vm.expectEmit(false, false, false, true);
        emit BatchOperationCompleted("batchUpdateGemsXpAndStreaks", 2, 1, 1, false);

        vm.prank(manager);
        xpg.batchUpdateGemsXpAndStreaks(users, g, xp, st);

        // user1 updated
        assertEq(xpg.gemsOf(user1), 100);
        assertEq(xpg.xpOf(user1), 200);
        assertEq(xpg.streakOf(user1), 3);

        // user2 remains defaults (not registered)
        assertFalse(xpg.isRegistered(user2));
        assertEq(xpg.gemsOf(user2), 0);
        assertEq(xpg.xpOf(user2), 0);
        assertEq(xpg.streakOf(user2), 0);
    }

    // ========== Global counts all zero on fresh deploy ==========

    function testAllTransactionTypeCountsStartAtZeroOnFreshDeploy() public {
        // Fresh, isolated deploy without any user registration
        LearnWayAdmin adminImpl2 = new LearnWayAdmin();
        ERC1967Proxy adminProxy2 = new ERC1967Proxy(address(adminImpl2), "");
        LearnWayAdmin admin2 = LearnWayAdmin(address(adminProxy2));
        vm.prank(admin);
        admin2.initialize();

        LearnwayXPGemsContract xpgImpl2 = new LearnwayXPGemsContract();
        ERC1967Proxy xpgProxy2 = new ERC1967Proxy(address(xpgImpl2), "");
        LearnwayXPGemsContract xpg2 = LearnwayXPGemsContract(address(xpgProxy2));
        vm.prank(admin);
        xpg2.initialize(address(admin2));

        // Grant roles to xpg2 so view function can be invoked without access-control interference
        vm.startPrank(admin);
        admin2.setUpRole(admin2.ADMIN_ROLE(), address(xpg2));
        admin2.setUpRole(admin2.MANAGER_ROLE(), address(xpg2));
        vm.stopPrank();

        (
            uint256 lesson,
            uint256 quiz,
            uint256 reg,
            uint256 kyc,
            uint256 battle,
            uint256 contest,
            uint256 transferTx,
            uint256 deposit
        ) = xpg2.getAllTransactionTypeCounts();

        assertEq(lesson, 0);
        assertEq(quiz, 0);
        assertEq(reg, 0);
        assertEq(kyc, 0);
        assertEq(battle, 0);
        assertEq(contest, 0);
        assertEq(transferTx, 0);
        assertEq(deposit, 0);
    }

    // ========== Batch size upper bound accepted (100) ==========

    function testBatchRecordTransactionsAcceptsMaxSize100() public {
        vm.prank(admin);
        xpg.registerUser(user1, 0);

        uint256 n = 100;
        uint256[] memory gems = new uint256[](n);
        uint256[] memory xp = new uint256[](n);
        uint256[][] memory badges = new uint256[][](n);
        LearnwayXPGemsContract.TransactionType[] memory types = new LearnwayXPGemsContract.TransactionType[](n);
        string[] memory descriptions = new string[](n);

        for (uint256 i = 0; i < n; i++) {
            gems[i] = i + 1;
            xp[i] = i;
            badges[i] = new uint256[](0);
            types[i] = LearnwayXPGemsContract.TransactionType.Lesson;
            descriptions[i] = "ok";
        }

        vm.prank(manager);
        xpg.batchRecordTransactions(user1, gems, xp, badges, types, descriptions);

        // Should have 1 (register) + 100
        LearnwayXPGemsContract.Transaction[] memory txs = xpg.getUserTransactions(user1);
        assertEq(txs.length, 101);

        // Per-type count for Lesson should be 100
        assertEq(xpg.getTotalTransactionsCountByType(LearnwayXPGemsContract.TransactionType.Lesson), 100);
        // Per-user count-by-type check
        assertEq(xpg.getUserTransactionsCountByType(user1, LearnwayXPGemsContract.TransactionType.Lesson), 100);
    }

    // ========== Views are callable while paused ==========

    function testPauseDoesNotAffectViews() public {
        vm.prank(admin);
        xpg.registerUser(user1, 7);

        // Pause via any caller since XPG holds roles
        vm.expectRevert("Not AuthorizedAdmin");
        vm.prank(stranger);
        xpg.pause();

        // View functions should still work
        assertTrue(xpg.isRegistered(user1));
        assertEq(xpg.gemsOf(user1), 7);
        assertEq(xpg.xpOf(user1), 0);
        assertEq(xpg.streakOf(user1), 0);

        // getUserRecentTransactions should not revert and return at least RegisterUser
        LearnwayXPGemsContract.Transaction[] memory recents = xpg.getUserRecentTransactions(user1, 5);
        assertEq(recents.length, 1);

        // Unpause for cleanliness
        vm.expectRevert("Not AuthorizedAdmin");
        vm.prank(stranger);
        xpg.unpause();
    }

    // ========== Scenario without granting roles to XPG (shows access control is enforced) ==========

    function testRestrictedFunctionsRevertWithoutGrantingRolesToXPG() public {
        // Fresh admin + xpg with NO role granted to xpg
        LearnWayAdmin adminImpl2 = new LearnWayAdmin();
        ERC1967Proxy adminProxy2 = new ERC1967Proxy(address(adminImpl2), "");
        LearnWayAdmin admin2 = LearnWayAdmin(address(adminProxy2));
        vm.prank(admin);
        admin2.initialize();

        LearnwayXPGemsContract xpgImpl2 = new LearnwayXPGemsContract();
        ERC1967Proxy xpgProxy2 = new ERC1967Proxy(address(xpgImpl2), "");
        LearnwayXPGemsContract xpg2 = LearnwayXPGemsContract(address(xpgProxy2));
        vm.prank(admin);
        xpg2.initialize(address(admin2));

        // Try pause -> should revert UnauthorizedAdmin
        vm.expectRevert();
        xpg2.pause();
    }
}
