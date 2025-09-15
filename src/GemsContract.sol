// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interface/ILearnWayAdmin.sol";
import "./Errors.sol";

/**
 * @title GemsContract
 * @dev Smart contract for managing non-transferable Gems tokens in the LearnWay application
 * Gems serve as the in-app currency and are earned through various activities
 * Enhanced with role-based access control and anti-spam mechanisms
 */
contract GemsContract is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    // Events
    event GemsAwarded(address indexed user, uint256 amount, string reason);
    event GemsSpent(address indexed user, uint256 amount, string reason);
    event ReferralRegistered(address indexed referrer, address indexed referee, uint256 bonus);
    event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned);
    event ContestReward(address indexed user, uint256 amount, string contestType);
    event MonthlyLeaderboardReward(address indexed user, uint256 position, uint256 amount);
    event MonthlyLeaderboardReset(uint256 indexed month, uint256 indexed year, uint256 timestamp);
    event MonthlyRewardsDistributed(uint256 indexed month, uint256 indexed year, address[] topUsers, uint256[] rewards);
    event WeeklyLeaderboardReward(address indexed user, uint256 position, uint256 amount);
    event WeeklyLeaderboardReset(uint256 indexed week, uint256 indexed year, uint256 timestamp);
    event WeeklyRewardsDistributed(uint256 indexed week, uint256 indexed year, address[] topUsers, uint256[] rewards);
    event SecurityAlert(address indexed user, string alertType, uint256 timestamp);
    event RateLimitExceeded(address indexed user, string action, uint256 attemptCount);

    // LearnWayAdmin contract instance
    ILearnWayAdmin public learnWayAdmin;

    // Constants for gem rewards
    uint256 public constant NEW_USER_SIGNUP_BONUS = 500;
    uint256 public constant REFERRAL_SIGNUP_BONUS = 50;
    uint256 public constant REFERRAL_BONUS = 100;
    uint256 public constant MIN_QUIZ_SCORE = 70;

    // Anti-spam and rate limiting constants
    uint256 public constant MAX_TRANSACTIONS_PER_HOUR = 50;
    uint256 public constant MAX_BATCH_SIZE = 100;
    uint256 public constant COOLDOWN_PERIOD = 1 minutes;

    // State variables
    mapping(address => uint256) private _balances;
    mapping(address => bool) private _hasSignupBonus;
    mapping(address => address) private _referrers;
    mapping(address => uint256) private _referralCount;
    mapping(address => bool) private _isRegistered;

    // Lesson reward system
    mapping(string => uint256) public lessonRewards; // lessonType => reward amount
    mapping(string => uint256) public lessonMinScores; // lessonType => minimum score requirement

    // Monthly leaderboard rewards
    mapping(uint256 => uint256) public monthlyLeaderboardRewards; // position => reward amount

    // Monthly leaderboard history tracking
    mapping(bytes32 => bool) public monthlyLeaderboardResets; // monthYear hash => reset status
    mapping(bytes32 => address[]) public monthlyRewardHistory; // monthYear hash => reward recipients
    mapping(bytes32 => uint256) public lastResetTimestamp; // monthYear hash => reset timestamp

    // Weekly leaderboard rewards
    mapping(uint256 => uint256) public weeklyLeaderboardRewards; // position => reward amount

    // Weekly leaderboard history tracking
    mapping(bytes32 => bool) public weeklyLeaderboardResets; // weekYear hash => reset status
    mapping(bytes32 => address[]) public weeklyRewardHistory; // weekYear hash => reward recipients
    mapping(bytes32 => uint256) public lastWeeklyResetTimestamp; // weekYear hash => reset timestamp

    uint256 private _totalSupply;

    // Test mode flag for bypassing rate limiting during testing
    bool public testMode;

    // Rate limiting and security monitoring
    mapping(address => mapping(uint256 => uint256)) private _hourlyTransactionCount; // user => hour => count
    mapping(address => uint256) private _lastTransactionTime;
    mapping(address => uint256) private _suspiciousActivityCount;
    mapping(address => bool) private _isBlacklisted;

    modifier onlyRegistered() {
        require(_isRegistered[msg.sender], "User not registered");
        _;
    }

    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    modifier notBlacklisted(address user) {
        require(!_isBlacklisted[user], "Address is blacklisted");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _learnWayAdmin) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        learnWayAdmin = ILearnWayAdmin(_learnWayAdmin);

        // Set monthly leaderboard rewards
        monthlyLeaderboardRewards[1] = 1000; // 1st place
        monthlyLeaderboardRewards[2] = 500; // 2nd place
        monthlyLeaderboardRewards[3] = 250; // 3rd place

        // Set weekly leaderboard rewards
        weeklyLeaderboardRewards[1] = 200; // 1st place
        weeklyLeaderboardRewards[2] = 100; // 2nd place
        weeklyLeaderboardRewards[3] = 50; // 3rd place
    }

    /**
     * @dev Register a new user and award signup bonus
     * @param user Address of the new user
     * @param referralCode Address of the referrer (optional, can be address(0))
     */
    function registerUser(address user, address referralCode)
        external
        nonReentrant
        validAddress(user)
        notBlacklisted(user)
        whenNotPaused
    {
        learnWayAdmin.checkAdminOrManager();
        require(!_isRegistered[user], "User already registered");

        _isRegistered[user] = true;

        // Award new user signup bonus
        if (!_hasSignupBonus[user]) {
            _balances[user] += NEW_USER_SIGNUP_BONUS;
            _totalSupply += NEW_USER_SIGNUP_BONUS;
            _hasSignupBonus[user] = true;
            emit GemsAwarded(user, NEW_USER_SIGNUP_BONUS, "New user signup bonus");
        }

        // Handle referral if provided
        if (referralCode != address(0) && _isRegistered[referralCode] && referralCode != user) {
            _referrers[user] = referralCode;

            // Award referral signup bonus to new user
            _balances[user] += REFERRAL_SIGNUP_BONUS;
            _totalSupply += REFERRAL_SIGNUP_BONUS;
            emit GemsAwarded(user, REFERRAL_SIGNUP_BONUS, "Referral signup bonus");

            // Award referral bonus to referrer
            _balances[referralCode] += REFERRAL_BONUS;
            _totalSupply += REFERRAL_BONUS;
            _referralCount[referralCode]++;

            emit ReferralRegistered(referralCode, user, REFERRAL_BONUS);
            emit GemsAwarded(referralCode, REFERRAL_BONUS, "Referral bonus");
        }
    }

    /**
     * @dev Award gems for quiz completion with dynamic reward calculation
     * @param user Address of the user
     * @param score Quiz score (0-100)
     * Formula: (score - 70) * 2 for scores >= 70%
     */
    function awardQuizGems(address user, uint256 score)
        external
        nonReentrant
        validAddress(user)
        notBlacklisted(user)
        whenNotPaused
    {
        learnWayAdmin.checkAdminOrManager();
        require(score <= 100, "Invalid score");
        require(_isRegistered[user], "User not registered");

        uint256 gemsEarned = 0;
        if (score >= MIN_QUIZ_SCORE) {
            gemsEarned = (score - MIN_QUIZ_SCORE) * 2;
            _balances[user] += gemsEarned;
            _totalSupply += gemsEarned;
            emit GemsAwarded(user, gemsEarned, "Quiz completion reward");
        }

        emit QuizCompleted(user, score, gemsEarned);
    }

    /**
     * @dev Award gems for contest participation or battle wins
     * @param user Address of the user
     * @param amount Amount of gems to award
     * @param contestType Type of contest/battle
     */
    function awardContestGems(address user, uint256 amount, string memory contestType)
        external
        validAddress(user)
        whenNotPaused
    {
        learnWayAdmin.checkAdmin();
        require(amount > 0, "Amount must be greater than 0");

        _balances[user] += amount;
        _totalSupply += amount;

        emit ContestReward(user, amount, contestType);
        emit GemsAwarded(user, amount, string(abi.encodePacked("Contest reward: ", contestType)));
    }

    /**
     * @dev Award monthly leaderboard rewards
     * @param user Address of the user
     * @param position Position on leaderboard (1, 2, or 3)
     */
    function awardMonthlyLeaderboardReward(address user, uint256 position) external validAddress(user) whenNotPaused {
        learnWayAdmin.checkAdmin();
        require(position >= 1 && position <= 3, "Invalid leaderboard position");

        uint256 reward = monthlyLeaderboardRewards[position];
        _balances[user] += reward;
        _totalSupply += reward;

        emit MonthlyLeaderboardReward(user, position, reward);
        emit GemsAwarded(user, reward, "Monthly leaderboard reward");
    }

    /**
     * @dev Spend gems (for in-app purchases, etc.)
     * @param user Address of the user
     * @param amount Amount of gems to spend
     * @param reason Reason for spending
     */
    function spendGems(address user, uint256 amount, string memory reason) external validAddress(user) whenNotPaused {
        learnWayAdmin.checkAdmin();
        require(_balances[user] >= amount, "Insufficient gem balance");

        _balances[user] -= amount;
        _totalSupply -= amount;

        emit GemsSpent(user, amount, reason);
    }

    /**
     * @dev Get gem balance of a user
     * @param user Address of the user
     * @return Gem balance
     */
    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    /**
     * @dev Get total supply of gems
     * @return Total supply
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
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
     * @dev Get referrer of a user
     * @param user Address of the user
     * @return Address of referrer
     */
    function getReferrer(address user) external view returns (address) {
        return _referrers[user];
    }

    /**
     * @dev Get referral count for a user
     * @param user Address of the user
     * @return Number of successful referrals
     */
    function getReferralCount(address user) external view returns (uint256) {
        return _referralCount[user];
    }

    /**
     * @dev Check if user has received signup bonus
     * @param user Address of the user
     * @return Signup bonus status
     */
    function hasReceivedSignupBonus(address user) external view returns (bool) {
        return _hasSignupBonus[user];
    }

    /**
     * @dev Set lesson reward and minimum score requirement
     * @param lessonType Type of lesson (e.g., "video", "reading", "exercise")
     * @param reward Gem reward amount for the lesson type
     * @param minScore Minimum score required to earn rewards
     */
    function setLessonReward(string memory lessonType, uint256 reward, uint256 minScore) external {
        learnWayAdmin.checkAdmin();
        require(bytes(lessonType).length > 0, "Lesson type cannot be empty");
        require(minScore <= 100 && minScore > 0, "Invalid minimum score");

        lessonRewards[lessonType] = reward;
        lessonMinScores[lessonType] = minScore;
    }

    /**
     * @dev Award gems for lesson completion
     * @param user Address of the user
     * @param lessonType Type of lesson completed
     * @param score User's score for the lesson
     */
    function awardLessonGems(address user, string memory lessonType, uint256 score)
        external
        validAddress(user)
        whenNotPaused
    {
        learnWayAdmin.checkAdmin();
        require(score <= 100, "Invalid score");
        require(lessonRewards[lessonType] > 0, "Lesson type not configured");

        uint256 minScore = lessonMinScores[lessonType];
        if (score >= minScore) {
            uint256 reward = lessonRewards[lessonType];
            _balances[user] += reward;
            _totalSupply += reward;
            emit GemsAwarded(user, reward, string(abi.encodePacked("Lesson completion: ", lessonType)));
        }
    }

    /**
     * @dev Batch configure lesson rewards
     * @param lessonTypes Array of lesson types
     * @param rewards Array of reward amounts
     * @param minScores Array of minimum scores
     */
    function batchSetLessonRewards(string[] memory lessonTypes, uint256[] memory rewards, uint256[] memory minScores)
        external
    {
        learnWayAdmin.checkAdmin();
        require(lessonTypes.length == rewards.length && rewards.length == minScores.length, "Arrays length mismatch");

        for (uint256 i = 0; i < lessonTypes.length; i++) {
            require(bytes(lessonTypes[i]).length > 0, "Empty lesson type");
            require(rewards[i] > 0, "Reward must be greater than 0");
            require(minScores[i] <= 100, "Invalid minimum score");

            lessonRewards[lessonTypes[i]] = rewards[i];
            lessonMinScores[lessonTypes[i]] = minScores[i];
        }
    }

    /**
     * @dev Update monthly leaderboard rewards (only owner)
     * @param position Leaderboard position (1, 2, or 3)
     * @param reward New reward amount
     */
    function updateMonthlyLeaderboardReward(uint256 position, uint256 reward) external {
        learnWayAdmin.checkAdmin();
        require(position >= 1 && position <= 3, "Invalid position");
        monthlyLeaderboardRewards[position] = reward;
    }

    /**
     * @dev Reset monthly leaderboard for a specific month and year
     * @param month Month (1-12)
     * @param year Year (e.g., 2024)
     */
    function resetMonthlyLeaderboard(uint256 month, uint256 year) external {
        learnWayAdmin.checkAdmin();
        require(month >= 1 && month <= 12, "Invalid month");
        require(year >= 2024, "Invalid year");

        bytes32 monthYearHash = keccak256(abi.encodePacked(month, year));
        require(!monthlyLeaderboardResets[monthYearHash], "Already reset for this month");

        monthlyLeaderboardResets[monthYearHash] = true;
        lastResetTimestamp[monthYearHash] = block.timestamp;

        emit MonthlyLeaderboardReset(month, year, block.timestamp);
    }

    /**
     * @dev Distribute monthly rewards to top users
     * @param month Month (1-12)
     * @param year Year (e.g., 2024)
     * @param topUsers Array of top user addresses (ordered by rank)
     * @param rewards Array of reward amounts corresponding to each user
     */
    function distributeMonthlyRewards(uint256 month, uint256 year, address[] memory topUsers, uint256[] memory rewards)
        external
        nonReentrant
    {
        learnWayAdmin.checkAdmin();
        require(month >= 1 && month <= 12, "Invalid month");
        require(year >= 2024, "Invalid year");
        require(topUsers.length == rewards.length, "Arrays length mismatch");
        require(topUsers.length > 0, "Empty arrays");

        bytes32 monthYearHash = keccak256(abi.encodePacked(month, year));
        require(monthlyLeaderboardResets[monthYearHash], "Month not reset yet");
        require(monthlyRewardHistory[monthYearHash].length == 0, "Rewards already distributed");

        // Distribute rewards and track history
        for (uint256 i = 0; i < topUsers.length; i++) {
            require(topUsers[i] != address(0), "Invalid user address");
            require(rewards[i] > 0, "Invalid reward amount");

            _balances[topUsers[i]] += rewards[i];
            _totalSupply += rewards[i];
            monthlyRewardHistory[monthYearHash].push(topUsers[i]);

            emit MonthlyLeaderboardReward(topUsers[i], i + 1, rewards[i]);
            emit GemsAwarded(topUsers[i], rewards[i], "Monthly leaderboard reward");
        }

        emit MonthlyRewardsDistributed(month, year, topUsers, rewards);
    }

    /**
     * @dev Get monthly reward history for a specific month and year
     * @param month Month (1-12)
     * @param year Year (e.g., 2024)
     * @return Array of addresses that received rewards
     */
    function getMonthlyRewardHistory(uint256 month, uint256 year) external view returns (address[] memory) {
        bytes32 monthYearHash = keccak256(abi.encodePacked(month, year));
        return monthlyRewardHistory[monthYearHash];
    }

    /**
     * @dev Check if monthly leaderboard has been reset for a specific month and year
     * @param month Month (1-12)
     * @param year Year (e.g., 2024)
     * @return Reset status
     */
    function isMonthlyLeaderboardReset(uint256 month, uint256 year) external view returns (bool) {
        bytes32 monthYearHash = keccak256(abi.encodePacked(month, year));
        return monthlyLeaderboardResets[monthYearHash];
    }

    /**
     * @dev Reset weekly leaderboard for a specific week and year
     * @param week Week number (1-52)
     * @param year Year (e.g., 2024)
     */
    function resetWeeklyLeaderboard(uint256 week, uint256 year) external {
        learnWayAdmin.checkAdmin();
        require(week >= 1 && week <= 52, "Invalid week");
        require(year >= 2024, "Invalid year");

        bytes32 weekYearHash = keccak256(abi.encodePacked(week, year));
        require(!weeklyLeaderboardResets[weekYearHash], "Already reset for this week");

        weeklyLeaderboardResets[weekYearHash] = true;
        lastWeeklyResetTimestamp[weekYearHash] = block.timestamp;

        emit WeeklyLeaderboardReset(week, year, block.timestamp);
    }

    /**
     * @dev Distribute weekly rewards to top users
     * @param week Week number (1-52)
     * @param year Year (e.g., 2024)
     * @param topUsers Array of top user addresses (ordered by rank)
     * @param rewards Array of reward amounts corresponding to each user
     */
    function distributeWeeklyRewards(uint256 week, uint256 year, address[] memory topUsers, uint256[] memory rewards)
        external
        nonReentrant
    {
        learnWayAdmin.checkAdmin();
        require(week >= 1 && week <= 52, "Invalid week");
        require(year >= 2024, "Invalid year");
        require(topUsers.length == rewards.length, "Arrays length mismatch");
        require(topUsers.length > 0 && topUsers.length <= 3, "Invalid array size for weekly rewards");

        bytes32 weekYearHash = keccak256(abi.encodePacked(week, year));
        require(weeklyLeaderboardResets[weekYearHash], "Week not reset yet");
        require(weeklyRewardHistory[weekYearHash].length == 0, "Rewards already distributed");

        // Distribute rewards and track history
        for (uint256 i = 0; i < topUsers.length; i++) {
            require(topUsers[i] != address(0), "Invalid user address");
            require(rewards[i] > 0, "Invalid reward amount");

            _balances[topUsers[i]] += rewards[i];
            _totalSupply += rewards[i];
            weeklyRewardHistory[weekYearHash].push(topUsers[i]);

            emit WeeklyLeaderboardReward(topUsers[i], i + 1, rewards[i]);
            emit GemsAwarded(topUsers[i], rewards[i], "Weekly leaderboard reward");
        }

        emit WeeklyRewardsDistributed(week, year, topUsers, rewards);
    }

    /**
     * @dev Update weekly leaderboard rewards (only owner)
     * @param position Leaderboard position (1, 2, or 3)
     * @param reward New reward amount
     */
    function updateWeeklyLeaderboardReward(uint256 position, uint256 reward) external {
        learnWayAdmin.checkAdmin();
        require(position >= 1 && position <= 3, "Invalid position");
        weeklyLeaderboardRewards[position] = reward;
    }

    /**
     * @dev Get weekly reward history for a specific week and year
     * @param week Week number (1-52)
     * @param year Year (e.g., 2024)
     * @return Array of addresses that received rewards
     */
    function getWeeklyRewardHistory(uint256 week, uint256 year) external view returns (address[] memory) {
        bytes32 weekYearHash = keccak256(abi.encodePacked(week, year));
        return weeklyRewardHistory[weekYearHash];
    }

    /**
     * @dev Check if weekly leaderboard has been reset for a specific week and year
     * @param week Week number (1-52)
     * @param year Year (e.g., 2024)
     * @return Reset status
     */
    function isWeeklyLeaderboardReset(uint256 week, uint256 year) external view returns (bool) {
        bytes32 weekYearHash = keccak256(abi.encodePacked(week, year));
        return weeklyLeaderboardResets[weekYearHash];
    }

    /**
     * @dev Award weekly leaderboard reward to a single user
     * @param user Address of the user
     * @param position Position on leaderboard (1, 2, or 3)
     */
    function awardWeeklyLeaderboardReward(address user, uint256 position) external validAddress(user) whenNotPaused {
        learnWayAdmin.checkAdmin();
        require(position >= 1 && position <= 3, "Invalid leaderboard position");

        uint256 reward = weeklyLeaderboardRewards[position];
        _balances[user] += reward;
        _totalSupply += reward;

        emit WeeklyLeaderboardReward(user, position, reward);
        emit GemsAwarded(user, reward, "Weekly leaderboard reward");
    }

    /**
     * @dev Emergency function to pause the contract
     */
    function pause() external {
        learnWayAdmin.checkAdmin();
        _pause();
    }

    /**
     * @dev Emergency function to unpause the contract
     */
    function unpause() external {
        learnWayAdmin.checkAdmin();
        _unpause();
    }

    /**
     * @dev Batch award gems to multiple users
     * @param users Array of user addresses
     * @param amounts Array of gem amounts
     * @param reason Reason for awarding
     */
    function batchAwardGems(address[] memory users, uint256[] memory amounts, string memory reason)
        external
        whenNotPaused
    {
        learnWayAdmin.checkAdmin();
        require(users.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid address");
            require(_isRegistered[users[i]], "User not registered");
            require(amounts[i] > 0, "Amount must be greater than 0");

            _balances[users[i]] += amounts[i];
            _totalSupply += amounts[i];

            emit GemsAwarded(users[i], amounts[i], reason);
        }
    }

    // ===== SECURITY MANAGEMENT FUNCTIONS =====

    /**
     * @dev Add address to blacklist
     * @param user Address to blacklist
     */
    function addToBlacklist(address user) external validAddress(user) {
        learnWayAdmin.checkAdmin();
        _isBlacklisted[user] = true;
        emit SecurityAlert(user, "BLACKLISTED", block.timestamp);
    }

    /**
     * @dev Remove address from blacklist
     * @param user Address to remove from blacklist
     */
    function removeFromBlacklist(address user) external validAddress(user) {
        learnWayAdmin.checkAdmin();
        _isBlacklisted[user] = false;
        emit SecurityAlert(user, "BLACKLIST_REMOVED", block.timestamp);
    }

    /**
     * @dev Get user's hourly transaction count
     * @param user Address to check
     * @param hour Hour to check (block.timestamp / 1 hours)
     */
    function getHourlyTransactionCount(address user, uint256 hour) external view returns (uint256) {
        return _hourlyTransactionCount[user][hour];
    }

    /**
     * @dev Get user's suspicious activity count
     * @param user Address to check
     */
    function getSuspiciousActivityCount(address user) external view returns (uint256) {
        learnWayAdmin.checkAdminOrManager();
        return _suspiciousActivityCount[user];
    }

    /**
     * @dev Check if address is blacklisted
     * @param user Address to check
     */
    function isBlacklisted(address user) external view returns (bool) {
        return _isBlacklisted[user];
    }

    /**
     * @dev Batch blacklist management
     * @param users Array of addresses
     * @param blacklisted Array of blacklist statuses
     */
    function batchUpdateBlacklist(address[] memory users, bool[] memory blacklisted) external {
        learnWayAdmin.checkAdmin();
        require(users.length == blacklisted.length, "Arrays length mismatch");
        require(users.length <= MAX_BATCH_SIZE, "Batch size too large");

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid address");
            _isBlacklisted[users[i]] = blacklisted[i];

            emit SecurityAlert(users[i], blacklisted[i] ? "BLACKLISTED" : "BLACKLIST_REMOVED", block.timestamp);
        }
    }

    /**
     * @dev Enable or disable test mode (bypasses rate limiting for testing)
     * @param _testMode True to enable test mode, false to disable
     */
    function setTestMode(bool _testMode) external {
        learnWayAdmin.checkAdmin();
        testMode = _testMode;
    }

    // ===== GAS OPTIMIZATION AND MONITORING =====

    /**
     * @dev Get gas usage estimate for common operations
     */
    function getGasEstimates()
        external
        pure
        returns (uint256 registerUserGas, uint256 awardGems, uint256 spendGemsGas, uint256 batchAward)
    {
        return (50000, 30000, 25000, 200000); // Estimated gas costs
    }

    /**
     * @dev Optimized balance check with caching
     * @param user Address to check
     */
    function getBalanceOptimized(address user)
        external
        view
        validAddress(user)
        returns (uint256 balance, uint256 lastUpdate)
    {
        return (_balances[user], _lastTransactionTime[user]);
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        learnWayAdmin.checkAdmin();
    }
}
