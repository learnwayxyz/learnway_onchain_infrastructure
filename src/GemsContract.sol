// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title GemsContract
 * @dev Smart contract for managing non-transferable Gems tokens in the LearnWay application
 * Gems serve as the in-app currency and are earned through various activities
 */
contract GemsContract is Ownable, ReentrancyGuard, Pausable {

    // Events
    event GemsAwarded(address indexed user, uint256 amount, string reason);
    event GemsSpent(address indexed user, uint256 amount, string reason);
    event ReferralRegistered(address indexed referrer, address indexed referee, uint256 bonus);
    event QuizCompleted(address indexed user, uint256 score, uint256 gemsEarned);
    event ContestReward(address indexed user, uint256 amount, string contestType);
    event MonthlyLeaderboardReward(address indexed user, uint256 position, uint256 amount);

    // Constants for gem rewards
    uint256 public constant NEW_USER_SIGNUP_BONUS = 500;
    uint256 public constant REFERRAL_SIGNUP_BONUS = 50;
    uint256 public constant REFERRAL_BONUS = 100;
    uint256 public constant QUIZ_REWARD = 60;
    uint256 public constant MIN_QUIZ_SCORE = 70;

    // State variables
    mapping(address => uint256) private _balances;
    mapping(address => bool) private _hasSignupBonus;
    mapping(address => address) private _referrers;
    mapping(address => uint256) private _referralCount;
    mapping(address => bool) private _isRegistered;

    // Monthly leaderboard rewards
    mapping(uint256 => uint256) public monthlyLeaderboardRewards; // position => reward amount

    uint256 private _totalSupply;

    modifier onlyRegistered() {
        require(_isRegistered[msg.sender], "User not registered");
        _;
    }

    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    constructor() Ownable(msg.sender) {
        // Set monthly leaderboard rewards
        monthlyLeaderboardRewards[1] = 1000; // 1st place
        monthlyLeaderboardRewards[2] = 500;  // 2nd place
        monthlyLeaderboardRewards[3] = 250;  // 3rd place
    }

    /**
     * @dev Register a new user and award signup bonus
     * @param user Address of the new user
     * @param referralCode Address of the referrer (optional, can be address(0))
     */
    function registerUser(address user, address referralCode)
        external
        onlyOwner
        validAddress(user)
        whenNotPaused
    {
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
     * @dev Award gems for quiz completion
     * @param user Address of the user
     * @param score Quiz score (0-100)
     */
    function awardQuizGems(address user, uint256 score)
        external
        onlyOwner
        validAddress(user)
        onlyRegistered
        whenNotPaused
    {
        require(score <= 100, "Invalid score");

        if (score >= MIN_QUIZ_SCORE) {
            _balances[user] += QUIZ_REWARD;
            _totalSupply += QUIZ_REWARD;
            emit QuizCompleted(user, score, QUIZ_REWARD);
            emit GemsAwarded(user, QUIZ_REWARD, "Quiz completion reward");
        } else {
            emit QuizCompleted(user, score, 0);
        }
    }

    /**
     * @dev Award gems for contest participation or battle wins
     * @param user Address of the user
     * @param amount Amount of gems to award
     * @param contestType Type of contest/battle
     */
    function awardContestGems(address user, uint256 amount, string memory contestType)
        external
        onlyOwner
        validAddress(user)
        onlyRegistered
        whenNotPaused
    {
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
    function awardMonthlyLeaderboardReward(address user, uint256 position)
        external
        onlyOwner
        validAddress(user)
        onlyRegistered
        whenNotPaused
    {
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
    function spendGems(address user, uint256 amount, string memory reason)
        external
        onlyOwner
        validAddress(user)
        onlyRegistered
        whenNotPaused
    {
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
     * @dev Update monthly leaderboard rewards (only owner)
     * @param position Leaderboard position (1, 2, or 3)
     * @param reward New reward amount
     */
    function updateMonthlyLeaderboardReward(uint256 position, uint256 reward)
        external
        onlyOwner
    {
        require(position >= 1 && position <= 3, "Invalid position");
        monthlyLeaderboardRewards[position] = reward;
    }

    /**
     * @dev Emergency function to pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Emergency function to unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Batch award gems to multiple users
     * @param users Array of user addresses
     * @param amounts Array of gem amounts
     * @param reason Reason for awarding
     */
    function batchAwardGems(
        address[] memory users,
        uint256[] memory amounts,
        string memory reason
    ) external onlyOwner whenNotPaused {
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
}
