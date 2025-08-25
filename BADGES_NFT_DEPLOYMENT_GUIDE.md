# BadgesNFT Contract Deployment Guide

## Overview

The `BadgesNFT` contract is a soulbound (non-transferable) NFT contract that manages achievement badges in the LearnWay ecosystem. Each badge represents a specific achievement milestone and is automatically awarded to users based on their activities.

## Constructor Parameters

The BadgesNFT constructor requires only **one parameter**:

```solidity
constructor(string memory baseURI) ERC721("LearnWay Badges", "LWB") Ownable(msg.sender)
```

### Parameter Details

- **`baseURI`** (string): The base URL where your badge metadata JSON files will be hosted
  - Example: `"https://learnway.com/badges/"`
  - The contract will append the badge's `imageURI` field to this base URL
  - Final URL format: `{baseURI}{imageURI}`

## Metadata Structure

### Hosting Requirements

You need to host 15 JSON metadata files corresponding to each badge type. The files should be accessible via HTTP/HTTPS and named according to the `imageURI` values defined in the contract:

1. `first_spark.json`
2. `duel_champion.json`
3. `squad_slayer.json`
4. `crown_holder.json`
5. `lightning_ace.json`
6. `quiz_warrior.json`
7. `supersonic.json`
8. `speed_scholar.json`
9. `brainiac.json`
10. `quiz_titan.json`
11. `elite.json`
12. `quiz_devotee.json`
13. `power_elite.json`
14. `echo_spreader.json`
15. `routine_master.json`

### JSON Metadata Format

Each metadata file follows the NFT metadata standard and includes:

```json
{
  "name": "Badge Name",
  "description": "Badge description explaining unlock requirements",
  "image": "https://your-domain.com/images/badges/badge_image.png",
  "external_url": "https://your-domain.com/badges/badge_details",
  "attributes": [
    {
      "trait_type": "Badge Type",
      "value": "Category"
    },
    {
      "trait_type": "Rarity",
      "value": "Common/Uncommon/Rare/Epic/Legendary"
    },
    {
      "trait_type": "Category",
      "value": "Specific Category"
    },
    {
      "trait_type": "Requirement",
      "value": "Unlock condition"
    },
    {
      "trait_type": "Badge ID",
      "value": "0-14"
    }
  ],
  "properties": {
    "badge_type": "CONTRACT_ENUM_NAME",
    "unlock_condition": "Detailed unlock condition",
    "is_active": true,
    "collection": "LearnWay Badges"
  }
}
```

## Badge Types and IDs

The contract defines 15 badge types (enum values 0-14):

| ID | Badge Type | Name | Unlock Condition |
|----|------------|------|------------------|
| 0 | FIRST_SPARK | First Spark | Complete first quiz |
| 1 | DUEL_CHAMPION | Duel Champion | Win one 1v1 battle |
| 2 | SQUAD_SLAYER | Squad Slayer | Win one group battle |
| 3 | CROWN_HOLDER | Crown Holder | Win one contest |
| 4 | LIGHTNING_ACE | Lightning Ace | Highest points in 1v1 battle |
| 5 | QUIZ_WARRIOR | Quiz Warrior | Win 3 consecutive battles |
| 6 | SUPERSONIC | SuperSonic | ≤25s avg on "guess_word" quizzes (min 5) |
| 7 | SPEED_SCHOLAR | Speed Scholar | ≤8s avg on "fun_learn" quizzes (min 5) |
| 8 | BRAINIAC | Brainiac | 5 perfect quizzes without lifeline |
| 9 | QUIZ_TITAN | Quiz Titan | 5000 correct answers |
| 10 | ELITE | Elite | 5000+ coins in wallet |
| 11 | QUIZ_DEVOTEE | Quiz Devotee | 30 consecutive days of quiz play |
| 12 | POWER_ELITE | Power Elite | Earn 10+ different badges |
| 13 | ECHO_SPREADER | Echo Spreader | Refer 50+ people |
| 14 | ROUTINE_MASTER | Routine Master | 30-day daily streak |

## Deployment Examples

### Using Foundry

```bash
# Deploy the contract
forge create src/BadgesNFT.sol:BadgesNFT \
  --constructor-args "https://learnway.com/badges/" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Using Hardhat

```javascript
const { ethers } = require("hardhat");

async function main() {
  const BadgesNFT = await ethers.getContractFactory("BadgesNFT");
  const badgesNFT = await BadgesNFT.deploy("https://learnway.com/badges/");
  
  await badgesNFT.deployed();
  console.log("BadgesNFT deployed to:", badgesNFT.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

### Using Remix

1. Compile the `BadgesNFT.sol` contract
2. Go to the Deploy tab
3. Select the contract from the dropdown
4. Enter the baseURI parameter: `"https://learnway.com/badges/"`
5. Click Deploy

## Post-Deployment Setup

After deployment, you need to:

1. **Set LearnWay Manager**: Call `setLearnWayManager(address _manager)` to authorize the LearnWayManager contract to mint badges
2. **Upload Metadata**: Host all 15 JSON metadata files at the URLs specified by your baseURI
3. **Upload Images**: Host badge images referenced in the metadata JSON files
4. **Test Integration**: Verify that the contract integrates properly with your LearnWayManager

## Important Notes

### Soulbound Tokens
- Badges are **non-transferable** (soulbound)
- Users cannot sell, transfer, or give away their badges
- Only minting is allowed; all transfer operations will revert

### Contract Integration
- The BadgesNFT contract works in conjunction with:
  - `LearnWayManager`: Orchestrates user activities and badge awards
  - `GemsContract`: Tracks user coin balances for Elite badge
  - `XPContract`: Tracks user experience points

### Metadata Hosting
- Ensure your metadata hosting is reliable and has good uptime
- Consider using IPFS for decentralized hosting
- Make sure CORS is properly configured if serving from a web domain

## Example Complete Deployment Flow

```solidity
// 1. Deploy BadgesNFT
BadgesNFT badges = new BadgesNFT("https://api.learnway.com/badges/metadata/");

// 2. Deploy other contracts
GemsContract gems = new GemsContract();
XPContract xp = new XPContract();
LearnWayManager manager = new LearnWayManager();

// 3. Set up relationships
manager.setContracts(address(gems), address(xp), address(badges));
badges.setLearnWayManager(address(manager));

// 4. Transfer ownership for proper access control
gems.transferOwnership(address(manager));
xp.transferOwnership(address(manager));
```

## Metadata URLs

With baseURI `"https://learnway.com/badges/"`, the contract will generate these URLs:

- Token ID 1 (First Spark): `https://learnway.com/badges/first_spark.json`
- Token ID 2 (Duel Champion): `https://learnway.com/badges/duel_champion.json`
- And so on...

Make sure all these URLs return valid JSON metadata when accessed via HTTP GET requests.
