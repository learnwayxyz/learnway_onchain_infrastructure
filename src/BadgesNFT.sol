// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BadgesNFT
 * @dev NFT contract for managing achievement badges in the LearnWay ecosystem
 * Each badge represents a specific achievement milestone
 */
contract BadgesNFT is ERC721, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;

    // Badge types enum
    enum BadgeType {
        FIRST_SPARK,        // 0 - First public appearance (play quizZone first time)
        DUEL_CHAMPION,      // 1 - Won one battle (1 vs 1)
        SQUAD_SLAYER,       // 2 - Won one group battle
        CROWN_HOLDER,       // 3 - Won one contest
        LIGHTNING_ACE,      // 4 - Highest point gainer in battle
        QUIZ_WARRIOR,       // 5 - Won back to back 3 battles
        SUPERSONIC,         // 6 - Fastest puzzle solver (avg 25s for guess the word, min 5 questions)
        SPEED_SCHOLAR,      // 7 - Average solver (avg 8s for fun & learn, min 5 questions)
        BRAINIAC,           // 8 - 100% quiz without lifeline (min 5 questions)
        QUIZ_TITAN,         // 9 - 5000 correct answers
        ELITE,              // 10 - 5k coins in wallet
        QUIZ_DEVOTEE,       // 11 - 30 days daily quiz play
        POWER_ELITE,        // 12 - Achieved more than 10 badges
        ECHO_SPREADER,      // 13 - Share app to more than 50 people
        ROUTINE_MASTER      // 14 - Maintain streak for 30 days
    }

    // Badge information struct
    struct BadgeInfo {
        string name;
        string description;
        string imageURI;
        bool isActive;
    }

    // User badge tracking
    struct UserBadgeData {
        mapping(BadgeType => bool) hasBadge;
        uint256 totalBadges;

        // Specific tracking for complex badges
        uint256 consecutiveWins;
        uint256 maxConsecutiveWins;
        uint256 dailyStreakCount;
        uint256 lastQuizDate;
        uint256 totalCorrectAnswers;
        uint256 referralCount;

        // Quiz performance tracking
        mapping(string => uint256) quizTypeCount; // "guess_word", "fun_learn"
        mapping(string => uint256) quizTypeTotalTime; // Total time spent on quiz type
        mapping(string => bool) perfectQuizzes; // Track 100% quizzes without lifeline
        uint256 perfectQuizCount;

        // Battle performance
        uint256 highestBattlePoints;
        bool hasWonDuel;
        bool hasWonGroupBattle;
        bool hasWonContest;
    }

    // Events
    event BadgeMinted(address indexed user, BadgeType badgeType, uint256 tokenId);
    event BadgeDataUpdated(address indexed user, string dataType, uint256 value);

    // State variables
    mapping(BadgeType => BadgeInfo) public badgeInfo;
    mapping(address => UserBadgeData) private userBadgeData;
    mapping(uint256 => BadgeType) public tokenToBadgeType;

    // Separate mappings for simple fields that need reliable storage
    mapping(address => uint256) private userDailyStreak;
    mapping(address => uint256) private userLastQuizDate;
    mapping(address => uint256) private userTotalCorrectAnswers;
    mapping(address => uint256) private userTotalBadges;
    mapping(address => uint256) private userConsecutiveWins;
    mapping(address => uint256) private userReferralCount;

    uint256 private _nextTokenId = 1;
    string private _baseTokenURI;

    // Contract addresses
    address public learnWayManager;

    modifier onlyManager() {
        require(msg.sender == learnWayManager || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validAddress(address user) {
        require(user != address(0), "Invalid address");
        _;
    }

    constructor(string memory baseURI) ERC721("LearnWay Badges", "LWB") Ownable(msg.sender) {
        _baseTokenURI = baseURI;
        _initializeBadges();
    }

    /**
     * @dev Set the LearnWay Manager contract address
     */
    function setLearnWayManager(address _manager) external onlyOwner {
        require(_manager != address(0), "Invalid manager address");
        learnWayManager = _manager;
    }

    /**
     * @dev Initialize all badge types with their metadata
     */
    function _initializeBadges() internal {
        badgeInfo[BadgeType.FIRST_SPARK] = BadgeInfo({
            name: "First Spark",
            description: "First public appearance - Play quizZone first time",
            imageURI: "first_spark.json",
            isActive: true
        });

        badgeInfo[BadgeType.DUEL_CHAMPION] = BadgeInfo({
            name: "Duel Champion",
            description: "Won one battle (1 vs 1). Winner must be declared by completing the battle.",
            imageURI: "duel_champion.json",
            isActive: true
        });

        badgeInfo[BadgeType.SQUAD_SLAYER] = BadgeInfo({
            name: "Squad Slayer",
            description: "Won one group battle. Winner must be declared by completing the battle.",
            imageURI: "squad_slayer.json",
            isActive: true
        });

        badgeInfo[BadgeType.CROWN_HOLDER] = BadgeInfo({
            name: "Crown Holder",
            description: "Won one contest",
            imageURI: "crown_holder.json",
            isActive: true
        });

        badgeInfo[BadgeType.LIGHTNING_ACE] = BadgeInfo({
            name: "Lightning Ace",
            description: "Highest point gainer in battle (1 vs 1). Winner must be declared by completing the battle.",
            imageURI: "lightning_ace.json",
            isActive: true
        });

        badgeInfo[BadgeType.QUIZ_WARRIOR] = BadgeInfo({
            name: "Quiz Warrior",
            description: "Won back to back 3 battles. Winner must be declared by completing the battle.",
            imageURI: "quiz_warrior.json",
            isActive: true
        });

        badgeInfo[BadgeType.SUPERSONIC] = BadgeInfo({
            name: "SuperSonic - Fastest Puzzle Solver",
            description: "Average time to solve one guess the word quiz question (25 seconds). Need minimum 5 questions to unlock",
            imageURI: "supersonic.json",
            isActive: true
        });

        badgeInfo[BadgeType.SPEED_SCHOLAR] = BadgeInfo({
            name: "Speed Scholar - Average",
            description: "Time to solve one fun & learn quiz question (8 seconds). Need minimum 5 questions to unlock",
            imageURI: "speed_scholar.json",
            isActive: true
        });

        badgeInfo[BadgeType.BRAINIAC] = BadgeInfo({
            name: "Brainiac",
            description: "Completed 100% quiz without using lifeline. Need minimum 5 questions to unlock",
            imageURI: "brainiac.json",
            isActive: true
        });

        badgeInfo[BadgeType.QUIZ_TITAN] = BadgeInfo({
            name: "Quiz Titan",
            description: "5000 correct answers",
            imageURI: "quiz_titan.json",
            isActive: true
        });

        badgeInfo[BadgeType.ELITE] = BadgeInfo({
            name: "Elite",
            description: "5k coins in wallet",
            imageURI: "elite.json",
            isActive: true
        });

        badgeInfo[BadgeType.QUIZ_DEVOTEE] = BadgeInfo({
            name: "Quiz Devotee",
            description: "30 days daily quiz play",
            imageURI: "quiz_devotee.json",
            isActive: true
        });

        badgeInfo[BadgeType.POWER_ELITE] = BadgeInfo({
            name: "Power Elite",
            description: "Achieved more than 10 badges",
            imageURI: "power_elite.json",
            isActive: true
        });

        badgeInfo[BadgeType.ECHO_SPREADER] = BadgeInfo({
            name: "Echo Spreader",
            description: "Share app to more than 50 people",
            imageURI: "echo_spreader.json",
            isActive: true
        });

        badgeInfo[BadgeType.ROUTINE_MASTER] = BadgeInfo({
            name: "Routine Master",
            description: "Maintain streak for 30 days",
            imageURI: "routine_master.json",
            isActive: true
        });
    }

    /**
     * @dev Record quiz completion for badge tracking
     */
    function recordQuizCompletion(
        address user,
        string memory quizType,
        uint256 timeTaken,
        bool usedLifeline,
        bool allCorrect,
        uint256 correctCount
    ) external onlyManager validAddress(user) {
        UserBadgeData storage userData = userBadgeData[user];

        // Update total correct answers using separate mapping
        userTotalCorrectAnswers[user] += correctCount;

        // Update daily streak using separate mappings for reliable storage
        uint256 today = block.timestamp / 1 days;
        uint256 lastQuizDate = userLastQuizDate[user];

        if (lastQuizDate == 0 && userDailyStreak[user] == 0) {
            // First time playing (never played before)
            userDailyStreak[user] = 1;
            userLastQuizDate[user] = today;
        } else if (today == lastQuizDate + 1) {
            // Next consecutive day
            userDailyStreak[user]++;
            userLastQuizDate[user] = today;
        } else if (today > lastQuizDate + 1) {
            // Gap in days - reset streak
            userDailyStreak[user] = 1;
            userLastQuizDate[user] = today;
        }
        // Same day - no change needed

        // Track quiz type performance
        userData.quizTypeCount[quizType]++;
        userData.quizTypeTotalTime[quizType] += timeTaken;

        // Track perfect quizzes without lifeline
        if (allCorrect && !usedLifeline) {
            string memory perfectKey = string(abi.encodePacked(quizType, "_", Strings.toString(block.timestamp)));
            userData.perfectQuizzes[perfectKey] = true;
            userData.perfectQuizCount++;
        }

        emit BadgeDataUpdated(user, "quiz_completion", correctCount);

        // Check for badges
        _checkAndAwardBadges(user);
    }

    /**
     * @dev Record battle completion for badge tracking
     */
    function recordBattleCompletion(
        address user,
        string memory battleType,
        bool isWin,
        uint256 points,
        bool isHighestScore
    ) external onlyManager validAddress(user) {
        UserBadgeData storage userData = userBadgeData[user];

        if (isWin) {
            userConsecutiveWins[user]++;
            if (userConsecutiveWins[user] > userData.maxConsecutiveWins) {
                userData.maxConsecutiveWins = userConsecutiveWins[user];
            }

            // Track battle type wins
            if (keccak256(bytes(battleType)) == keccak256(bytes("1v1"))) {
                userData.hasWonDuel = true;
                if (isHighestScore && points > userData.highestBattlePoints) {
                    userData.highestBattlePoints = points;
                }
            } else if (keccak256(bytes(battleType)) == keccak256(bytes("group"))) {
                userData.hasWonGroupBattle = true;
            }
        } else {
            userConsecutiveWins[user] = 0; // Reset consecutive wins on loss
        }

        emit BadgeDataUpdated(user, "battle_completion", isWin ? 1 : 0);

        // Check for badges
        _checkAndAwardBadges(user);
    }

    /**
     * @dev Record contest win for badge tracking
     */
    function recordContestWin(address user) external onlyManager validAddress(user) {
        UserBadgeData storage userData = userBadgeData[user];
        userData.hasWonContest = true;

        emit BadgeDataUpdated(user, "contest_win", 1);

        // Check for badges
        _checkAndAwardBadges(user);
    }

    /**
     * @dev Update referral count for badge tracking
     */
    function updateReferralCount(address user, uint256 count) external onlyManager validAddress(user) {
        UserBadgeData storage userData = userBadgeData[user];
        userReferralCount[user] = count;

        emit BadgeDataUpdated(user, "referral_count", count);

        // Check for badges
        _checkAndAwardBadges(user);
    }

    /**
     * @dev Check and award badges based on current user data
     */
    function _checkAndAwardBadges(address user) internal {
        UserBadgeData storage userData = userBadgeData[user];

        // Check each badge type
        _checkFirstSpark(user, userData);
        _checkDuelChampion(user, userData);
        _checkSquadSlayer(user, userData);
        _checkCrownHolder(user, userData);
        _checkLightningAce(user, userData);
        _checkQuizWarrior(user, userData);
        _checkSupersonic(user, userData);
        _checkSpeedScholar(user, userData);
        _checkBrainiac(user, userData);
        _checkQuizTitan(user, userData);
        _checkElite(user, userData);
        _checkQuizDevotee(user, userData);
        _checkEchoSpreader(user, userData);
        _checkRoutineMaster(user, userData);
        _checkPowerElite(user, userData); // Check this last as it depends on total badges
    }

    /**
     * @dev Check and award First Spark badge (first quiz completion)
     */
    function _checkFirstSpark(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.FIRST_SPARK] && userTotalCorrectAnswers[user] > 0) {
            _awardBadge(user, BadgeType.FIRST_SPARK);
        }
    }

    /**
     * @dev Check and award Duel Champion badge (won 1v1 battle)
     */
    function _checkDuelChampion(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.DUEL_CHAMPION] && userData.hasWonDuel) {
            _awardBadge(user, BadgeType.DUEL_CHAMPION);
        }
    }

    /**
     * @dev Check and award Squad Slayer badge (won group battle)
     */
    function _checkSquadSlayer(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.SQUAD_SLAYER] && userData.hasWonGroupBattle) {
            _awardBadge(user, BadgeType.SQUAD_SLAYER);
        }
    }

    /**
     * @dev Check and award Crown Holder badge (won contest)
     */
    function _checkCrownHolder(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.CROWN_HOLDER] && userData.hasWonContest) {
            _awardBadge(user, BadgeType.CROWN_HOLDER);
        }
    }

    /**
     * @dev Check and award Lightning Ace badge (highest points in 1v1)
     */
    function _checkLightningAce(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.LIGHTNING_ACE] && userData.highestBattlePoints > 0) {
            // This badge is awarded when user gets highest score in a battle (tracked in recordBattleCompletion)
            _awardBadge(user, BadgeType.LIGHTNING_ACE);
        }
    }

    /**
     * @dev Check and award Quiz Warrior badge (3 consecutive wins)
     */
    function _checkQuizWarrior(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.QUIZ_WARRIOR] && userData.maxConsecutiveWins >= 3) {
            _awardBadge(user, BadgeType.QUIZ_WARRIOR);
        }
    }

    /**
     * @dev Check and award Supersonic badge (avg 25s for guess word, min 5 questions)
     */
    function _checkSupersonic(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.SUPERSONIC] &&
            userData.quizTypeCount["guess_word"] >= 5) {

            uint256 avgTime = userData.quizTypeTotalTime["guess_word"] / userData.quizTypeCount["guess_word"];
            if (avgTime <= 25) {
                _awardBadge(user, BadgeType.SUPERSONIC);
            }
        }
    }

    /**
     * @dev Check and award Speed Scholar badge (avg 8s for fun & learn, min 5 questions)
     */
    function _checkSpeedScholar(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.SPEED_SCHOLAR] &&
            userData.quizTypeCount["fun_learn"] >= 5) {

            uint256 avgTime = userData.quizTypeTotalTime["fun_learn"] / userData.quizTypeCount["fun_learn"];
            if (avgTime <= 8) {
                _awardBadge(user, BadgeType.SPEED_SCHOLAR);
            }
        }
    }

    /**
     * @dev Check and award Brainiac badge (100% quiz without lifeline, min 5)
     */
    function _checkBrainiac(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.BRAINIAC] && userData.perfectQuizCount >= 5) {
            _awardBadge(user, BadgeType.BRAINIAC);
        }
    }

    /**
     * @dev Check and award Quiz Titan badge (5000 correct answers)
     */
    function _checkQuizTitan(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.QUIZ_TITAN] && userTotalCorrectAnswers[user] >= 5000) {
            _awardBadge(user, BadgeType.QUIZ_TITAN);
        }
    }

    /**
     * @dev Check and award Elite badge (5k coins in wallet)
     * This requires external call to GemsContract
     */
    function _checkElite(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.ELITE]) {
            // This will be checked by LearnWayManager when it has access to GemsContract
            // For now, we'll implement a manual trigger
        }
    }

    /**
     * @dev Manually award Elite badge (called by LearnWayManager with gems check)
     */
    function awardEliteBadge(address user) external onlyManager {
        UserBadgeData storage userData = userBadgeData[user];
        if (!userData.hasBadge[BadgeType.ELITE]) {
            _awardBadge(user, BadgeType.ELITE);
            // Check for additional badges that might be unlocked (like Power Elite)
            _checkAndAwardBadges(user);
        }
    }

    /**
     * @dev Check and award Quiz Devotee badge (30 days daily play)
     */
    function _checkQuizDevotee(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.QUIZ_DEVOTEE] && userDailyStreak[user] >= 30) {
            _awardBadge(user, BadgeType.QUIZ_DEVOTEE);
        }
    }

    /**
     * @dev Check and award Echo Spreader badge (50+ referrals)
     */
    function _checkEchoSpreader(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.ECHO_SPREADER] && userReferralCount[user] >= 50) {
            _awardBadge(user, BadgeType.ECHO_SPREADER);
        }
    }

    /**
     * @dev Check and award Routine Master badge (30 day streak)
     */
    function _checkRoutineMaster(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.ROUTINE_MASTER] && userDailyStreak[user] >= 30) {
            _awardBadge(user, BadgeType.ROUTINE_MASTER);
        }
    }

    /**
     * @dev Check and award Power Elite badge (10+ badges)
     */
    function _checkPowerElite(address user, UserBadgeData storage userData) internal {
        if (!userData.hasBadge[BadgeType.POWER_ELITE] && userTotalBadges[user] >= 10) {
            _awardBadge(user, BadgeType.POWER_ELITE);
        }
    }

    /**
     * @dev Internal function to award a badge
     */
    function _awardBadge(address user, BadgeType badgeType) internal {
        UserBadgeData storage userData = userBadgeData[user];

        if (!userData.hasBadge[badgeType] && badgeInfo[badgeType].isActive) {
            uint256 tokenId = _nextTokenId++;
            userData.hasBadge[badgeType] = true;
            userTotalBadges[user]++;
            tokenToBadgeType[tokenId] = badgeType;

            _safeMint(user, tokenId);
            emit BadgeMinted(user, badgeType, tokenId);
        }
    }

    /**
     * @dev Get user's badge status
     */
    function getUserBadgeStatus(address user) external view returns (
        bool[15] memory badges,
        uint256 totalBadges,
        uint256 consecutiveWins,
        uint256 dailyStreak,
        uint256 correctAnswers
    ) {
        UserBadgeData storage userData = userBadgeData[user];

        for (uint256 i = 0; i < 15; i++) {
            badges[i] = userData.hasBadge[BadgeType(i)];
        }

        return (
            badges,
            userTotalBadges[user],
            userConsecutiveWins[user],
            userDailyStreak[user],
            userTotalCorrectAnswers[user]
        );
    }

    /**
     * @dev Get badges owned by a user
     */
    function getUserBadges(address user) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory badges = new uint256[](balance);

        uint256 index = 0;
        for (uint256 i = 1; i < _nextTokenId; i++) {
            if (_ownerOf(i) != address(0) && ownerOf(i) == user) {
                badges[index] = i;
                index++;
            }
        }

        return badges;
    }

    /**
     * @dev Get badge information
     */
    function getBadgeInfo(BadgeType badgeType) external view returns (BadgeInfo memory) {
        return badgeInfo[badgeType];
    }

    /**
     * @dev Override tokenURI to return metadata
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "URI query for nonexistent token");

        BadgeType badgeType = tokenToBadgeType[tokenId];
        return string(abi.encodePacked(_baseTokenURI, badgeInfo[badgeType].imageURI));
    }

    /**
     * @dev Set base URI for metadata
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Emergency pause functionality
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause functionality
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Override _update to prevent transfers (soulbound tokens)
     * This is the internal function called by all transfer methods
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);

        // Allow minting (from == address(0)) but prevent transfers
        if (from != address(0) && to != address(0)) {
            revert("Badges are non-transferable");
        }

        return super._update(to, tokenId, auth);
    }
}
