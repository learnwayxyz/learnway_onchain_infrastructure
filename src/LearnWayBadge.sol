// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Errors.sol";
import "./interface/ILearnWayAdmin.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title LearnWayBadge
 * @dev Simplified NFT contract for LearnWay badges with admin-controlled minting
 * All badges are non-transferable (soulbound) and metadata is stored on-chain
 */
contract LearnWayBadge is ERC721, ReentrancyGuard, Pausable {
    using Strings for uint256;

    ILearnWayAdmin public adminContract;
    uint256 private _tokenIdCounter = 1;

    // Configurable early bird limit
    uint256 public maxEarlyBirdSpots = 1000;
    uint256 public earlyBirdCount;
    uint256 public totalRegistrations;

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

    // Badge Tier
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
        bool isDynamic;
        uint256 maxSupply;
        uint256 currentSupply;
    }

    // Badge attributes stored on-chain
    struct BadgeAttributes {
        uint256 badgeId;
        BadgeTier tier;
        uint256 mintedAt;
        uint256 lastUpdated;
        string status; // Dynamic status based on badge type and tier
    }

    // User information
    struct UserInfo {
        bool isRegistered;
        bool kycVerified;
        uint256 registrationOrder;
        uint256 totalBadgesEarned;
    }

    // Mappings
    mapping(uint256 => Badge) public badges;
    mapping(address => UserInfo) public userInfo;
    mapping(address => mapping(uint256 => bool)) public userHasBadge;
    mapping(address => mapping(uint256 => uint256)) public userBadgeTokenId;
    mapping(uint256 => BadgeAttributes) public tokenAttributes;
    mapping(address => uint256[]) public userBadgeList;
    mapping(uint256 => address) public tokenToOwner;

    string public baseTokenURI;

    // Events with action and status
    event BadgeMinted(
        address indexed user, uint256 indexed badgeId, uint256 tokenId, BadgeTier tier, string action, bool status
    );

    event BadgeUpgraded(
        address indexed user, uint256 indexed badgeId, uint256 tokenId, BadgeTier newTier, string action, bool status
    );

    event UserRegistered(address indexed user, uint256 registrationOrder, bool kycStatus, string action, bool status);

    event KycStatusUpdated(address indexed user, bool kycStatus, string action, bool status);

    event EarlyBirdLimitUpdated(uint256 oldLimit, uint256 newLimit, string action, bool status);

    modifier onlyAdmin() {
        require(adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender), "Not AuthorizedAdmin");
        _;
    }

    modifier onlyManager() {
        require(adminContract.isAuthorized(keccak256("MANAGER_ROLE"), msg.sender), "Not Authorized Manager");
        _;
    }
    modifier onlyPausableAndAdmin() {
        require(
            adminContract.isAuthorized(keccak256("PAUSER_ROLE"), msg.sender) ||
            adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender),
            "Not authorized Admin or Pauser"
        );
        _;
    }

    constructor(address _admin) ERC721("LearnWay Badges", "LWB") {
        adminContract = ILearnWayAdmin(_admin);
        _initializeBadges();
    }

    /**
     * @dev Initialize all 24 badge types
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
            true, // Keyholder - tier depends on KYC
            false, // First Spark
            false, // Early Bird
            true, // Quiz Explorer
            true, // Master of Levels
            true, // Quiz Titan
            true, // BRAINIAC
            true, // Legend
            true, // Daily Claims
            false, // Routine Master
            false, // Quiz Devotee
            true, // Elite
            false, // Duel Champion
            false, // Squad Slayer
            false, // Crown Holder
            false, // Rising Star
            true, // DeFi Voyager
            true, // Savings Champion
            true, // Power Elite
            false, // Community Connector
            true, // Echo Spreader
            false, // Event Star
            false, // Grandmaster
            false // Hall of Famer
        ];

        uint8[24] memory maxSupplies = [
            0, // Keyholder - unlimited
            0, // First Spark - unlimited
            0, // Early Bird - will use maxEarlyBirdSpots dynamically
            0, // Quiz Explorer - unlimited
            0, // Master of Levels - unlimited
            0, // Quiz Titan - unlimited
            0, // BRAINIAC - unlimited
            0, // Legend - unlimited
            0, // Daily Claims - unlimited
            0, // Routine Master - unlimited
            0, // Quiz Devotee - unlimited
            0, // Elite - unlimited
            0, // Duel Champion - unlimited
            0, // Squad Slayer - unlimited
            0, // Crown Holder - unlimited
            0, // Rising Star - unlimited
            0, // DeFi Voyager - unlimited
            0, // Savings Champion - unlimited
            0, // Power Elite - unlimited
            0, // Community Connector - unlimited
            0, // Echo Spreader - unlimited
            0, // Event Star - unlimited
            1, // Grandmaster - limited to 1
            1 // Hall of Famer - limited to 1
        ];

        for (uint256 i = 0; i < 24; i++) {
            badges[i] = Badge({
                name: names[i],
                category: categories[i],
                isDynamic: isDynamic[i],
                maxSupply: maxSupplies[i],
                currentSupply: 0
            });
        }
    }

    /**
     * @dev Register a new user - automatically mints Keyholder badge
     * @param user Address of the user to register
     * @param kycStatus KYC verification status
     */
    function registerUser(address user, bool kycStatus) external onlyManager nonReentrant {
        require(!userInfo[user].isRegistered, "User already registered");

        // Register user
        totalRegistrations++;
        userInfo[user] = UserInfo({
            isRegistered: true,
            kycVerified: kycStatus,
            registrationOrder: totalRegistrations,
            totalBadgesEarned: 0
        });

        emit UserRegistered(user, totalRegistrations, kycStatus, "USER_REGISTERED", true);

        // Automatically mint Keyholder badge (ID 0) with tier based on KYC status
        BadgeTier keyholderTier = kycStatus ? BadgeTier.GOLD : BadgeTier.SILVER;
        _mintBadge(user, 0, keyholderTier);
    }

    /**
     * @dev Mint a specific badge to a user
     * @param user Address to mint to
     * @param badgeId ID of the badge to mint
     * @param tier Tier of the badge
     */
    function mintBadge(address user, uint256 badgeId, BadgeTier tier) external onlyManager nonReentrant {
        require(userInfo[user].isRegistered, "User not registered");
        _mintBadge(user, badgeId, tier);
    }

    /**
     * @dev Batch mint multiple badges to a user
     */
    function batchMintBadges(address user, uint256[] calldata badgeIds, BadgeTier[] calldata tiers)
        external
        onlyManager
        nonReentrant
    {
        require(userInfo[user].isRegistered, "User not registered");
        require(badgeIds.length == tiers.length, "Arrays length mismatch");

        for (uint256 i = 0; i < badgeIds.length; i++) {
            _mintBadge(user, badgeIds[i], tiers[i]);
        }
    }

    /**
     * @dev Internal function to mint badge
     */
    function _mintBadge(address user, uint256 badgeId, BadgeTier tier) internal {
        require(badgeId < 24, "Invalid badge ID");
        require(!userHasBadge[user][badgeId], "User already has this badge");

        Badge storage badge = badges[badgeId];

        // Check max supply
        if (badge.maxSupply > 0 && badge.currentSupply >= badge.maxSupply) {
            revert("Badge max supply reached");
        }

        // Special handling for Early Bird badge (ID 2)
        if (badgeId == 2) {
            require(userInfo[user].kycVerified, "Early Bird requires KYC");
            require(userInfo[user].registrationOrder <= maxEarlyBirdSpots, "Not eligible for Early Bird");
            require(earlyBirdCount < maxEarlyBirdSpots, "Early Bird limit reached");
            earlyBirdCount++;
        }

        uint256 tokenId = _tokenIdCounter++;
        _mint(user, tokenId);

        badge.currentSupply++;
        userHasBadge[user][badgeId] = true;
        userBadgeTokenId[user][badgeId] = tokenId;
        userBadgeList[user].push(badgeId);
        userInfo[user].totalBadgesEarned++;
        tokenToOwner[tokenId] = user;

        string memory status = _getBadgeStatus(badgeId, tier);

        tokenAttributes[tokenId] = BadgeAttributes({
            badgeId: badgeId,
            tier: tier,
            mintedAt: block.timestamp,
            lastUpdated: block.timestamp,
            status: status
        });

        emit BadgeMinted(user, badgeId, tokenId, tier, "BADGE_MINTED", true);
    }

    /**
     * @dev Update badge tier for a user's existing badge
     */
    function upgradeBadge(address user, uint256 badgeId, BadgeTier newTier) external onlyManager nonReentrant {
        require(userHasBadge[user][badgeId], "User doesn't have this badge");
        require(badges[badgeId].isDynamic, "Badge is not upgradeable");

        uint256 tokenId = userBadgeTokenId[user][badgeId];
        BadgeAttributes storage attrs = tokenAttributes[tokenId];
        require(newTier > attrs.tier, "New tier must be higher");

        _updateBadgeTier(user, badgeId, newTier);
    }

    /**
     * @dev Internal function to update badge tier
     */
    function _updateBadgeTier(address user, uint256 badgeId, BadgeTier newTier) internal {
        if (!userHasBadge[user][badgeId]) return;

        uint256 tokenId = userBadgeTokenId[user][badgeId];
        BadgeAttributes storage attrs = tokenAttributes[tokenId];

        if (newTier != attrs.tier) {
            attrs.tier = newTier;
            attrs.lastUpdated = block.timestamp;
            attrs.status = _getBadgeStatus(badgeId, newTier);

            emit BadgeUpgraded(user, badgeId, tokenId, newTier, "BADGE_UPGRADED", true);
        }
    }

    /**
     * @dev Update KYC status for a user and adjust Keyholder badge tier
     */
    function updateKycStatus(address user, bool kycStatus) external onlyManager nonReentrant {
        require(userInfo[user].isRegistered, "User not registered");
        require(userInfo[user].kycVerified != kycStatus, "KYC status unchanged");

        userInfo[user].kycVerified = kycStatus;

        // Update Keyholder badge tier if user has it
        if (userHasBadge[user][0]) {
            _updateBadgeTier(user, 0, kycStatus ? BadgeTier.GOLD : BadgeTier.SILVER);
        }

        emit KycStatusUpdated(user, kycStatus, kycStatus ? "KYC_VERIFIED" : "KYC_UNVERIFIED", true);
    }

    /**
     * @dev Set the maximum number of Early Bird badges
     */
    function setMaxEarlyBirdSpots(uint256 newLimit) external onlyAdmin {
        require(newLimit > 0, "Limit must be greater than 0");
        uint256 oldLimit = maxEarlyBirdSpots;
        maxEarlyBirdSpots = newLimit;

        emit EarlyBirdLimitUpdated(oldLimit, newLimit, "EARLY_BIRD_LIMIT_UPDATED", true);
    }

    /**
     * @dev Get badge status based on badge ID and tier
     */
    function _getBadgeStatus(uint256 badgeId, BadgeTier tier) internal pure returns (string memory) {
        if (badgeId == 0) {
            // Keyholder
            return tier == BadgeTier.GOLD ? "Verified Member" : "Basic Member";
        } else if (badgeId == 3) {
            // Quiz Explorer
            if (tier == BadgeTier.DIAMOND) return "Quiz Legend";
            if (tier == BadgeTier.PLATINUM) return "Quiz Master";
            if (tier == BadgeTier.GOLD) return "Advanced Explorer";
            if (tier == BadgeTier.SILVER) return "Explorer";
            return "Beginner Explorer";
        } else if (badgeId == 4) {
            // Master of Levels
            if (tier == BadgeTier.GOLD) return "Level Master";
            if (tier == BadgeTier.SILVER) return "Level Expert";
            return "Level Climber";
        } else if (badgeId == 8) {
            // Daily Claims
            if (tier == BadgeTier.DIAMOND) return "Legendary Streak";
            if (tier == BadgeTier.PLATINUM) return "Epic Streak";
            if (tier == BadgeTier.GOLD) return "Golden Streak";
            if (tier == BadgeTier.SILVER) return "Silver Streak";
            return "Active Streak";
        } else if (badgeId == 11) {
            // Elite
            if (tier == BadgeTier.DIAMOND) return "Diamond Elite";
            if (tier == BadgeTier.PLATINUM) return "Platinum Elite";
            if (tier == BadgeTier.GOLD) return "Gold Elite";
            return "Elite Member";
        } else {
            return "Earned";
        }
    }

    /**
     * @dev Override _update to make tokens non-transferable (soulbound)
     */
    function _update(address to, uint256 tokenId, address auth) internal override whenNotPaused returns (address) {
        address from = _ownerOf(tokenId);

        // Allow minting and burning, but prevent transfers
        if (from != address(0) && to != address(0)) {
            revert("LearnWay badges are non-transferable");
        }

        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Check if a user is eligible for Early Bird badge
     */
    function isEligibleForEarlyBird(address user) external view returns (bool) {
        return userInfo[user].kycVerified && userInfo[user].registrationOrder <= maxEarlyBirdSpots
            && !userHasBadge[user][2] && earlyBirdCount < maxEarlyBirdSpots;
    }

    /**
     * @dev Get detailed Early Bird eligibility info
     */
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
        UserInfo memory info = userInfo[user];
        registrationOrder = info.registrationOrder;
        isKycCompleted = info.kycVerified;
        hasEarlyBirdBadge = userHasBadge[user][2];
        isEligible = isKycCompleted && registrationOrder <= maxEarlyBirdSpots && !hasEarlyBirdBadge
            && earlyBirdCount < maxEarlyBirdSpots;
        currentEarlyBirdCount = earlyBirdCount;
        currentMaxEarlyBirdSpots = maxEarlyBirdSpots;
    }

    /**
     * @dev Get user's badge collection
     */
    function getUserBadges(address user) external view returns (uint256[] memory) {
        return userBadgeList[user];
    }

    /**
     * @dev Get detailed info about a user's specific badge
     */
    function getUserBadgeInfo(address user, uint256 badgeId)
        external
        view
        returns (bool hasBadge, uint256 tokenId, BadgeTier tier, uint256 mintedAt, string memory status)
    {
        hasBadge = userHasBadge[user][badgeId];
        if (hasBadge) {
            tokenId = userBadgeTokenId[user][badgeId];
            BadgeAttributes memory attrs = tokenAttributes[tokenId];
            tier = attrs.tier;
            mintedAt = attrs.mintedAt;
            status = attrs.status;
        }
    }

    /**
     * @dev Get token attributes
     */
    function getTokenAttributes(uint256 tokenId) external view returns (BadgeAttributes memory) {
        return tokenAttributes[tokenId];
    }

    /**
     * @dev Override tokenURI to return dynamic on-chain metadata
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        address owner = tokenToOwner[tokenId];
        BadgeAttributes memory attrs = tokenAttributes[tokenId];
        Badge memory badge = badges[attrs.badgeId];
        UserInfo memory user = userInfo[owner];

        // Generate fully on-chain metadata
        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                badge.name,
                '",',
                '"description":"',
                _getBadgeDescription(attrs.badgeId, attrs.tier),
                '",',
                '"image":"',
                baseTokenURI,
                attrs.badgeId.toString(),
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
                '{"trait_type":"Dynamic","value":"',
                badge.isDynamic ? "Yes" : "No",
                '"},',
                '{"trait_type":"KYC Verified","value":"',
                user.kycVerified ? "Yes" : "No",
                '"},',
                '{"trait_type":"Badge ID","value":',
                attrs.badgeId.toString(),
                "},",
                '{"trait_type":"Minted At","value":',
                attrs.mintedAt.toString(),
                "},",
                '{"trait_type":"Last Updated","value":',
                attrs.lastUpdated.toString(),
                "}]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /**
     * @dev Get badge description based on badge ID and tier
     */
    function _getBadgeDescription(uint256 badgeId, BadgeTier tier) internal pure returns (string memory) {
        if (badgeId == 0) {
            return tier == BadgeTier.GOLD
                ? "A verified LearnWay member with full platform access"
                : "A registered LearnWay member";
        } else if (badgeId == 1) {
            return "Completed first quiz on LearnWay platform";
        } else if (badgeId == 2) {
            return "One of the first 1000 verified members of LearnWay";
        } else if (badgeId == 3) {
            return "Dedicated quiz explorer on LearnWay";
        } else if (badgeId == 8) {
            return "Maintaining consistent daily activity";
        } else {
            return "LearnWay achievement badge for outstanding performance";
        }
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

    // Admin functions
    function setBaseTokenURI(string calldata uri) external onlyAdmin {
        baseTokenURI = uri;
    }

    function updateAdminContract(address newAdmin) external onlyAdmin {
        adminContract = ILearnWayAdmin(newAdmin);
    }

    function pause() external onlyPausableAndAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    // Required overrides
    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
