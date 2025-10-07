// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "src/LearnWayBadge.sol";
import "src/LearnWayManager.sol";
import "src/LearnWayAdmin.sol";
import "src/GemsContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestManager is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);


        
         LearnWayManager managerContract =  LearnWayManager(0x55541731173DFC29b7CdB37ff6BB23d010f40242);

         managerContract.registerUser(address(0x4131811b8a4237712905650985A7474F8f92b18b), 0x4131811b8a4237712905650985A7474F8f92b18b,
         "Lamsy", false);


        vm.stopBroadcast();
        return (address(managerContract));
    }
}
