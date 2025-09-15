// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Errors.sol";

contract learnWayAdmin is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    // Role-based access control
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // --- Modifiers ---
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedAdmin();
        }
        _;
    }

      modifier onlyPauser() {
        if (!hasRole(PAUSER_ROLE, msg.sender)) {
            revert UnauthorizedAdmin();
        }
        _;
    }

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert UnauthorizedManager();
        }
        _;
    }

    modifier onlyModerator() {
        if (!hasRole(MODERATOR_ROLE, msg.sender)) {
            revert UnauthorizedModerator();
        }
        _;
    }

    modifier onlyEmergency() {
        if (!hasRole(EMERGENCY_ROLE, msg.sender)) {
            revert UnauthorizedEmergency();
        }
        _;
    }

    modifier onlyAdminOrManager() {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
                hasRole(MANAGER_ROLE, msg.sender),
            "Requires manager role or higher"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        // Initialize parent contracts
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MANAGER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MODERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(EMERGENCY_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
    }

    // Pause functionality
    function pause() external onlyPauser {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    // Role renouncing functions
    function renounceManagerRole() external {
        renounceRole(MANAGER_ROLE, msg.sender);
    }

    function renounceModeratorRole() external {
        renounceRole(MODERATOR_ROLE, msg.sender);
    }

    function renounceEmergencyRole() external {
        renounceRole(EMERGENCY_ROLE, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyAdmin {}
}