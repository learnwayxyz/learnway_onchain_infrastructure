// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnWayAdmin} from "../../src/learnWayAdmin.sol";
import "../utils/BaseTest.t.sol";
import "../utils/Mocks.t.sol";

/*
 * @audit checkAdmin() and checkAdminOrManager() have no external callers. Candidates for removal.
 * @audit checkAdminOrManager() uses require(string) instead of a custom error.
 * @audit EMERGENCY_ROLE is defined and renounceEmergencyRole() exists, but the role is never
 *        checked in any external function — operationally unused.
 * @audit Pausing the contract produces no effect — whenNotPaused is missing from all
 *        operations. Pausing should block Admin operations to match spec intent.
 * @audit Verify full compliance with OZ AccessControlUpgradeable standards — check for quirks
 *        or deviations from the expected pattern (role hierarchy, admin role setup, etc.).
 * @audit No guard against removing the last admin. Spec requires at least one admin must always
 *        exist. Needs contract fix — see LearnWayAdminTest_LastAdminProtection stubs.
 */

contract LearnWayAdminTest_Initialize is BaseTest {
    LearnWayAdmin uninitializedAdmin;

    function setUp() public override {
        super.setUp();
        LearnWayAdmin impl = new LearnWayAdmin();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
        uninitializedAdmin = LearnWayAdmin(address(proxy));
        vm.label(address(uninitializedAdmin), "UninitializedAdmin");
    }

    function test_RevertWhen_AlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        adminContract.initialize();
    }

    function test_GrantsAdminRoleToCallerOnInitialize() public {
        assertTrue(adminContract.hasRole(ADMIN_ROLE, admin));
    }

    function test_AdminRoleAdministersAdminRole() public {
        assertEq(adminContract.getRoleAdmin(ADMIN_ROLE), ADMIN_ROLE);
    }

    function test_AdminRoleAdministersManagerRole() public {
        assertEq(adminContract.getRoleAdmin(MANAGER_ROLE), ADMIN_ROLE);
    }

    function test_AdminRoleAdministersPauserRole() public {
        assertEq(adminContract.getRoleAdmin(PAUSER_ROLE), ADMIN_ROLE);
    }

    function test_AdminRoleAdministersEmergencyRole() public {
        bytes32 EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
        assertEq(adminContract.getRoleAdmin(EMERGENCY_ROLE), ADMIN_ROLE);
    }

    function test_InitializerDisabledOnImplementationContract() public {
        LearnWayAdmin impl = new LearnWayAdmin();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        impl.initialize();
    }
}

contract LearnWayAdminTest_Pause is BaseTest {
    event Paused(address account);

    function test_RevertWhen_CallerIsNotPauser() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedPauser()"));
        adminContract.pause();
    }

    function test_RevertWhen_AlreadyPaused() public {
        vm.prank(pauser);
        adminContract.pause();

        vm.prank(pauser);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        adminContract.pause();
    }

    function test_ContractIsPaused() public {
        vm.prank(pauser);
        adminContract.pause();
        assertTrue(adminContract.paused());
    }

    function test_EmitsPausedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Paused(pauser);
        vm.prank(pauser);
        adminContract.pause();
    }
}

contract LearnWayAdminTest_Unpause is BaseTest {
    event Unpaused(address account);

    function setUp() public override {
        super.setUp();
        vm.prank(pauser);
        adminContract.pause();
    }

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        adminContract.unpause();
    }

    function test_RevertWhen_PauserCannotUnpause() public {
        vm.prank(pauser);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        adminContract.unpause();
    }

    function test_RevertWhen_NotPaused() public {
        vm.prank(admin);
        adminContract.unpause();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        adminContract.unpause();
    }

    function test_ContractIsUnpaused() public {
        vm.prank(admin);
        adminContract.unpause();
        assertFalse(adminContract.paused());
    }

    function test_EmitsUnpausedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Unpaused(admin);
        vm.prank(admin);
        adminContract.unpause();
    }
}

contract LearnWayAdminTest_SetUpRole is BaseTest {
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    function test_RevertWhen_CallerIsNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        adminContract.setUpRole(MANAGER_ROLE, user1);
    }

    function test_AdminCanGrantManagerRole() public {
        vm.prank(admin);
        adminContract.setUpRole(MANAGER_ROLE, user1);
        assertTrue(adminContract.hasRole(MANAGER_ROLE, user1));
    }

    function test_AdminCanGrantPauserRole() public {
        vm.prank(admin);
        adminContract.setUpRole(PAUSER_ROLE, user1);
        assertTrue(adminContract.hasRole(PAUSER_ROLE, user1));
    }

    function test_AdminCanGrantAdminRole() public {
        vm.prank(admin);
        adminContract.setUpRole(ADMIN_ROLE, user1);
        assertTrue(adminContract.hasRole(ADMIN_ROLE, user1));
    }

    function test_AccountHasRoleAfterGrant() public {
        assertFalse(adminContract.hasRole(MANAGER_ROLE, user1));
        vm.prank(admin);
        adminContract.setUpRole(MANAGER_ROLE, user1);
        assertTrue(adminContract.hasRole(MANAGER_ROLE, user1));
    }

    function test_EmitsRoleGrantedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(MANAGER_ROLE, user1, admin);
        vm.prank(admin);
        adminContract.setUpRole(MANAGER_ROLE, user1);
    }

    function test_GrantingAlreadyHeldRoleIsIdempotent() public {
        assertTrue(adminContract.hasRole(MANAGER_ROLE, manager));
        vm.prank(admin);
        adminContract.setUpRole(MANAGER_ROLE, manager);
        assertTrue(adminContract.hasRole(MANAGER_ROLE, manager));
    }
}

contract LearnWayAdminTest_RenounceManagerRole is BaseTest {
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function test_CallerNoLongerHasManagerRoleAfterRenounce() public {
        vm.prank(manager);
        adminContract.renounceManagerRole();
        assertFalse(adminContract.hasRole(MANAGER_ROLE, manager));
    }

    function test_EmitsRoleRevokedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(MANAGER_ROLE, manager, manager);
        vm.prank(manager);
        adminContract.renounceManagerRole();
    }

    function test_RenounceHasNoEffectWhenRoleNotHeld() public {
        assertFalse(adminContract.hasRole(MANAGER_ROLE, stranger));
        vm.prank(stranger);
        adminContract.renounceManagerRole();
        assertFalse(adminContract.hasRole(MANAGER_ROLE, stranger));
    }
}

contract LearnWayAdminTest_RenounceEmergencyRole is BaseTest {
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    bytes32 internal EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        adminContract.setUpRole(EMERGENCY_ROLE, user1);
    }

    function test_CallerNoLongerHasEmergencyRoleAfterRenounce() public {
        vm.prank(user1);
        adminContract.renounceEmergencyRole();
        assertFalse(adminContract.hasRole(EMERGENCY_ROLE, user1));
    }

    function test_EmitsRoleRevokedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(EMERGENCY_ROLE, user1, user1);
        vm.prank(user1);
        adminContract.renounceEmergencyRole();
    }

    function test_RenounceHasNoEffectWhenRoleNotHeld() public {
        assertFalse(adminContract.hasRole(EMERGENCY_ROLE, stranger));
        vm.prank(stranger);
        adminContract.renounceEmergencyRole();
        assertFalse(adminContract.hasRole(EMERGENCY_ROLE, stranger));
    }
}

contract LearnWayAdminTest_IsAuthorized is BaseTest {
    function test_ReturnsTrueForAccountWithRole() public {
        assertTrue(adminContract.isAuthorized(ADMIN_ROLE, admin));
        assertTrue(adminContract.isAuthorized(MANAGER_ROLE, manager));
        assertTrue(adminContract.isAuthorized(PAUSER_ROLE, pauser));
    }

    function test_ReturnsFalseForAccountWithoutRole() public {
        assertFalse(adminContract.isAuthorized(ADMIN_ROLE, stranger));
    }

    function test_ReturnsFalseForUnknownRole() public {
        bytes32 unknownRole = keccak256("UNKNOWN_ROLE");
        assertFalse(adminContract.isAuthorized(unknownRole, admin));
    }
}

contract LearnWayAdminTest_AuthorizeUpgrade is BaseTest {
    event Upgraded(address indexed implementation);

    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function test_RevertWhen_CallerIsNotAdmin() public {
        LearnWayAdmin newImpl = new LearnWayAdmin();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedAdmin()"));
        adminContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_ImplementationAddressChangesAfterUpgrade() public {
        address implBefore = address(uint160(uint256(vm.load(address(adminContract), IMPL_SLOT))));

        LearnWayAdmin newImpl = new LearnWayAdmin();
        vm.prank(admin);
        adminContract.upgradeToAndCall(address(newImpl), "");

        address implAfter = address(uint160(uint256(vm.load(address(adminContract), IMPL_SLOT))));
        assertNotEq(implBefore, implAfter);
        assertEq(implAfter, address(newImpl));
    }

    function test_EmitsUpgradedEvent() public {
        LearnWayAdmin newImpl = new LearnWayAdmin();
        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(newImpl));
        vm.prank(admin);
        adminContract.upgradeToAndCall(address(newImpl), "");
    }

    function test_RevertWhen_NewImplementationIsNotUUPS() public {
        MockNonUUPS nonUUPS = new MockNonUUPS();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("ERC1967InvalidImplementation(address)", address(nonUUPS)));
        adminContract.upgradeToAndCall(address(nonUUPS), "");
    }

    function test_StorageLayoutPreservedAfterUpgrade() public {
        LearnWayAdmin newImpl = new LearnWayAdmin();
        vm.prank(admin);
        adminContract.upgradeToAndCall(address(newImpl), "");

        assertTrue(adminContract.hasRole(ADMIN_ROLE, admin));
        assertTrue(adminContract.hasRole(MANAGER_ROLE, manager));
        assertTrue(adminContract.hasRole(PAUSER_ROLE, pauser));
        assertEq(adminContract.getRoleAdmin(ADMIN_ROLE), ADMIN_ROLE);
    }
}

contract LearnWayAdminTest_LastAdminProtection is BaseTest {
    function test_RevertWhen_RevokingTheLastAdmin() public {
        // @todo Implement when the last-admin guard lands in revokeRole.
        vm.skip(true);
    }

    function test_RevertWhen_LastAdminRenouncesOwnRole() public {
        // @todo Implement when the last-admin guard lands in renounceRole.
        vm.skip(true);
    }

    function test_CanRevokeAdminRoleWhenAnotherAdminExists() public {
        vm.prank(admin);
        adminContract.setUpRole(ADMIN_ROLE, user1);

        vm.prank(admin);
        adminContract.revokeRole(ADMIN_ROLE, user1);

        assertFalse(adminContract.hasRole(ADMIN_ROLE, user1));
        assertTrue(adminContract.hasRole(ADMIN_ROLE, admin));
    }
}
