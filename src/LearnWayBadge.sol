// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interface/ILearnWayAdmin.sol";

/**
 * @title LearnWayBadge
 * @dev Upgradeable NFT contract for LearnWay badges with dynamic on-chain metadata
 * Integrates with central LearnWayAdmin for access control
 */
contract LearnWayBadge is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, UUPSUpgradeable {
    using Strings for uint256;

    ILearnWayAdmin public adminContract;
    uint256 private _tokenIdCounter;

    // Badge Categories
    enum BadgeCategory {
        ONBOARDING,
        QUIZ_COMPLETION,
        STREAKS_CONSISTENCY,
        BATTLES_CONTESTS,
        SKILL_MASTERY,
        COMMUNITY_SHARING,
        ULTIMATE
    }

    // Badge Tier for dynamic badges
    enum BadgeTier {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM,
        DIAMOND
    }

    // Core badge definition
    struct Badge {
        string name;
        BadgeCategory category;
        string emoji;
        bool isDynamic;
        uint256 maxSupply;
        uint256 currentSupply;
    }

    // Dynamic badge attributes stored on-chain
    struct BadgeAttributes {
        BadgeTier tier;
        uint256 progress;
        uint256 maxProgress;
        string status;
        uint256 lastUpdated;
    }

    // User stats for badge calculations
    struct UserStats {
        uint256 totalQuizzes;
        uint256 correctAnswers;
        uint256 currentLevel;
        uint256 dailyStreak;
        uint256 contestsWon;
        uint256 battlesWon;
        uint256 gemsCollected;
        uint256 transactionsCompleted;
        uint256 depositsCompleted;
        uint256 sharesCompleted;
        uint256 referrals;
        bool kycCompleted;
        bool hasFirstDeposit;
        bool attendedEvent;
        uint256 totalBadgesEarned;
    }

    // Mappings
    mapping(uint256 => Badge) public badges;
    mapping(address => UserStats) public userStats;
    mapping(address => mapping(uint256 => bool)) public userHasBadge;
    mapping(address => mapping(uint256 => uint256)) public userBadgeTokenId;
    mapping(uint256 => BadgeAttributes) public tokenAttributes;
    mapping(address => uint256[]) public userBadgeList;

    uint256 public constant MAX_EARLY_BIRD_SPOTS = 1000;
    uint256 public earlyBirdCount;
    string public baseTokenURI;

    // Events
    event BadgeEarned(address indexed user, uint256 indexed badgeId, uint256 tokenId, BadgeTier tier);
    event BadgeUpgraded(address indexed user, uint256 indexed badgeId, uint256 tokenId, BadgeTier newTier);
    // event MetadataUpdate(uint256 tokenId); // ERC-4906 compliant

    modifier onlyAdmin() {
        adminContract.checkAdmin();
        _;
    }

    modifier onlyAdminOrManager() {
        adminContract.checkAdminOrManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _adminContract) external initializer {
        __ERC721_init("LearnWay Badge", "LWB");
        __ERC721URIStorage_init();
        __UUPSUpgradeable_init();

        adminContract = ILearnWayAdmin(_adminContract);
        _tokenIdCounter = 1;
        _initializeBadges();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /**
     * @dev Initialize all 24 badge types efficiently
     */
    function _initializeBadges() internal {
        string[24] memory names = [
            "Keyholder",
            "First Spark",
            "Early Bird",
            "Quiz Explorer",
            "Master of Levels",
            "Quiz Titan",
            "BRAINIAC",
            "Legend",
            "Daily Claims",
            "Routine Master",
            "Quiz Devotee",
            "Elite",
            "Duel Champion",
            "Squad Slayer",
            "Crown Holder",
            "Rising Star",
            "DeFi Voyager",
            "Savings Champion",
            "Power Elite",
            "Community Connector",
            "Echo Spreader",
            "Event Star",
            "Grandmaster",
            "Hall of Famer"
        ];

        string[24] memory emojis = [
            unicode"🎉",
            unicode"🔥",
            unicode"🧭",
            unicode"🗺️",
            unicode"🎮",
            unicode"🧠",
            unicode"🧩",
            unicode"🏆",
            unicode"📅",
            unicode"🕒",
            unicode"🙌",
            unicode"💎",
            unicode"🥇",
            unicode"🛡️",
            unicode"👑",
            unicode"🪙",
            unicode"🌐",
            unicode"💸",
            unicode"🏆",
            unicode"🤝",
            unicode"📢",
            unicode"🎤",
            unicode"🧙🏾‍♂️",
            unicode"🌟"
        ];

        BadgeCategory[24] memory categories = [
            BadgeCategory.ONBOARDING,
            BadgeCategory.ONBOARDING,
            BadgeCategory.ONBOARDING,
            BadgeCategory.QUIZ_COMPLETION,
            BadgeCategory.QUIZ_COMPLETION,
            BadgeCategory.QUIZ_COMPLETION,
            BadgeCategory.QUIZ_COMPLETION,
            BadgeCategory.QUIZ_COMPLETION,
            BadgeCategory.STREAKS_CONSISTENCY,
            BadgeCategory.STREAKS_CONSISTENCY,
            BadgeCategory.STREAKS_CONSISTENCY,
            BadgeCategory.STREAKS_CONSISTENCY,
            BadgeCategory.BATTLES_CONTESTS,
            BadgeCategory.BATTLES_CONTESTS,
            BadgeCategory.BATTLES_CONTESTS,
            BadgeCategory.SKILL_MASTERY,
            BadgeCategory.SKILL_MASTERY,
            BadgeCategory.SKILL_MASTERY,
            BadgeCategory.SKILL_MASTERY,
            BadgeCategory.COMMUNITY_SHARING,
            BadgeCategory.COMMUNITY_SHARING,
            BadgeCategory.COMMUNITY_SHARING,
            BadgeCategory.ULTIMATE,
            BadgeCategory.ULTIMATE
        ];

        bool[24] memory isDynamic = [
            true,
            false,
            false, // Onboarding
            true,
            true,
            true,
            true,
            true, // Quiz
            true,
            false,
            false,
            true, // Streaks
            false,
            false,
            false, // Battles
            false,
            true,
            true,
            true, // Skill
            false,
            true,
            false, // Community
            false,
            false // Ultimate
        ];

        uint256[24] memory maxSupplies =
            [0, 0, MAX_EARLY_BIRD_SPOTS, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1];

        for (uint256 i = 0; i < 24; i++) {
            badges[i] = Badge({
                name: names[i],
                category: categories[i],
                emoji: emojis[i],
                isDynamic: isDynamic[i],
                maxSupply: maxSupplies[i],
                currentSupply: 0
            });
        }
    }

    function registerUser(address user, bool kycStatus) external onlyAdminOrManager {
        require(userStats[user].totalBadgesEarned == 0, "User already registered");

        userStats[user].kycCompleted = kycStatus;
        _awardBadge(user, 0, kycStatus ? BadgeTier.GOLD : BadgeTier.SILVER);

        if (earlyBirdCount < MAX_EARLY_BIRD_SPOTS) {
            earlyBirdCount++;
            _awardBadge(user, 2, BadgeTier.BRONZE);
        }
    }

    function updateUserStats(address user, uint256 statType, uint256[] calldata values) external onlyAdminOrManager {
        UserStats storage stats = userStats[user];

        if (statType == 0) {
            // Quiz stats
            bool isFirstQuiz = stats.totalQuizzes == 0;
            stats.totalQuizzes += values[0];
            stats.correctAnswers += values[1];
            if (values[2] > stats.currentLevel) stats.currentLevel = values[2];

            if (isFirstQuiz) _awardBadge(user, 1, BadgeTier.BRONZE);
            _checkAndUpdateQuizBadges(user);
        } else if (statType == 1) {
            // Streak
            stats.dailyStreak = values[0];
            _checkAndUpdateStreakBadges(user);
        } else if (statType == 2) {
            // Battle/Contest
            if (values[0] > 0) stats.battlesWon += values[0];
            if (values[1] > 0) stats.contestsWon += values[1];
            _checkBattleBadges(user);
        } else if (statType == 3) {
            // Financial
            if (values[0] > 0 && !stats.hasFirstDeposit) {
                stats.hasFirstDeposit = true;
                _awardBadge(user, 15, BadgeTier.BRONZE);
            }
            stats.depositsCompleted += values[0];
            stats.transactionsCompleted += values[1];
            _checkFinancialBadges(user);
        } else if (statType == 4) {
            // Community
            stats.referrals += values[0];
            stats.sharesCompleted += values[1];
            if (values[2] > 0) stats.attendedEvent = true;
            _checkCommunityBadges(user);
        } else if (statType == 5) {
            // Gems
            stats.gemsCollected += values[0];
            _updateDynamicBadge(user, 11);
        }
    }

    function _awardBadge(address user, uint256 badgeId, BadgeTier tier) internal {
        require(badgeId < 24, "Invalid badge ID");
        require(!userHasBadge[user][badgeId], "Badge already owned");

        Badge storage badge = badges[badgeId];
        if (badge.maxSupply > 0 && badge.currentSupply >= badge.maxSupply) return;

        uint256 tokenId = _tokenIdCounter++;
        _mint(user, tokenId);

        badge.currentSupply++;
        userHasBadge[user][badgeId] = true;
        userBadgeTokenId[user][badgeId] = tokenId;
        userBadgeList[user].push(badgeId);
        userStats[user].totalBadgesEarned++;

        (uint256 progress, uint256 maxProgress, string memory status) = _getBadgeAttributes(user, badgeId, tier);
        tokenAttributes[tokenId] = BadgeAttributes({
            tier: tier,
            progress: progress,
            maxProgress: maxProgress,
            status: status,
            lastUpdated: block.timestamp
        });

        emit BadgeEarned(user, badgeId, tokenId, tier);

        if (userStats[user].totalBadgesEarned >= 10 && !userHasBadge[user][18]) {
            _awardBadge(user, 18, BadgeTier.BRONZE);
        }
    }

    function _updateDynamicBadge(address user, uint256 badgeId) internal {
        if (!userHasBadge[user][badgeId]) {
            BadgeTier initialTier = _calculateBadgeTier(user, badgeId);
            if (initialTier != BadgeTier.BRONZE || _shouldAwardBadge(user, badgeId)) {
                _awardBadge(user, badgeId, initialTier);
            }
            return;
        }

        if (!badges[badgeId].isDynamic) return;

        uint256 tokenId = userBadgeTokenId[user][badgeId];
        BadgeAttributes storage attrs = tokenAttributes[tokenId];
        BadgeTier newTier = _calculateBadgeTier(user, badgeId);

        if (newTier > attrs.tier) {
            attrs.tier = newTier;
            (attrs.progress, attrs.maxProgress, attrs.status) = _getBadgeAttributes(user, badgeId, newTier);
            attrs.lastUpdated = block.timestamp;

            emit BadgeUpgraded(user, badgeId, tokenId, newTier);
            emit MetadataUpdate(tokenId);
        }
    }

    function _calculateBadgeTier(address user, uint256 badgeId) internal view returns (BadgeTier) {
        UserStats storage stats = userStats[user];

        if (badgeId == 0) return stats.kycCompleted ? BadgeTier.GOLD : BadgeTier.SILVER;
        if (badgeId == 3) {
            if (stats.totalQuizzes >= 1000) return BadgeTier.GOLD;
            if (stats.totalQuizzes >= 500) return BadgeTier.SILVER;
            return BadgeTier.BRONZE;
        }
        if (badgeId == 4) {
            if (stats.currentLevel >= 100) return BadgeTier.GOLD;
            if (stats.currentLevel >= 50) return BadgeTier.SILVER;
            return BadgeTier.BRONZE;
        }
        if (badgeId == 5) {
            if (stats.correctAnswers >= 1000) return BadgeTier.GOLD;
            if (stats.correctAnswers >= 500) return BadgeTier.SILVER;
            return BadgeTier.BRONZE;
        }
        if (badgeId == 8) {
            if (stats.dailyStreak >= 180) return BadgeTier.DIAMOND;
            if (stats.dailyStreak >= 90) return BadgeTier.GOLD;
            if (stats.dailyStreak >= 30) return BadgeTier.SILVER;
            return BadgeTier.BRONZE;
        }
        if (badgeId == 11) {
            if (stats.gemsCollected >= 10000) return BadgeTier.DIAMOND;
            if (stats.gemsCollected >= 5000) return BadgeTier.PLATINUM;
            if (stats.gemsCollected >= 3000) return BadgeTier.GOLD;
            return BadgeTier.SILVER;
        }

        return BadgeTier.BRONZE;
    }

    function _getBadgeAttributes(address user, uint256 badgeId, BadgeTier tier)
        internal
        view
        returns (uint256 progress, uint256 maxProgress, string memory status)
    {
        UserStats storage stats = userStats[user];

        if (badgeId == 3) {
            progress = stats.totalQuizzes;
            maxProgress = tier == BadgeTier.GOLD ? 1000 : (tier == BadgeTier.SILVER ? 500 : 100);
            status = tier == BadgeTier.GOLD
                ? "Master Explorer"
                : (tier == BadgeTier.SILVER ? "Advanced Explorer" : "Explorer");
        } else if (badgeId == 8) {
            progress = stats.dailyStreak;
            maxProgress =
                tier == BadgeTier.DIAMOND ? 365 : (tier == BadgeTier.GOLD ? 180 : (tier == BadgeTier.SILVER ? 90 : 30));
            status = tier == BadgeTier.DIAMOND
                ? "Legendary Streak"
                : (tier == BadgeTier.GOLD ? "Golden Streak" : "Active Streak");
        } else if (badgeId == 11) {
            progress = stats.gemsCollected;
            maxProgress = tier == BadgeTier.DIAMOND ? 50000 : (tier == BadgeTier.PLATINUM ? 10000 : 5000);
            status =
                tier == BadgeTier.DIAMOND ? "Diamond Elite" : (tier == BadgeTier.PLATINUM ? "Platinum Elite" : "Elite");
        } else {
            progress = 1;
            maxProgress = 1;
            status = "Earned";
        }
    }

    /**
     * @dev Override tokenURI to return dynamic on-chain metadata
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        string memory customURI = ERC721URIStorageUpgradeable.tokenURI(tokenId);

        // If admin has set a custom URI, use it
        if (bytes(customURI).length > 0) {
            return customURI;
        }

        // Generate dynamic on-chain metadata
        return _generateMetadata(tokenId);
    }

    /**
     * @dev Generate dynamic JSON metadata with attributes
     */
    function _generateMetadata(uint256 tokenId) internal view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        (uint256 badgeId, address owner) = _findBadgeIdByTokenId(tokenId);
        Badge storage badge = badges[badgeId];
        BadgeAttributes storage attrs = tokenAttributes[tokenId];

        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                badge.name,
                " ",
                badge.emoji,
                '",',
                '"description":"',
                _getDescription(badgeId, attrs.tier, attrs.progress),
                '",',
                '"image":"',
                baseTokenURI,
                badgeId.toString(),
                "_",
                uint256(attrs.tier).toString(),
                '.png",',
                '"attributes":['
            )
        );

        json = string(
            abi.encodePacked(
                json,
                '{"trait_type":"Category","value":"',
                _getCategoryName(badge.category),
                '"},',
                '{"trait_type":"Tier","value":"',
                _getTierName(attrs.tier),
                '"},',
                '{"trait_type":"Status","value":"',
                attrs.status,
                '"},',
                '{"trait_type":"Progress","value":',
                attrs.progress.toString(),
                "},",
                '{"trait_type":"Max Progress","value":',
                attrs.maxProgress.toString(),
                "},",
                '{"trait_type":"Last Updated","value":',
                attrs.lastUpdated.toString(),
                "},",
                '{"trait_type":"Badge ID","value":',
                badgeId.toString(),
                "}",
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function _getDescription(uint256 badgeId, BadgeTier tier, uint256 progress) internal pure returns (string memory) {
        if (badgeId == 0) return tier == BadgeTier.GOLD ? "Verified LearnWay member" : "Basic LearnWay member";
        if (badgeId == 3) return string(abi.encodePacked("Completed ", progress.toString(), " quizzes"));
        if (badgeId == 8) return string(abi.encodePacked(progress.toString(), " day streak"));
        if (badgeId == 11) return string(abi.encodePacked(progress.toString(), " gems collected"));
        return "LearnWay achievement badge";
    }

    function _findBadgeIdByTokenId(uint256 tokenId) internal view returns (uint256 badgeId, address owner) {
        owner = _ownerOf(tokenId);
        uint256[] storage userBadges = userBadgeList[owner];
        for (uint256 i = 0; i < userBadges.length; i++) {
            if (userBadgeTokenId[owner][userBadges[i]] == tokenId) {
                return (userBadges[i], owner);
            }
        }
        revert("Badge not found");
    }

    function _getCategoryName(BadgeCategory category) internal pure returns (string memory) {
        if (category == BadgeCategory.ONBOARDING) return "Onboarding";
        if (category == BadgeCategory.QUIZ_COMPLETION) return "Quiz Completion";
        if (category == BadgeCategory.STREAKS_CONSISTENCY) return "Streaks & Consistency";
        if (category == BadgeCategory.BATTLES_CONTESTS) return "Battles & Contests";
        if (category == BadgeCategory.SKILL_MASTERY) return "Skill Mastery";
        if (category == BadgeCategory.COMMUNITY_SHARING) return "Community & Sharing";
        return "Ultimate";
    }

    function _getTierName(BadgeTier tier) internal pure returns (string memory) {
        if (tier == BadgeTier.DIAMOND) return "Diamond";
        if (tier == BadgeTier.PLATINUM) return "Platinum";
        if (tier == BadgeTier.GOLD) return "Gold";
        if (tier == BadgeTier.SILVER) return "Silver";
        return "Bronze";
    }

    // Badge checking functions (simplified for gas efficiency)
    function _shouldAwardBadge(address user, uint256 badgeId) internal view returns (bool) {
        UserStats storage stats = userStats[user];
        if (badgeId == 3) return stats.totalQuizzes >= 100;
        if (badgeId == 4) return stats.currentLevel >= 10;
        if (badgeId == 5) return stats.correctAnswers >= 100;
        if (badgeId == 8) return stats.dailyStreak >= 30;
        if (badgeId == 11) return stats.gemsCollected >= 1000;
        if (badgeId == 16) return stats.transactionsCompleted >= 3;
        if (badgeId == 17) return stats.depositsCompleted >= 1;
        if (badgeId == 20) return stats.sharesCompleted >= 1;
        return false;
    }

    function _checkAndUpdateQuizBadges(address user) internal {
        _updateDynamicBadge(user, 3);
        _updateDynamicBadge(user, 4);
        _updateDynamicBadge(user, 5);
    }

    function _checkAndUpdateStreakBadges(address user) internal {
        UserStats storage stats = userStats[user];
        _updateDynamicBadge(user, 8);

        if (stats.dailyStreak >= 30 && !userHasBadge[user][9]) {
            _awardBadge(user, 9, BadgeTier.BRONZE);
        }
        if (stats.dailyStreak >= 60 && !userHasBadge[user][10]) {
            _awardBadge(user, 10, BadgeTier.BRONZE);
        }
    }

    function _checkBattleBadges(address user) internal {
        UserStats storage stats = userStats[user];
        if (stats.battlesWon >= 15 && !userHasBadge[user][12]) {
            _awardBadge(user, 12, BadgeTier.BRONZE);
        }
        if (stats.contestsWon >= 3 && !userHasBadge[user][14]) {
            _awardBadge(user, 14, BadgeTier.BRONZE);
        }
    }

    function _checkFinancialBadges(address user) internal {
        _updateDynamicBadge(user, 16);
        _updateDynamicBadge(user, 17);
    }

    function _checkCommunityBadges(address user) internal {
        UserStats storage stats = userStats[user];
        if (stats.referrals > 0 && !userHasBadge[user][19]) {
            _awardBadge(user, 19, BadgeTier.BRONZE);
        }
        _updateDynamicBadge(user, 20);
        if (stats.attendedEvent && !userHasBadge[user][21]) {
            _awardBadge(user, 21, BadgeTier.BRONZE);
        }
    }

    // View functions
    function getTokenAttributes(uint256 tokenId) external view returns (BadgeAttributes memory) {
        return tokenAttributes[tokenId];
    }

    function getUserBadges(address user) external view returns (uint256[] memory) {
        return userBadgeList[user];
    }

    // Admin functions
    function setBaseTokenURI(string calldata uri) external onlyAdmin {
        baseTokenURI = uri;
    }

    function updateAdminContract(address newAdmin) external onlyAdmin {
        adminContract = ILearnWayAdmin(newAdmin);
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external onlyAdmin {
        _setTokenURI(tokenId, uri);
    }

    // Required overrides
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
