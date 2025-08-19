# LearnWay Smart Contracts

This directory contains the smart contracts for the LearnWay learn-to-earn module, designed to make certain information immutable on the blockchain.

## Overview

The LearnWay ecosystem consists of three main smart contracts:

1. **GemsContract.sol** - Manages non-transferable Gems tokens (in-app currency) (Contract Address: 0x588eD1BEEEFFFcBAd9c7B43d0853bbE4328a5485)
2. **XPContract.sol** - Manages Experience Points and leaderboard functionality (Contract Address: 0x1891ee3b89836fFF24a7F7588BB18f683322947d)
3. **LearnWayManager.sol** - Central coordinator that integrates both systems and manages achievements

## Contract Details

### 1. GemsContract.sol

**Purpose**: Manages non-transferable Gems tokens that serve as the in-app currency within the LearnWay application.

**Key Features**:
- Non-transferable tokens (users cannot send gems to each other)
- Automated reward distribution for various activities
- Referral system with bonuses
- Monthly leaderboard rewards
- Batch operations for efficiency
- Emergency pause functionality

**Gem Earning Mechanisms**:
- **New User Sign-Up Bonus**: 500 Gems
- **Sign-Up with Referral Code**: Extra 50 Gems for new user
- **Referral Bonus**: 100 Gems for the referrer
- **Quiz Rewards**: 60 Gems for each quiz completed with score ≥ 70%
- **Contest & Battle Rewards**: Variable gems based on performance
- **Monthly Leaderboard**: 1000/500/250 Gems for top 3 positions

**Main Functions**:
- `registerUser(address user, address referralCode)` - Register new user with optional referral
- `awardQuizGems(address user, uint256 score)` - Award gems for quiz completion
- `awardContestGems(address user, uint256 amount, string contestType)` - Award gems for contests/battles
- `awardMonthlyLeaderboardReward(address user, uint256 position)` - Award monthly rewards
- `spendGems(address user, uint256 amount, string reason)` - Spend gems for in-app purchases
- `balanceOf(address user)` - Get user's gem balance

### 2. XPContract.sol

**Purpose**: Manages Experience Points (XPs) that users earn for correct answers and lose for incorrect ones, determining leaderboard positions.

**Key Features**:
- Dynamic XP earning and losing system
- Real-time leaderboard management with automatic ranking
- Contest-specific leaderboards
- Comprehensive user statistics tracking
- Battle result tracking (1v1 and group battles)
- Configurable XP rewards and penalties

**XP Earning/Losing Mechanisms**:
- **Correct Quiz Answer**: +10 XP (configurable)
- **Incorrect Quiz Answer**: -5 XP (configurable)
- **Contest Participation**: +25 XP (configurable)
- **Battle Win**: +50 XP (configurable)
- **Battle Loss**: -10 XP (configurable)

**Main Functions**:
- `registerUser(address user)` - Register new user
- `recordQuizAnswer(address user, bool isCorrect)` - Record quiz answer and update XP
- `recordContestParticipation(address user, string contestId, uint256 xpEarned)` - Record contest participation
- `recordBattleResult(address user, string battleType, bool isWin, uint256 customXP)` - Record battle results
- `getUserStats(address user)` - Get comprehensive user statistics
- `getTopUsers(uint256 count)` - Get top N users from leaderboard
- `getContestLeaderboard(string contestId)` - Get contest-specific leaderboard

### 3. LearnWayManager.sol

**Purpose**: Central management contract that coordinates between Gems and XP contracts, manages user profiles, achievements, and provides unified functionality.

**Key Features**:
- Unified user registration across both systems
- Achievement system with automatic unlocking
- User profile management with activity tracking
- Monthly reward distribution coordination
- Comprehensive user data aggregation
- Custom achievement creation

**Achievement System**:
The contract includes a built-in achievement system with the following default achievements:

**Quiz Achievements**:
- First Steps: Complete 1 quiz (100 gems)
- Quiz Master: Complete 50 quizzes (500 gems)
- Quiz Legend: Complete 200 quizzes (1000 gems)

**Contest Achievements**:
- Contest Participant: Participate in 1 contest (150 gems)
- Contest Veteran: Participate in 25 contests (750 gems)

**Battle Achievements**:
- First Battle: Participate in 1 battle (200 gems)
- Battle Warrior: Participate in 100 battles (1000 gems)

**XP Achievements**:
- XP Collector: Earn 1000 XP (300 gems)
- XP Master: Earn 10000 XP (1500 gems)

**Gems Achievements**:
- Gem Saver: Accumulate 5000 gems (500 gems)
- Gem Collector: Accumulate 20000 gems (2000 gems)

**Main Functions**:
- `setContracts(address _gemsContract, address _xpContract)` - Set contract addresses
- `registerUser(address user, address referralCode, string username)` - Unified user registration
- `completeQuiz(address user, uint256 score, bool[] correctAnswers)` - Process quiz completion
- `completeContest(address user, string contestId, uint256 gemsEarned, uint256 xpEarned)` - Process contest completion
- `completeBattle(address user, string battleType, bool isWin, uint256 gemsEarned, uint256 customXP)` - Process battle completion
- `distributeMonthlyRewards(uint256 month, uint256 year, address[] topUsers)` - Distribute monthly rewards
- `getUserData(address user)` - Get comprehensive user data
- `addCustomAchievement(...)` - Add custom achievements

## Security Features

All contracts implement the following security measures:

1. **Access Control**: Using OpenZeppelin's `Ownable` for owner-only functions
2. **Reentrancy Protection**: Using `ReentrancyGuard` to prevent reentrancy attacks
3. **Pausable**: Emergency pause functionality for all contracts
4. **Input Validation**: Comprehensive validation of all inputs
5. **Safe Math**: Using Solidity 0.8.19+ built-in overflow protection
6. **Event Logging**: Comprehensive event emission for all important actions

## Deployment Instructions

1. Deploy `GemsContract.sol` first
2. Deploy `XPContract.sol` second
3. Deploy `LearnWayManager.sol` third
4. Call `setContracts()` on LearnWayManager with the addresses of the first two contracts
5. Transfer ownership of GemsContract and XPContract to LearnWayManager if desired for unified management

## Integration with Backend

The smart contracts are designed to be integrated with the existing NestJS backend. The backend should:

1. Monitor blockchain events for real-time updates
2. Call contract functions when users perform actions (quiz completion, contest participation, etc.)
3. Query contract state for displaying user balances, rankings, and achievements
4. Handle user registration by calling the appropriate contract functions

## Gas Optimization

The contracts include several gas optimization features:

1. **Batch Operations**: Functions like `batchAwardGems()` and `batchUpdateXP()` for efficient bulk operations
2. **Efficient Data Structures**: Optimized mappings and arrays for leaderboard management
3. **Event-Based Architecture**: Minimal on-chain storage with comprehensive event logging
4. **Configurable Parameters**: Adjustable reward amounts without contract redeployment

## Testing

Before deployment, ensure comprehensive testing of:

1. All reward mechanisms
2. Leaderboard functionality
3. Achievement unlocking
4. Access control mechanisms
5. Emergency pause functionality
6. Edge cases (zero balances, maximum values, etc.)

## Contract Addresses
1. Gems Contract: https://sepolia-blockscout.lisk.com/address/0x588ed1beeefffcbad9c7b43d0853bbe4328a5485?tab=contract
2. XP Contract: https://sepolia-blockscout.lisk.com/address/0x1891ee3b89836ff24a7f7588bb18f683322947d?tab=contract
3. LearnWay Manager: https://sepolia-blockscout.lisk.com/address/0xf313ac1363ee491992fabdc38c8d78b5763f2ed2?tab=contract

## How To Setup
Install Forge CLI:
```bash
curl -L https://foundry.paradigm.xyz | bash
```

Verify Forge CLI installation:
```bash
forge -V
```

Install OpenZeppelin contracts:
```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

## How To Deploy
```bash
forge create src/LearnWayManager.sol:LearnWayManager --rpc-url https://rpc.sepolia-api.lisk.com --private-key <YOUR_PRIVATE_KEY>
```

## How To Verify
```bash
forge verify-contract \                                                                                                                                                                       ─╯
  --rpc-url https://rpc.sepolia-api.lisk.com \
  --verifier blockscout \
  --verifier-url 'https://sepolia-blockscout.lisk.com/api/' \
  <Contract_Address> \
  src/LearnWayManager.sol:LearnWayManager
```

## License

These contracts are licensed under the MIT License.
