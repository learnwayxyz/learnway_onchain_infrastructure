// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interface/ILearnWayAdmin.sol";
import "./Errors.sol";

// Updated interface for LearnwayXPGemsContract (without lessons, with transactions)
interface ILearnwayXPGemsContract {
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

    struct Transaction {
        address walletAddress;
        uint256 gems;
        uint256 xp;
        uint256[] badgesList;
        TransactionType txType;
        uint256 timestamp;
        string description;
    }

    function registerUser(address user, uint256 gems) external;
    function updateUserGemsXpAndStreak(address user, uint256 newGems, uint256 newXp, uint256 newStreak) external;
    function recordTransaction(
        address user,
        uint256 gems,
        uint256 xp,
        uint256[] calldata badgesList,
        TransactionType txType,
        string calldata description
    ) external;
    function batchRecordTransactions(
        address user,
        uint256[] calldata gemsAmounts,
        uint256[] calldata xpAmounts,
        uint256[][] calldata badgesLists,
        TransactionType[] calldata txTypes,
        string[] calldata descriptions
    ) external;
    function gemsOf(address user) external view returns (uint256);
    function xpOf(address user) external view returns (uint256);
    function streakOf(address user) external view returns (uint256);
    function isRegistered(address user) external view returns (bool);
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
        );
    function getUserTransactions(address user) external view returns (Transaction[] memory);
    function getUserTransaction(address user, uint256 index) external view returns (Transaction memory);
    function getUserTransactionsByType(address user, TransactionType txType)
        external
        view
        returns (Transaction[] memory);
    function getUserRecentTransactions(address user, uint256 count) external view returns (Transaction[] memory);
    function transactionCount(address user) external view returns (uint256);
    function totalRegisteredUsers() external view returns (uint256);
}

interface ILearnWayBadge {
    function registerUser(address user, bool kycStatus) external;
    function mintBadge(address user, uint256 badgeId, BadgeTier tier) external;
    function upgradeBadge(address user, uint256 badgeId, BadgeTier newTier) external;
    function updateKycStatus(address user, bool kycStatus) external;
    function getUserBadges(address user) external view returns (uint256[] memory);
    function userHasBadge(address user, uint256 badgeId) external view returns (bool);
    function getUserBadgeInfo(address user, uint256 badgeId)
        external
        view
        returns (bool hasBadge, uint256 tokenId, BadgeTier tier, uint256 mintedAt, string memory status);
    function getEarlyBirdInfo(address user)
        external
        view
        returns (
            uint256 registrationOrder,
            uint256 kycOrder,
            bool isKycCompleted,
            bool hasEarlyBirdBadge,
            bool isEligible,
            uint256 currentTotalKycCompletions,
            uint256 currentMaxEarlyBirdSpots
        );
    function getUserBadgeData(address user)
        external
        view
        returns (
            bool kycCompleted,
            bool isRegistered,
            uint256 totalBadgesEarned,
            uint256 registrationOrder,
            uint256[] memory badgesList
        );

    struct UserInfo {
        bool isRegistered;
        bool kycVerified;
        uint256 registrationOrder;
        uint256 kycOrder;
        uint256 totalBadgesEarned;
    }

    function userInfo(address user) external view returns (UserInfo memory);

    enum BadgeTier {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM,
        DIAMOND
    }
}

contract LearnWayManager is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    /* =========================
       EVENTS
       ========================= */
    event UserRegistered(address indexed user, uint256 initialGems, bool kycStatus, uint256 timestamp);
    event UserDataUpdated(address indexed user, uint256 gems, uint256 xp, uint256 streak, uint256 timestamp);
    event TransactionRecorded(
        address indexed user,
        uint256 gems,
        uint256 xp,
        ILearnwayXPGemsContract.TransactionType txType,
        uint256 timestamp
    );
    event BadgeMinted(address indexed user, uint256 badgeId, uint256 timestamp);
    event BadgeUpgraded(address indexed user, uint256 badgeId, uint256 timestamp);
    event KycStatusUpdated(address indexed user, bool kycStatus, uint256 timestamp);
    event ContractsUpdated(address xpGemsContract, address badgesContract, uint256 timestamp);

    /* =========================
       CONTRACTS (external)
       ========================= */
    ILearnWayAdmin public adminContract;
    ILearnwayXPGemsContract public xpGemsContract;
    ILearnWayBadge public badgesContract;

    /* =========================
       MODIFIERS
       ========================= */
    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    modifier contractsSet() {
        require(address(xpGemsContract) != address(0) && address(badgesContract) != address(0), "Contracts not set");
        _;
    }

    modifier onlyAdmin() {
        require(adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender), "Not AuthorizedAdmin");
        _;
    }

    modifier onlyAdminOrManager() {
        require(
            adminContract.isAuthorized(keccak256("MANAGER_ROLE"), msg.sender)
                || adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender),
            "Not Authorized Manager"
        );
        _;
    }

    modifier userRegistered(address user) {
        require(xpGemsContract.isRegistered(user), "User not registered");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _adminContract) public initializer {
        require(_adminContract != address(0), "Invalid admin contract address");

        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        adminContract = ILearnWayAdmin(_adminContract);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /* =========================
       ADMIN / SETTERS
       ========================= */

    function setContracts(address _xpGemsContract, address _badgesContract) external onlyAdmin {
        require(_xpGemsContract != address(0) && _badgesContract != address(0), "Invalid contract addresses");

        xpGemsContract = ILearnwayXPGemsContract(_xpGemsContract);
        badgesContract = ILearnWayBadge(_badgesContract);

        emit ContractsUpdated(_xpGemsContract, _badgesContract, block.timestamp);
    }

    /* =========================
       USER DATA MANAGEMENT
       ========================= */

    function updateUserData(address user, uint256 newGems, uint256 newXp, uint256 newStreak)
        external
        onlyAdminOrManager
        validAddress(user)
        userRegistered(user)
        contractsSet
        nonReentrant
        whenNotPaused
    {
        xpGemsContract.updateUserGemsXpAndStreak(user, newGems, newXp, newStreak);
        emit UserDataUpdated(user, newGems, newXp, newStreak, block.timestamp);
    }

    /* =========================
       TRANSACTION MANAGEMENT
       ========================= */

    /**
     * @dev Batch record transactions for a user
     */
    function batchRecordTransactions(
        address user,
        uint256[] calldata gemsAmounts,
        uint256[] calldata xpAmounts,
        uint256[][] calldata badgesLists,
        ILearnwayXPGemsContract.TransactionType[] calldata txTypes,
        string[] calldata descriptions
    ) external onlyAdminOrManager validAddress(user) userRegistered(user) contractsSet nonReentrant whenNotPaused {
        xpGemsContract.batchRecordTransactions(user, gemsAmounts, xpAmounts, badgesLists, txTypes, descriptions);

        for (uint256 i = 0; i < gemsAmounts.length; i++) {
            emit TransactionRecorded(user, gemsAmounts[i], xpAmounts[i], txTypes[i], block.timestamp);
        }
    }

    function batchRecordTransactionsForUsers(
        address[] calldata users,
        uint256[][] calldata gemsAmounts,
        uint256[][] calldata xpAmounts,
        uint256[][][] calldata badgesLists,
        ILearnwayXPGemsContract.TransactionType[][] calldata txTypes,
        string[][] calldata descriptions
    ) external onlyAdminOrManager contractsSet nonReentrant whenNotPaused {
        require(users.length <= 100, "Batch size too large");
        require(users.length == gemsAmounts.length, "Array length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            if (!xpGemsContract.isRegistered(users[i])) continue;

            xpGemsContract.batchRecordTransactions(
                users[i], gemsAmounts[i], xpAmounts[i], badgesLists[i], txTypes[i], descriptions[i]
            );

            for (uint256 j = 0; j < gemsAmounts[i].length; j++) {
                emit TransactionRecorded(users[i], gemsAmounts[i][j], xpAmounts[i][j], txTypes[i][j], block.timestamp);
            }
        }
    }

    /* =========================
       BADGE MANAGEMENT
       ========================= */

    function upgradeBadgeForUser(address user, uint256 badgeId, ILearnWayBadge.BadgeTier newTier)
        external
        onlyAdminOrManager
        validAddress(user)
        userRegistered(user)
        contractsSet
        nonReentrant
        whenNotPaused
    {
        badgesContract.upgradeBadge(user, badgeId, newTier);
        emit BadgeUpgraded(user, badgeId, block.timestamp);
    }

    /* =========================
       BATCH OPERATIONS
       ========================= */

    function batchRegisterUsers(address[] calldata users, uint256[] calldata initialGems, bool[] calldata kycStatuses)
        external
        onlyAdminOrManager
        contractsSet
        nonReentrant
        whenNotPaused
    {
        require(users.length == initialGems.length && users.length == kycStatuses.length, "Array length mismatch");
        require(users.length <= 100, "Batch size too large");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            require(user != address(0), "Invalid address in batch");

            if (xpGemsContract.isRegistered(user)) continue;

            xpGemsContract.registerUser(user, initialGems[i]);
            badgesContract.registerUser(user, kycStatuses[i]);
        }
    }

    function batchUpdateUserData(
        address[] calldata users,
        uint256[] calldata newGems,
        uint256[] calldata newXp,
        uint256[] calldata newStreaks
    ) external onlyAdminOrManager contractsSet nonReentrant whenNotPaused {
        require(
            users.length == newGems.length && users.length == newXp.length && users.length == newStreaks.length,
            "Array length mismatch"
        );
        require(users.length <= 100, "Batch size too large");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            require(user != address(0), "Invalid address in batch");

            if (!xpGemsContract.isRegistered(user)) continue;

            xpGemsContract.updateUserGemsXpAndStreak(user, newGems[i], newXp[i], newStreaks[i]);
            emit UserDataUpdated(user, newGems[i], newXp[i], newStreaks[i], block.timestamp);
        }
    }

    function batchMintBadges(
        address[] calldata users,
        uint256[] calldata badgeIds,
        ILearnWayBadge.BadgeTier[] calldata tiers
    ) external onlyAdminOrManager contractsSet nonReentrant whenNotPaused {
        require(users.length == badgeIds.length && users.length == tiers.length, "Array length mismatch");
        require(users.length <= 50, "Batch size too large");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            require(user != address(0), "Invalid address in batch");

            if (!xpGemsContract.isRegistered(user)) continue;

            badgesContract.mintBadge(user, badgeIds[i], tiers[i]);
            emit BadgeMinted(user, badgeIds[i], block.timestamp);
        }
    }

    function batchUpdateKycStatus(address[] calldata users, bool[] calldata kycStatuses)
        external
        onlyAdminOrManager
        contractsSet
        nonReentrant
        whenNotPaused
    {
        require(users.length == kycStatuses.length, "Array length mismatch");
        require(users.length <= 100, "Batch size too large");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            require(user != address(0), "Invalid address in batch");

            if (!xpGemsContract.isRegistered(user)) continue;

            badgesContract.updateKycStatus(user, kycStatuses[i]);
            emit KycStatusUpdated(user, kycStatuses[i], block.timestamp);
        }
    }

    /* =========================
       VIEW FUNCTIONS
       ========================= */

    function getUserCompleteData(address user)
        external
        view
        returns (
            uint256 gems,
            uint256 xp,
            uint256 longestStreak,
            uint256 createdAt,
            uint256 lastUpdated,
            uint256[] memory badgesList,
            uint256 transactionCount,
            bool kycCompleted,
            uint256 totalBadgesEarned,
            uint256 registrationOrder
        )
    {
        if (address(xpGemsContract) != address(0)) {
            (gems, xp, longestStreak,, createdAt, lastUpdated) = xpGemsContract.getUserInfo(user);
            transactionCount = xpGemsContract.transactionCount(user);
        }

        if (address(badgesContract) != address(0)) {
            badgesList = badgesContract.getUserBadges(user);
            ILearnWayBadge.UserInfo memory userBadgeInfo = badgesContract.userInfo(user);
            kycCompleted = userBadgeInfo.kycVerified;
            totalBadgesEarned = userBadgeInfo.totalBadgesEarned;
            registrationOrder = userBadgeInfo.registrationOrder;
        }
    }

    function getUserGemsData(address user)
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
        if (address(xpGemsContract) != address(0)) {
            return xpGemsContract.getUserInfo(user);
        }
        // All return values automatically default to 0/false
    }

    function getUserBadgeData(address user)
        external
        view
        returns (
            bool kycCompleted,
            bool isRegistered,
            uint256 totalBadgesEarned,
            uint256 registrationOrder,
            uint256[] memory badgesList
        )
    {
        if (address(badgesContract) != address(0)) {
            return badgesContract.getUserBadgeData(user);
        } else {
            // Return empty array for badgesList when contract not set
            badgesList = new uint256[](0);
        }
    }

    function getUserBadgeInfo(address user, uint256 badgeId)
        external
        view
        returns (bool hasBadge, uint256 tokenId, ILearnWayBadge.BadgeTier tier, uint256 mintedAt, string memory status)
    {
        if (address(badgesContract) != address(0)) {
            return badgesContract.getUserBadgeInfo(user, badgeId);
        }
        // When contract not set, return empty string for status
        status = "";
        // Other values automatically default to: false, 0, BRONZE, 0
    }

    function getUserGems(address user) external view returns (uint256) {
        return address(xpGemsContract) != address(0) ? xpGemsContract.gemsOf(user) : 0;
    }

    function getUserXp(address user) external view returns (uint256) {
        return address(xpGemsContract) != address(0) ? xpGemsContract.xpOf(user) : 0;
    }

    function getUserStreak(address user) external view returns (uint256) {
        return address(xpGemsContract) != address(0) ? xpGemsContract.streakOf(user) : 0;
    }

    // Transaction view functions
    function getUserTransactions(address user) external view returns (ILearnwayXPGemsContract.Transaction[] memory) {
        return address(xpGemsContract) != address(0)
            ? xpGemsContract.getUserTransactions(user)
            : new ILearnwayXPGemsContract.Transaction[](0);
    }

    function getUserTransaction(address user, uint256 index)
        external
        view
        returns (ILearnwayXPGemsContract.Transaction memory)
    {
        require(address(xpGemsContract) != address(0), "Gems contract not set");
        return xpGemsContract.getUserTransaction(user, index);
    }

    function getUserTransactionsByType(address user, ILearnwayXPGemsContract.TransactionType txType)
        external
        view
        returns (ILearnwayXPGemsContract.Transaction[] memory)
    {
        return address(xpGemsContract) != address(0)
            ? xpGemsContract.getUserTransactionsByType(user, txType)
            : new ILearnwayXPGemsContract.Transaction[](0);
    }

    function getUserRecentTransactions(address user, uint256 count)
        external
        view
        returns (ILearnwayXPGemsContract.Transaction[] memory)
    {
        return address(xpGemsContract) != address(0)
            ? xpGemsContract.getUserRecentTransactions(user, count)
            : new ILearnwayXPGemsContract.Transaction[](0);
    }

    function getUserTransactionCount(address user) external view returns (uint256) {
        return address(xpGemsContract) != address(0) ? xpGemsContract.transactionCount(user) : 0;
    }

    function getUserBadges(address user) external view returns (uint256[] memory) {
        return address(badgesContract) != address(0) ? badgesContract.getUserBadges(user) : new uint256[](0);
    }

    function userHasBadge(address user, uint256 badgeId) external view returns (bool) {
        return address(badgesContract) != address(0) ? badgesContract.userHasBadge(user, badgeId) : false;
    }

    function isUserRegistered(address user) external view returns (bool) {
        return address(xpGemsContract) != address(0) ? xpGemsContract.isRegistered(user) : false;
    }

    function getEarlyBirdInfo(address user)
        external
        view
        returns (
            uint256 registrationOrder,
            uint256 kycOrder,
            bool isKycCompleted,
            bool hasEarlyBirdBadge,
            bool isEligible,
            uint256 currentTotalKycCompletions,
            uint256 currentMaxEarlyBirdSpots
        )
    {
        if (address(badgesContract) != address(0)) {
            return badgesContract.getEarlyBirdInfo(user);
        }
    }

    function getTotalUsers() external view returns (uint256) {
        return address(xpGemsContract) != address(0) ? xpGemsContract.totalRegisteredUsers() : 0;
    }

    function getContractAddresses() external view returns (address gemsAddr, address badgesAddr) {
        return (address(xpGemsContract), address(badgesContract));
    }

    /* =========================
       ADMIN FUNCTIONS
       ========================= */

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    function updateAdminContract(address newAdminContract) external onlyAdmin {
        require(newAdminContract != address(0), "Invalid admin contract address");
        adminContract = ILearnWayAdmin(newAdminContract);
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
