# LearnWay Smart Contracts - Actionable Improvement Tasks

## Phase 1: Core Architecture & TODO Implementation

### Priority 1: GemsContract.sol Improvements

#### 1.1 Dynamic Quiz Reward System
- [x] Remove fixed `QUIZ_REWARD = 60` constant
- [x] Implement dynamic reward calculation formula: `(score - 70) * 2` for scores ≥ 70%
- [x] Update `awardQuizGems()` function to use dynamic calculation
- [x] Add minimum score validation in reward calculation
- [x] Test dynamic reward calculation with various score inputs
- [x] Update contract documentation for new reward system

#### 1.2 Dynamic Lesson Rewards System
- [x] Create mapping for different lesson types and their rewards
- [x] Add `mapping(string => uint256) lessonRewards` state variable
- [x] Implement `setLessonReward(string lessonType, uint256 reward)` function
- [x] Add lesson-specific minimum score requirements mapping
- [x] Update reward functions to accept lesson type parameter
- [x] Create batch lesson reward configuration function

#### 1.3 Monthly Leaderboard Reset & Rewards
- [x] Implement automatic monthly leaderboard reset functionality
- [x] Create `resetMonthlyLeaderboard(uint256 month, uint256 year)` function
- [x] Add `distributeMonthlyRewards(address[] topUsers, uint256[] rewards)` function
- [x] Implement reward distribution history tracking
- [x] Add monthly reset automation mechanism
- [x] Create event emissions for monthly operations

#### 1.4 Weekly Leaderboard System
- [x] Add weekly leaderboard tracking alongside monthly
- [x] Implement weekly reward distribution for top 3 users
- [x] Create weekly reset mechanism
- [x] Add weekly reward configuration functions
- [x] Implement automated weekly processing
- [x] Add weekly leaderboard query functions

### Priority 2: Test Suite Development

#### 2.1 GemsContract Test Suite
- [x] Create `test/GemsContract.t.sol` test file
- [x] Test user registration with referral codes
- [x] Test user registration without referral codes
- [x] Test dynamic quiz reward calculations with various scores
- [x] Test contest and battle gem awards
- [x] Test monthly leaderboard reward distribution
- [x] Test gem spending functionality
- [x] Test access control and ownership functions
- [x] Test pause/unpause functionality
- [x] Test edge cases and error conditions
- [x] Test integration with referral system
- [x] Test batch operations functionality

#### 2.2 XPContract Test Suite
- [x] Create `test/XPContract.t.sol` test file
- [x] Test user registration and XP initialization
- [x] Test quiz answer recording (correct/incorrect)
- [x] Test contest participation XP awards
- [x] Test battle result recording and XP changes
- [x] Test leaderboard management and ranking
- [x] Test contest-specific leaderboards
- [x] Test user statistics tracking
- [x] Test XP configuration updates
- [x] Test access control and permissions
- [x] Test integration with other contracts

#### 2.3 LearnWayManager Test Suite
- [x] Create `test/LearnWayManager.t.sol` test file
- [x] Test contract initialization and setup
- [x] Test user registration flow integration
- [x] Test quiz completion workflow
- [x] Test achievement system functionality
- [x] Test user profile management
- [x] Test contest and battle integration
- [x] Test monthly reward distribution
- [x] Test achievement unlocking mechanisms
- [x] Test multi-contract integration scenarios
- [x] Test error handling and edge cases

#### 2.4 Integration Test Suite
- [x] Create `test/Integration.t.sol` test file
- [x] Test end-to-end user journey scenarios
- [x] Test cross-contract communication validation
- [x] Test complex workflow scenarios
- [x] Test data consistency across contracts
- [x] Test event emission verification
- [x] Test performance and gas optimization
- [x] Test system-wide error handling
- [x] Test concurrent user operations
- [x] Test system scalability scenarios
