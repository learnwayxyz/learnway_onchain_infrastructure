// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/LearnWayBadge.sol";

/**
 * @title UpgradeBadgeContract
 * @dev Script to upgrade the LearnWayBadge contract implementation via UUPS proxy
 *
 * Usage:
 * forge script script/UpgradeBadgeContract.s.sol:UpgradeBadgeContract \
 *   --rpc-url <RPC_URL> \
 *   --broadcast \
 *   --verify
 */
contract UpgradeBadgeContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address badgeProxy = vm.envAddress("BADGE_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        LearnWayBadge newImplementation = new LearnWayBadge();

        console.log("Proxy address:", badgeProxy);
        console.log("New implementation:", address(newImplementation));

        LearnWayBadge(badgeProxy).upgradeToAndCall(address(newImplementation), "");

        console.log("Upgrade successful!");
        console.log("Version:", LearnWayBadge(badgeProxy).version());

        vm.stopBroadcast();
    }
}
