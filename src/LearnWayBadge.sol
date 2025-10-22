// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Errors.sol";
import "./interface/ILearnWayAdmin.sol";

/**
 * @title LearnWayBadge
 * @dev Upgradeable NFT contract for LearnWay badges with admin-controlled minting
 * All badges are non-transferable (soulbound) and metadata is stored on-chain
 */
contract LearnWayBadge is
    Initializable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using Strings for uint256;

    ILearnWayAdmin public adminContract;
    uint256 private _tokenIdCounter;

    // Configurable early bird limit
    uint256 public maxEarlyBirdSpots;
    uint256 public totalKycCompletions; // NEW: Tracks order of KYC completion
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
        string status;
    }

    // User information
    struct UserInfo {
        bool isRegistered;
        bool kycVerified;
        uint256 registrationOrder;
        uint256 kycOrder; // NEW: Order of KYC completion (0 if not KYC'd)
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

    // Events
    event BadgeMinted(address indexed user, uint256 indexed badgeId, uint256 tokenId, BadgeTier tier, bool status);
    event BadgeUpgraded(address indexed user, uint256 indexed badgeId, uint256 tokenId, BadgeTier newTier, bool status);
    event UserRegistered(address indexed user, uint256 registrationOrder, bool kycStatus, bool status);
    event KycStatusUpdated(address indexed user, bool kycStatus, uint256 kycOrder, bool status); // UPDATED
    event EarlyBirdLimitUpdated(uint256 oldLimit, uint256 newLimit, bool status);

    uint256[45] private _gap;

    // Modifiers

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
            adminContract.isAuthorized(keccak256("PAUSER_ROLE"), msg.sender)
                || adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender),
            "Not authorized Admin or Pauser"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin) public initializer {
        require(_admin != address(0), "Invalid admin address");

        __ERC721_init("LearnWay Badges", "LWB");
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        adminContract = ILearnWayAdmin(_admin);
        _tokenIdCounter = 1;
        maxEarlyBirdSpots = 1000;

        _initializeBadges();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

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
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false
        ];

        uint8[24] memory maxSupplies = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1];

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

    function registerUser(address user, bool kycStatus) external onlyManager nonReentrant {
        require(!userInfo[user].isRegistered, "User already registered");

        totalRegistrations++;

        uint256 kycOrder = 0;
        if (kycStatus) {
            totalKycCompletions++;
            kycOrder = totalKycCompletions;
        }

        userInfo[user] = UserInfo({
            isRegistered: true,
            kycVerified: kycStatus,
            registrationOrder: totalRegistrations,
            kycOrder: kycOrder,
            totalBadgesEarned: 0
        });

        emit UserRegistered(user, totalRegistrations, kycStatus, true);

        BadgeTier keyholderTier = kycStatus ? BadgeTier.GOLD : BadgeTier.SILVER;
        _mintBadge(user, 0, keyholderTier);
    }

    function mintBadge(address user, uint256 badgeId, BadgeTier tier) external onlyManager nonReentrant {
        require(userInfo[user].isRegistered, "User not registered");
        _mintBadge(user, badgeId, tier);
    }

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

    function _mintBadge(address user, uint256 badgeId, BadgeTier tier) internal {
        require(badgeId < 24, "Invalid badge ID");
        require(!userHasBadge[user][badgeId], "User already has this badge");

        Badge storage badge = badges[badgeId];

        if (badge.maxSupply > 0 && badge.currentSupply >= badge.maxSupply) {
            revert("Badge max supply reached");
        }

        // UPDATED: Early Bird logic now based on KYC completion order
        if (badgeId == 2) {
            require(userInfo[user].kycVerified, "Early Bird requires KYC");
            require(userInfo[user].kycOrder > 0, "KYC order not set");
            require(userInfo[user].kycOrder <= maxEarlyBirdSpots, "Not eligible for Early Bird");
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

        emit BadgeMinted(user, badgeId, tokenId, tier, true);
    }

    function upgradeBadge(address user, uint256 badgeId, BadgeTier newTier) external onlyManager nonReentrant {
        require(userHasBadge[user][badgeId], "User doesn't have this badge");
        require(badges[badgeId].isDynamic, "Badge is not upgradeable");

        uint256 tokenId = userBadgeTokenId[user][badgeId];
        BadgeAttributes storage attrs = tokenAttributes[tokenId];
        require(newTier > attrs.tier, "New tier must be higher");

        _updateBadgeTier(user, badgeId, newTier);
    }

    function _updateBadgeTier(address user, uint256 badgeId, BadgeTier newTier) internal {
        if (!userHasBadge[user][badgeId]) return;

        uint256 tokenId = userBadgeTokenId[user][badgeId];
        BadgeAttributes storage attrs = tokenAttributes[tokenId];

        if (newTier != attrs.tier) {
            attrs.tier = newTier;
            attrs.lastUpdated = block.timestamp;
            attrs.status = _getBadgeStatus(badgeId, newTier);

            emit BadgeUpgraded(user, badgeId, tokenId, newTier, true);
        }
    }

    // UPDATED: Now assigns kycOrder when KYC is completed
    function updateKycStatus(address user, bool kycStatus) external onlyManager nonReentrant {
        require(userInfo[user].isRegistered, "User not registered");

        userInfo[user].kycVerified = kycStatus;

        // Assign KYC order when user completes KYC
        if (kycStatus && userInfo[user].kycOrder == 0) {
            totalKycCompletions++;
            userInfo[user].kycOrder = totalKycCompletions;
        }

        if (userHasBadge[user][0]) {
            _updateBadgeTier(user, 0, kycStatus ? BadgeTier.GOLD : BadgeTier.SILVER);
        }

        emit KycStatusUpdated(user, kycStatus, userInfo[user].kycOrder, true);
    }

    function setMaxEarlyBirdSpots(uint256 newLimit) external onlyAdmin {
        require(newLimit > 0, "Limit must be greater than 0");
        uint256 oldLimit = maxEarlyBirdSpots;
        maxEarlyBirdSpots = newLimit;

        emit EarlyBirdLimitUpdated(oldLimit, newLimit, true);
    }

    function _getBadgeStatus(uint256 badgeId, BadgeTier tier) internal pure returns (string memory) {
        if (badgeId == 0) {
            return tier == BadgeTier.GOLD ? "Verified Member" : "Basic Member";
        } else if (badgeId == 1) {
            return "Completed first quiz on LearnWay platform";
        } else if (badgeId == 2) {
            return "One of the first 1000 verified members of LearnWay";
        } else if (badgeId == 3) {
            if (tier == BadgeTier.DIAMOND) return "Quiz Legend";
            if (tier == BadgeTier.PLATINUM) return "Quiz Master";
            if (tier == BadgeTier.GOLD) return "Advanced Explorer";
            if (tier == BadgeTier.SILVER) return "Explorer";
            return "Beginner Explorer";
        } else if (badgeId == 4) {
            if (tier == BadgeTier.GOLD) return "Level Master";
            if (tier == BadgeTier.SILVER) return "Level Expert";
            return "Level Climber";
        } else if (badgeId == 8) {
            if (tier == BadgeTier.DIAMOND) return "Legendary Streak";
            if (tier == BadgeTier.PLATINUM) return "Epic Streak";
            if (tier == BadgeTier.GOLD) return "Golden Streak";
            if (tier == BadgeTier.SILVER) return "Silver Streak";
            return "Active Streak";
        } else if (badgeId == 11) {
            if (tier == BadgeTier.DIAMOND) return "Diamond Elite";
            if (tier == BadgeTier.PLATINUM) return "Platinum Elite";
            if (tier == BadgeTier.GOLD) return "Gold Elite";
            return "Elite Member";
        } else {
            return "Earned";
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal override whenNotPaused returns (address) {
        address from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            revert("LearnWay badges are non-transferable");
        }

        return super._update(to, tokenId, auth);
    }

    function isEligibleForEarlyBird(address user) external view returns (bool) {
        return userInfo[user].kycVerified && userInfo[user].kycOrder > 0 && userInfo[user].kycOrder <= maxEarlyBirdSpots
            && !userHasBadge[user][2];
    }

    // UPDATED: Now returns kycOrder information
    function getEarlyBirdInfo(address user)
        external
        view
        returns (
            uint256 registrationOrder,
            uint256 kycOrder,
            bool isKycCompleted,
            bool hasEarlyBirdBadge,
            bool isEligible,
            uint256 currentTotalKycCompletions,
            uint256 currentMaxEarlyBirdSpots
        )
    {
        UserInfo memory info = userInfo[user];
        registrationOrder = info.registrationOrder;
        kycOrder = info.kycOrder;
        isKycCompleted = info.kycVerified;
        hasEarlyBirdBadge = userHasBadge[user][2];
        isEligible = isKycCompleted && kycOrder > 0 && kycOrder <= maxEarlyBirdSpots && !hasEarlyBirdBadge;
        currentTotalKycCompletions = totalKycCompletions;
        currentMaxEarlyBirdSpots = maxEarlyBirdSpots;
    }

    function getUserBadges(address user) external view returns (uint256[] memory) {
        return userBadgeList[user];
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
        UserInfo memory info = userInfo[user];
        kycCompleted = info.kycVerified;
        isRegistered = info.isRegistered;
        totalBadgesEarned = info.totalBadgesEarned;
        registrationOrder = info.registrationOrder;
        badgesList = userBadgeList[user];
    }

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

    function getTokenAttributes(uint256 tokenId) external view returns (BadgeAttributes memory) {
        return tokenAttributes[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        address owner = tokenToOwner[tokenId];
        BadgeAttributes memory attrs = tokenAttributes[tokenId];
        Badge memory badge = badges[attrs.badgeId];
        UserInfo memory user = userInfo[owner];

        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                badge.name,
                '","description":"',
                _getBadgeDescription(attrs.badgeId, attrs.tier),
                '","image":"',
                baseTokenURI,
                attrs.badgeId.toString(),
                "_",
                uint256(attrs.tier).toString(),
                '.png","attributes":['
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

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
