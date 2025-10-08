// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interface/ILearnWayAdmin.sol";
import "./Errors.sol";

// Corrected interfaces matching actual contracts
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

interface ILearnWayBadge {
    function registerUser(address user, bool kycStatus) external;
    function updateUserStats(address user, uint256 statType, uint256[] calldata values) external;
    function getUserBadges(address user) external view returns (uint256[] memory);
    function userHasBadge(address user, uint256 badgeId) external view returns (bool);
    function userStats(address user)
        external
        view
        returns (
            uint256 totalQuizzes,
            uint256 correctAnswers,
            uint256 currentLevel,
            uint256 dailyStreak,
            uint256 contestsWon,
            uint256 battlesWon,
            uint256 gemsCollected,
            uint256 transactionsCompleted,
            uint256 depositsCompleted,
            uint256 sharesCompleted,
            uint256 referrals,
            bool kycCompleted,
            bool hasFirstDeposit,
            bool attendedEvent,
            uint256 totalBadgesEarned
        );
}

contract LearnWayManager is ReentrancyGuard, Pausable {
    using Strings for uint256;

    /* =========================
       CUSTOM ERRORS
       ========================= */
    error InvalidAddress();
    error EmptyUsername();
    error AlreadyRegistered();
    error NotRegistered();
    error ContractsNotSet();
    error RewardsAlreadyDistributed();
    error AchievementExists();
    error InvalidMonth();
    error InvalidArrayLength();

    /* =========================
       EVENTS
       ========================= */
    event UserRegistered(address indexed user, address indexed referrer, uint256 timestamp);
    event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned, uint256 xpChange);
    event AchievementUnlocked(address indexed user, string achievementId, uint256 gemsReward);
    event ContestCompleted(address indexed user, string contestId, uint256 gemsEarned, uint256 xpEarned);
    event BattleCompleted(address indexed user, string battleType, bool isWin, uint256 gemsEarned, uint256 xpChange);
    event MonthlyRewardsDistributed(uint256 month, uint256 year, address[] topUsers, uint256[] rewards);
    event UserProfileUpdated(address indexed user, string profileData);

    /* =========================
       CONTRACTS (external)
       ========================= */
    ILearnWayAdmin public adminContract;
    IGemsContract public gemsContract;
    IXPContract public xpContract;
    ILearnWayBadge public badgesContract;

    /* =========================
       STRUCTS
       ========================= */
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
        bytes32 requirementTypeHash;
        bool isActive;
    }

    /* =========================
       STORAGE
       ========================= */
    mapping(address => UserProfile) private _userProfiles;
    mapping(address => mapping(bytes32 => bool)) private _userAchievements;
    mapping(bytes32 => Achievement) private _achievements;
    bytes32[] private _achievementIds;

    // Monthly leaderboard tracking
    mapping(uint256 => mapping(uint256 => address[])) private _monthlyTopUsers;
    mapping(uint256 => mapping(uint256 => bool)) private _monthlyRewardsDistributed;

    // Contest and battle tracking
    mapping(bytes32 => mapping(address => bool)) private _contestParticipants;
    mapping(address => uint256) private _userContestCount;
    mapping(address => uint256) private _userBattleCount;

    uint256 private _totalUsers;

    /* =========================
       MODIFIERS
       ========================= */
    modifier validAddress(address user) {
        if (user == address(0)) revert InvalidAddress();
        _;
    }

    modifier contractsSet() {
        if (
            address(gemsContract) == address(0) || address(xpContract) == address(0)
                || address(badgesContract) == address(0)
        ) {
            revert ContractsNotSet();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender)) revert UnauthorizedAdmin();
        _;
    }

    modifier onlyAdminOrManager() {
        if (
            !adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender)
                && !adminContract.isAuthorized(keccak256("MANAGER_ROLE"), msg.sender)
        ) revert UnauthorizedAdminOrManager();
        _;
    }

    /* =========================
       CONSTRUCTOR
       ========================= */
    constructor(address _adminContract) {
        if (_adminContract != address(0)) adminContract = ILearnWayAdmin(_adminContract);
        _initializeAchievements();
    }

    /* =========================
       ADMIN / SETTERS
       ========================= */

    function setAdminContract(address _adminContract) external onlyAdmin {
        adminContract = ILearnWayAdmin(_adminContract);
    }

    function setContracts(address _gemsContract, address _xpContract, address _badgesContract) external onlyAdmin {
        if (_gemsContract == address(0) || _xpContract == address(0) || _badgesContract == address(0)) {
            revert InvalidAddress();
        }
        gemsContract = IGemsContract(_gemsContract);
        xpContract = IXPContract(_xpContract);
        badgesContract = ILearnWayBadge(_badgesContract);
    }

    /* =========================
       USER REGISTRATION
       ========================= */

    function registerUser(address user, address referralCode, string memory username, bool kycStatus)
        external
        nonReentrant
        onlyAdminOrManager
        validAddress(user)
        whenNotPaused
    {
        if (bytes(username).length == 0) revert EmptyUsername();
        if (
            address(gemsContract) == address(0) || address(xpContract) == address(0)
                || address(badgesContract) == address(0)
        ) {
            revert ContractsNotSet();
        }

        if (gemsContract.isRegistered(user)) revert AlreadyRegistered();

        // Register in all contracts
        gemsContract.registerUser(user, referralCode);
        xpContract.registerUser(user);
        badgesContract.registerUser(user, kycStatus);

        // Create profile
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
        _checkAchievements(user);
    }

    /* =========================
       QUIZ FLOW
       ========================= */

    function completeQuiz(address user, uint256 score, bool[] memory correctAnswers)
        external
        onlyAdminOrManager
        nonReentrant
        validAddress(user)
        whenNotPaused
    {
        if (!gemsContract.isRegistered(user)) revert NotRegistered();
        if (score > 100) revert InvalidAddress();

        // Award gems through GemsContract
        gemsContract.awardQuizGems(user, score);

        // Record each answer in XP contract
        uint256 correctCount = 0;
        for (uint256 i = 0; i < correctAnswers.length; i++) {
            xpContract.recordQuizAnswer(user, correctAnswers[i]);
            if (correctAnswers[i]) correctCount++;
        }

        // Update badge stats - statType 0 = quiz stats
        uint256[] memory values = new uint256[](3);
        values[0] = 1; // quizzes completed
        values[1] = correctCount; // correct answers
        values[2] = 0; // level (can be calculated separately or passed as parameter)
        badgesContract.updateUserStats(user, 0, values);

        // Update manager profile
        UserProfile storage profile = _userProfiles[user];
        profile.totalQuizzesCompleted++;
        profile.lastActiveDate = block.timestamp;

        // Calculate expected gems earned for event
        uint256 gemsEarned = 0;
        if (score >= 70) gemsEarned = (score - 70) * 2;

        // Calculate XP change for event
        uint256 totalAnswers = correctAnswers.length;
        uint256 incorrectCount = totalAnswers - correctCount;
        uint256 xpChange = correctCount * 4;
        if (incorrectCount * 2 < xpChange) {
            xpChange -= incorrectCount * 2;
        } else {
            xpChange = 0;
        }

        emit QuizCompleted(user, score, gemsEarned, xpChange);
        _checkAchievements(user);
    }

    /* =========================
       CONTEST FLOW
       ========================= */

    function completeContest(address user, string memory contestId, uint256 gemsEarned, uint256 xpEarned, bool isWin)
        external
        onlyAdminOrManager
        nonReentrant
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        if (!gemsContract.isRegistered(user)) revert NotRegistered();

        // Award gems if configured
        if (gemsEarned > 0) {
            gemsContract.awardContestGems(user, gemsEarned, contestId);
        }

        // Record XP
        xpContract.recordContestParticipation(user, contestId, xpEarned);

        // Update badge stats - statType 2 = battle/contest stats
        if (isWin) {
            uint256[] memory values = new uint256[](2);
            values[0] = 0; // battles won
            values[1] = 1; // contests won
            badgesContract.updateUserStats(user, 2, values);
        }

        // Contest participants tracking
        bytes32 cid = keccak256(bytes(contestId));
        if (!_contestParticipants[cid][user]) {
            _contestParticipants[cid][user] = true;
            _userContestCount[user]++;
        }

        // Update profile
        UserProfile storage profile = _userProfiles[user];
        profile.totalContestsParticipated++;
        profile.lastActiveDate = block.timestamp;

        emit ContestCompleted(user, contestId, gemsEarned, xpEarned);
        _checkAchievements(user);
    }

    /* =========================
       BATTLE FLOW
       ========================= */

    function completeBattle(address user, string memory battleType, bool isWin, uint256 gemsEarned, uint256 customXP)
        external
        onlyAdminOrManager
        nonReentrant
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        if (!gemsContract.isRegistered(user)) revert NotRegistered();

        // Award gems if any
        if (gemsEarned > 0) {
            string memory contestLabel = string(abi.encodePacked("Battle: ", battleType));
            gemsContract.awardContestGems(user, gemsEarned, contestLabel);
        }

        // Record XP
        xpContract.recordBattleResult(user, battleType, isWin, customXP);

        // Update badge stats - statType 2 = battle/contest stats
        if (isWin) {
            uint256[] memory values = new uint256[](2);
            values[0] = 1; // battles won
            values[1] = 0; // contests won
            badgesContract.updateUserStats(user, 2, values);
        }

        // Update local tracking
        _userBattleCount[user]++;

        // Update profile
        UserProfile storage profile = _userProfiles[user];
        profile.totalBattlesParticipated++;
        profile.lastActiveDate = block.timestamp;

        uint256 xpChange = customXP > 0 ? customXP : (isWin ? 50 : 10);

        emit BattleCompleted(user, battleType, isWin, gemsEarned, xpChange);
        _checkAchievements(user);
    }

    /* =========================
       MONTHLY REWARDS
       ========================= */

    function distributeMonthlyRewards(uint256 month, uint256 year, address[] memory topUsers)
        external
        onlyAdmin
        nonReentrant
        whenNotPaused
    {
        if (!(month >= 1 && month <= 12)) revert InvalidMonth();
        if (topUsers.length > 3) revert InvalidArrayLength();
        if (_monthlyRewardsDistributed[year][month]) revert RewardsAlreadyDistributed();

        uint256[] memory rewards = new uint256[](topUsers.length);

        for (uint256 i = 0; i < topUsers.length; i++) {
            address u = topUsers[i];
            if (u == address(0)) revert InvalidAddress();
            if (!gemsContract.isRegistered(u)) revert NotRegistered();

            gemsContract.awardMonthlyLeaderboardReward(u, i + 1);

            // Store reward amounts for event
            if (i == 0) rewards[i] = 1000;
            else if (i == 1) rewards[i] = 500;
            else rewards[i] = 250;
        }

        _monthlyTopUsers[year][month] = topUsers;
        _monthlyRewardsDistributed[year][month] = true;

        emit MonthlyRewardsDistributed(month, year, topUsers, rewards);
    }

    /* =========================
       PROFILE MANAGEMENT
       ========================= */

    function updateUserProfile(address user, string memory username, string memory profileImageHash)
        external
        onlyAdminOrManager
        nonReentrant
        validAddress(user)
        whenNotPaused
    {
        if (!gemsContract.isRegistered(user)) revert NotRegistered();
        UserProfile storage profile = _userProfiles[user];
        profile.username = username;
        profile.profileImageHash = profileImageHash;
        profile.lastActiveDate = block.timestamp;

        emit UserProfileUpdated(user, string(abi.encodePacked(username, ",", profileImageHash)));
    }

    // function updateUserKYCStatus(address user, bool kycStatus)
    //     external onlyAdmin validAddress(user) contractsSet whenNotPaused
    // {
    //     if (!gemsContract.isRegistered(user)) revert NotRegistered();

    //     // This would require a new function in the badge contract to update KYC status
    //     // For now, we can track it here and update through stats
    //     uint256[] memory values = new uint256[](0); // Empty array to trigger KYC update
    //     // Note: This would need to be implemented in the badge contract
    // }

    function updateReferralCount(address user, uint256 referralCount)
        external
        onlyAdminOrManager
        validAddress(user)
        whenNotPaused
    {
        if (!gemsContract.isRegistered(user)) revert NotRegistered();

        // Update badge stats - statType 4 = community stats
        uint256[] memory values = new uint256[](3);
        values[0] = referralCount; // referrals
        values[1] = 0; // shares
        values[2] = 0; // attended event
        badgesContract.updateUserStats(user, 4, values);
    }

    function updateGemsCollected(address user)
        external
        onlyAdminOrManager
        validAddress(user)
        contractsSet
        whenNotPaused
    {
        if (!gemsContract.isRegistered(user)) revert NotRegistered();

        uint256 userGems = gemsContract.balanceOf(user);

        // Update badge stats - statType 5 = gems
        uint256[] memory values = new uint256[](1);
        values[0] = userGems;
        badgesContract.updateUserStats(user, 5, values);
    }

    /* =========================
       VIEW FUNCTIONS
       ========================= */

    function getUserData(address user)
        external
        view
        returns (
            UserProfile memory profile,
            uint256 gemsBalance,
            uint256 xpBalance,
            uint256 userRank,
            uint256[] memory badgesList,
            uint256 totalBadgesEarned
        )
    {
        profile = _userProfiles[user];
        gemsBalance = address(gemsContract) != address(0) ? gemsContract.balanceOf(user) : 0;
        xpBalance = address(xpContract) != address(0) ? xpContract.getXP(user) : 0;
        userRank = address(xpContract) != address(0) ? xpContract.getUserRank(user) : 0;

        if (address(badgesContract) != address(0)) {
            badgesList = badgesContract.getUserBadges(user);
            (,,,,,,,,,,,,,, totalBadgesEarned) = badgesContract.userStats(user);
        }
    }

    /* =========================
       ACHIEVEMENT MANAGEMENT
       ========================= */

    function hasAchievement(address user, string memory achievementId) external view returns (bool) {
        bytes32 aid = keccak256(bytes(achievementId));
        return _userAchievements[user][aid];
    }

    function getAchievement(string memory achievementId) external view returns (Achievement memory) {
        bytes32 aid = keccak256(bytes(achievementId));
        return _achievements[aid];
    }

    function getAllAchievementIds() external view returns (string[] memory) {
        string[] memory ids = new string[](_achievementIds.length);
        for (uint256 i = 0; i < _achievementIds.length; i++) {
            ids[i] = _achievements[_achievementIds[i]].id;
        }
        return ids;
    }

    function getMonthlyTopUsers(uint256 year, uint256 month) external view returns (address[] memory) {
        return _monthlyTopUsers[year][month];
    }

    function _checkAchievements(address user) internal {
        UserProfile memory profile = _userProfiles[user];
        uint256 userXP = address(xpContract) != address(0) ? xpContract.getXP(user) : 0;
        uint256 userGems = address(gemsContract) != address(0) ? gemsContract.balanceOf(user) : 0;

        for (uint256 i = 0; i < _achievementIds.length; i++) {
            bytes32 aid = _achievementIds[i];
            Achievement memory achievement = _achievements[aid];

            if (!achievement.isActive) continue;
            if (_userAchievements[user][aid]) continue;

            bool unlocked = false;
            bytes32 t = achievement.requirementTypeHash;

            if (t == keccak256("quizzes")) {
                unlocked = profile.totalQuizzesCompleted >= achievement.requirement;
            } else if (t == keccak256("contests")) {
                unlocked = profile.totalContestsParticipated >= achievement.requirement;
            } else if (t == keccak256("battles")) {
                unlocked = profile.totalBattlesParticipated >= achievement.requirement;
            } else if (t == keccak256("xp")) {
                unlocked = userXP >= achievement.requirement;
            } else if (t == keccak256("gems")) {
                unlocked = userGems >= achievement.requirement;
            }

            if (unlocked) {
                _userAchievements[user][aid] = true;

                if (achievement.gemsReward > 0 && address(gemsContract) != address(0)) {
                    gemsContract.awardContestGems(user, achievement.gemsReward, "Achievement reward");
                }

                emit AchievementUnlocked(user, achievement.id, achievement.gemsReward);
            }
        }
    }

    /* =========================
       ACHIEVEMENT INITIALIZATION
       ========================= */

    function _initializeAchievements() internal {
        _addAchievement("first_quiz", "First Steps", "Complete your first quiz", 100, 1, "quizzes");
        _addAchievement("quiz_master", "Quiz Master", "Complete 50 quizzes", 500, 50, "quizzes");
        _addAchievement("quiz_legend", "Quiz Legend", "Complete 200 quizzes", 1000, 200, "quizzes");

        _addAchievement(
            "contest_participant", "Contest Participant", "Participate in your first contest", 150, 1, "contests"
        );
        _addAchievement("contest_veteran", "Contest Veteran", "Participate in 25 contests", 750, 25, "contests");

        _addAchievement("first_battle", "First Battle", "Participate in your first battle", 200, 1, "battles");
        _addAchievement("battle_warrior", "Battle Warrior", "Participate in 100 battles", 1000, 100, "battles");

        _addAchievement("xp_collector", "XP Collector", "Earn 1000 XP", 300, 1000, "xp");
        _addAchievement("xp_master", "XP Master", "Earn 10000 XP", 1500, 10000, "xp");

        _addAchievement("gem_saver", "Gem Saver", "Accumulate 5000 gems", 500, 5000, "gems");
        _addAchievement("gem_collector", "Gem Collector", "Accumulate 20000 gems", 2000, 20000, "gems");
    }

    function _addAchievement(
        string memory id,
        string memory name,
        string memory description,
        uint256 gemsReward,
        uint256 requirement,
        string memory requirementType
    ) internal {
        bytes32 aid = keccak256(bytes(id));
        if (bytes(_achievements[aid].id).length != 0) revert AchievementExists();

        _achievements[aid] = Achievement({
            id: id,
            name: name,
            description: description,
            gemsReward: gemsReward,
            requirement: requirement,
            requirementTypeHash: keccak256(bytes(requirementType)),
            isActive: true
        });

        _achievementIds.push(aid);
    }

    function addCustomAchievement(
        string memory id,
        string memory name,
        string memory description,
        uint256 gemsReward,
        uint256 requirement,
        string memory requirementType
    ) external onlyAdmin {
        _addAchievement(id, name, description, gemsReward, requirement, requirementType);
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

    function getTotalUsers() external view returns (uint256) {
        return _totalUsers;
    }

    function getUserProfile(address user) external view returns (UserProfile memory) {
        return _userProfiles[user];
    }

    function deactivateUser(address user) external onlyAdmin validAddress(user) {
        _userProfiles[user].isActive = false;
    }

    function reactivateUser(address user) external onlyAdmin validAddress(user) {
        _userProfiles[user].isActive = true;
    }
}
