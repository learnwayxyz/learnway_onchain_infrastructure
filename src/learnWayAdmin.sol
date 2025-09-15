// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Errors.sol";

contract LearnWayAdmin is
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

    // --- Access Check Functions ---

    // --- Mutative Functions ---
    function pause() external {
        if (!hasRole(PAUSER_ROLE, msg.sender)) {
            revert UnauthorizedPauser();
        }
        _pause();
    }

    function unpause() external {
        _checkAdmin();
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

    function _authorizeUpgrade(address newImplementation) internal override {
        _checkAdmin();
    }

    function checkAdmin() external view {
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedAdmin();
        }
    }

    function checkModerator() external view {
        if (!hasRole(MODERATOR_ROLE, msg.sender)) {
            revert UnauthorizedModerator();
        }
    }

    function checkAdminOrManager() external view {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert UnauthorizedAdminOrManager();
        }
    }

    function _checkAdmin() internal view {
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedAdmin();
        }
    }

    function checkEmergency() internal view {
        if (!hasRole(EMERGENCY_ROLE, msg.sender)) {
            revert UnauthorizedEmergency();
        }
    }
}
