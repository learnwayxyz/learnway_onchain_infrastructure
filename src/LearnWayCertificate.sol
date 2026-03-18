// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Errors.sol";
import "./interface/ILearnWayAdmin.sol";

/**
 * @title LearnWayCertificate
 * @dev Upgradeable soulbound NFT contract for LearnWay course completion certificates.
 * Certificates are non-transferable and metadata is stored on IPFS.
 */
contract LearnWayCertificate is
    Initializable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    ILearnWayAdmin public adminContract;
    uint256 private _tokenIdCounter;

    struct Course {
        string courseName;
        string instructorName;
        bool active;
    }

    struct CertificateData {
        uint256 courseId;
        address recipient;
        uint256 mintedAt;
        string metadataURI;
    }

    mapping(uint256 => Course) internal courses;
    mapping(uint256 => bool) public courseExists;
    mapping(uint256 => CertificateData) internal certificates;
    mapping(address => mapping(uint256 => bool)) public hasCertificate;
    mapping(address => mapping(uint256 => uint256)) public userCertificateTokenId;
    mapping(address => uint256[]) internal userCertificateList;

    event CourseAdded(uint256 indexed courseId, string courseName, string instructorName, bool status);
    event CourseStatusUpdated(uint256 indexed courseId, bool active, bool status);
    event CertificateMinted(
        address indexed user, uint256 indexed courseId, uint256 tokenId, string metadataURI, bool status
    );
    event AdminContractUpdated(address indexed newAdminContract, bool status);

    uint256[45] private _gap;

    modifier onlyAdmin() {
        if (!adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender)) {
            revert UnauthorizedAdmin();
        }
        _;
    }

    modifier onlyAdminOrManager() {
        if (
            !adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender)
                && !adminContract.isAuthorized(keccak256("MANAGER_ROLE"), msg.sender)
        ) {
            revert UnauthorizedAdminOrManager();
        }
        _;
    }

    modifier onlyPausableAndAdmin() {
        if (
            !adminContract.isAuthorized(keccak256("PAUSER_ROLE"), msg.sender)
                && !adminContract.isAuthorized(keccak256("ADMIN_ROLE"), msg.sender)
        ) {
            revert UnauthorizedPauser();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin) public initializer {
        if (_admin == address(0)) revert InvalidAddress();

        __ERC721_init("LearnWay Certificate", "LWC");
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        adminContract = ILearnWayAdmin(_admin);
        _tokenIdCounter = 1;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function addCourse(uint256 courseId, string calldata courseName, string calldata instructorName)
        external
        onlyAdmin
        nonReentrant
        whenNotPaused
    {
        if (courseExists[courseId]) revert CourseAlreadyExists();
        if (bytes(courseName).length == 0) revert EmptyCourseName();
        if (bytes(instructorName).length == 0) revert EmptyInstructorName();

        courseExists[courseId] = true;
        courses[courseId] = Course({courseName: courseName, instructorName: instructorName, active: true});

        emit CourseAdded(courseId, courseName, instructorName, true);
    }

    function updateCourseStatus(uint256 courseId, bool active) external onlyAdmin nonReentrant whenNotPaused {
        if (!courseExists[courseId]) revert InvalidCourseId();

        courses[courseId].active = active;

        emit CourseStatusUpdated(courseId, active, true);
    }

    function mintCertificate(address user, uint256 courseId, string calldata metadataURI)
        external
        onlyAdminOrManager
        nonReentrant
        whenNotPaused
    {
        if (user == address(0)) revert InvalidAddress();
        if (!courseExists[courseId]) revert InvalidCourseId();
        if (!courses[courseId].active) revert CourseNotActive();
        if (hasCertificate[user][courseId]) revert CertificateAlreadyMinted();
        if (bytes(metadataURI).length == 0) revert EmptyMetadataURI();

        uint256 tokenId = _tokenIdCounter++;
        _mint(user, tokenId);

        certificates[tokenId] =
            CertificateData({courseId: courseId, recipient: user, mintedAt: block.timestamp, metadataURI: metadataURI});

        hasCertificate[user][courseId] = true;
        userCertificateTokenId[user][courseId] = tokenId;
        userCertificateList[user].push(courseId);

        emit CertificateMinted(user, courseId, tokenId, metadataURI, true);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return certificates[tokenId].metadataURI;
    }

    function getCertificateByToken(uint256 tokenId)
        external
        view
        returns (uint256 courseId, address recipient, uint256 mintedAt, string memory metadataURI)
    {
        _requireOwned(tokenId);
        CertificateData storage cert = certificates[tokenId];
        return (cert.courseId, cert.recipient, cert.mintedAt, cert.metadataURI);
    }

    function getCertificate(address user, uint256 courseId)
        external
        view
        returns (bool exists, uint256 tokenId, uint256 mintedAt, string memory metadataURI)
    {
        exists = hasCertificate[user][courseId];
        if (exists) {
            tokenId = userCertificateTokenId[user][courseId];
            CertificateData storage cert = certificates[tokenId];
            mintedAt = cert.mintedAt;
            metadataURI = cert.metadataURI;
        }
    }

    function getUserCertificates(address user) external view returns (uint256[] memory) {
        return userCertificateList[user];
    }

    function getCourseInfo(uint256 courseId)
        external
        view
        returns (string memory courseName, string memory instructorName, bool active)
    {
        if (!courseExists[courseId]) revert InvalidCourseId();
        Course storage course = courses[courseId];
        return (course.courseName, course.instructorName, course.active);
    }

    function updateAdminContract(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidAddress();
        adminContract = ILearnWayAdmin(newAdmin);
        emit AdminContractUpdated(newAdmin, true);
    }

    function pause() external onlyPausableAndAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    function _update(address to, uint256 tokenId, address auth) internal override whenNotPaused returns (address) {
        address from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            revert CertificateNonTransferable();
        }

        return super._update(to, tokenId, auth);
    }
}
