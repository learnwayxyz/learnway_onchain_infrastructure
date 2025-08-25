# Pinata IPFS Integration for LearnWay NFT Metadata

This document explains how to upload LearnWay Badge NFT metadata to Pinata IPFS and update the smart contract to use the hosted metadata.

## Overview

The LearnWay Badges NFT contract currently uses a `baseURI + filename.json` approach for metadata. This integration uses the official Pinata SDK to upload all metadata JSON files to Pinata's IPFS service, providing decentralized hosting for NFT metadata.

## Prerequisites

1. **Pinata Account**: Create a free account at [pinata.cloud](https://pinata.cloud)
2. **JWT Token**: Generate a JWT token from your Pinata dashboard
3. **Node.js**: Install Node.js (version 20+ recommended for Pinata SDK)

## Setup Instructions

### 1. Get Pinata JWT Token

1. Log in to your Pinata dashboard
2. Navigate to "Developers" → "API Keys"
3. Click "New Key"
4. Enable the following permissions:
   - `pinFileToIPFS`
   - `pinJSONToIPFS`
   - `unpin`
   - `userPinnedDataTotal`
5. Copy the JWT token (this replaces the old API key/secret approach)

### 2. Set Environment Variables

Create a `.env` file in the project root or export the variables:

```bash
export PINATA_JWT="your_jwt_token_here"
```

### 3. Install Dependencies

Navigate to the scripts directory and install dependencies:

```bash
cd scripts
npm install
```

## Usage

### Upload Metadata to Pinata

1. Ensure all metadata JSON files are in the `metadata/` directory
2. Run the upload script:

```bash
cd scripts
npm run upload
```

Or directly:

```bash
node upload_to_pinata.js
```

### Script Output

The script will:
- Upload all 15 badge metadata JSON files to Pinata
- Display progress and IPFS hashes for each file
- Generate a summary of successful/failed uploads
- Save detailed results to `pinata_upload_results.json`
- Suggest the new baseURI for the contract

Example output:
```
Found 15 JSON files to upload to Pinata...
Uploading first_spark.json...
✓ first_spark.json uploaded successfully
  IPFS Hash: QmXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx
  Pinata URL: https://gateway.pinata.cloud/ipfs/QmXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx

=== UPLOAD SUMMARY ===
Total files: 15
Successful uploads: 15
Failed uploads: 0

=== SUGGESTED CONTRACT UPDATE ===
Update contract baseURI to: https://gateway.pinata.cloud/ipfs/
Contract function: setBaseURI("https://gateway.pinata.cloud/ipfs/")
```

## Update Smart Contract

After successful upload, update the contract's baseURI:

### Option 1: Using Foundry Script (Recommended)

Run the provided Foundry script:

```bash
forge script script/UpdateBaseURI.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Option 2: Direct Contract Call

Call the `setBaseURI` function on the deployed contract:

```solidity
// Call this function as contract owner
setBaseURI("https://gateway.pinata.cloud/ipfs/")
```

## Verification

After updating the baseURI, verify the integration:

1. **Check individual metadata**: Visit `https://gateway.pinata.cloud/ipfs/[IPFS_HASH]` for any uploaded file
2. **Test tokenURI function**: Call `tokenURI(tokenId)` on the contract - it should return Pinata URLs
3. **Verify in NFT marketplaces**: The metadata should load correctly in OpenSea, etc.

## File Structure

```
learnway_v2_contracts/
├── metadata/                    # Original JSON files
│   ├── first_spark.json
│   ├── duel_champion.json
│   └── ... (13 more files)
├── scripts/
│   ├── upload_to_pinata.js     # Upload script
│   ├── package.json            # Node.js dependencies
│   └── UpdateBaseURI.s.sol     # Foundry script
└── PINATA_INTEGRATION.md       # This documentation
```

## Cost Considerations

- **Pinata Free Tier**: 1GB storage, 100GB bandwidth/month
- **Current usage**: ~15 JSON files (~12KB total) - well within free limits
- **Images**: Consider uploading badge images to Pinata as well for full decentralization

## Security Notes

- Store JWT tokens securely (use environment variables, never commit to git)
- JWT tokens provide secure authentication and replace the old API key/secret approach
- The contract owner can update baseURI anytime if needed

## Troubleshooting

### Common Issues

1. **JWT Authentication Error**: Verify your JWT token is correct and has proper permissions
2. **Rate Limiting**: The script includes 1-second delays between uploads
3. **Network Issues**: Check internet connection and Pinata service status
4. **File Not Found**: Ensure all JSON files exist in the metadata directory
5. **Node.js Version**: Ensure you're using Node.js 20+ as required by the Pinata SDK

### Support

- Pinata Documentation: [docs.pinata.cloud](https://docs.pinata.cloud)
- Pinata Support: Available through their dashboard
- IPFS Gateway Issues: Try alternative gateways if needed

## Next Steps

1. Consider uploading badge images to Pinata for full decentralization
2. Implement automated metadata updates for new badges
3. Set up monitoring for IPFS availability
4. Consider using Pinata's dedicated gateways for production

---

**Note**: This integration maintains backward compatibility. The original metadata files remain in the repository, and the baseURI can be reverted if needed.
