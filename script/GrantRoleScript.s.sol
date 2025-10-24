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
    address public constant proxyAddress = 0x4f02b67CfA5030B7A80974cf605cD416B9f11814;

    // Example target accounts (you can modify or extend this list)
    address public constant targetAccount1 = 0xe735e92D7cad4c59BD8A819Ac53d3b77843EF9ca;
    address public constant targetAccount2 = 0x8739B22Dd60EFDa57752f861324B3a59722F2F73;

    function run() external {
        // Load deployer private key from .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions with deployer's key
        vm.startBroadcast(deployerPrivateKey);

        ILearnWayAdmin learnway = ILearnWayAdmin(proxyAddress);

        // Choose which role to grant (change ADMIN_ROLE to MANAGER_ROLE etc.)
        bytes32 varOcg = learnway.MANAGER_ROLE();

        // Create an array of target addresses
        address[2] memory accounts = [targetAccount1, targetAccount2];

        // Grant the role to each address in a loop
        for (uint256 i = 0; i < accounts.length; i++) {
            learnway.setUpRole(varOcg, accounts[i]);
        }

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
