# BadgesNFT - LearnWay Achievement System

## Quick Start

The **BadgesNFT** contract requires only one parameter to deploy:

```solidity
constructor(string memory baseURI)
```

**Example deployment:**
```solidity
BadgesNFT badges = new BadgesNFT("https://learnway.com/badges/");
```

## What You Need

### 1. Constructor Parameter
- **`baseURI`**: The base URL where your JSON metadata files will be hosted
- Example: `"https://learnway.com/badges/"`

### 2. Metadata Files
You need to host 15 JSON files at your baseURI location:

- `first_spark.json` - First quiz completion badge
- `duel_champion.json` - 1v1 battle winner badge  
- `squad_slayer.json` - Group battle winner badge
- `crown_holder.json` - Contest winner badge
- `lightning_ace.json` - Highest 1v1 battle points badge
- `quiz_warrior.json` - 3 consecutive battle wins badge
- `supersonic.json` - Fast "guess_word" quiz solver badge
- `speed_scholar.json` - Fast "fun_learn" quiz solver badge
- `brainiac.json` - Perfect quiz without lifeline badge
- `quiz_titan.json` - 5000 correct answers badge
- `elite.json` - 5000+ coins wallet badge
- `quiz_devotee.json` - 30 days daily quiz badge
- `power_elite.json` - 10+ badges earned badge
- `echo_spreader.json` - 50+ referrals badge
- `routine_master.json` - 30-day streak badge

## Complete Metadata Collection

All 15 metadata files are included in the `/metadata/` directory of this repository. Each file follows the NFT metadata standard with:

- **name**: Badge display name
- **description**: Achievement requirement description  
- **image**: URL to badge artwork
- **external_url**: Link to badge details page
- **attributes**: Structured traits for marketplaces
- **properties**: Custom badge properties

## Contract Features

### Soulbound NFTs
- Badges are **non-transferable** (soulbound tokens)
- Users earn badges but cannot sell or transfer them
- Represents true achievement rather than purchased status

### Automatic Badge Awards
Badges are automatically awarded when users:
- Complete quizzes with specific performance metrics
- Win battles and contests
- Maintain daily streaks
- Reach milestone achievements
- Build community through referrals

### Integration Ready
Works seamlessly with:
- **LearnWayManager**: Orchestrates user activities
- **GemsContract**: Tracks user coin balances  
- **XPContract**: Manages experience points

## Badge Categories & Rarities

| Category | Count | Examples |
|----------|-------|----------|
| **Common** (First achievements) | 3 | First Spark, Duel Champion, Squad Slayer |
| **Uncommon** (Skill-based) | 2 | Crown Holder, Lightning Ace |
| **Rare** (Performance-based) | 3 | Quiz Warrior, Supersonic, Speed Scholar |
| **Epic** (Long-term commitment) | 4 | Brainiac, Elite, Quiz Devotee, Echo Spreader, Routine Master |
| **Legendary** (Master level) | 2 | Quiz Titan, Power Elite |

## Deployment Steps

1. **Deploy Contract**
   ```bash
   forge create src/BadgesNFT.sol:BadgesNFT \
     --constructor-args "https://your-domain.com/badges/" \
     --private-key $PRIVATE_KEY
   ```

2. **Upload Metadata Files**
   - Host all 15 JSON files at your baseURI location
   - Ensure they're accessible via HTTPS
   - Test that URLs return valid JSON

3. **Deploy Supporting Contracts**
   ```solidity
   GemsContract gems = new GemsContract();
   XPContract xp = new XPContract();  
   LearnWayManager manager = new LearnWayManager();
   ```

4. **Configure Relationships**
   ```solidity
   manager.setContracts(address(gems), address(xp), address(badges));
   badges.setLearnWayManager(address(manager));
   ```

5. **Transfer Ownership**
   ```solidity
   gems.transferOwnership(address(manager));
   xp.transferOwnership(address(manager));
   ```

## Example Metadata Structure

```json
{
  "name": "First Spark",
  "description": "First public appearance - Play quizZone first time",
  "image": "https://learnway.com/images/badges/first_spark.png",
  "external_url": "https://learnway.com/badges/first_spark",
  "attributes": [
    {
      "trait_type": "Badge Type",
      "value": "Achievement"
    },
    {
      "trait_type": "Rarity", 
      "value": "Common"
    },
    {
      "trait_type": "Badge ID",
      "value": "0"
    }
  ],
  "properties": {
    "badge_type": "FIRST_SPARK",
    "unlock_condition": "First quiz completion",
    "is_active": true,
    "collection": "LearnWay Badges"
  }
}
```

## Key Functions

### Owner Functions
- `setLearnWayManager(address)` - Authorize badge minting contract
- `setBaseURI(string)` - Update metadata base URL
- `pause()/unpause()` - Emergency controls

### Manager Functions  
- `recordQuizCompletion(...)` - Track quiz performance
- `recordBattleCompletion(...)` - Track battle results
- `recordContestWin(address)` - Record contest victories
- `updateReferralCount(...)` - Update referral statistics

### View Functions
- `getUserBadgeStatus(address)` - Get user's badge collection
- `getUserBadges(address)` - Get user's token IDs  
- `getBadgeInfo(BadgeType)` - Get badge metadata
- `tokenURI(uint256)` - Get token metadata URL

## File Structure

```
learnway_v2_contracts/
├── src/
│   └── BadgesNFT.sol              # Main contract
├── test/  
│   └── BadgesNFT.t.sol           # Comprehensive tests
├── metadata/                      # All 15 JSON files
│   ├── first_spark.json
│   ├── duel_champion.json
│   ├── squad_slayer.json
│   └── ... (12 more files)
├── BADGES_NFT_DEPLOYMENT_GUIDE.md # Detailed deployment guide
└── BADGES_NFT_README.md          # This overview
```

## Testing

Run the comprehensive test suite:

```bash
forge test --match-contract BadgesNFTTest -v
```

Tests cover:
- All 15 badge unlock conditions
- Soulbound transfer restrictions  
- Metadata functionality
- Integration with other contracts
- Edge cases and error conditions

## Support

For questions about:
- **Contract deployment**: See `BADGES_NFT_DEPLOYMENT_GUIDE.md`
- **Metadata hosting**: Check the `/metadata/` directory
- **Integration**: Review the test files for examples
- **Badge mechanics**: Examine badge unlock logic in the contract

The BadgesNFT contract is designed to be simple to deploy while providing a robust achievement system for the LearnWay ecosystem.
