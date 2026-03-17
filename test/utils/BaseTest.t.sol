// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LearnWayAdmin} from "../../src/LearnWayAdmin.sol";
import {LearnWayBadge} from "../../src/LearnWayBadge.sol";
import {LearnwayXPGemsContract} from "../../src/LearnwayXPGemsContract.sol";
import {LearnWayManager} from "../../src/LearnWayManager.sol";
import {LearnWayCertificate} from "../../src/LearnWayCertificate.sol";

contract BaseTest is Test {
    LearnWayAdmin internal adminContract;
    LearnWayBadge internal badgeContract;
    LearnwayXPGemsContract internal xpGemsContract;
    LearnWayManager internal managerContract;
    LearnWayCertificate internal certificateContract;

    address internal admin = makeAddr("admin");
    address internal manager = makeAddr("manager");
    address internal pauser = makeAddr("pauser");
    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal user3 = makeAddr("user3");
    address internal stranger = makeAddr("stranger");

    bytes32 internal ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 internal MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 internal PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public virtual {
        LearnWayAdmin adminImpl = new LearnWayAdmin();
        ERC1967Proxy adminProxy = new ERC1967Proxy(address(adminImpl), bytes(""));
        adminContract = LearnWayAdmin(address(adminProxy));
        vm.prank(admin);
        adminContract.initialize();

        vm.startPrank(admin);
        adminContract.setUpRole(MANAGER_ROLE, manager);
        adminContract.setUpRole(PAUSER_ROLE, pauser);
        vm.stopPrank();

        LearnWayBadge badgeImpl = new LearnWayBadge();
        ERC1967Proxy badgeProxy = new ERC1967Proxy(address(badgeImpl), bytes(""));
        badgeContract = LearnWayBadge(address(badgeProxy));
        badgeContract.initialize(address(adminContract));

        LearnwayXPGemsContract xpGemsImpl = new LearnwayXPGemsContract();
        ERC1967Proxy xpGemsProxy = new ERC1967Proxy(address(xpGemsImpl), bytes(""));
        xpGemsContract = LearnwayXPGemsContract(address(xpGemsProxy));
        xpGemsContract.initialize(address(adminContract));

        LearnWayManager managerImpl = new LearnWayManager();
        ERC1967Proxy managerProxy = new ERC1967Proxy(address(managerImpl), bytes(""));
        managerContract = LearnWayManager(address(managerProxy));
        managerContract.initialize(address(adminContract));

        LearnWayCertificate certificateImpl = new LearnWayCertificate();
        ERC1967Proxy certificateProxy = new ERC1967Proxy(address(certificateImpl), bytes(""));
        certificateContract = LearnWayCertificate(address(certificateProxy));
        certificateContract.initialize(address(adminContract));

        vm.startPrank(admin);
        adminContract.setUpRole(MANAGER_ROLE, address(managerContract));
        managerContract.setContracts(address(xpGemsContract), address(badgeContract));
        vm.stopPrank();

        vm.label(address(adminContract), "AdminContract");
        vm.label(address(badgeContract), "BadgeContract");
        vm.label(address(xpGemsContract), "XPGemsContract");
        vm.label(address(managerContract), "ManagerContract");
        vm.label(address(certificateContract), "CertificateContract");
        vm.label(admin, "Admin");
        vm.label(manager, "Manager");
        vm.label(pauser, "Pauser");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
        vm.label(stranger, "Stranger");
    }
}
