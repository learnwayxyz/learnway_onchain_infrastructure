// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "src/LearnWayBadge.sol";
import "src/LearnWayAdmin.sol";
import "src/GemsContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLearnWayAdmin is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LearnWayAdmin
        LearnWayAdmin adminImplementation = new LearnWayAdmin();
        bytes memory adminInitData = abi.encodeWithSelector(LearnWayAdmin.initialize.selector);
        ERC1967Proxy adminProxy = new ERC1967Proxy(address(adminImplementation), adminInitData);
        LearnWayAdmin admin = LearnWayAdmin(address(adminProxy));

        // // Deploy LearnWayBadge
        // LearnWayBadge badgeImplementation = new LearnWayBadge();
        // bytes memory badgeInitData =  abi.encodeWithSelector(LearnWayBadge.initialize.selector, address(admin));
        // ERC1967Proxy badgeProxy = new ERC1967Proxy(address(badgeImplementation), badgeInitData);
        // LearnWayBadge badge = LearnWayBadge(address(badgeProxy));

        // // Deploy GemsContract
        // GemsContract gemsImplementation = new GemsContract();
        // bytes memory gemsInitData = abi.encodeWithSelector(GemsContract.initialize.selector, address(admin));
        // ERC1967Proxy gemsProxy = new ERC1967Proxy(address(gemsImplementation), gemsInitData);
        // GemsContract gems = GemsContract(address(gemsProxy));

        // admin.grantRole(admin.ADMIN_ROLE(), address(badgeProxy));
        admin.grantRole(admin.ADMIN_ROLE(), 0x4131811b8a4237712905650985A7474F8f92b18b);
        admin.grantRole(admin.ADMIN_ROLE(), 0x298AAA9A0822eB8117F9ea24D28c897E83415440);
        // badge.setBaseTokenURI("https://api.learnway.io/images/");

        vm.stopBroadcast();

        // string memory addresses = string.concat(
        //     '{"admin_proxy": "', vm.toString(address(adminProxy)), '",',
        //     '"admin_implementation": "', vm.toString(address(adminImplementation)), '",',
        //     '"badge_proxy": "', vm.toString(address(badgeProxy)), '",',
        //     '"badge_implementation": "', vm.toString(address(badgeImplementation)), '",',
        //     '"gems_proxy": "', vm.toString(address(gemsProxy)), '",',
        //     '"gems_implementation": "', vm.toString(address(gemsImplementation)), '"}'
        // );
        // vm.writeFile("deployment_addresses.json", addresses);

        return (address(admin));
    }
}
