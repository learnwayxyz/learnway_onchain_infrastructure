// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "src/LearnWayBadge.sol";
import "src/LearnWayAdmin.sol";
import "src/GemsContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLearnWayBadge is Script {
    function run() external returns (address, address, address, address, address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LearnWayAdmin
        LearnWayAdmin adminImplementation = new LearnWayAdmin();
        bytes memory adminInitData = abi.encodeWithSelector(LearnWayAdmin.initialize.selector);
        ERC1967Proxy adminProxy = new ERC1967Proxy(address(adminImplementation), adminInitData);
        LearnWayAdmin admin = LearnWayAdmin(address(adminProxy));

        // Deploy LearnWayBadge
        LearnWayBadge badge = new LearnWayBadge(address(admin));

        // Deploy GemsContract
        GemsContract gemsImplementation = new GemsContract();
        bytes memory gemsInitData = abi.encodeWithSelector(GemsContract.initialize.selector, address(admin));
        ERC1967Proxy gemsProxy = new ERC1967Proxy(address(gemsImplementation), gemsInitData);
        GemsContract gems = GemsContract(address(gemsProxy));

        admin.grantRole(admin.ADMIN_ROLE(), address(badge));
        admin.grantRole(admin.ADMIN_ROLE(), address(gemsProxy));
        admin.grantRole(admin.ADMIN_ROLE(), 0x298AAA9A0822eB8117F9ea24D28c897E83415440);
        badge.setBaseTokenURI("https://api.learnway.io/images/");

        vm.stopBroadcast();


        return (address(adminProxy), address(admin), address(badge),address(gemsProxy), address(gemsImplementation));
    }
}
