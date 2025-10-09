// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interface/ILearnWayAdmin.sol";
import "./Errors.sol";

/**
 * @title LearnwayXPGemsContract
 * @dev Ultra-simplified smart contract for managing LearnWay XpGems contract
 * Admin has complete control - all operations override existing data, no calculations
 */
contract LearnwayXPGemsContract is ReentrancyGuard, Pausable {
    // User data structure
    struct UserData {
        address user;
        uint256 gems;
        uint256 xp; // Experience points
        uint256 longestStreak; // Longest streak achieved by user
        uint256 createdAt; // Block timestamp when user was registered
        uint256 lastUpdated; // Block timestamp of last update
    }

    // Events with status
    event UserRegistered(address indexed user, uint256 gems, uint256 xp, uint256 createdAt, bool status);
    event UserAlreadyRegistered(address indexed user, uint256 gems, uint256 xp, uint256 createdAt, bool status);
    event UserGemsUpdated(address indexed user, uint256 oldGems, uint256 newGems, uint256 lastUpdated, bool status);
    event UserXpUpdated(address indexed user, uint256 oldXp, uint256 newXp, uint256 lastUpdated, bool status);
    event UserStreakUpdated(
        address indexed user, uint256 oldStreak, uint256 newStreak, uint256 lastUpdated, bool status
    );

    // Batch operation events
    event BatchOperationCompleted(
        string operation, uint256 totalProcessed, uint256 successful, uint256 failed, bool status
    );

    // LearnWayAdmin contract instance
    ILearnWayAdmin public immutable learnWayAdmin;

    // State variables
    mapping(address => UserData) private _userData;
    mapping(address => bool) private _isRegistered;

    uint256 public totalRegisteredUsers;

    // Modifiers
    modifier onlyAdmin() {
        learnWayAdmin.checkAdmin();
        _;
    }

    modifier onlyAdminOrManager() {
        learnWayAdmin.checkAdminOrManager();
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

    constructor(address _learnWayAdmin) {
        require(_learnWayAdmin != address(0), "Invalid admin contract address");
        learnWayAdmin = ILearnWayAdmin(_learnWayAdmin);
    }

    /**
     * @dev Register a new user with initial gems
     * @param user Address of the new user
     * @param gems Initial gems amount to set
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
            xp: 0, // Default XP is zero
            longestStreak: 0, // Default streak is zero
            createdAt: currentTime,
            lastUpdated: currentTime
        });

        _isRegistered[user] = true;
        totalRegisteredUsers++;

        emit UserRegistered(user, gems, 0, currentTime, true);
    }

    /**
     * @dev Update user gems, XP and streak
     * @param user Address of the user
     * @param newGems New gems amount (overrides current gems)
     * @param newXp New XP amount (overrides current XP)
     * @param newStreak New streak value (only updates if higher)
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

        // Always update gems and XP
        _userData[user].gems = newGems;
        _userData[user].xp = newXp;
        _userData[user].lastUpdated = block.timestamp;

        emit UserGemsUpdated(user, oldGems, newGems, block.timestamp, true);
        emit UserXpUpdated(user, oldXp, newXp, block.timestamp, true);

        // Only update streak if new streak is higher
        if (newStreak > oldStreak) {
            _userData[user].longestStreak = newStreak;
            emit UserStreakUpdated(user, oldStreak, newStreak, block.timestamp, true);
        } else {
            // Emit event with false status if streak wasn't updated
            emit UserStreakUpdated(user, oldStreak, newStreak, block.timestamp, false);
        }
    }

    /**
     * @dev Batch register multiple users
     * @param users Array of user addresses
     * @param gemsAmounts Array of gems amounts
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

            // Check for invalid conditions and handle gracefully
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

            // Successful registration
            _userData[user] = UserData({
                user: user,
                gems: gemsAmounts[i],
                xp: 0, // Default XP is zero
                longestStreak: 0, // Default streak is zero
                createdAt: currentTime,
                lastUpdated: currentTime
            });

            _isRegistered[user] = true;
            totalRegisteredUsers++;
            successful++;

            emit UserRegistered(user, gemsAmounts[i], 0, currentTime, true);
        }

        // Emit batch completion event
        bool batchStatus = failed == 0;
        emit BatchOperationCompleted("batchRegisterUsers", users.length, successful, failed, batchStatus);
    }

    /**
     * @dev Batch update gems, XP and streaks for multiple users
     * @param users Array of user addresses
     * @param newGemsAmounts Array of new gems amounts
     * @param newXpAmounts Array of new XP amounts
     * @param newStreaks Array of new streak values
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

            // Check for invalid conditions and handle gracefully
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

            // Successful update
            uint256 oldGems = _userData[user].gems;
            uint256 oldXp = _userData[user].xp;
            uint256 oldStreak = _userData[user].longestStreak;

            // Always update gems and XP
            _userData[user].gems = newGemsAmounts[i];
            _userData[user].xp = newXpAmounts[i];
            _userData[user].lastUpdated = currentTime;
            successful++;

            emit UserGemsUpdated(user, oldGems, newGemsAmounts[i], currentTime, true);
            emit UserXpUpdated(user, oldXp, newXpAmounts[i], currentTime, true);

            // Only update streak if new streak is higher
            if (newStreaks[i] > oldStreak) {
                _userData[user].longestStreak = newStreaks[i];
                emit UserStreakUpdated(user, oldStreak, newStreaks[i], currentTime, true);
            } else {
                // Emit event with false status if streak wasn't updated
                emit UserStreakUpdated(user, oldStreak, newStreaks[i], currentTime, false);
            }
        }

        // Emit batch completion event
        bool batchStatus = failed == 0;
        emit BatchOperationCompleted("batchUpdateGemsXpAndStreaks", users.length, successful, failed, batchStatus);
    }

    // ===== VIEW FUNCTIONS =====

    /**
     * @dev Get gems amount of a user
     * @param user Address of the user
     * @return Gems amount
     */
    function gemsOf(address user) external view returns (uint256) {
        return _userData[user].gems;
    }

    /**
     * @dev Get XP amount of a user
     * @param user Address of the user
     * @return XP amount
     */
    function xpOf(address user) external view returns (uint256) {
        return _userData[user].xp;
    }

    /**
     * @dev Get longest streak of a user
     * @param user Address of the user
     * @return Longest streak
     */
    function streakOf(address user) external view returns (uint256) {
        return _userData[user].longestStreak;
    }

    /**
     * @dev Check if user is registered
     * @param user Address of the user
     * @return Registration status
     */
    function isRegistered(address user) external view returns (bool) {
        return _isRegistered[user];
    }

    /**
     * @dev Get user's creation timestamp
     * @param user Address of the user
     * @return Creation timestamp
     */
    function getCreatedAt(address user) external view returns (uint256) {
        return _userData[user].createdAt;
    }

    /**
     * @dev Get user's last update timestamp
     * @param user Address of the user
     * @return Last update timestamp
     */
    function getLastUpdated(address user) external view returns (uint256) {
        return _userData[user].lastUpdated;
    }

    /**
     * @dev Get complete user data
     * @param user Address of the user
     * @return userData Complete UserData struct
     */
    function getUserData(address user) external view returns (UserData memory userData) {
        return _userData[user];
    }

    /**
     * @dev Get comprehensive user information
     * @param user Address of the user
     * @return gems Current gems amount
     * @return xp Current XP amount
     * @return longestStreak Longest streak achieved
     * @return registered Registration status
     * @return createdAt Creation timestamp
     * @return lastUpdated Last update timestamp
     */
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
     * @dev Get multiple users' gems amounts in one call
     * @param users Array of user addresses
     * @return gemsAmounts Array of corresponding gems amounts
     */
    function getMultipleGems(address[] calldata users) external view returns (uint256[] memory gemsAmounts) {
        gemsAmounts = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            gemsAmounts[i] = _userData[users[i]].gems;
        }
    }

    /**
     * @dev Get multiple users' XP amounts in one call
     * @param users Array of user addresses
     * @return xpAmounts Array of corresponding XP amounts
     */
    function getMultipleXp(address[] calldata users) external view returns (uint256[] memory xpAmounts) {
        xpAmounts = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            xpAmounts[i] = _userData[users[i]].xp;
        }
    }

    /**
     * @dev Get multiple users' longest streaks in one call
     * @param users Array of user addresses
     * @return streaks Array of corresponding longest streaks
     */
    function getMultipleStreaks(address[] calldata users) external view returns (uint256[] memory streaks) {
        streaks = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            streaks[i] = _userData[users[i]].longestStreak;
        }
    }

    /**
     * @dev Get multiple users' complete information in one call
     * @param users Array of user addresses
     * @return gemsAmounts Array of gems amounts
     * @return xpAmounts Array of XP amounts
     * @return streaks Array of longest streaks
     * @return registered Array of registration statuses
     * @return createdAt Array of creation timestamps
     * @return lastUpdated Array of last update timestamps
     */
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

    /**
     * @dev Get multiple users' complete UserData structs
     * @param users Array of user addresses
     * @return usersData Array of UserData structs
     */
    function getMultipleUserData(address[] calldata users) external view returns (UserData[] memory usersData) {
        usersData = new UserData[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            usersData[i] = _userData[users[i]];
        }
    }

    // ===== ADMIN FUNCTIONS =====

    /**
     * @dev Emergency function to pause the contract
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Emergency function to unpause the contract
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    // ===== LEGACY COMPATIBILITY FUNCTIONS =====
    // These functions maintain compatibility with existing interfaces

    /**
     * @dev Legacy function - alias for gemsOf
     * @param user Address of the user
     * @return Gems amount
     */
    function balanceOf(address user) external view returns (uint256) {
        return _userData[user].gems;
    }
}
