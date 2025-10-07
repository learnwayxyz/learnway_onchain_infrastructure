// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "src/LearnWayBadge.sol";
import "src/LearnWayManager.sol";
import "src/LearnWayAdmin.sol";
import "src/GemsContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLearnWayManager is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LearnWayAdmin
        LearnWayAdmin admin = LearnWayAdmin(0xcA3B36b55E3a0be7FbB7c7789D590D81ba55C578);

        // deploy LearnWayManager contract 
         LearnWayManager managerContract =  LearnWayManager(address(0x55541731173DFC29b7CdB37ff6BB23d010f40242));


        // admin.grantRole(admin.ADMIN_ROLE(), address(badgeProxy));
        admin.grantRole(admin.ADMIN_ROLE(), address(managerContract));
        admin.grantRole(admin.MANAGER_ROLE(), address(managerContract));


        vm.stopBroadcast();
        return (address(managerContract));
    }
}
