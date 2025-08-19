// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IGemsContract {
    function registerUser(address user, address referralCode) external;
    function awardQuizGems(address user, uint256 score) external;
    function awardContestGems(address user, uint256 amount, string memory contestType) external;
    function awardMonthlyLeaderboardReward(address user, uint256 position) external;
    function spendGems(address user, uint256 amount, string memory reason) external;
    function balanceOf(address user) external view returns (uint256);
    function isRegistered(address user) external view returns (bool);
}

interface IXPContract {
    function registerUser(address user) external;
    function recordQuizAnswer(address user, bool isCorrect) external;
    function recordContestParticipation(address user, string memory contestId, uint256 xpEarned) external;
    function recordBattleResult(address user, string memory battleType, bool isWin, uint256 customXP) external;
    function awardXP(address user, uint256 amount, string memory reason) external;
    function getXP(address user) external view returns (uint256);
    function getUserRank(address user) external view returns (uint256);
    function isRegistered(address user) external view returns (bool);
}

/**
 * @title LearnWayManager
 * @dev Central management contract for the LearnWay learn-to-earn ecosystem
 * Coordinates between Gems and XP contracts and manages achievements, user profiles, and rewards
 */
contract LearnWayManager is Ownable, ReentrancyGuard, Pausable {

    // Events
    event UserRegistered(address indexed user, address indexed referrer, uint256 timestamp);
    event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned, uint256 xpChange);
    event AchievementUnlocked(address indexed user, string achievementId, uint256 gemsReward);
    event ContestCompleted(address indexed user, string contestId, uint256 gemsEarned, uint256 xpEarned);
    event BattleCompleted(address indexed user, string battleType, bool isWin, uint256 gemsEarned, uint256 xpChange);
    event MonthlyRewardsDistributed(uint256 month, uint256 year, address[] topUsers, uint256[] rewards);
    event UserProfileUpdated(address indexed user, string profileData);

    // Structs
    struct UserProfile {
        string username;
        string profileImageHash;
        uint256 joinDate;
        uint256 lastActiveDate;
        uint256 totalQuizzesCompleted;
        uint256 totalContestsParticipated;
        uint256 totalBattlesParticipated;
        bool isActive;
    }

    struct Achievement {
        string id;
        string name;
        string description;
        uint256 gemsReward;
        uint256 requirement;
        string requirementType; // "quizzes", "contests", "battles", "xp", "gems", "referrals"
        bool isActive;
    }

    // State variables
    IGemsContract public gemsContract;
    IXPContract public xpContract;

    mapping(address => UserProfile) private _userProfiles;
    mapping(address => mapping(bytes32 => bool)) private _userAchievements;
    mapping(bytes32 => Achievement) private _achievements;
    string[] private _achievementIds;

    // Monthly leaderboard tracking
    mapping(uint256 => mapping(uint256 => address[])) private _monthlyTopUsers; // year => month => users
    mapping(uint256 => mapping(uint256 => bool)) private _monthlyRewardsDistributed; // year => month => distributed

    // Contest and battle tracking
    mapping(bytes32 => mapping(address => bool)) private _contestParticipants;
    mapping(address => uint256) private _userContestCount;
    mapping(address => uint256) private _userBattleCount;

    uint256 private _totalUsers;

    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    modifier contractsSet() {
        require(address(gemsContract) != address(0) && address(xpContract) != address(0), "Contracts not set");
        _;
    }

    constructor() Ownable(msg.sender) {
        _initializeAchievements();
    }

    /**
     * @dev Set the Gems and XP contract addresses
     * @param _gemsContract Address of the GemsContract
     * @param _xpContract Address of the XPContract
     */
    function setContracts(address _gemsContract, address _xpContract)
        external
        onlyOwner
    {
        require(_gemsContract != address(0) && _xpContract != address(0), "Invalid contract addresses");
        gemsContract = IGemsContract(_gemsContract);
        xpContract = IXPContract(_xpContract);
    }

    /**
     * @dev Register a new user in both Gems and XP contracts
     * @param user Address of the new user
     * @param referralCode Address of the referrer (optional)
     * @param username Username for the user profile
     */
    function registerUser(
        address user,
        address referralCode,
        string memory username
    )
        external
        onlyOwner
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        require(!gemsContract.isRegistered(user), "User already registered");

        // Register in both contracts
        gemsContract.registerUser(user, referralCode);
        xpContract.registerUser(user);

        // Create user profile
        _userProfiles[user] = UserProfile({
            username: username,
            profileImageHash: "",
            joinDate: block.timestamp,
            lastActiveDate: block.timestamp,
            totalQuizzesCompleted: 0,
            totalContestsParticipated: 0,
            totalBattlesParticipated: 0,
            isActive: true
        });

        _totalUsers++;

        emit UserRegistered(user, referralCode, block.timestamp);

        // Check for first-time registration achievements
        _checkAchievements(user);
    }

    /**
     * @dev Complete a quiz and update both gems and XP
     * @param user Address of the user
     * @param score Quiz score (0-100)
     * @param correctAnswers Array of boolean values for each answer
     */
    function completeQuiz(
        address user,
        uint256 score,
        bool[] memory correctAnswers
    )
        external
        onlyOwner
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        require(gemsContract.isRegistered(user), "User not registered");

        // Award gems based on score
        gemsContract.awardQuizGems(user, score);

        // Record each answer for XP calculation
        for (uint256 i = 0; i < correctAnswers.length; i++) {
            xpContract.recordQuizAnswer(user, correctAnswers[i]);
        }

        // Update user profile
        UserProfile storage profile = _userProfiles[user];
        profile.totalQuizzesCompleted++;
        profile.lastActiveDate = block.timestamp;

        // Calculate gems earned (60 if score >= 70, 0 otherwise)
        uint256 gemsEarned = score >= 70 ? 60 : 0;

        emit QuizCompleted(user, score, gemsEarned, correctAnswers.length * 10); // Assuming 10 XP per correct answer

        // Check for quiz-related achievements
        _checkAchievements(user);
    }

    /**
     * @dev Complete a contest and update rewards
     * @param user Address of the user
     * @param contestId Contest identifier
     * @param gemsEarned Gems earned in the contest
     * @param xpEarned XP earned in the contest
     */
    function completeContest(
        address user,
        string memory contestId,
        uint256 gemsEarned,
        uint256 xpEarned
    )
        external
        onlyOwner
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        require(gemsContract.isRegistered(user), "User not registered");

        // Award gems and XP
        if (gemsEarned > 0) {
            gemsContract.awardContestGems(user, gemsEarned, contestId);
        }
        xpContract.recordContestParticipation(user, contestId, xpEarned);

        // Update tracking
        bytes32 cid = keccak256(bytes(contestId));
        if (!_contestParticipants[cid][user]) {
            _contestParticipants[cid][user] = true;
            _userContestCount[user]++;
        }

        // Update user profile
        UserProfile storage profile = _userProfiles[user];
        profile.totalContestsParticipated++;
        profile.lastActiveDate = block.timestamp;

        emit ContestCompleted(user, contestId, gemsEarned, xpEarned);

        // Check for contest-related achievements
        _checkAchievements(user);
    }

    /**
     * @dev Complete a battle and update rewards
     * @param user Address of the user
     * @param battleType Type of battle ("1v1" or "group")
     * @param isWin Whether the user won
     * @param gemsEarned Gems earned from the battle
     * @param customXP Custom XP amount (0 to use default)
     */
    function completeBattle(
        address user,
        string memory battleType,
        bool isWin,
        uint256 gemsEarned,
        uint256 customXP
    )
        external
        onlyOwner
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        require(gemsContract.isRegistered(user), "User not registered");

        // Award gems if any
        if (gemsEarned > 0) {
            gemsContract.awardContestGems(user, gemsEarned, string(abi.encodePacked("Battle: ", battleType)));
        }

        // Record battle result for XP
        xpContract.recordBattleResult(user, battleType, isWin, customXP);

        // Update tracking
        _userBattleCount[user]++;

        // Update user profile
        UserProfile storage profile = _userProfiles[user];
        profile.totalBattlesParticipated++;
        profile.lastActiveDate = block.timestamp;

        uint256 xpChange = customXP > 0 ? customXP : (isWin ? 50 : 10); // Default XP values

        emit BattleCompleted(user, battleType, isWin, gemsEarned, xpChange);

        // Check for battle-related achievements
        _checkAchievements(user);
    }

    /**
     * @dev Distribute monthly leaderboard rewards
     * @param month Month (1-12)
     * @param year Year
     * @param topUsers Array of top 3 users
     */
    function distributeMonthlyRewards(
        uint256 month,
        uint256 year,
        address[] memory topUsers
    )
        external
        onlyOwner
        contractsSet
        whenNotPaused
    {
        require(month >= 1 && month <= 12, "Invalid month");
        require(topUsers.length <= 3, "Maximum 3 users");
        require(!_monthlyRewardsDistributed[year][month], "Rewards already distributed");

        uint256[] memory rewards = new uint256[](topUsers.length);

        for (uint256 i = 0; i < topUsers.length; i++) {
            require(gemsContract.isRegistered(topUsers[i]), "User not registered");
            gemsContract.awardMonthlyLeaderboardReward(topUsers[i], i + 1);

            // Store reward amount for event
            if (i == 0) rewards[i] = 1000; // 1st place
            else if (i == 1) rewards[i] = 500; // 2nd place
            else rewards[i] = 250; // 3rd place
        }

        _monthlyTopUsers[year][month] = topUsers;
        _monthlyRewardsDistributed[year][month] = true;

        emit MonthlyRewardsDistributed(month, year, topUsers, rewards);
    }

    /**
     * @dev Update user profile information
     * @param user Address of the user
     * @param username New username
     * @param profileImageHash IPFS hash of profile image
     */
    function updateUserProfile(
        address user,
        string memory username,
        string memory profileImageHash
    )
        external
        onlyOwner
        validAddress(user)
        whenNotPaused
    {
        require(gemsContract.isRegistered(user), "User not registered");

        UserProfile storage profile = _userProfiles[user];
        profile.username = username;
        profile.profileImageHash = profileImageHash;
        profile.lastActiveDate = block.timestamp;

        emit UserProfileUpdated(user, string(abi.encodePacked(username, ",", profileImageHash)));
    }

    /**
     * @dev Get comprehensive user data
     * @param user Address of the user
     * @return profile User profile
     * @return gemsBalance Current gems balance
     * @return xpBalance Current XP balance
     * @return userRank Current leaderboard rank
     */
    function getUserData(address user)
        external
        view
        returns (
            UserProfile memory profile,
            uint256 gemsBalance,
            uint256 xpBalance,
            uint256 userRank
        )
    {
        profile = _userProfiles[user];
        gemsBalance = address(gemsContract) != address(0) ? gemsContract.balanceOf(user) : 0;
        xpBalance = address(xpContract) != address(0) ? xpContract.getXP(user) : 0;
        userRank = address(xpContract) != address(0) ? xpContract.getUserRank(user) : 0;
    }

    /**
     * @dev Check if user has unlocked a specific achievement
     * @param user Address of the user
     * @param achievementId Achievement identifier
     * @return Whether the achievement is unlocked
     */
    function hasAchievement(address user, string memory achievementId)
        external
        view
        returns (bool)
    {
        bytes32 aid = keccak256(bytes(achievementId));
        return _userAchievements[user][aid];
    }

    /**
     * @dev Get achievement details
     * @param achievementId Achievement identifier
     * @return Achievement struct
     */
    function getAchievement(string memory achievementId)
        external
        view
        returns (Achievement memory)
    {
        bytes32 aid = keccak256(bytes(achievementId));
        return _achievements[aid];
    }

    /**
     * @dev Get all achievement IDs
     * @return Array of achievement IDs
     */
    function getAllAchievementIds() external view returns (string[] memory) {
        return _achievementIds;
    }

    /**
     * @dev Get monthly top users
     * @param year Year
     * @param month Month
     * @return Array of top users for the month
     */
    function getMonthlyTopUsers(uint256 year, uint256 month)
        external
        view
        returns (address[] memory)
    {
        return _monthlyTopUsers[year][month];
    }

    /**
     * @dev Internal function to check and unlock achievements
     * @param user Address of the user
     */
    function _checkAchievements(address user) internal {
        UserProfile memory profile = _userProfiles[user];
        uint256 userXP = address(xpContract) != address(0) ? xpContract.getXP(user) : 0;
        uint256 userGems = address(gemsContract) != address(0) ? gemsContract.balanceOf(user) : 0;

        for (uint256 i = 0; i < _achievementIds.length; i++) {
            string memory achievementId = _achievementIds[i];
            bytes32 aid = keccak256(bytes(achievementId));
            Achievement memory achievement = _achievements[aid];

            if (!achievement.isActive || _userAchievements[user][aid]) {
                continue;
            }

            bool unlocked = false;

            // Check achievement requirements
            if (keccak256(bytes(achievement.requirementType)) == keccak256(bytes("quizzes"))) {
                unlocked = profile.totalQuizzesCompleted >= achievement.requirement;
            } else if (keccak256(bytes(achievement.requirementType)) == keccak256(bytes("contests"))) {
                unlocked = profile.totalContestsParticipated >= achievement.requirement;
            } else if (keccak256(bytes(achievement.requirementType)) == keccak256(bytes("battles"))) {
                unlocked = profile.totalBattlesParticipated >= achievement.requirement;
            } else if (keccak256(bytes(achievement.requirementType)) == keccak256(bytes("xp"))) {
                unlocked = userXP >= achievement.requirement;
            } else if (keccak256(bytes(achievement.requirementType)) == keccak256(bytes("gems"))) {
                unlocked = userGems >= achievement.requirement;
            }

            if (unlocked) {
                _userAchievements[user][aid] = true;

                // Award gems for achievement
                if (achievement.gemsReward > 0 && address(gemsContract) != address(0)) {
                    gemsContract.awardContestGems(user, achievement.gemsReward, "Achievement reward");
                }

                emit AchievementUnlocked(user, achievementId, achievement.gemsReward);
            }
        }
    }

    /**
     * @dev Initialize default achievements
     */
    function _initializeAchievements() internal {
        // Quiz achievements
        _addAchievement("first_quiz", "First Steps", "Complete your first quiz", 100, 1, "quizzes");
        _addAchievement("quiz_master", "Quiz Master", "Complete 50 quizzes", 500, 50, "quizzes");
        _addAchievement("quiz_legend", "Quiz Legend", "Complete 200 quizzes", 1000, 200, "quizzes");

        // Contest achievements
        _addAchievement("contest_participant", "Contest Participant", "Participate in your first contest", 150, 1, "contests");
        _addAchievement("contest_veteran", "Contest Veteran", "Participate in 25 contests", 750, 25, "contests");

        // Battle achievements
        _addAchievement("first_battle", "First Battle", "Participate in your first battle", 200, 1, "battles");
        _addAchievement("battle_warrior", "Battle Warrior", "Participate in 100 battles", 1000, 100, "battles");

        // XP achievements
        _addAchievement("xp_collector", "XP Collector", "Earn 1000 XP", 300, 1000, "xp");
        _addAchievement("xp_master", "XP Master", "Earn 10000 XP", 1500, 10000, "xp");

        // Gems achievements
        _addAchievement("gem_saver", "Gem Saver", "Accumulate 5000 gems", 500, 5000, "gems");
        _addAchievement("gem_collector", "Gem Collector", "Accumulate 20000 gems", 2000, 20000, "gems");
    }

    /**
     * @dev Add a new achievement
     */
    function _addAchievement(
        string memory id,
        string memory name,
        string memory description,
        uint256 gemsReward,
        uint256 requirement,
        string memory requirementType
    ) internal {
        bytes32 aid = keccak256(bytes(id));
        _achievements[aid] = Achievement({
            id: id,
            name: name,
            description: description,
            gemsReward: gemsReward,
            requirement: requirement,
            requirementType: requirementType,
            isActive: true
        });
        _achievementIds.push(id);
    }

    /**
     * @dev Add custom achievement (only owner)
     */
    function addCustomAchievement(
        string memory id,
        string memory name,
        string memory description,
        uint256 gemsReward,
        uint256 requirement,
        string memory requirementType
    ) external onlyOwner {
        bytes32 aid = keccak256(bytes(id));
        require(bytes(_achievements[aid].id).length == 0, "Achievement already exists");
        _addAchievement(id, name, description, gemsReward, requirement, requirementType);
    }

    /**
     * @dev Emergency pause function
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Emergency unpause function
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get total registered users
     */
    function getTotalUsers() external view returns (uint256) {
        return _totalUsers;
    }
}
