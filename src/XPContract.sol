// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interface/ILearnWayAdmin.sol";
import "./Errors.sol";

/**
 * @title XPContract
 * @dev Smart contract for managing Experience Points (XPs) in the LearnWay application
 * XPs are earned for correct answers and lost for incorrect ones, affecting leaderboard positions
 */
contract XPContract is  ReentrancyGuard, Pausable {
    // Events
    event XPAwarded(address indexed user, uint256 amount, string reason);
    event XPDeducted(address indexed user, uint256 amount, string reason);
    event QuizAnswered(address indexed user, bool isCorrect, uint256 xpChange);
    event ContestParticipation(address indexed user, uint256 xpEarned, string contestType);
    event BattleResult(address indexed user, uint256 xpChange, string battleType, bool isWin);
    event LeaderboardUpdated(address indexed user, uint256 newXP, uint256 newRank);
    ILearnWayAdmin public adminContract;
 

    modifier onlyAdminOrManager() {
        if (!adminContract.isAuthorized(keccak256("MANAGER_ROLE"), msg.sender)) revert UnauthorizedAdminOrManager();
        _;
    }

    // Structs
    struct UserStats {
        uint256 totalXP;
        uint256 correctAnswers;
        uint256 incorrectAnswers;
        uint256 contestsParticipated;
        uint256 battlesWon;
        uint256 battlesLost;
        uint256 currentRank;
        uint256 lastActivityTimestamp;
    }

    struct LeaderboardEntry {
        address user;
        uint256 xp;
        uint256 rank;
    }

    // State variables
    mapping(address => UserStats) private _userStats;
    mapping(address => bool) private _isRegistered;

    // Leaderboard management
    address[] private _leaderboard;
    mapping(address => uint256) private _leaderboardIndex;

    // XP reward/penalty configurations
    uint256 public correctAnswerXP = 4;
    uint256 public incorrectAnswerXP = 2;
    uint256 public contestParticipationXP = 25;
    uint256 public battleWinXP = 50;
    uint256 public battleLossXP = 10;

    // Contest leaderboards (contestIdHash => user => xp)
    mapping(bytes32 => mapping(address => uint256)) private _contestLeaderboards;
    mapping(bytes32 => address[]) private _contestParticipants;

    uint256 private _totalUsers;

    modifier onlyRegistered() {
        require(_isRegistered[msg.sender], "User not registered");
        _;
    }

    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    constructor(address _admin)  {
        adminContract = ILearnWayAdmin(_admin);
    }

    /**
     * @dev Register a new user
     * @param user Address of the new user
     */
    function registerUser(address user) external onlyAdminOrManager nonReentrant validAddress(user) whenNotPaused {
        require(!_isRegistered[user], "User already registered");

        _isRegistered[user] = true;
        _userStats[user] = UserStats({
            totalXP: 0,
            correctAnswers: 0,
            incorrectAnswers: 0,
            contestsParticipated: 0,
            battlesWon: 0,
            battlesLost: 0,
            currentRank: 0,
            lastActivityTimestamp: block.timestamp
        });

        _totalUsers++;
        _addToLeaderboard(user);
    }

    /**
     * @dev Award or deduct XP for quiz answers
     * @param user Address of the user
     * @param isCorrect Whether the answer was correct
     */
    function recordQuizAnswer(address user, bool isCorrect) external onlyAdminOrManager nonReentrant validAddress(user) whenNotPaused {
        require(_isRegistered[user], "User not registered");

        UserStats storage stats = _userStats[user];
        stats.lastActivityTimestamp = block.timestamp;

        if (isCorrect) {
            stats.totalXP += correctAnswerXP;
            stats.correctAnswers++;
            emit XPAwarded(user, correctAnswerXP, "Correct quiz answer");
        } else {
            // Ensure XP doesn't go below 0
            if (stats.totalXP >= incorrectAnswerXP) {
                stats.totalXP -= incorrectAnswerXP;
            } else {
                stats.totalXP = 0;
            }
            stats.incorrectAnswers++;
            emit XPDeducted(user, incorrectAnswerXP, "Incorrect quiz answer");
        }

        emit QuizAnswered(user, isCorrect, isCorrect ? correctAnswerXP : incorrectAnswerXP);
        _updateLeaderboard(user);
    }

    /**
     * @dev Record contest participation and award XP
     * @param user Address of the user
     * @param contestId Unique identifier for the contest
     * @param xpEarned XP earned in the contest
     */
    function recordContestParticipation(address user, string memory contestId, uint256 xpEarned)
        external
        onlyAdminOrManager nonReentrant
        validAddress(user)
        whenNotPaused
    {
        require(_isRegistered[user], "User not registered");

        UserStats storage stats = _userStats[user];
        stats.totalXP += xpEarned;
        stats.contestsParticipated++;
        stats.lastActivityTimestamp = block.timestamp;

        // Add to contest leaderboard
        bytes32 cid = keccak256(bytes(contestId));
        if (_contestLeaderboards[cid][user] == 0) {
            _contestParticipants[cid].push(user);
        }
        _contestLeaderboards[cid][user] += xpEarned;

        emit ContestParticipation(user, xpEarned, contestId);
        emit XPAwarded(user, xpEarned, string(abi.encodePacked("Contest participation: ", contestId)));
        _updateLeaderboard(user);
    }

    /**
     * @dev Record battle result and update XP
     * @param user Address of the user
     * @param battleType Type of battle ("1v1" or "group")
     * @param isWin Whether the user won the battle
     * @param customXP Custom XP amount (optional, 0 to use default)
     */
    function recordBattleResult(address user, string memory battleType, bool isWin, uint256 customXP)
        external
        onlyAdminOrManager nonReentrant
        validAddress(user)
        whenNotPaused
    {
        require(_isRegistered[user], "User not registered");

        UserStats storage stats = _userStats[user];
        stats.lastActivityTimestamp = block.timestamp;

        uint256 xpChange;
        if (customXP > 0) {
            xpChange = customXP;
        } else {
            xpChange = isWin ? battleWinXP : battleLossXP;
        }

        if (isWin) {
            stats.totalXP += xpChange;
            stats.battlesWon++;
            emit XPAwarded(user, xpChange, string(abi.encodePacked("Battle win: ", battleType)));
        } else {
            // Ensure XP doesn't go below 0
            if (stats.totalXP >= xpChange) {
                stats.totalXP -= xpChange;
            } else {
                stats.totalXP = 0;
            }
            stats.battlesLost++;
            emit XPDeducted(user, xpChange, string(abi.encodePacked("Battle loss: ", battleType)));
        }

        emit BattleResult(user, xpChange, battleType, isWin);
        _updateLeaderboard(user);
    }

    /**
     * @dev Manually award XP to a user
     * @param user Address of the user
     * @param amount Amount of XP to award
     * @param reason Reason for awarding XP
     */
    function awardXP(address user, uint256 amount, string memory reason)
        external
        onlyAdminOrManager nonReentrant
        validAddress(user)
        whenNotPaused
    {
        require(_isRegistered[user], "User not registered");
        require(amount > 0, "Amount must be greater than 0");

        _userStats[user].totalXP += amount;
        _userStats[user].lastActivityTimestamp = block.timestamp;

        emit XPAwarded(user, amount, reason);
        _updateLeaderboard(user);
    }

    /**
     * @dev Manually deduct XP from a user
     * @param user Address of the user
     * @param amount Amount of XP to deduct
     * @param reason Reason for deducting XP
     */
    function deductXP(address user, uint256 amount, string memory reason)
        external
        onlyAdminOrManager nonReentrant
        validAddress(user)
        whenNotPaused
    {
        require(_isRegistered[user], "User not registered");
        require(amount > 0, "Amount must be greater than 0");

        UserStats storage stats = _userStats[user];
        if (stats.totalXP >= amount) {
            stats.totalXP -= amount;
        } else {
            stats.totalXP = 0;
        }
        stats.lastActivityTimestamp = block.timestamp;

        emit XPDeducted(user, amount, reason);
        _updateLeaderboard(user);
    }

    /**
     * @dev Get user's XP and stats
     * @param user Address of the user
     * @return UserStats struct
     */
    function getUserStats(address user) external view returns (UserStats memory) {
        return _userStats[user];
    }

    /**
     * @dev Get user's total XP
     * @param user Address of the user
     * @return Total XP
     */
    function getXP(address user) external view returns (uint256) {
        return _userStats[user].totalXP;
    }

    /**
     * @dev Get user's current rank
     * @param user Address of the user
     * @return Current rank (1-based)
     */
    function getUserRank(address user) external view returns (uint256) {
        return _userStats[user].currentRank;
    }

    /**
     * @dev Get top N users from leaderboard
     * @param count Number of top users to return
     * @return Array of LeaderboardEntry structs
     */
    function getTopUsers(uint256 count) external view returns (LeaderboardEntry[] memory) {
        uint256 actualCount = count > _leaderboard.length ? _leaderboard.length : count;
        LeaderboardEntry[] memory topUsers = new LeaderboardEntry[](actualCount);

        for (uint256 i = 0; i < actualCount; i++) {
            address user = _leaderboard[i];
            topUsers[i] = LeaderboardEntry({user: user, xp: _userStats[user].totalXP, rank: i + 1});
        }

        return topUsers;
    }

    /**
     * @dev Get contest leaderboard
     * @param contestId Contest identifier
     * @return participants Array of participants and their XP in the contest
     */
    function getContestLeaderboard(string memory contestId)
        external
        view
        returns (address[] memory participants, uint256[] memory xpScores)
    {
        bytes32 cid = keccak256(bytes(contestId));
        address[] memory contestUsers = _contestParticipants[cid];
        participants = new address[](contestUsers.length);
        xpScores = new uint256[](contestUsers.length);

        for (uint256 i = 0; i < contestUsers.length; i++) {
            participants[i] = contestUsers[i];
            xpScores[i] = _contestLeaderboards[cid][contestUsers[i]];
        }

        return (participants, xpScores);
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
     * @dev Get total number of registered users
     * @return Total users count
     */
    function getTotalUsers() external view returns (uint256) {
        return _totalUsers;
    }

    /**
     * @dev Update XP reward/penalty configurations
     */
    function updateXPConfig(
        uint256 _correctAnswerXP,
        uint256 _incorrectAnswerXP,
        uint256 _contestParticipationXP,
        uint256 _battleWinXP,
        uint256 _battleLossXP
    ) external onlyAdminOrManager nonReentrant {
        correctAnswerXP = _correctAnswerXP;
        incorrectAnswerXP = _incorrectAnswerXP;
        contestParticipationXP = _contestParticipationXP;
        battleWinXP = _battleWinXP;
        battleLossXP = _battleLossXP;
    }

    /**
     * @dev Internal function to add user to leaderboard
     * @param user Address of the user
     */
    function _addToLeaderboard(address user) internal {
        _leaderboard.push(user);
        _leaderboardIndex[user] = _leaderboard.length - 1;
        _userStats[user].currentRank = _leaderboard.length;
    }

    /**
     * @dev Internal function to update leaderboard after XP change
     * @param user Address of the user whose XP changed
     */
    function _updateLeaderboard(address user) internal {
        uint256 userIndex = _leaderboardIndex[user];
        uint256 userXP = _userStats[user].totalXP;
        uint256 startIndex = userIndex;
        uint256 endIndex = userIndex;

        // Move user up in leaderboard if they have more XP than users above them
        while (userIndex > 0 && _userStats[_leaderboard[userIndex - 1]].totalXP < userXP) {
            // Swap with user above
            address userAbove = _leaderboard[userIndex - 1];
            _leaderboard[userIndex] = userAbove;
            _leaderboard[userIndex - 1] = user;

            // Update indices
            _leaderboardIndex[userAbove] = userIndex;
            _leaderboardIndex[user] = userIndex - 1;

            userIndex--;
            startIndex = userIndex; // Track the range affected
        }

        // Move user down in leaderboard if they have less XP than users below them
        while (userIndex < _leaderboard.length - 1 && _userStats[_leaderboard[userIndex + 1]].totalXP > userXP) {
            // Swap with user below
            address userBelow = _leaderboard[userIndex + 1];
            _leaderboard[userIndex] = userBelow;
            _leaderboard[userIndex + 1] = user;

            // Update indices
            _leaderboardIndex[userBelow] = userIndex;
            _leaderboardIndex[user] = userIndex + 1;

            userIndex++;
            endIndex = userIndex; // Track the range affected
        }

        // Update ranks for all affected users in the range that changed
        uint256 rangeStart = startIndex < endIndex ? startIndex : endIndex;
        uint256 rangeEnd = startIndex > endIndex ? startIndex : endIndex;

        for (uint256 i = rangeStart; i <= rangeEnd && i < _leaderboard.length; i++) {
            _userStats[_leaderboard[i]].currentRank = i + 1;
        }

        emit LeaderboardUpdated(user, userXP, _userStats[user].currentRank);
    }

    /**
     * @dev Emergency function to pause the contract
     */
    function pause() external onlyAdminOrManager  {
        _pause();
    }

    /**
     * @dev Emergency function to unpause the contract
     */
    function unpause() external onlyAdminOrManager  {
        _unpause();
    }

    /**
     * @dev Batch update XP for multiple users
     * @param users Array of user addresses
     * @param amounts Array of XP amounts (positive for award, negative for deduct)
     * @param reason Reason for XP change
     */
    function batchUpdateXP(address[] memory users, int256[] memory amounts, string memory reason)
        external
        onlyAdminOrManager nonReentrant
        whenNotPaused
    {
        require(users.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid address");
            require(_isRegistered[users[i]], "User not registered");

            UserStats storage stats = _userStats[users[i]];
            stats.lastActivityTimestamp = block.timestamp;

            if (amounts[i] > 0) {
                stats.totalXP += uint256(amounts[i]);
                emit XPAwarded(users[i], uint256(amounts[i]), reason);
            } else if (amounts[i] < 0) {
                uint256 deductAmount = uint256(-amounts[i]);
                if (stats.totalXP >= deductAmount) {
                    stats.totalXP -= deductAmount;
                } else {
                    stats.totalXP = 0;
                }
                emit XPDeducted(users[i], deductAmount, reason);
            }

            _updateLeaderboard(users[i]);
        }
    }
}
