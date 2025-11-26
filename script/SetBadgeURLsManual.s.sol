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
        // NOTE: Badge IDs now start from 1 (not 0)
        
        // Badge 1: Keyholder (Silver)
        badgeContract.setBadgeImageURL(
            1,
            LearnWayBadge.BadgeTier.SILVER,
            "https://ik.imagekit.io/wqbvwdo34/badges/SilverKeyholder_cH_Dd3Whl.svg"
        );
        
        // Badge 1: Keyholder (Gold)
        badgeContract.setBadgeImageURL(
            1,
            LearnWayBadge.BadgeTier.GOLD,
            "https://ik.imagekit.io/wqbvwdo34/badges/GoldKeyholder_nEvwt1qVi.svg"
        );
        
        // Badge 2: First Spark
        badgeContract.setBadgeImageURL(
            2,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/FirstSpark_uOj9dts8D.svg"
        );
        
        // Badge 3: Early Bird
        badgeContract.setBadgeImageURL(
            3,
            LearnWayBadge.BadgeTier.GOLD,
            "https://ik.imagekit.io/wqbvwdo34/badges/EarlyBird_HAOtsKKG1-.svg"
        );
        
        // Badge 4: Quiz Explorer
        badgeContract.setBadgeImageURL(
            4,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/QuizExplorer_3sxw-AM1Z.svg"
        );
        
        // Badge 5: Master of Levels
        badgeContract.setBadgeImageURL(
            5,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/MasterOfLevels_mO-EokdYc.svg"
        );
        
        // Badge 6: Quiz Titan
        badgeContract.setBadgeImageURL(
            6,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/QuizTitans_Cjd6NQ32G.svg"
        );
        
        // Badge 7: BRAINIAC
        badgeContract.setBadgeImageURL(
            7,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/Brainiac_eIE08H6Dr.svg"
        );
        
        // Badge 8: Legend
        badgeContract.setBadgeImageURL(
            8,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/Legend_wdfiNd7-f.svg"
        );
        
        // Badge 9: Daily Claims
        badgeContract.setBadgeImageURL(
            9,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/DailyClaims_kvSrakbkl.svg"
        );
        
        // Badge 10: Routine Master (Streaks Routine Master)
        badgeContract.setBadgeImageURL(
            10,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/StreaksRoutineMaster_i0AfiVswqW.svg"
        );
        
        // Badge 11: Quiz Devotee
        badgeContract.setBadgeImageURL(
            11,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/QuizDevotee_xTWy1KNh2.svg"
        );
        
        // Badge 12: Elite
        badgeContract.setBadgeImageURL(
            12,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/Elite_NVbf8d-eN.svg"
        );
        
        // Badge 13: Duel Champion
        badgeContract.setBadgeImageURL(
            13,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/DuelChampion_GqtqSxDFu.svg"
        );
        
        // Badge 14: Squad Slayer
        badgeContract.setBadgeImageURL(
            14,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/SquadSlayer__FDy5_B2Y.svg"
        );
        
        // Badge 15: Crown Holder
        // NOTE: Add URL when available
        // badgeContract.setBadgeImageURL(
        //     15,
        //     LearnWayBadge.BadgeTier.BRONZE,
        //     "https://ik.imagekit.io/wqbvwdo34/badges/CrownHolder_PLACEHOLDER.svg"
        // );
        
        // Badge 16: Rising Star
        badgeContract.setBadgeImageURL(
            16,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/RisingStar_mleCCG9Uz.svg"
        );
        
        // Badge 17: DeFi Voyager
        badgeContract.setBadgeImageURL(
            17,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/DefiVoyager_xQuuE7egs.svg"
        );
        
        // Badge 18: Savings Champion
        badgeContract.setBadgeImageURL(
            18,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/SavingsChampion_cGFSRUE6m.svg"
        );
        
        // Badge 19: Power Elite
        badgeContract.setBadgeImageURL(
            19,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/PowerElite_o3xtjJqZv.svg"
        );
        
        // Badge 20: Community Connector
        badgeContract.setBadgeImageURL(
            20,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/CommunityConnector_FFW7Jj9HG.svg"
        );
        
        // Badge 21: Echo Spreader
        badgeContract.setBadgeImageURL(
            21,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/EchoSpreader_p-2FqOeLd6.svg"
        );
        
        // Badge 22: Event Star (Silver)
        badgeContract.setBadgeImageURL(
            22,
            LearnWayBadge.BadgeTier.SILVER,
            "https://ik.imagekit.io/wqbvwdo34/badges/EventStarSilver_eajvcvwhk.svg"
        );
        
        // Badge 22: Event Star (Gold)
        badgeContract.setBadgeImageURL(
            22,
            LearnWayBadge.BadgeTier.GOLD,
            "https://ik.imagekit.io/wqbvwdo34/badges/EventStar_Y4npXYoFE.svg"
        );
        
        // Badge 23: Grandmaster
        badgeContract.setBadgeImageURL(
            23,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/GrandMaster_MpYe73kal.svg"
        );
        
        // Badge 24: Hall of Famer
        badgeContract.setBadgeImageURL(
            24,
            LearnWayBadge.BadgeTier.BRONZE,
            "https://ik.imagekit.io/wqbvwdo34/badges/HallOfFamer_Dvc18L5ay.svg"
        );
        
        vm.stopBroadcast();
    }
}
