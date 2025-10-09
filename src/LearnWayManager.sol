// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interface/ILearnWayAdmin.sol";
import "./Errors.sol";

// Updated interfaces matching the new simplified contracts
interface ILearnwayXPGemsContract {
    function registerUser(address user, uint256 gems) external;
    function updateUserGemsXpAndStreak(address user, uint256 newGems, uint256 newXp, uint256 newStreak) external;
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
    function totalRegisteredUsers() external view returns (uint256);
}

interface ILearnWayBadge {
    function registerUser(address user, bool kycStatus) external;
    function mintBadge(address user, uint256 badgeId, BadgeTier tier) external;
    function batchMintBadges(address user, uint256[] calldata badgeIds, BadgeTier[] calldata tiers) external;
    function upgradeBadge(address user, uint256 badgeId, BadgeTier newTier) external;
    function updateKycStatus(address user, bool kycStatus) external;
    function getUserBadges(address user) external view returns (uint256[] memory);
    function userHasBadge(address user, uint256 badgeId) external view returns (bool);
    function getUserBadgeInfo(address user, uint256 badgeId)
        external
        view
        returns (bool hasBadge, uint256 tokenId, BadgeTier tier, uint256 mintedAt, string memory status);
    function isEligibleForEarlyBird(address user) external view returns (bool);
    function getEarlyBirdInfo(address user)
        external
        view
        returns (
            uint256 registrationOrder,
            bool isKycCompleted,
            bool hasEarlyBirdBadge,
            bool isEligible,
            uint256 currentEarlyBirdCount,
            uint256 currentMaxEarlyBirdSpots
        );

    // Access to userInfo struct
    struct UserInfo {
        bool isRegistered;
        bool kycVerified;
        uint256 registrationOrder;
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

contract LearnWayManager is ReentrancyGuard, Pausable {
    /* =========================
       EVENTS
       ========================= */
    event UserRegistered(address indexed user, uint256 initialGems, bool kycStatus, uint256 timestamp);
    event UserDataUpdated(address indexed user, uint256 gems, uint256 xp, uint256 streak, uint256 timestamp);
    event BadgeMinted(address indexed user, uint256 badgeId, uint256 timestamp);
    event BadgeUpgraded(address indexed user, uint256 badgeId, uint256 timestamp);
    event KycStatusUpdated(address indexed user, bool kycStatus, uint256 timestamp);
    event ContractsUpdated(address gemsContract, address badgesContract, uint256 timestamp);

    /* =========================
       CONTRACTS (external)
       ========================= */
    ILearnWayAdmin public adminContract;
    ILearnwayXPGemsContract public gemsContract;
    ILearnWayBadge public badgesContract;

    /* =========================
       MODIFIERS
       ========================= */
    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    modifier contractsSet() {
        require(address(gemsContract) != address(0) && address(badgesContract) != address(0), "Contracts not set");
        _;
    }

    modifier onlyAdmin() {
        adminContract.checkAdmin();
        _;
    }

    modifier onlyAdminOrManager() {
        adminContract.checkAdminOrManager();
        _;
    }

    modifier userRegistered(address user) {
        require(gemsContract.isRegistered(user), "User not registered");
        _;
    }

    /* =========================
       CONSTRUCTOR
       ========================= */
    constructor(address _adminContract) {
        require(_adminContract != address(0), "Invalid admin contract address");
        adminContract = ILearnWayAdmin(_adminContract);
    }

    /* =========================
       ADMIN / SETTERS
       ========================= */

    function setContracts(address _gemsContract, address _badgesContract) external onlyAdmin {
        require(_gemsContract != address(0) && _badgesContract != address(0), "Invalid contract addresses");

        gemsContract = ILearnwayXPGemsContract(_gemsContract);
        badgesContract = ILearnWayBadge(_badgesContract);

        emit ContractsUpdated(_gemsContract, _badgesContract, block.timestamp);
    }

    /* =========================
       USER REGISTRATION
       ========================= */

    function registerUser(address user, uint256 initialGems, bool kycStatus)
        external
        nonReentrant
        onlyAdminOrManager
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        require(!gemsContract.isRegistered(user), "User already registered");

        // Register in both contracts
        gemsContract.registerUser(user, initialGems);
        badgesContract.registerUser(user, kycStatus);

        emit UserRegistered(user, initialGems, kycStatus, block.timestamp);
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
        gemsContract.updateUserGemsXpAndStreak(user, newGems, newXp, newStreak);
        emit UserDataUpdated(user, newGems, newXp, newStreak, block.timestamp);
    }

    /* =========================
       BADGE MANAGEMENT
       ========================= */

    function mintBadgeForUser(address user, uint256 badgeId, ILearnWayBadge.BadgeTier tier)
        external
        onlyAdminOrManager
        validAddress(user)
        userRegistered(user)
        contractsSet
        nonReentrant
        whenNotPaused
    {
        badgesContract.mintBadge(user, badgeId, tier);
        emit BadgeMinted(user, badgeId, block.timestamp);
    }

    function batchMintBadgesForUser(
        address user,
        uint256[] calldata badgeIds,
        ILearnWayBadge.BadgeTier[] calldata tiers
    ) external onlyAdminOrManager validAddress(user) userRegistered(user) contractsSet nonReentrant whenNotPaused {
        badgesContract.batchMintBadges(user, badgeIds, tiers);

        // Emit events for each badge minted
        for (uint256 i = 0; i < badgeIds.length; i++) {
            emit BadgeMinted(user, badgeIds[i], block.timestamp);
        }
    }

    /**
     * @dev Batch mint multiple badges for multiple users
     * @param users Array of user addresses (max 100)
     * @param badgeIds Array of badge IDs to mint for each user
     * @param tiers Array of badge tiers for each user
     */
    function batchMintBadgesForMultipleUsers(
        address[] calldata users,
        uint256[][] calldata badgeIds,
        ILearnWayBadge.BadgeTier[][] calldata tiers
    ) external onlyAdminOrManager contractsSet nonReentrant whenNotPaused {
        require(users.length <= 100, "Batch size too large");
        require(users.length == badgeIds.length && users.length == tiers.length, "Array length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            require(user != address(0), "Invalid address in batch");

            // Skip unregistered users
            if (!gemsContract.isRegistered(user)) continue;

            // Ensure badgeIds and tiers arrays match for this user
            require(badgeIds[i].length == tiers[i].length, "Badge arrays length mismatch for user");

            // Skip if no badges to mint for this user
            if (badgeIds[i].length == 0) continue;

            // Mint badges for this user
            badgesContract.batchMintBadges(user, badgeIds[i], tiers[i]);

            // Emit events for each badge minted for this user
            for (uint256 j = 0; j < badgeIds[i].length; j++) {
                emit BadgeMinted(user, badgeIds[i][j], block.timestamp);
            }
        }
    }

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

    function updateUserKycStatus(address user, bool kycStatus)
        external
        onlyAdminOrManager
        validAddress(user)
        userRegistered(user)
        contractsSet
        nonReentrant
        whenNotPaused
    {
        badgesContract.updateKycStatus(user, kycStatus);
        emit KycStatusUpdated(user, kycStatus, block.timestamp);
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

            if (gemsContract.isRegistered(user)) continue; // Skip already registered users

            // Register in both contracts
            gemsContract.registerUser(user, initialGems[i]);
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

            if (!gemsContract.isRegistered(user)) continue; // Skip unregistered users

            gemsContract.updateUserGemsXpAndStreak(user, newGems[i], newXp[i], newStreaks[i]);
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

            if (!gemsContract.isRegistered(user)) continue; // Skip unregistered users

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

            if (!gemsContract.isRegistered(user)) continue; // Skip unregistered users

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
            bool kycCompleted,
            uint256 totalBadgesEarned,
            uint256 registrationOrder
        )
    {
        if (address(gemsContract) != address(0)) {
            (gems, xp, longestStreak,, createdAt, lastUpdated) = gemsContract.getUserInfo(user);
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
        if (address(gemsContract) != address(0)) {
            return gemsContract.getUserInfo(user);
        }
        return (0, 0, 0, false, 0, 0);
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
            ILearnWayBadge.UserInfo memory userBadgeInfo = badgesContract.userInfo(user);
            kycCompleted = userBadgeInfo.kycVerified;
            isRegistered = userBadgeInfo.isRegistered;
            totalBadgesEarned = userBadgeInfo.totalBadgesEarned;
            registrationOrder = userBadgeInfo.registrationOrder;
            badgesList = badgesContract.getUserBadges(user);
        }
        return (false, false, 0, 0, new uint256[](0));
    }

    function getUserBadgeInfo(address user, uint256 badgeId)
        external
        view
        returns (bool hasBadge, uint256 tokenId, ILearnWayBadge.BadgeTier tier, uint256 mintedAt, string memory status)
    {
        if (address(badgesContract) != address(0)) {
            return badgesContract.getUserBadgeInfo(user, badgeId);
        }
        return (false, 0, ILearnWayBadge.BadgeTier.BRONZE, 0, "");
    }

    function getUserGems(address user) external view returns (uint256) {
        return address(gemsContract) != address(0) ? gemsContract.gemsOf(user) : 0;
    }

    function getUserXp(address user) external view returns (uint256) {
        return address(gemsContract) != address(0) ? gemsContract.xpOf(user) : 0;
    }

    function getUserStreak(address user) external view returns (uint256) {
        return address(gemsContract) != address(0) ? gemsContract.streakOf(user) : 0;
    }

    function getUserBadges(address user) external view returns (uint256[] memory) {
        return address(badgesContract) != address(0) ? badgesContract.getUserBadges(user) : new uint256[](0);
    }

    function userHasBadge(address user, uint256 badgeId) external view returns (bool) {
        return address(badgesContract) != address(0) ? badgesContract.userHasBadge(user, badgeId) : false;
    }

    function isUserRegistered(address user) external view returns (bool) {
        return address(gemsContract) != address(0) ? gemsContract.isRegistered(user) : false;
    }

    function isEligibleForEarlyBird(address user) external view returns (bool) {
        return address(badgesContract) != address(0) ? badgesContract.isEligibleForEarlyBird(user) : false;
    }

    function getEarlyBirdInfo(address user)
        external
        view
        returns (
            uint256 registrationOrder,
            bool isKycCompleted,
            bool hasEarlyBirdBadge,
            bool isEligible,
            uint256 currentEarlyBirdCount,
            uint256 currentMaxEarlyBirdSpots
        )
    {
        if (address(badgesContract) != address(0)) {
            return badgesContract.getEarlyBirdInfo(user);
        }
        return (0, false, false, false, 0, 0);
    }

    function getTotalUsers() external view returns (uint256) {
        return address(gemsContract) != address(0) ? gemsContract.totalRegisteredUsers() : 0;
    }

    function getContractAddresses() external view returns (address gemsAddr, address badgesAddr) {
        return (address(gemsContract), address(badgesContract));
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
}
