// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/LearnWayAdmin.sol";
import "../src/LearnWayCertificate.sol";
import "../src/LearnWayManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCertificateAndUpgradeManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address adminProxy = vm.envAddress("ADMIN_PROXY_ADDRESS");
        address managerProxy = vm.envAddress("MANAGER_PROXY_ADDRESS");

        console.log("Deployer:", deployer);
        console.log("Admin proxy:", adminProxy);
        console.log("Manager proxy:", managerProxy);

        vm.startBroadcast(deployerPrivateKey);

        console.log("\n1. Deploying LearnWayCertificate...");
        LearnWayCertificate certificateImpl = new LearnWayCertificate();
        console.log("Certificate implementation:", address(certificateImpl));

        bytes memory certInitData = abi.encodeWithSelector(LearnWayCertificate.initialize.selector, adminProxy);
        ERC1967Proxy certificateProxy = new ERC1967Proxy(address(certificateImpl), certInitData);
        address certificateAddr = address(certificateProxy);
        console.log("Certificate proxy:", certificateAddr);

        console.log("\n2. Granting ADMIN_ROLE to Certificate proxy...");
        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        LearnWayAdmin(adminProxy).setUpRole(ADMIN_ROLE, certificateAddr);
        console.log("ADMIN_ROLE granted");

        console.log("\n3. Upgrading LearnWayManager...");
        LearnWayManager newManagerImpl = new LearnWayManager();
        console.log("New Manager implementation:", address(newManagerImpl));

        LearnWayManager(managerProxy).upgradeToAndCall(address(newManagerImpl), "");
        console.log("Manager upgraded");

        console.log("\n4. Setting certificate contract on Manager...");
        LearnWayManager(managerProxy).setCertificateContract(certificateAddr);
        console.log("Certificate contract set");

        vm.stopBroadcast();

        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("Certificate Implementation:", address(certificateImpl));
        console.log("Certificate Proxy:         ", certificateAddr);
        console.log("New Manager Implementation:", address(newManagerImpl));
        console.log("Manager Proxy (unchanged): ", managerProxy);
        console.log("Manager Version:           ", LearnWayManager(managerProxy).version());
        console.log("========================================");
        console.log("\n========== Copy Deployment Data ==========");
        console.log("CERTIFICATE_IMPLEMENTATION_ADDRESS=", address(certificateImpl));
        console.log("CERTIFICATE_PROXY_ADDRESS=", certificateAddr);
        console.log("NEW_MANAGER_IMPLEMENTATION_ADDRESS=", address(newManagerImpl));
        console.log("==========================================");
    }
}
