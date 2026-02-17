// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/LearnWayBadge.sol";

/**
 * @title UpgradeBadgeContract
 * @dev Script to upgrade the LearnWayBadge contract implementation via UUPS proxy
 *
 * Network: Lisk Sepolia
 * Proxy Address: 0x5D27d814E30ea8d3130f41a1B7E76210a3738eCc
 * Current Implementation: 0xDcEC6a018C602ABc831d4F6219f0CbA432bbFF3E
 *
 * Usage:
 * forge script script/UpgradeBadgeContract.s.sol:UpgradeBadgeContract \
 *   --rpc-url https://rpc.sepolia-api.lisk.com \
 *   --broadcast \
 *   --verify
 */
contract UpgradeBadgeContract is Script {
    // Proxy address
    address constant BADGE_PROXY = 0x5D27d814E30ea8d3130f41a1B7E76210a3738eCc;

    // Current implementation (for reference)
    address constant CURRENT_IMPLEMENTATION = 0xDcEC6a018C602ABc831d4F6219f0CbA432bbFF3E;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        LearnWayBadge newImplementation = new LearnWayBadge();

        console.log("New Implementation deployed at:", address(newImplementation));
        console.log("Proxy address:", BADGE_PROXY);
        console.log("Previous implementation:", CURRENT_IMPLEMENTATION);

        // Call upgradeTo on the proxy (which calls _authorizeUpgrade internally)
        LearnWayBadge(BADGE_PROXY).upgradeToAndCall(address(newImplementation), "");

        console.log("Upgrade successful!");
        console.log("New implementation:", address(newImplementation));

        vm.stopBroadcast();
    }
}
