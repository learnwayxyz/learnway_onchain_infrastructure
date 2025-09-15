// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BadgesNFT.sol";

/**
 * @title UpdateBaseURI
 * @dev Foundry script to update the BadgesNFT contract baseURI to use Pinata IPFS
 *
 * Usage:
 * forge script script/UpdateBaseURI.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 *
 * Make sure to set environment variables:
 * - BADGES_NFT_ADDRESS: The deployed BadgesNFT contract address
 * - NEW_BASE_URI: The new Pinata IPFS base URI (default: https://gateway.pinata.cloud/ipfs/)
 */
contract UpdateBaseURIScript is Script {
    // Default Pinata gateway URL
    string constant DEFAULT_PINATA_GATEWAY = "https://gateway.pinata.cloud/ipfs/";

    function run() external {
        // Get environment variables
        address badgesNFTAddress = vm.envOr("BADGES_NFT_ADDRESS", address(0));
        string memory newBaseURI = vm.envOr("NEW_BASE_URI", DEFAULT_PINATA_GATEWAY);

        require(badgesNFTAddress != address(0), "BADGES_NFT_ADDRESS environment variable not set");

        console.log("=== UpdateBaseURI Script ===");
        console.log("Contract Address:", badgesNFTAddress);
        console.log("New Base URI:", newBaseURI);

        // Start broadcasting transactions
        vm.startBroadcast();

        // Get the contract instance
        BadgesNFT badgesNFT = BadgesNFT(badgesNFTAddress);

        // Update the base URI
        badgesNFT.setBaseURI(newBaseURI);

        vm.stopBroadcast();

        console.log("Base URI updated successfully!");
        console.log("Next steps:");
        console.log("1. Verify the tokenURI function returns correct Pinata URLs");
        console.log("2. Test metadata accessibility via Pinata gateway");
        console.log("3. Check NFT marketplace compatibility");
    }

    /**
     * @dev Function to verify the update worked correctly
     * This can be called separately to test the integration
     */
    function verify() external view {
        address badgesNFTAddress = vm.envOr("BADGES_NFT_ADDRESS", address(0));
        require(badgesNFTAddress != address(0), "BADGES_NFT_ADDRESS environment variable not set");

        BadgesNFT badgesNFT = BadgesNFT(badgesNFTAddress);

        console.log("=== Verification Results ===");

        // Try to get tokenURI for token ID 1 (if it exists)
        try badgesNFT.ownerOf(1) {
            string memory tokenURI = badgesNFT.tokenURI(1);
            console.log("Token 1 URI:", tokenURI);

            // Check if it contains pinata gateway
            if (bytes(tokenURI).length > 0) {
                console.log("TokenURI is set and not empty");

                // Basic check for pinata gateway in URI
                bool containsPinata = contains(tokenURI, "pinata.cloud") || contains(tokenURI, "gateway.pinata.cloud");
                if (containsPinata) {
                    console.log("TokenURI contains Pinata gateway");
                } else {
                    console.log("WARNING: TokenURI does not contain Pinata gateway");
                }
            }
        } catch {
            console.log("No token with ID 1 exists yet");
        }

        // Get badge info for the first badge type to see the imageURI
        BadgesNFT.BadgeInfo memory firstBadge = badgesNFT.getBadgeInfo(BadgesNFT.BadgeType.FIRST_SPARK);
        console.log("First badge imageURI:", firstBadge.imageURI);
        console.log("First badge name:", firstBadge.name);
    }

    /**
     * @dev Helper function to check if a string contains a substring
     */
    function contains(string memory str, string memory substring) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory subBytes = bytes(substring);

        if (subBytes.length > strBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= strBytes.length - subBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < subBytes.length; j++) {
                if (strBytes[i + j] != subBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }

        return false;
    }
}
