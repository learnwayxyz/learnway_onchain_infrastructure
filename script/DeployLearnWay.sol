// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/LearnWayAdmin.sol";
import "../src/LearnwayXPGemsContract.sol";
import "../src/LearnWayBadge.sol";
import "../src/LearnWayManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLearnWay is Script {
    // Contract instances
    LearnWayAdmin public adminImplementation;
    LearnWayAdmin public admin;
    ERC1967Proxy public adminProxy;
    
    LearnwayXPGemsContract public xpGemsImplementation;
    ERC1967Proxy public xpGemsProxy;
    LearnwayXPGemsContract public xpGemsLesson;
    
    LearnWayBadge public badgeImplementation;
    ERC1967Proxy public badgeProxy;
    LearnWayBadge public badges;
    
    LearnWayManager public managerImplementation;
    ERC1967Proxy public managerProxy;
    LearnWayManager public manager;

    // Deployment addresses (will be set during deployment)
    address public adminImplementationAddress;
    address public adminAddress;
    address public xpGemsLessonAddress;
    address public badgesAddress;
    address public managerAddress;

    function run() external {
        // Get the deployer's private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying LearnWay contracts with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy LearnWayAdmin Implementation
        console.log("\n1. Deploying LearnWayAdmin Implementation...");
        adminImplementation = new LearnWayAdmin();
        adminImplementationAddress = address(adminImplementation);
        console.log("LearnWayAdmin Implementation deployed at:", adminImplementationAddress);

        // 2. Deploy Proxy and Initialize LearnWayAdmin
        console.log("\n2. Deploying LearnWayAdmin Proxy and Initializing...");
        bytes memory initData = abi.encodeWithSelector(LearnWayAdmin.initialize.selector);
        adminProxy = new ERC1967Proxy(adminImplementationAddress, initData);
        adminAddress = address(adminProxy);
        admin = LearnWayAdmin(adminAddress);
        console.log("LearnWayAdmin Proxy deployed at:", adminAddress);
        console.log("LearnWayAdmin initialized");

        // 3. Deploy XPGems as upgradeable
        console.log("\n3. Deploying LearnwayXPGemsContract as upgradeable...");
        xpGemsImplementation = new LearnwayXPGemsContract();
        console.log("LearnwayXPGemsContract Implementation deployed at:", address(xpGemsImplementation));
        bytes memory xpGemsInitData = abi.encodeWithSelector(
            LearnwayXPGemsContract.initialize.selector,
            adminAddress
        );
        xpGemsProxy = new ERC1967Proxy(address(xpGemsImplementation), xpGemsInitData);
        xpGemsLesson = LearnwayXPGemsContract(address(xpGemsProxy));
        xpGemsLessonAddress = address(xpGemsProxy);
        console.log("LearnwayXPGemsContract Proxy deployed at:", xpGemsLessonAddress);

        // 4. Deploy Badge as upgradeable
        console.log("\n4. Deploying LearnWayBadge as upgradeable...");
        badgeImplementation = new LearnWayBadge();
        console.log("LearnWayBadge Implementation deployed at:", address(badgeImplementation));
        bytes memory badgeInitData = abi.encodeWithSelector(
            LearnWayBadge.initialize.selector,
            adminAddress
        );
        badgeProxy = new ERC1967Proxy(address(badgeImplementation), badgeInitData);
        badges = LearnWayBadge(address(badgeProxy));
        badgesAddress = address(badgeProxy);
        console.log("LearnWayBadge Proxy deployed at:", badgesAddress);

        // 5. Deploy Manager as upgradeable
        console.log("\n5. Deploying LearnWayManager as upgradeable...");
        managerImplementation = new LearnWayManager();
        console.log("LearnWayManager Implementation deployed at:", address(managerImplementation));
        bytes memory managerInitData = abi.encodeWithSelector(
            LearnWayManager.initialize.selector,
            adminAddress
        );
        managerProxy = new ERC1967Proxy(address(managerImplementation), managerInitData);
        manager = LearnWayManager(address(managerProxy));
        managerAddress = address(managerProxy);
        console.log("LearnWayManager Proxy deployed at:", managerAddress);

        // 6. Setup roles and permissions
        console.log("\n6. Setting up roles and permissions...");
        
        // grant all the 3 contracts ADMIN ROLE
        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        for (uint256 i = 0; i < 3; i++) {
            address contractAddress = i == 0 ? xpGemsLessonAddress : (i == 1 ? badgesAddress : managerAddress);
            admin.setUpRole(ADMIN_ROLE, contractAddress);
            console.log("Granted ADMIN_ROLE to contract:", contractAddress);
        }

        // Grant MANAGER_ROLE to the LearnWayManager contract
        bytes32 MANAGER_ROLE = keccak256("MANAGER_ROLE");
        admin.setUpRole(MANAGER_ROLE, managerAddress);
        console.log("Granted MANAGER_ROLE to LearnWayManager");

        // 7. Configure LearnWayManager with the other contracts
        console.log("\n7. Configuring LearnWayManager...");
        manager.setContracts(xpGemsLessonAddress, badgesAddress);
        console.log("LearnWayManager configured with XPGems and Badge contracts");

        // 8. Optional: Set base URI for badges (can be updated later)
        // badges.setBaseTokenURI("https://api.learnway.io/badges/");
        
        vm.stopBroadcast();

        // Print deployment summary
        _printDeploymentSummary();
    }

    function _printDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("LearnWayAdmin Implementation:", adminImplementationAddress);
        console.log("LearnWayAdmin Proxy:         ", adminAddress);
        console.log("LearnwayXPGemsLessonContract:      ", xpGemsLessonAddress);
        console.log("LearnWayBadge:               ", badgesAddress);
        console.log("LearnWayManager:             ", managerAddress);
        console.log("========================================");
        console.log("\nDeployment completed successfully!");
        console.log("\nIMPORTANT: Save these addresses for verification and future reference.");
        console.log("NOTE: Use the Proxy address for all interactions with LearnWayAdmin.");
        console.log("\n========== Copy Deployment Data ==========");
        console.log("ADMIN_IMPLEMENTATION_ADDRESS=", adminImplementationAddress);
        console.log("ADMIN_PROXY_ADDRESS=", adminAddress);
        console.log("XPGEMS_ADDRESS=", xpGemsLessonAddress);
        console.log("BADGE_ADDRESS=", badgesAddress);
        console.log("MANAGER_ADDRESS=", managerAddress);
        console.log("==========================================");
    }
}
