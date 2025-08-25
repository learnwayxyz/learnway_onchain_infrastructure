// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BadgesNFT.sol";
import "../src/LearnWayManager.sol";
import "../src/GemsContract.sol";
import "../src/XPContract.sol";

/**
 * @title PinataIntegrationTest
 * @dev Test suite to verify Pinata IPFS integration for BadgesNFT metadata
 */
contract PinataIntegrationTest is Test {
    BadgesNFT public badgesNFT;
    LearnWayManager public learnWayManager;
    GemsContract public gemsContract;
    XPContract public xpContract;
    address public owner;
    address public user1;

    string constant PINATA_GATEWAY = "https://gateway.pinata.cloud/ipfs/";
    string constant OLD_BASE_URI = "https://oldserver.com/metadata/";

    event BadgeMinted(address indexed user, BadgesNFT.BadgeType badgeType, uint256 tokenId);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");

        // Deploy contracts
        badgesNFT = new BadgesNFT(OLD_BASE_URI);
        gemsContract = new GemsContract();
        xpContract = new XPContract();
        learnWayManager = new LearnWayManager();

        // Set up contract relationships
        learnWayManager.setContracts(
            address(gemsContract),
            address(xpContract),
            address(badgesNFT)
        );
        badgesNFT.setLearnWayManager(address(learnWayManager));

        // Transfer ownership of subsidiary contracts to LearnWayManager
        gemsContract.transferOwnership(address(learnWayManager));
        xpContract.transferOwnership(address(learnWayManager));

        // Register test user
        learnWayManager.registerUser(user1, address(0), "TestUser1");
    }

    function test_InitialSetup() public {
        // Verify contract is set up correctly
        assertEq(badgesNFT.owner(), owner);
        assertEq(badgesNFT.learnWayManager(), address(learnWayManager));

        // Award FIRST_SPARK badge by completing a quiz
        bool[] memory correctAnswers = new bool[](5);
        correctAnswers[0] = true;
        correctAnswers[1] = false;
        correctAnswers[2] = true;
        correctAnswers[3] = true;
        correctAnswers[4] = true;

        learnWayManager.completeQuiz(
            user1,
            80,
            correctAnswers,
            "fun_learn",
            30,
            false
        );

        string memory tokenURI = badgesNFT.tokenURI(1);
        assertTrue(bytes(tokenURI).length > 0);
        assertTrue(contains(tokenURI, OLD_BASE_URI));
    }

    function test_UpdateBaseURIToPinata() public {
        // Update baseURI to Pinata gateway as owner
        vm.prank(owner);
        badgesNFT.setBaseURI(PINATA_GATEWAY);

        // Award FIRST_SPARK badge by completing a quiz
        bool[] memory correctAnswers = new bool[](5);
        correctAnswers[0] = true;
        correctAnswers[1] = false;
        correctAnswers[2] = true;
        correctAnswers[3] = true;
        correctAnswers[4] = true;

        learnWayManager.completeQuiz(
            user1,
            80,
            correctAnswers,
            "fun_learn",
            30,
            false
        );

        // Verify tokenURI now uses Pinata gateway
        string memory tokenURI = badgesNFT.tokenURI(1);
        assertTrue(contains(tokenURI, PINATA_GATEWAY));
        assertTrue(contains(tokenURI, "first_spark.json"));

        // Full expected URI should be: https://gateway.pinata.cloud/ipfs/first_spark.json
        string memory expectedURI = string(abi.encodePacked(PINATA_GATEWAY, "first_spark.json"));
        assertEq(tokenURI, expectedURI);
    }

    function test_OnlyOwnerCanUpdateBaseURI() public {
        // Test that non-owner cannot update baseURI
        vm.prank(user1);
        vm.expectRevert();
        badgesNFT.setBaseURI(PINATA_GATEWAY);

        // Test that LearnWayManager cannot update baseURI (only owner can)
        vm.prank(address(learnWayManager));
        vm.expectRevert();
        badgesNFT.setBaseURI(PINATA_GATEWAY);

        // Test that owner can update baseURI
        vm.prank(owner);
        badgesNFT.setBaseURI(PINATA_GATEWAY);
    }

    function test_AllBadgeTypesUsePinataURI() public {
        // Update to Pinata gateway
        vm.prank(owner);
        badgesNFT.setBaseURI(PINATA_GATEWAY);

        // Award FIRST_SPARK badge by completing a quiz
        bool[] memory correctAnswers = new bool[](5);
        correctAnswers[0] = true;
        correctAnswers[1] = false;
        correctAnswers[2] = true;
        correctAnswers[3] = true;
        correctAnswers[4] = true;

        learnWayManager.completeQuiz(
            user1,
            80,
            correctAnswers,
            "fun_learn",
            30,
            false
        );

        string memory uri1 = badgesNFT.tokenURI(1);
        assertEq(uri1, string(abi.encodePacked(PINATA_GATEWAY, "first_spark.json")));

        // Award DUEL_CHAMPION badge by completing a battle
        learnWayManager.completeBattle(
            user1,
            "1v1",
            true,  // isWin
            100,   // gemsEarned
            0,     // customXP
            150,   // points
            false  // isHighestScore
        );

        string memory uri2 = badgesNFT.tokenURI(2);
        assertEq(uri2, string(abi.encodePacked(PINATA_GATEWAY, "duel_champion.json")));
    }

    function test_TokenURIFailsForNonexistentToken() public {
        vm.prank(owner);
        badgesNFT.setBaseURI(PINATA_GATEWAY);

        // Should revert for nonexistent token
        vm.expectRevert("URI query for nonexistent token");
        badgesNFT.tokenURI(999);
    }

    function test_BadgeInfoRemainsUnchanged() public {
        // Verify that updating baseURI doesn't affect badge info
        BadgesNFT.BadgeInfo memory badgeInfo = badgesNFT.getBadgeInfo(BadgesNFT.BadgeType.FIRST_SPARK);

        assertEq(badgeInfo.name, "First Spark");
        assertEq(badgeInfo.description, "First public appearance - Play quizZone first time");
        assertEq(badgeInfo.imageURI, "first_spark.json");
        assertTrue(badgeInfo.isActive);

        // Update baseURI
        vm.prank(owner);
        badgesNFT.setBaseURI(PINATA_GATEWAY);

        // Verify badge info is still the same
        BadgesNFT.BadgeInfo memory badgeInfoAfter = badgesNFT.getBadgeInfo(BadgesNFT.BadgeType.FIRST_SPARK);

        assertEq(badgeInfoAfter.name, badgeInfo.name);
        assertEq(badgeInfoAfter.description, badgeInfo.description);
        assertEq(badgeInfoAfter.imageURI, badgeInfo.imageURI);
        assertEq(badgeInfoAfter.isActive, badgeInfo.isActive);
    }

    function test_MultipleBaseURIUpdates() public {
        string memory gateway1 = "https://ipfs.io/ipfs/";
        string memory gateway2 = "https://gateway.pinata.cloud/ipfs/";
        string memory gateway3 = "https://cloudflare-ipfs.com/ipfs/";

        // Update to different gateways and verify each works
        vm.prank(owner);
        badgesNFT.setBaseURI(gateway1);

        // Award FIRST_SPARK badge by completing a quiz
        bool[] memory correctAnswers = new bool[](5);
        correctAnswers[0] = true;
        correctAnswers[1] = false;
        correctAnswers[2] = true;
        correctAnswers[3] = true;
        correctAnswers[4] = true;

        learnWayManager.completeQuiz(
            user1,
            80,
            correctAnswers,
            "fun_learn",
            30,
            false
        );

        string memory uri1 = badgesNFT.tokenURI(1);
        assertEq(uri1, string(abi.encodePacked(gateway1, "first_spark.json")));

        // Update to Pinata gateway
        vm.prank(owner);
        badgesNFT.setBaseURI(gateway2);

        string memory uri2 = badgesNFT.tokenURI(1);
        assertEq(uri2, string(abi.encodePacked(gateway2, "first_spark.json")));

        // Update to Cloudflare gateway
        vm.prank(owner);
        badgesNFT.setBaseURI(gateway3);

        string memory uri3 = badgesNFT.tokenURI(1);
        assertEq(uri3, string(abi.encodePacked(gateway3, "first_spark.json")));
    }

    function test_EmptyBaseURI() public {
        vm.prank(owner);
        badgesNFT.setBaseURI("");

        // Award FIRST_SPARK badge by completing a quiz
        bool[] memory correctAnswers = new bool[](5);
        correctAnswers[0] = true;
        correctAnswers[1] = false;
        correctAnswers[2] = true;
        correctAnswers[3] = true;
        correctAnswers[4] = true;

        learnWayManager.completeQuiz(
            user1,
            80,
            correctAnswers,
            "fun_learn",
            30,
            false
        );

        string memory tokenURI = badgesNFT.tokenURI(1);
        assertEq(tokenURI, "first_spark.json"); // Should just return the imageURI
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

        for (uint i = 0; i <= strBytes.length - subBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < subBytes.length; j++) {
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
