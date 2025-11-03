// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interface/ILearnWayAdmin.sol";
import "./Errors.sol";

/**
 * @title LearnwayXPGemsContract
 * @dev Upgradeable smart contract for managing LearnWay XP, Gems, and Transactions
 * Admin has complete control - all operations override existing data, no calculations
 */
contract LearnwayXPGemsContract is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    // Transaction Types
    enum TransactionType {
        Lesson,
        DailyQuiz,
        RegisterUser,
        KYCVerified,
        Battle,
        Contest,
        Transfer,
        Deposit
    }

    // User data structure
    struct UserData {
        address user;
        uint256 gems;
        uint256 xp;
        uint256 longestStreak;
        uint256 createdAt;
        uint256 lastUpdated;
    }

    // Transaction structure
    struct Transaction {
        address walletAddress;
        uint256 gems;
        uint256 xp;
        uint256[] badgesList;
        TransactionType txType;
        uint256 timestamp;
        string description;
    }

    // Events
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
        TransactionType txType,
        uint256 gems,
        uint256 xp,
        uint256 timestamp
    );
    event BatchOperationCompleted(
        string operation, uint256 totalProcessed, uint256 successful, uint256 failed, bool status
    );

    // State variables
    ILearnWayAdmin public learnWayAdmin;
    mapping(address => UserData) public _userData;
    mapping(address => bool) public _isRegistered;
    mapping(address => Transaction[]) public _userTransactions;
    mapping(address => uint256) public transactionCount;
    uint256 public totalRegisteredUsers;

    // Global transaction type counters
    uint256 public totalLessonTransactions;
    uint256 public totalDailyQuizTransactions;
    uint256 public totalRegisterUserTransactions;
    uint256 public totalKYCVerifiedTransactions;
    uint256 public totalBattleTransactions;
    uint256 public totalContestTransactions;
    uint256 public totalTransferTransactions;
    uint256 public totalDepositTransactions;

    uint256[45] private _gap;
    // Modifiers

    modifier onlyAdmin() {
        require(learnWayAdmin.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender), "Not AuthorizedAdmin");
        _;
    }

    modifier onlyAdminOrManager() {
        require(
            learnWayAdmin.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender)
                || learnWayAdmin.isAuthorized(keccak256("MANAGER_ROLE"), msg.sender),
            "Not AuthorizedAdminOrManager"
        );
        _;
    }

    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    modifier userExists(address user) {
        require(_isRegistered[user], "User not registered");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _learnWayAdmin) public initializer {
        require(_learnWayAdmin != address(0), "Invalid admin contract address");

        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        learnWayAdmin = ILearnWayAdmin(_learnWayAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /**
     * @dev Register a new user with initial gems
     */
    function registerUser(address user, uint256 gems)
        external
        onlyAdminOrManager
        validAddress(user)
        nonReentrant
        whenNotPaused
    {
        require(!_isRegistered[user], "User already registered");
        uint256 currentTime = block.timestamp;

        _userData[user] = UserData({
            user: user,
            gems: gems,
            xp: 0,
            longestStreak: 0,
            createdAt: currentTime,
            lastUpdated: currentTime
        });

        _isRegistered[user] = true;
        totalRegisteredUsers++;
        emit UserRegistered(user, gems, 0, currentTime, true);

        // Record registration transaction
        _recordTransaction(user, gems, 0, new uint256[](0), TransactionType.RegisterUser, "User registration");
    }

    /**
     * @dev Update user gems, XP and streak
     */
    function updateUserGemsXpAndStreak(address user, uint256 newGems, uint256 newXp, uint256 newStreak)
        external
        onlyAdminOrManager
        validAddress(user)
        userExists(user)
        nonReentrant
        whenNotPaused
    {
        uint256 oldGems = _userData[user].gems;
        uint256 oldXp = _userData[user].xp;
        uint256 oldStreak = _userData[user].longestStreak;

        _userData[user].gems = newGems;
        _userData[user].xp = newXp;
        _userData[user].lastUpdated = block.timestamp;

        emit UserGemsUpdated(user, oldGems, newGems, block.timestamp, true);
        emit UserXpUpdated(user, oldXp, newXp, block.timestamp, true);

        if (newStreak > oldStreak) {
            _userData[user].longestStreak = newStreak;
            emit UserStreakUpdated(user, oldStreak, newStreak, block.timestamp, true);
        } else {
            emit UserStreakUpdated(user, oldStreak, newStreak, block.timestamp, false);
        }
    }

    /**
     * @dev Record a transaction for a user
     */
    function recordTransaction(
        address user,
        uint256 gems,
        uint256 xp,
        uint256[] calldata badgesList,
        TransactionType txType,
        string calldata description
    ) external onlyAdminOrManager validAddress(user) userExists(user) nonReentrant whenNotPaused {
        _recordTransaction(user, gems, xp, badgesList, txType, description);
    }

    /**
     * @dev Internal function to record transaction
     */
    function _recordTransaction(
        address user,
        uint256 gems,
        uint256 xp,
        uint256[] memory badgesList,
        TransactionType txType,
        string memory description
    ) internal {
        Transaction memory newTx = Transaction({
            walletAddress: user,
            gems: gems,
            xp: xp,
            badgesList: badgesList,
            txType: txType,
            timestamp: block.timestamp,
            description: description
        });

        _userTransactions[user].push(newTx);
        uint256 txIndex = transactionCount[user];
        transactionCount[user]++;

        // Increment global counter
        if (txType == TransactionType.Lesson) totalLessonTransactions++;
        else if (txType == TransactionType.DailyQuiz) totalDailyQuizTransactions++;
        else if (txType == TransactionType.RegisterUser) totalRegisterUserTransactions++;
        else if (txType == TransactionType.KYCVerified) totalKYCVerifiedTransactions++;
        else if (txType == TransactionType.Battle) totalBattleTransactions++;
        else if (txType == TransactionType.Contest) totalContestTransactions++;
        else if (txType == TransactionType.Transfer) totalTransferTransactions++;
        else if (txType == TransactionType.Deposit) totalDepositTransactions++;

        emit TransactionRecorded(user, txIndex, txType, gems, xp, block.timestamp);
    }

    /**
     * @dev Batch record transactions for a user
     */
    function batchRecordTransactions(
        address user,
        uint256[] calldata gemsAmounts,
        uint256[] calldata xpAmounts,
        uint256[][] calldata badgesLists,
        TransactionType[] calldata txTypes,
        string[] calldata descriptions
    ) external onlyAdminOrManager validAddress(user) userExists(user) nonReentrant whenNotPaused {
        require(gemsAmounts.length == xpAmounts.length, "Arrays length mismatch");
        require(gemsAmounts.length == badgesLists.length, "Arrays length mismatch");
        require(gemsAmounts.length == txTypes.length, "Arrays length mismatch");
        require(gemsAmounts.length == descriptions.length, "Arrays length mismatch");
        require(gemsAmounts.length > 0, "Empty arrays");
        require(gemsAmounts.length <= 100, "Batch size too large");

        for (uint256 i = 0; i < gemsAmounts.length; i++) {
            _recordTransaction(user, gemsAmounts[i], xpAmounts[i], badgesLists[i], txTypes[i], descriptions[i]);
        }
    }

    /**
     * @dev Batch register multiple users
     */
    function batchRegisterUsers(address[] calldata users, uint256[] calldata gemsAmounts)
        external
        onlyAdminOrManager
        nonReentrant
        whenNotPaused
    {
        require(users.length == gemsAmounts.length, "Arrays length mismatch");
        require(users.length > 0, "Empty arrays");
        require(users.length <= 100, "Batch size too large");

        uint256 currentTime = block.timestamp;
        uint256 successful = 0;
        uint256 failed = 0;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            if (user == address(0)) {
                emit UserRegistered(user, gemsAmounts[i], 0, currentTime, false);
                failed++;
                continue;
            }

            if (_isRegistered[user]) {
                emit UserAlreadyRegistered(user, gemsAmounts[i], 0, currentTime, false);
                failed++;
                continue;
            }

            _userData[user] = UserData({
                user: user,
                gems: gemsAmounts[i],
                xp: 0,
                longestStreak: 0,
                createdAt: currentTime,
                lastUpdated: currentTime
            });

            _isRegistered[user] = true;
            totalRegisteredUsers++;
            successful++;

            emit UserRegistered(user, gemsAmounts[i], 0, currentTime, true);

            // Record registration transaction
            _recordTransaction(
                user, gemsAmounts[i], 0, new uint256[](0), TransactionType.RegisterUser, "User registration"
            );
        }

        bool batchStatus = failed == 0;
        emit BatchOperationCompleted("batchRegisterUsers", users.length, successful, failed, batchStatus);
    }

    /**
     * @dev Batch update gems, XP and streaks for multiple users
     */
    function batchUpdateGemsXpAndStreaks(
        address[] calldata users,
        uint256[] calldata newGemsAmounts,
        uint256[] calldata newXpAmounts,
        uint256[] calldata newStreaks
    ) external onlyAdminOrManager nonReentrant whenNotPaused {
        require(users.length == newGemsAmounts.length, "Users and gems arrays length mismatch");
        require(users.length == newXpAmounts.length, "Users and XP arrays length mismatch");
        require(users.length == newStreaks.length, "Users and streaks arrays length mismatch");
        require(users.length > 0, "Empty arrays");
        require(users.length <= 100, "Batch size too large");

        uint256 currentTime = block.timestamp;
        uint256 successful = 0;
        uint256 failed = 0;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            if (user == address(0)) {
                emit UserGemsUpdated(user, 0, newGemsAmounts[i], currentTime, false);
                emit UserXpUpdated(user, 0, newXpAmounts[i], currentTime, false);
                emit UserStreakUpdated(user, 0, newStreaks[i], currentTime, false);
                failed++;
                continue;
            }

            if (!_isRegistered[user]) {
                emit UserGemsUpdated(user, 0, newGemsAmounts[i], currentTime, false);
                emit UserXpUpdated(user, 0, newXpAmounts[i], currentTime, false);
                emit UserStreakUpdated(user, 0, newStreaks[i], currentTime, false);
                failed++;
                continue;
            }

            uint256 oldGems = _userData[user].gems;
            uint256 oldXp = _userData[user].xp;
            uint256 oldStreak = _userData[user].longestStreak;

            _userData[user].gems = newGemsAmounts[i];
            _userData[user].xp = newXpAmounts[i];
            _userData[user].lastUpdated = currentTime;
            successful++;

            emit UserGemsUpdated(user, oldGems, newGemsAmounts[i], currentTime, true);
            emit UserXpUpdated(user, oldXp, newXpAmounts[i], currentTime, true);

            if (newStreaks[i] > oldStreak) {
                _userData[user].longestStreak = newStreaks[i];
                emit UserStreakUpdated(user, oldStreak, newStreaks[i], currentTime, true);
            } else {
                emit UserStreakUpdated(user, oldStreak, newStreaks[i], currentTime, false);
            }
        }

        bool batchStatus = failed == 0;
        emit BatchOperationCompleted("batchUpdateGemsXpAndStreaks", users.length, successful, failed, batchStatus);
    }

    // ===== VIEW FUNCTIONS =====

    function gemsOf(address user) external view returns (uint256) {
        return _userData[user].gems;
    }

    function xpOf(address user) external view returns (uint256) {
        return _userData[user].xp;
    }

    function streakOf(address user) external view returns (uint256) {
        return _userData[user].longestStreak;
    }

    function isRegistered(address user) external view returns (bool) {
        return _isRegistered[user];
    }

    function getCreatedAt(address user) external view returns (uint256) {
        return _userData[user].createdAt;
    }

    function getLastUpdated(address user) external view returns (uint256) {
        return _userData[user].lastUpdated;
    }

    function getUserData(address user) external view returns (UserData memory userData) {
        return _userData[user];
    }

    function getUserInfo(address user)
        external
        view
        returns (
            uint256 gems,
            uint256 xp,
            uint256 longestStreak,
            bool registered,
            uint256 createdAt,
            uint256 lastUpdated
        )
    {
        UserData memory data = _userData[user];
        return (data.gems, data.xp, data.longestStreak, _isRegistered[user], data.createdAt, data.lastUpdated);
    }

    /**
     * @dev Get user's transaction history
     */
    function getUserTransactions(address user) external view returns (Transaction[] memory) {
        return _userTransactions[user];
    }

    /**
     * @dev Get user's transaction by index
     */
    function getUserTransaction(address user, uint256 index) external view returns (Transaction memory) {
        require(index < _userTransactions[user].length, "Transaction index out of bounds");
        return _userTransactions[user][index];
    }

    /**
     * @dev Get user's transactions by type
     */
    function getUserTransactionsByType(address user, TransactionType txType)
        external
        view
        returns (Transaction[] memory)
    {
        Transaction[] memory allTxs = _userTransactions[user];
        uint256 count = 0;

        // Count matching transactions
        for (uint256 i = 0; i < allTxs.length; i++) {
            if (allTxs[i].txType == txType) {
                count++;
            }
        }

        // Create result array
        Transaction[] memory result = new Transaction[](count);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < allTxs.length; i++) {
            if (allTxs[i].txType == txType) {
                result[resultIndex] = allTxs[i];
                resultIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get user's recent transactions (last N transactions)
     */
    function getUserRecentTransactions(address user, uint256 count) external view returns (Transaction[] memory) {
        Transaction[] memory allTxs = _userTransactions[user];
        uint256 totalTxs = allTxs.length;

        if (totalTxs == 0) {
            return new Transaction[](0);
        }

        uint256 returnCount = count > totalTxs ? totalTxs : count;
        Transaction[] memory result = new Transaction[](returnCount);

        for (uint256 i = 0; i < returnCount; i++) {
            result[i] = allTxs[totalTxs - returnCount + i];
        }

        return result;
    }

    function getMultipleGems(address[] calldata users) external view returns (uint256[] memory gemsAmounts) {
        gemsAmounts = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            gemsAmounts[i] = _userData[users[i]].gems;
        }
    }

    function getMultipleXp(address[] calldata users) external view returns (uint256[] memory xpAmounts) {
        xpAmounts = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            xpAmounts[i] = _userData[users[i]].xp;
        }
    }

    function getMultipleStreaks(address[] calldata users) external view returns (uint256[] memory streaks) {
        streaks = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            streaks[i] = _userData[users[i]].longestStreak;
        }
    }

    function getMultipleUsersInfo(address[] calldata users)
        external
        view
        returns (
            uint256[] memory gemsAmounts,
            uint256[] memory xpAmounts,
            uint256[] memory streaks,
            bool[] memory registered,
            uint256[] memory createdAt,
            uint256[] memory lastUpdated
        )
    {
        gemsAmounts = new uint256[](users.length);
        xpAmounts = new uint256[](users.length);
        streaks = new uint256[](users.length);
        registered = new bool[](users.length);
        createdAt = new uint256[](users.length);
        lastUpdated = new uint256[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            UserData memory data = _userData[users[i]];
            gemsAmounts[i] = data.gems;
            xpAmounts[i] = data.xp;
            streaks[i] = data.longestStreak;
            registered[i] = _isRegistered[users[i]];
            createdAt[i] = data.createdAt;
            lastUpdated[i] = data.lastUpdated;
        }
    }

    function getMultipleUserData(address[] calldata users) external view returns (UserData[] memory usersData) {
        usersData = new UserData[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            usersData[i] = _userData[users[i]];
        }
    }
    // ===== NEW: COUNT-BY-TYPE VIEW FUNCTIONS =====

    /**
     * @dev Get the total number of transactions recorded globally for a given type.
     */
    function getTotalTransactionsCountByType(TransactionType txType) external view returns (uint256) {
        if (txType == TransactionType.Lesson) return totalLessonTransactions;
        else if (txType == TransactionType.DailyQuiz) return totalDailyQuizTransactions;
        else if (txType == TransactionType.RegisterUser) return totalRegisterUserTransactions;
        else if (txType == TransactionType.KYCVerified) return totalKYCVerifiedTransactions;
        else if (txType == TransactionType.Battle) return totalBattleTransactions;
        else if (txType == TransactionType.Contest) return totalContestTransactions;
        else if (txType == TransactionType.Transfer) return totalTransferTransactions;
        else if (txType == TransactionType.Deposit) return totalDepositTransactions;
        return 0;
    }

    /**
     * @dev Get the number of transactions for a specific user and type.
     */
    function getUserTransactionsCountByType(address user, TransactionType txType) external view returns (uint256) {
        Transaction[] storage allTxs = _userTransactions[user];
        uint256 count = 0;
        for (uint256 i = 0; i < allTxs.length; i++) {
            if (allTxs[i].txType == txType) {
                unchecked {
                    ++count;
                }
            }
        }
        return count;
    }

    /**
     * @dev Get all transaction type counts at once
     */
    function getAllTransactionTypeCounts()
        external
        view
        returns (
            uint256 lesson,
            uint256 dailyquiz,
            uint256 registeredUser,
            uint256 kycVerified,
            uint256 battle,
            uint256 contest,
            uint256 transfer,
            uint256 deposit
        )
    {
        return (
            totalLessonTransactions,
            totalDailyQuizTransactions,
            totalRegisterUserTransactions,
            totalKYCVerifiedTransactions,
            totalBattleTransactions,
            totalContestTransactions,
            totalTransferTransactions,
            totalDepositTransactions
        );
    }

    // ===== ADMIN FUNCTIONS =====

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    // ===== LEGACY COMPATIBILITY =====

    function balanceOf(address user) external view returns (uint256) {
        return _userData[user].gems;
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
