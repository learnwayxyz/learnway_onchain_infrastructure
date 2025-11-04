// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/LearnWayBadge.sol";

/**
 * @title SetBadgeURLsManual
 * @dev Alternative script to set badge URLs one by one
 * Useful for testing or setting URLs individually
 */
contract SetBadgeURLsManual is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address badgeContractAddress = vm.envAddress("BADGE_CONTRACT_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        LearnWayBadge badgeContract = LearnWayBadge(badgeContractAddress);
        
        // Set individual badge URLs
        // Badge 0: Keyholder (Silver)
        badgeContract.setBadgeImageURL(
            0,
            LearnWayBadge.BadgeTier.SILVER,
            "https://ik.imagekit.io/wqbvwdo34/badges/StreaksRoutineMaster_i0AfiVswqW.svg"
        );
        
        // Badge 0: Keyholder (Gold)
        badgeContract.setBadgeImageURL(
            0,
            LearnWayBadge.BadgeTier.GOLD,
            "https://ik.imagekit.io/wqbvwdo34/badges/GoldKeyholder_nEvwt1qVi.svg"
        );
        
        // Badge 1: First Spark
        badgeContract.setBadgeImageURL(
            1,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/FirstSpark_uOj9dts8D.svg"
        );
        
        // Badge 2: Early Bird
        badgeContract.setBadgeImageURL(
            2,
            LearnWayBadge.BadgeTier.GOLD,
            "https://ik.imagekit.io/wqbvwdo34/badges/EarlyBird_HAOtsKKG1-.svg"
        );
        
        // Badge 3: Quiz Explorer
        badgeContract.setBadgeImageURL(
            3,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/QuizExplorer_3sxw-AM1Z.svg"
        );
        
        // Badge 4: Master of Levels
        badgeContract.setBadgeImageURL(
            4,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/MasterOfLevels_mO-EokdYc.svg"
        );
        
        // Badge 5: Quiz Titan
        badgeContract.setBadgeImageURL(
            5,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/QuizTitans_Cjd6NQ32G.svg"
        );
        
        // Badge 6: BRAINIAC
        badgeContract.setBadgeImageURL(
            6,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/Brainiac_eIE08H6Dr.svg"
        );
        
        // Badge 7: Legend
        badgeContract.setBadgeImageURL(
            7,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/Legend_wdfiNd7-f.svg"
        );
        
        // Badge 8: Daily Claims
        badgeContract.setBadgeImageURL(
            8,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/DailyClaims_kvSrakbkl.svg"
        );
        
        // Badge 9: Routine Master (Streaks Routine Master)
        badgeContract.setBadgeImageURL(
            9,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/StreaksRoutineMaster_i0AfiVswqW.svg"
        );
        
        // Badge 10: Quiz Devotee
        badgeContract.setBadgeImageURL(
            10,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/QuizDevotee_xTWy1KNh2.svg"
        );
        
        // Badge 11: Elite
        badgeContract.setBadgeImageURL(
            11,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/Elite_NVbf8d-eN.svg"
        );
        
        // Badge 12: Duel Champion
        badgeContract.setBadgeImageURL(
            12,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/DuelChampion_GqtqSxDFu.svg"
        );
        
        // Badge 13: Squad Slayer
        badgeContract.setBadgeImageURL(
            13,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/SquadSlayer__FDy5_B2Y.svg"
        );
        
        // Badge 15: Rising Star
        badgeContract.setBadgeImageURL(
            15,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/RisingStar_mleCCG9Uz.svg"
        );
        
        // Badge 16: DeFi Voyager
        badgeContract.setBadgeImageURL(
            16,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/DefiVoyager_xQuuE7egs.svg"
        );
        
        // Badge 17: Savings Champion
        badgeContract.setBadgeImageURL(
            17,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/SavingsChampion_cGFSRUE6m.svg"
        );
        
        // Badge 18: Power Elite
        badgeContract.setBadgeImageURL(
            18,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/PowerElite_o3xtjJqZv.svg"
        );
        
        // Badge 19: Community Connector
        badgeContract.setBadgeImageURL(
            19,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/CommunityConnector_FFW7Jj9HG.svg"
        );
        
        // Badge 20: Echo Spreader
        badgeContract.setBadgeImageURL(
            20,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/EchoSpreader_p-2FqOeLd6.svg"
        );
        
        // Badge 21: Event Star (Silver)
        badgeContract.setBadgeImageURL(
            21,
            LearnWayBadge.BadgeTier.SILVER,
            "https://ik.imagekit.io/wqbvwdo34/badges/EventStarSilver_eajvcvwhk.svg"
        );
        
        // Badge 21: Event Star (Gold)
        badgeContract.setBadgeImageURL(
            21,
            LearnWayBadge.BadgeTier.GOLD,
            "https://ik.imagekit.io/wqbvwdo34/badges/EventStar_Y4npXYoFE.svg"
        );
        
        // Badge 22: Grandmaster
        badgeContract.setBadgeImageURL(
            22,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/GrandMaster_MpYe73kal.svg"
        );
        
        // Badge 23: Hall of Famer
        badgeContract.setBadgeImageURL(
            23,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/HallOfFamer_Dvc18L5ay.svg"
        );
        
        vm.stopBroadcast();
    }
}
