// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// __define-ocg__ Script to grant roles to multiple addresses using Foundry
import "forge-std/Script.sol";

interface ILearnWayAdmin {
    function ADMIN_ROLE() external view returns (bytes32);
    function MANAGER_ROLE() external view returns (bytes32);
    function EMERGENCY_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function setUpRole(bytes32 role, address account) external;
}

contract GrantRoleScript is Script {
    // Deployed proxy contract
    // address public constant proxyAddress = 0x120D60993d6768fCa20e7B0Ee1266Fb0a6470109;

    // Example target accounts (you can modify or extend this list)
    // address public constant targetAccount1 = 0xe735e92D7cad4c59BD8A819Ac53d3b77843EF9ca;
    // address public constant targetAccount2 = 0x8739B22Dd60EFDa57752f861324B3a59722F2F73;
    address public constant targetAccount1 = 0x298AAA9A0822eB8117F9ea24D28c897E83415440;
    address public constant targetAccount2 = 0x7Ce816337061f359Be88367dfD79f19Ad1Ff48d1;
    address public constant targetAccount3 = 0xF295F0700e643000C9f816536B9092FbD13D05D4;

    function run() external {
        // Load deployer private key from .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Try to get ADMIN_PROXY_ADDRESS from environment variable
        // If not set, it will be provided by the deployment script
        address proxyAddress;
        try vm.envAddress("ADMIN_PROXY_ADDRESS") returns (address addr) {
            proxyAddress = addr;
            console.log("Using ADMIN_PROXY_ADDRESS from environment:", proxyAddress);
        } catch {
            revert("ADMIN_PROXY_ADDRESS not set. Please export it or run from deploy script.");
        }

        // Start broadcasting transactions with deployer's key
        vm.startBroadcast(deployerPrivateKey);

        ILearnWayAdmin learnway = ILearnWayAdmin(proxyAddress);

        // Choose which role to grant (change ADMIN_ROLE to MANAGER_ROLE etc.)
        bytes32 varOcg = learnway.ADMIN_ROLE();
        bytes32 varMag = learnway.MANAGER_ROLE();

        // Create an array of target addresses
        address[3] memory accounts = [
            targetAccount1, targetAccount2, targetAccount3];

        // Grant the role to each address in a loop
        for (uint256 i = 0; i < accounts.length; i++) {
            learnway.setUpRole(varOcg, accounts[i]);
            learnway.setUpRole(varMag, accounts[i]);
        }

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
