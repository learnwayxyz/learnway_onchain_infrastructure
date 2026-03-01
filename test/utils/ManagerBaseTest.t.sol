// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LearnWayManager, ILearnwayXPGemsContract, ILearnWayBadge} from "../../src/LearnWayManager.sol";
import "./BaseTest.t.sol";

contract ManagerBaseTest is BaseTest {
    function registerUser(address user, uint256 gems, bool kyc) internal {
        address[] memory users = new address[](1);
        users[0] = user;
        uint256[] memory gemsArr = new uint256[](1);
        gemsArr[0] = gems;
        bool[] memory kycArr = new bool[](1);
        kycArr[0] = kyc;
        vm.prank(manager);
        managerContract.batchRegisterUsers(users, gemsArr, kycArr);
    }

    function deployManagerWithoutContracts() internal returns (LearnWayManager) {
        LearnWayManager impl = new LearnWayManager();
        LearnWayManager mgr = LearnWayManager(address(new ERC1967Proxy(address(impl), "")));
        mgr.initialize(address(adminContract));
        return mgr;
    }

    function buildTxBatch(uint256 n)
        internal
        pure
        returns (
            uint256[] memory gemsAmounts,
            uint256[] memory xpAmounts,
            uint256[][] memory badgesLists,
            ILearnwayXPGemsContract.TransactionType[] memory txTypes,
            string[] memory descriptions
        )
    {
        gemsAmounts = new uint256[](n);
        xpAmounts = new uint256[](n);
        badgesLists = new uint256[][](n);
        txTypes = new ILearnwayXPGemsContract.TransactionType[](n);
        descriptions = new string[](n);
        for (uint256 i = 0; i < n; i++) {
            gemsAmounts[i] = (i + 1) * 10;
            xpAmounts[i] = (i + 1) * 5;
            badgesLists[i] = new uint256[](0);
            txTypes[i] = ILearnwayXPGemsContract.TransactionType.Lesson;
            descriptions[i] = "Test";
        }
    }

    function buildMultiUserTxBatch(uint256 n)
        internal
        pure
        returns (
            uint256[][] memory gemsAmounts,
            uint256[][] memory xpAmounts,
            uint256[][][] memory badgesLists,
            ILearnwayXPGemsContract.TransactionType[][] memory txTypes,
            string[][] memory descriptions
        )
    {
        gemsAmounts = new uint256[][](n);
        xpAmounts = new uint256[][](n);
        badgesLists = new uint256[][][](n);
        txTypes = new ILearnwayXPGemsContract.TransactionType[][](n);
        descriptions = new string[][](n);
        for (uint256 i = 0; i < n; i++) {
            gemsAmounts[i] = new uint256[](1);
            gemsAmounts[i][0] = 10;
            xpAmounts[i] = new uint256[](1);
            xpAmounts[i][0] = 5;
            badgesLists[i] = new uint256[][](1);
            badgesLists[i][0] = new uint256[](0);
            txTypes[i] = new ILearnwayXPGemsContract.TransactionType[](1);
            txTypes[i][0] = ILearnwayXPGemsContract.TransactionType.Lesson;
            descriptions[i] = new string[](1);
            descriptions[i][0] = "Test";
        }
    }
}
