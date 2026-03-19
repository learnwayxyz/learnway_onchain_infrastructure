# CERTIFICATE NFT SYSTEM - HOW IT WORKS

## Table of Contents

- [System Overview](#system-overview)
- [Contract Architecture](#contract-architecture)
- [Data Structures and Storage](#data-structures-and-storage)
- [Course Management](#course-management)
- [Certificate Minting](#certificate-minting)
- [Soulbound Mechanics](#soulbound-mechanics)
- [Query Functions](#query-functions)
- [Manager Integration](#manager-integration)
- [Access Control](#access-control)
- [Pausability](#pausability)
- [Upgrade Safety](#upgrade-safety)
- [Events](#events)
- [Error Reference](#error-reference)
- [IPFS Metadata Standard](#ipfs-metadata-standard)
- [Deployment and Verification](#deployment-and-verification)
- [Conclusion](#conclusion)

---

## System Overview

The LearnWay Certificate NFT system issues **soulbound (non-transferable) ERC-721 tokens** as on-chain proof of course completion. When a user finishes a course on the LearnWay platform, a certificate NFT is minted to their wallet — permanently. The token cannot be transferred, sold, or traded. Certificate metadata (name, image, attributes) is stored on IPFS and referenced on-chain via a URI.

### Key Characteristics

- **Soulbound**: Certificates are non-transferable — permanently bound to the recipient's wallet
- **ERC-721 Compliant**: Standard NFT interface, compatible with wallets and block explorers
- **IPFS Metadata**: Certificate visuals and descriptive data stored off-chain on IPFS, referenced by on-chain URI
- **One Per User Per Course**: The contract prevents duplicate certificates at the storage level
- **Course Gating**: Only courses explicitly registered on-chain can issue certificates
- **Batch Support**: The Manager contract supports minting up to 50 certificates in a single transaction
- **UUPS Upgradeable**: Proxy-based upgradeability preserving all existing certificate data
- **Role-Based Access**: All operations gated by the LearnWayAdmin role system

### Contract Identity

- **Name**: `LearnWay Certificate`
- **Symbol**: `LWC`
- **Token Standard**: ERC-721
- **Solidity Version**: `^0.8.22`
- **Inheritance**: `Initializable`, `ERC721Upgradeable`, `ReentrancyGuardUpgradeable`, `PausableUpgradeable`, `UUPSUpgradeable`

### System Diagram

```
┌──────────────────────────────────────────────────────┐
│                   LearnWay Admin                     │
│              (Role-Based Access Control)             │
│         ADMIN_ROLE / MANAGER_ROLE / PAUSER_ROLE      │
└──────────────┬───────────────────────┬───────────────┘
               │                       │
               v                       v
┌──────────────────────┐   ┌───────────────────────────┐
│  LearnWayCertificate │   │     LearnWayManager       │
│      (ERC-721)       │<──│   (Batch Ops + Views)     │
│                      │   │                           │
│  - Course Registry   │   │  - batchMintCertificates  │
│  - Mint Soulbound    │   │  - getUserCertificates    │
│  - Certificate Data  │   │  - userHasCertificate     │
│  - IPFS Token URIs   │   │  - getUserCertificate     │
└──────────────────────┘   └───────────────────────────┘
               │
               v
        ┌─────────────┐
        │    IPFS     │
        │  (Metadata  │
        │  + Images)  │
        └─────────────┘
```

---

## Contract Architecture

`LearnWayCertificate.sol` is a UUPS-upgradeable ERC-721 contract with the following OpenZeppelin mixins:

| Mixin                        | Purpose                                                   |
| ---------------------------- | --------------------------------------------------------- |
| `Initializable`              | Proxy-safe constructor replacement                        |
| `ERC721Upgradeable`          | Standard NFT functionality                                |
| `ReentrancyGuardUpgradeable` | Protection against reentrancy on state-changing functions |
| `PausableUpgradeable`        | Emergency pause capability                                |
| `UUPSUpgradeable`            | Proxy upgrade authorization                               |

### Initialization

```
initialize(address _admin)
  │
  ├── Require: _admin != address(0)
  │
  ├── __ERC721_init("LearnWay Certificate", "LWC")
  ├── __ReentrancyGuard_init()
  ├── __Pausable_init()
  ├── __UUPSUpgradeable_init()
  │
  ├── adminContract = ILearnWayAdmin(_admin)
  └── _tokenIdCounter = 1
```

The contract is initialized with a reference to the `LearnWayAdmin` contract, which provides all role-based access control. Token IDs start at 1.

---

## Data Structures and Storage

### Structs

#### Course

Represents a course registered on-chain that can issue certificates.

```solidity
struct Course {
    string courseName;       // Human-readable course title
    string instructorName;   // Name of the course instructor
    bool active;             // Whether new certificates can be minted
}
```

#### CertificateData

Represents a minted certificate NFT and its associated metadata.

```solidity
struct CertificateData {
    uint256 courseId;         // ID of the course this certificate belongs to
    address recipient;       // Wallet address of the certificate holder
    uint256 mintedAt;        // block.timestamp when minted
    string metadataURI;      // IPFS URI for the certificate metadata JSON
}
```

### Storage Mappings

| Mapping                  | Type                            | Visibility | Purpose                                                |
| ------------------------ | ------------------------------- | ---------- | ------------------------------------------------------ |
| `courses`                | `uint256 => Course`             | internal   | Course struct storage by courseId                      |
| `courseExists`           | `uint256 => bool`               | public     | Quick existence check for a courseId                   |
| `certificates`           | `uint256 => CertificateData`    | internal   | Certificate data by NFT tokenId                        |
| `hasCertificate`         | `address => uint256 => bool`    | public     | Whether user has a cert for a course (duplicate guard) |
| `userCertificateTokenId` | `address => uint256 => uint256` | public     | Maps (user, courseId) to tokenId                       |
| `userCertificateList`    | `address => uint256[]`          | internal   | Array of courseIds a user holds certificates for       |

### Token ID Counter

- `_tokenIdCounter` starts at `1` (set in `initialize`)
- Uses post-increment assignment: `uint256 tokenId = _tokenIdCounter++`
- Token IDs are globally unique across all courses and all users
- IDs are sequential — no gaps unless a future upgrade introduces burning

### Storage Gap

```solidity
uint256[45] private _gap;
```

45 storage slots reserved for future upgrades without colliding with inherited or new state variables.

---

## Course Management

Courses must be registered on-chain before certificates can be minted for them. This is an admin-only operation.

### addCourse

Registers a new course in the on-chain registry.

```
addCourse(uint256 courseId, string courseName, string instructorName)
```

**Access**: ADMIN_ROLE only
**Guards**: `nonReentrant`, `whenNotPaused`

**Flow**:

```
addCourse(courseId, courseName, instructorName)
  │
  ├── Revert if courseExists[courseId]         → CourseAlreadyExists()
  ├── Revert if courseName is empty           → EmptyCourseName()
  ├── Revert if instructorName is empty       → EmptyInstructorName()
  │
  ├── courseExists[courseId] = true
  ├── courses[courseId] = Course { courseName, instructorName, active: true }
  │
  └── Emit CourseAdded(courseId, courseName, instructorName, true)
```

**Notes**:

- The `courseId` is caller-supplied (not auto-incremented) — this allows the backend to use its own course ID scheme
- Courses are active by default upon creation
- Course data (name, instructor) is immutable after creation — only the `active` status can be changed

### updateCourseStatus

Enables or disables certificate minting for a course.

```
updateCourseStatus(uint256 courseId, bool active)
```

**Access**: ADMIN_ROLE only
**Guards**: `nonReentrant`, `whenNotPaused`

**Flow**:

```
updateCourseStatus(courseId, active)
  │
  ├── Revert if !courseExists[courseId]        → InvalidCourseId()
  │
  ├── courses[courseId].active = active
  │
  └── Emit CourseStatusUpdated(courseId, active, true)
```

**Important**: Deactivating a course does **not** revoke or affect existing certificates. It only prevents new certificates from being minted for that course.

---

## Certificate Minting

### mintCertificate

Mints a soulbound certificate NFT to a user for a specific course.

```
mintCertificate(address user, uint256 courseId, string metadataURI)
```

**Access**: ADMIN_ROLE or MANAGER_ROLE
**Guards**: `nonReentrant`, `whenNotPaused`

**Validation Chain** (in order):

1. `user != address(0)` — revert `InvalidAddress()`
2. `courseExists[courseId]` — revert `InvalidCourseId()`
3. `courses[courseId].active` — revert `CourseNotActive()`
4. `!hasCertificate[user][courseId]` — revert `CertificateAlreadyMinted()`
5. `bytes(metadataURI).length > 0` — revert `EmptyMetadataURI()`

**Minting Flow**:

```
mintCertificate(user, courseId, metadataURI)
  │
  ├── [5 validation checks above]
  │
  ├── tokenId = _tokenIdCounter++
  ├── _mint(user, tokenId)                     ← ERC-721 mint
  │
  ├── certificates[tokenId] = CertificateData {
  │     courseId, recipient: user,
  │     mintedAt: block.timestamp,
  │     metadataURI
  │   }
  │
  ├── hasCertificate[user][courseId] = true
  ├── userCertificateTokenId[user][courseId] = tokenId
  ├── userCertificateList[user].push(courseId)
  │
  └── Emit CertificateMinted(user, courseId, tokenId, metadataURI, true)
```

**State changes on successful mint**:

- New ERC-721 token minted to `user` with `tokenId`
- `CertificateData` struct stored at `certificates[tokenId]`
- Duplicate guard set: `hasCertificate[user][courseId] = true`
- Reverse lookup stored: `userCertificateTokenId[user][courseId] = tokenId`
- Course ID appended to user's certificate list

**Gas considerations**:

- Each mint writes to 5 storage slots + the ERC-721 balance/owner slots
- String storage (`metadataURI`) is the most gas-expensive part — keep URIs compact (IPFS CIDs are ~46 chars)

---

## Soulbound Mechanics

The certificate contract enforces non-transferability by overriding the internal `_update` function from `ERC721Upgradeable`:

```solidity
function _update(address to, uint256 tokenId, address auth)
    internal override whenNotPaused returns (address)
{
    address from = _ownerOf(tokenId);

    // Block transfers (from != 0 AND to != 0)
    if (from != address(0) && to != address(0)) {
        revert CertificateNonTransferable();
    }

    return super._update(to, tokenId, auth);
}
```

### Transfer Rules

| Operation    | `from` | `to`         | Allowed?                                              |
| ------------ | ------ | ------------ | ----------------------------------------------------- |
| **Mint**     | `0x0`  | user         | Yes                                                   |
| **Transfer** | user   | another user | **No** — reverts `CertificateNonTransferable()`       |
| **Burn**     | user   | `0x0`        | Yes (no public burn function exists, but not blocked) |

### Implications

- `transferFrom()`, `safeTransferFrom()`, and `approve()` will all revert when attempting an actual transfer — they all route through `_update`
- NFT marketplaces (OpenSea, etc.) will see transfer attempts revert, effectively marking these tokens as non-tradeable
- The `_update` override also includes `whenNotPaused`, meaning even minting is blocked when the contract is paused
- This enforcement is at the EVM level — it cannot be bypassed by any off-chain system

---

## Query Functions

All query functions are `view` (read-only) and cost no gas when called off-chain.

### tokenURI

Returns the IPFS metadata URI for a certificate.

```
tokenURI(uint256 tokenId) → string
```

- Reverts with `ERC721NonexistentToken` if token does not exist
- Returns the `metadataURI` stored in `certificates[tokenId]`

### getCertificateByToken

Returns full certificate data by token ID.

```
getCertificateByToken(uint256 tokenId)
  → (uint256 courseId, address recipient, uint256 mintedAt, string metadataURI)
```

- Reverts with `ERC721NonexistentToken` if token does not exist

### getCertificate

Looks up a certificate by user address and course ID.

```
getCertificate(address user, uint256 courseId)
  → (bool exists, uint256 tokenId, uint256 mintedAt, string metadataURI)
```

- Returns `exists = false` with zeroed fields if no certificate exists
- Does **not** revert on missing certificate — returns a boolean instead

### getUserCertificates

Returns all course IDs for which a user holds certificates.

```
getUserCertificates(address user) → uint256[]
```

- Returns an empty array if the user has no certificates
- Returns course IDs, not token IDs — use `userCertificateTokenId` to map course → token

### getCourseInfo

Returns course details by ID.

```
getCourseInfo(uint256 courseId)
  → (string courseName, string instructorName, bool active)
```

- Reverts with `InvalidCourseId()` if the course does not exist

---

## Manager Integration

`LearnWayManager.sol` provides batch operations and unified view proxies for the certificate system. The backend typically interacts through the Manager rather than calling `LearnWayCertificate` directly.

### Setup

```
setCertificateContract(address _certificateContract)
```

- Called by ADMIN_ROLE on the Manager to set the certificate contract address
- Must be called before any certificate operations through the Manager

### Batch Minting

```
batchMintCertificates(
    address[] users,
    uint256[] courseIds,
    string[] metadataURIs
)
```

**Access**: ADMIN_ROLE or MANAGER_ROLE
**Guards**: `nonReentrant`, `whenNotPaused`
**Max batch size**: 50

**Flow**:

```
batchMintCertificates(users, courseIds, metadataURIs)
  │
  ├── Require: certificateContract != address(0)
  ├── Require: all arrays same length
  ├── Require: users.length <= 50
  │
  └── For each entry i:
      ├── Require: users[i] != address(0)
      ├── certificateContract.mintCertificate(users[i], courseIds[i], metadataURIs[i])
      └── Emit CertificateMinted(users[i], courseIds[i], block.timestamp)
```

**Note**: Unlike other Manager batch functions (e.g., `batchRegisterUsers` which skips unregistered users), `batchMintCertificates` will **revert the entire transaction** if any individual mint fails (e.g., duplicate certificate, inactive course).

### View Proxies

The Manager provides null-safe wrappers that return defaults when the certificate contract is not set:

| Manager Function                     | Delegates To                                         | Default (if cert contract not set) |
| ------------------------------------ | ---------------------------------------------------- | ---------------------------------- |
| `getUserCertificates(user)`          | `certificateContract.getUserCertificates(user)`      | Empty `uint256[]`                  |
| `userHasCertificate(user, courseId)` | `certificateContract.hasCertificate(user, courseId)` | `false`                            |
| `getUserCertificate(user, courseId)` | `certificateContract.getCertificate(user, courseId)` | Zeroed tuple                       |

### Unified User Data

`getUserCompleteData(user)` returns a combined view of the user's entire on-chain profile, including a `certificatesList` field alongside XP, gems, badges, streak, and registration data.

`getContractAddresses()` returns the certificate contract address (along with XP/Gems and Badges addresses).

---

## Access Control

All access control is delegated to `LearnWayAdmin.sol` via the `ILearnWayAdmin.isAuthorized(role, account)` interface.

### Role Matrix

| Function              | ADMIN_ROLE | MANAGER_ROLE | PAUSER_ROLE |
| --------------------- | :--------: | :----------: | :---------: |
| `addCourse`           |    Yes     |      —       |      —      |
| `updateCourseStatus`  |    Yes     |      —       |      —      |
| `mintCertificate`     |    Yes     |     Yes      |      —      |
| `updateAdminContract` |    Yes     |      —       |      —      |
| `pause`               |    Yes     |      —       |     Yes     |
| `unpause`             |    Yes     |      —       |      —      |
| `_authorizeUpgrade`   |    Yes     |      —       |      —      |

### Modifiers

- **`onlyAdmin`**: Requires `ADMIN_ROLE` — reverts `UnauthorizedAdmin()`
- **`onlyAdminOrManager`**: Requires `ADMIN_ROLE` or `MANAGER_ROLE` — reverts `UnauthorizedAdminOrManager()`
- **`onlyPausableAndAdmin`**: Requires `PAUSER_ROLE` or `ADMIN_ROLE` — reverts `UnauthorizedPauser()`

### Admin Contract Update

```
updateAdminContract(address newAdmin)
```

- ADMIN_ROLE only (no additional guards)
- Reverts `InvalidAddress()` if zero address
- Emits `AdminContractUpdated(newAdmin, true)`

---

## Pausability

The contract can be paused for emergency situations.

| Function    | Who Can Call              |
| ----------- | ------------------------- |
| `pause()`   | ADMIN_ROLE or PAUSER_ROLE |
| `unpause()` | ADMIN_ROLE only           |

### What Gets Blocked When Paused

- `addCourse` (via `whenNotPaused`)
- `updateCourseStatus` (via `whenNotPaused`)
- `mintCertificate` (via `whenNotPaused`)
- `_update` — even ERC-721 minting is blocked (via `whenNotPaused` in the override)

### What Remains Available When Paused

All view/query functions continue to work:

- `tokenURI`, `getCertificate`, `getCertificateByToken`, `getUserCertificates`, `getCourseInfo`
- `ownerOf`, `balanceOf` (inherited ERC-721)
- `hasCertificate`, `courseExists`, `userCertificateTokenId` (public mappings)

---

## Upgrade Safety

### UUPS Pattern

- `_authorizeUpgrade(address newImplementation)` restricted to ADMIN_ROLE
- Constructor calls `_disableInitializers()` to prevent initialization of the implementation contract
- `initialize()` uses the `initializer` modifier — can only be called once per proxy

### Storage Gap

```solidity
uint256[45] private _gap;
```

45 reserved storage slots after all current state variables. This allows future upgrades to add new state variables without overwriting existing storage layout.

### Storage Layout (in order)

1. `adminContract` — `ILearnWayAdmin` (1 slot)
2. `_tokenIdCounter` — `uint256` (1 slot)
3. `courses` — `mapping(uint256 => Course)` (1 slot)
4. `courseExists` — `mapping(uint256 => bool)` (1 slot)
5. `certificates` — `mapping(uint256 => CertificateData)` (1 slot)
6. `hasCertificate` — `mapping(address => mapping(uint256 => bool))` (1 slot)
7. `userCertificateTokenId` — `mapping(address => mapping(uint256 => uint256))` (1 slot)
8. `userCertificateList` — `mapping(address => uint256[])` (1 slot)
9. `_gap` — `uint256[45]` (45 slots)

Total contract-specific storage: 53 slots (8 state + 45 gap), plus inherited OpenZeppelin slots.

---

## Events

### CourseAdded

```solidity
event CourseAdded(uint256 indexed courseId, string courseName, string instructorName, bool status);
```

Emitted when a new course is registered on-chain.

### CourseStatusUpdated

```solidity
event CourseStatusUpdated(uint256 indexed courseId, bool active, bool status);
```

Emitted when a course's active status is changed.

### CertificateMinted

```solidity
event CertificateMinted(
    address indexed user,
    uint256 indexed courseId,
    uint256 tokenId,
    string metadataURI,
    bool status
);
```

Emitted when a certificate NFT is minted. Both `user` and `courseId` are indexed for efficient filtering.

### AdminContractUpdated

```solidity
event AdminContractUpdated(address indexed newAdminContract, bool status);
```

Emitted when the admin contract reference is changed.

**Note**: The `bool status` parameter on all events is always `true` — it serves as a success flag consistent with other LearnWay contracts.

---

## Error Reference

### Certificate Contract Errors

| Error                          | Trigger                                 | Context                                                |
| ------------------------------ | --------------------------------------- | ------------------------------------------------------ |
| `InvalidAddress()`             | Zero address passed                     | `initialize`, `mintCertificate`, `updateAdminContract` |
| `InvalidCourseId()`            | Course ID not registered                | `updateCourseStatus`, `getCourseInfo`                  |
| `CourseAlreadyExists()`        | Duplicate course registration           | `addCourse`                                            |
| `CourseNotActive()`            | Course is deactivated                   | `mintCertificate`                                      |
| `CertificateAlreadyMinted()`   | User already has cert for course        | `mintCertificate`                                      |
| `CertificateNonTransferable()` | Transfer attempted                      | `_update` (via `transferFrom`, etc.)                   |
| `EmptyCourseName()`            | Empty course name string                | `addCourse`                                            |
| `EmptyInstructorName()`        | Empty instructor name string            | `addCourse`                                            |
| `EmptyMetadataURI()`           | Empty metadata URI string               | `mintCertificate`                                      |
| `UnauthorizedAdmin()`          | Caller lacks ADMIN_ROLE                 | `onlyAdmin` modifier                                   |
| `UnauthorizedAdminOrManager()` | Caller lacks both roles                 | `onlyAdminOrManager` modifier                          |
| `UnauthorizedPauser()`         | Caller lacks PAUSER_ROLE and ADMIN_ROLE | `onlyPausableAndAdmin` modifier                        |

### Manager Contract Errors (require strings)

| Error Message                            | Trigger                                                        |
| ---------------------------------------- | -------------------------------------------------------------- |
| `"Certificate contract not set"`         | `batchMintCertificates` called before `setCertificateContract` |
| `"Array length mismatch"`                | Batch arrays have different lengths                            |
| `"Batch size too large"`                 | More than 50 entries in batch mint                             |
| `"Invalid address in batch"`             | Zero address in batch array                                    |
| `"Invalid certificate contract address"` | Zero address in `setCertificateContract`                       |

---

## IPFS Metadata Standard

Certificate metadata follows the [ERC-721 Metadata JSON Schema](https://eips.ethereum.org/EIPS/eip-721). The `metadataURI` stored on-chain should point to a JSON file on IPFS.

### Expected Schema

```json
{
  "name": "LearnWay Certificate — Introduction to DeFi",
  "description": "This certificate verifies that the holder successfully completed the course 'Introduction to DeFi' on LearnWay.",
  "image": "ipfs://QmExampleImageCID/certificate.png",
  "attributes": [
    { "trait_type": "Course Name", "value": "Introduction to DeFi" },
    { "trait_type": "Instructor", "value": "Jane Doe" },
    { "trait_type": "Course ID", "value": "42" },
    { "trait_type": "Completion Date", "value": "2026-03-15" },
    { "trait_type": "Recipient", "value": "0x1234...abcd" },
    { "trait_type": "Transferable", "value": "No (Soulbound)" }
  ],
  "external_url": "https://blockscout.lisk.com/token/{contractAddress}/instance/{tokenId}"
}
```

### URI Resolution

- `tokenURI(tokenId)` returns the raw `metadataURI` string (e.g., `ipfs://QmABC123...`)
- Wallets and explorers resolve this via IPFS gateways
- The URI is immutable after minting — there is no function to update a certificate's metadata URI

### Immutability

- IPFS URIs are content-addressed: the CID changes if the content changes
- Once a certificate is minted, its `metadataURI` is permanent on-chain
- This provides a guarantee that the certificate metadata cannot be tampered with post-mint

---

## Deployment and Verification

### Network Details

- **Testnet**: Lisk Sepolia (Chain ID: 4202)
- **Mainnet**: Lisk Mainnet (Chain ID: 1135)
- **Verification**: Blockscout

### Deployment Steps

1. Deploy `LearnWayCertificate` implementation contract
2. Deploy UUPS proxy pointing to the implementation
3. Call `initialize(adminContractAddress)` on the proxy
4. On `LearnWayManager`, call `setCertificateContract(certificateProxyAddress)`
5. Register courses via `addCourse(courseId, name, instructor)` for each course that should issue certificates
6. Verify the implementation contract on Blockscout

### Post-Deployment Verification Checklist

- [ ] `adminContract` returns the correct LearnWayAdmin proxy address
- [ ] `name()` returns `"LearnWay Certificate"` and `symbol()` returns `"LWC"`
- [ ] `courseExists(testCourseId)` returns `true` after registration
- [ ] `getCourseInfo(testCourseId)` returns correct course data
- [ ] Test mint succeeds and `CertificateMinted` event is emitted
- [ ] `tokenURI(tokenId)` returns the correct IPFS URI
- [ ] Transfer attempt reverts with `CertificateNonTransferable()`
- [ ] Duplicate mint attempt reverts with `CertificateAlreadyMinted()`
- [ ] Manager `getContractAddresses()` returns the certificate proxy address
- [ ] Manager `batchMintCertificates` works for a small test batch

---

## Conclusion

The LearnWay Certificate NFT system provides tamper-proof, on-chain proof of course completion through soulbound ERC-721 tokens. Certificates are permanently bound to the earner's wallet and reference immutable IPFS metadata, making them verifiable by anyone without reliance on a centralized server.

### Key Benefits

- **On-Chain Verifiability**: Anyone can verify a certificate by querying the smart contract or checking Blockscout
- **Soulbound Non-Transferability**: Certificates cannot be sold or traded, preserving credential integrity
- **Immutable Metadata**: IPFS-backed metadata ensures certificate details cannot be altered post-mint
- **Batch Efficiency**: Up to 50 certificates per transaction via the Manager contract
- **Ecosystem Integration**: Certificate data flows through the Manager alongside XP, gems, badges, and streaks for a unified user profile
- **Upgrade Safety**: UUPS proxy pattern with 45-slot storage gap allows the contract to evolve while preserving all existing data

---

**Related Contracts**:

- `LearnWayAdmin.sol` — Role-based access control
- `LearnWayManager.sol` — Batch operations and unified view layer
- `LearnWayBadge.sol` — Badge NFT system (ERC-1155)
- `LearnwayXPGems.sol` — XP, gems, and streak tracking
