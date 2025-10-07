// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "src/LearnWayAdmin.sol";
import "src/XPContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLearnWayXp is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LearnWayAdmin
        LearnWayAdmin admin = LearnWayAdmin(0xcA3B36b55E3a0be7FbB7c7789D590D81ba55C578);

        // deploy XPContract contract 
         XPContract xpContract = new XPContract(address(admin));

        admin.grantRole(admin.ADMIN_ROLE(), address(xpContract));

        vm.stopBroadcast();
        return (address(xpContract));
    }
}
