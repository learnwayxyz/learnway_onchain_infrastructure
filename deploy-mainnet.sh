#!/bin/bash

# LearnWay Deployment Script for Lisk Mainnet
# This script deploys all LearnWay contracts and verifies them on Blockscout

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - LISK MAINNET
RPC_URL="https://lisk.drpc.org"
VERIFIER="blockscout"
VERIFIER_URL="https://blockscout.lisk.com/api/"
CHAIN_ID=1135

# File to store deployment addresses
DEPLOYMENT_FILE="deployment-addresses-mainnet.txt"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}LearnWay Contract Deployment Script${NC}"
echo -e "${RED}⚠️  MAINNET DEPLOYMENT - LISK MAINNET ⚠️${NC}"
echo -e "${BLUE}Chain ID: $CHAIN_ID${NC}"
echo -e "${BLUE}All contracts are upgradeable (UUPS)${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY environment variable is not set${NC}"
    echo -e "${YELLOW}Please export your private key:${NC}"
    echo -e "export PRIVATE_KEY=your_private_key_here"
    exit 1
fi

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}Error: Foundry is not installed${NC}"
    echo -e "${YELLOW}Please install Foundry: https://book.getfoundry.sh/getting-started/installation${NC}"
    exit 1
fi

# Confirmation prompt for mainnet deployment
echo -e "${RED}⚠️  WARNING: You are about to deploy to LISK MAINNET ⚠️${NC}"
echo -e "${YELLOW}This will use real funds and deploy production contracts.${NC}"
echo -e "${YELLOW}Please ensure you have:${NC}"
echo -e "  1. Sufficient ETH for gas fees on Lisk Mainnet"
echo -e "  2. Reviewed all contract code"
echo -e "  3. Tested on testnet first"
echo -e "  4. Backed up your private key securely"
echo -e ""
read -p "Are you sure you want to continue? (type 'YES' to proceed): " confirmation

if [ "$confirmation" != "YES" ]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 0
fi

# Clean previous deployment file
rm -f $DEPLOYMENT_FILE

echo -e "${GREEN}Step 1: Installing dependencies...${NC}"
forge install

echo -e "${GREEN}Step 2: Building contracts...${NC}"
forge build

echo -e "${GREEN}Step 3: Running deployment script...${NC}"
DEPLOYMENT_OUTPUT=$(forge script script/DeployLearnWay.sol:DeployLearnWay \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL \
    -vvv 2>&1)

echo "$DEPLOYMENT_OUTPUT"

# Extract addresses from deployment output
echo -e "\n${GREEN}Step 4: Extracting deployment addresses...${NC}"

# Parse the deployment output for contract addresses using sed (macOS compatible)
ADMIN_IMPL_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "ADMIN_IMPLEMENTATION_ADDRESS=" | sed -E 's/.*ADMIN_IMPLEMENTATION_ADDRESS= (0x[a-fA-F0-9]{40}).*/\1/')
ADMIN_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "ADMIN_PROXY_ADDRESS=" | sed -E 's/.*ADMIN_PROXY_ADDRESS= (0x[a-fA-F0-9]{40}).*/\1/')
XPGEMS_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "XPGEMS_ADDRESS=" | sed -E 's/.*XPGEMS_ADDRESS= (0x[a-fA-F0-9]{40}).*/\1/')
BADGE_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "BADGE_ADDRESS=" | sed -E 's/.*BADGE_ADDRESS= (0x[a-fA-F0-9]{40}).*/\1/')
MANAGER_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "MANAGER_ADDRESS=" | sed -E 's/.*MANAGER_ADDRESS= (0x[a-fA-F0-9]{40}).*/\1/')

# Extract implementation addresses (these are printed in the deployment logs)
XPGEMS_IMPL_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "LearnwayXPGemsContract Implementation deployed at:" | sed -E 's/.*deployed at: (0x[a-fA-F0-9]{40}).*/\1/')
BADGE_IMPL_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "LearnWayBadge Implementation deployed at:" | sed -E 's/.*deployed at: (0x[a-fA-F0-9]{40}).*/\1/')
MANAGER_IMPL_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | grep "LearnWayManager Implementation deployed at:" | sed -E 's/.*deployed at: (0x[a-fA-F0-9]{40}).*/\1/')

# Validate that we extracted the addresses
if [ -z "$ADMIN_IMPL_ADDRESS" ] || [ -z "$ADMIN_ADDRESS" ] || [ -z "$XPGEMS_ADDRESS" ] || [ -z "$BADGE_ADDRESS" ] || [ -z "$MANAGER_ADDRESS" ]; then
    echo -e "${RED}Error: Failed to extract some contract addresses!${NC}"
    echo -e "${YELLOW}Admin Implementation: $ADMIN_IMPL_ADDRESS${NC}"
    echo -e "${YELLOW}Admin Proxy: $ADMIN_ADDRESS${NC}"
    echo -e "${YELLOW}XPGems Proxy: $XPGEMS_ADDRESS${NC}"
    echo -e "${YELLOW}Badge Proxy: $BADGE_ADDRESS${NC}"
    echo -e "${YELLOW}Manager Proxy: $MANAGER_ADDRESS${NC}"
    echo -e "${YELLOW}Please check the deployment output manually${NC}"
    # Don't exit, continue with what we have
fi

# Save addresses to file
{
    echo "# LearnWay Deployment Addresses - $(date)"
    echo "# Network: Lisk Mainnet"
    echo "# All contracts are upgradeable using UUPS proxy pattern"
    echo ""
    echo "# Implementation Addresses"
    echo "ADMIN_IMPLEMENTATION_ADDRESS=$ADMIN_IMPL_ADDRESS"
    echo "XPGEMS_IMPLEMENTATION_ADDRESS=$XPGEMS_IMPL_ADDRESS"
    echo "BADGE_IMPLEMENTATION_ADDRESS=$BADGE_IMPL_ADDRESS"
    echo "MANAGER_IMPLEMENTATION_ADDRESS=$MANAGER_IMPL_ADDRESS"
    echo ""
    echo "# Proxy Addresses (Use these for all interactions)"
    echo "ADMIN_PROXY_ADDRESS=$ADMIN_ADDRESS"
    echo "XPGEMS_PROXY_ADDRESS=$XPGEMS_ADDRESS"
    echo "BADGE_PROXY_ADDRESS=$BADGE_ADDRESS"
    echo "MANAGER_PROXY_ADDRESS=$MANAGER_ADDRESS"
    echo ""
    echo "# Note: Always use PROXY addresses for contract interactions"
    echo "# Implementation addresses are only needed for upgrades"
} > $DEPLOYMENT_FILE

echo -e "${GREEN}Deployment addresses saved to: $DEPLOYMENT_FILE${NC}"

# Display deployment summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}MAINNET DEPLOYMENT COMPLETE!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Implementation Addresses:${NC}"
echo -e "  Admin:   $ADMIN_IMPL_ADDRESS"
echo -e "  XPGems:  $XPGEMS_IMPL_ADDRESS"
echo -e "  Badge:   $BADGE_IMPL_ADDRESS"
echo -e "  Manager: $MANAGER_IMPL_ADDRESS"
echo -e ""
echo -e "${GREEN}Proxy Addresses (Use these):${NC}"
echo -e "  Admin:   $ADMIN_ADDRESS"
echo -e "  XPGems:  $XPGEMS_ADDRESS"
echo -e "  Badge:   $BADGE_ADDRESS"
echo -e "  Manager: $MANAGER_ADDRESS"
echo -e "${BLUE}========================================${NC}"

# Verify contracts individually if automatic verification failed
echo -e "\n${YELLOW}Step 5: Verifying contracts on Blockscout...${NC}"

verify_contract() {
    local CONTRACT_ADDRESS=$1
    local CONTRACT_PATH=$2
    local CONTRACT_NAME=$3
    local CONSTRUCTOR_ARGS=$4
    local MAX_RETRIES=5
    local RETRY_DELAY=3
    
    echo -e "${YELLOW}Verifying $CONTRACT_NAME at $CONTRACT_ADDRESS...${NC}"
    
    if [ -z "$CONTRACT_ADDRESS" ] || [ "$CONTRACT_ADDRESS" == "null" ]; then
        echo -e "${RED}Error: Contract address not found for $CONTRACT_NAME${NC}"
        return 1
    fi
    
    for attempt in $(seq 1 $MAX_RETRIES); do
        if [ $attempt -gt 1 ]; then
            echo -e "${YELLOW}Retry attempt $attempt of $MAX_RETRIES for $CONTRACT_NAME...${NC}"
            sleep $RETRY_DELAY
        fi
        
        if [ -z "$CONSTRUCTOR_ARGS" ]; then
            forge verify-contract \
                --rpc-url $RPC_URL \
                --verifier $VERIFIER \
                --verifier-url $VERIFIER_URL \
                $CONTRACT_ADDRESS \
                $CONTRACT_PATH:$CONTRACT_NAME 2>&1
        else
            forge verify-contract \
                --rpc-url $RPC_URL \
                --verifier $VERIFIER \
                --verifier-url $VERIFIER_URL \
                --constructor-args $CONSTRUCTOR_ARGS \
                $CONTRACT_ADDRESS \
                $CONTRACT_PATH:$CONTRACT_NAME 2>&1
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $CONTRACT_NAME verified successfully${NC}"
            return 0
        fi
    done
    
    echo -e "${RED}✗ Failed to verify $CONTRACT_NAME after $MAX_RETRIES attempts${NC}"
    return 1
}

echo -e "${BLUE}Verifying Implementation Contracts...${NC}"

# Verify Admin Implementation
verify_contract "$ADMIN_IMPL_ADDRESS" "src/LearnWayAdmin.sol" "LearnWayAdmin" ""

# Verify XPGems Implementation
verify_contract "$XPGEMS_IMPL_ADDRESS" "src/LearnwayXPGemsContract.sol" "LearnwayXPGemsContract" ""

# Verify Badge Implementation
verify_contract "$BADGE_IMPL_ADDRESS" "src/LearnWayBadge.sol" "LearnWayBadge" ""

# Verify Manager Implementation
verify_contract "$MANAGER_IMPL_ADDRESS" "src/LearnWayManager.sol" "LearnWayManager" ""

echo -e "\n${BLUE}Verifying Proxy Contracts...${NC}"

# Verify Admin Proxy
if [ ! -z "$ADMIN_IMPL_ADDRESS" ] && [ ! -z "$ADMIN_ADDRESS" ]; then
    INIT_DATA=$(cast abi-encode "initialize()")
    PROXY_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,bytes)" $ADMIN_IMPL_ADDRESS $INIT_DATA)
    verify_contract "$ADMIN_ADDRESS" "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol" "ERC1967Proxy" "$PROXY_CONSTRUCTOR_ARGS"
fi

# Verify XPGems Proxy
if [ ! -z "$XPGEMS_IMPL_ADDRESS" ] && [ ! -z "$XPGEMS_ADDRESS" ] && [ ! -z "$ADMIN_ADDRESS" ]; then
    XPGEMS_INIT_DATA=$(cast abi-encode "initialize(address)" $ADMIN_ADDRESS)
    XPGEMS_PROXY_ARGS=$(cast abi-encode "constructor(address,bytes)" $XPGEMS_IMPL_ADDRESS $XPGEMS_INIT_DATA)
    verify_contract "$XPGEMS_ADDRESS" "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol" "ERC1967Proxy" "$XPGEMS_PROXY_ARGS"
fi

# Verify Badge Proxy
if [ ! -z "$BADGE_IMPL_ADDRESS" ] && [ ! -z "$BADGE_ADDRESS" ] && [ ! -z "$ADMIN_ADDRESS" ]; then
    BADGE_INIT_DATA=$(cast abi-encode "initialize(address)" $ADMIN_ADDRESS)
    BADGE_PROXY_ARGS=$(cast abi-encode "constructor(address,bytes)" $BADGE_IMPL_ADDRESS $BADGE_INIT_DATA)
    verify_contract "$BADGE_ADDRESS" "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol" "ERC1967Proxy" "$BADGE_PROXY_ARGS"
fi

# Verify Manager Proxy
if [ ! -z "$MANAGER_IMPL_ADDRESS" ] && [ ! -z "$MANAGER_ADDRESS" ] && [ ! -z "$ADMIN_ADDRESS" ]; then
    MANAGER_INIT_DATA=$(cast abi-encode "initialize(address)" $ADMIN_ADDRESS)
    MANAGER_PROXY_ARGS=$(cast abi-encode "constructor(address,bytes)" $MANAGER_IMPL_ADDRESS $MANAGER_INIT_DATA)
    verify_contract "$MANAGER_ADDRESS" "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol" "ERC1967Proxy" "$MANAGER_PROXY_ARGS"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}MAINNET Deployment and verification complete!${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 6: Grant roles to addresses
echo -e "\n${YELLOW}Step 6: Granting roles to addresses...${NC}"

# Read ADMIN_PROXY_ADDRESS from deployment file
if [ -f "$DEPLOYMENT_FILE" ]; then
    ADMIN_PROXY_FROM_FILE=$(grep "^ADMIN_PROXY_ADDRESS=" $DEPLOYMENT_FILE | cut -d'=' -f2)
    export ADMIN_PROXY_ADDRESS=$ADMIN_PROXY_FROM_FILE
    echo -e "${BLUE}Admin Proxy Address from file: $ADMIN_PROXY_ADDRESS${NC}"
else
    echo -e "${RED}Error: $DEPLOYMENT_FILE not found${NC}"
    export ADMIN_PROXY_ADDRESS=$ADMIN_ADDRESS
fi

echo -e "${BLUE}Running GrantRoleScript...${NC}"
GRANT_ROLE_OUTPUT=$(forge script script/GrantRoleScript.s.sol:GrantRoleScript \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vv 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Roles granted successfully${NC}"
else
    echo -e "${RED}✗ Failed to grant roles${NC}"
    echo -e "${YELLOW}You can run it manually later with:${NC}"
    echo -e "export ADMIN_PROXY_ADDRESS=\$(grep '^ADMIN_PROXY_ADDRESS=' $DEPLOYMENT_FILE | cut -d'=' -f2)"
    echo -e "forge script script/GrantRoleScript.s.sol:GrantRoleScript --rpc-url $RPC_URL --private-key \$PRIVATE_KEY --broadcast"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All MAINNET deployment steps completed!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${RED}⚠️  IMPORTANT POST-DEPLOYMENT STEPS:${NC}"
echo -e "${YELLOW}1. IMMEDIATELY save the deployment addresses from $DEPLOYMENT_FILE${NC}"
echo -e "${YELLOW}2. Backup your private key securely${NC}"
echo -e "${YELLOW}3. Update your production frontend/backend with the PROXY contract addresses${NC}"
echo -e "${YELLOW}4. Verify that roles were granted correctly${NC}"
echo -e "${YELLOW}5. Set badge image URLs by running:${NC}"
echo -e "   ${BLUE}export BADGE_CONTRACT_ADDRESS=\$(grep '^BADGE_PROXY_ADDRESS=' $DEPLOYMENT_FILE | cut -d'=' -f2)${NC}"
echo -e "   ${BLUE}forge script script/SetBadgeURLsManual.s.sol:SetBadgeURLsManual --rpc-url $RPC_URL --private-key \$PRIVATE_KEY --broadcast${NC}"
echo -e "${YELLOW}6. Set the base URI for badges:${NC}"
echo -e "${YELLOW}7. Grant additional roles if needed through the Admin contract${NC}"
echo -e "${YELLOW}8. Test all functionality on mainnet with small amounts first${NC}"
echo -e "${YELLOW}9. Set up monitoring and alerts for your contracts${NC}"
echo -e "${YELLOW}10. Document all admin operations and keep audit logs${NC}"

echo -e "\n${BLUE}View your contracts on Lisk Blockscout:${NC}"
echo -e "${BLUE}Implementation Contracts:${NC}"
echo -e "  Admin:   https://blockscout.lisk.com/address/$ADMIN_IMPL_ADDRESS"
echo -e "  XPGems:  https://blockscout.lisk.com/address/$XPGEMS_IMPL_ADDRESS"
echo -e "  Badge:   https://blockscout.lisk.com/address/$BADGE_IMPL_ADDRESS"
echo -e "  Manager: https://blockscout.lisk.com/address/$MANAGER_IMPL_ADDRESS"
echo -e ""
echo -e "${BLUE}Proxy Contracts (Use these for all interactions):${NC}"
echo -e "  Admin:   https://blockscout.lisk.com/address/$ADMIN_ADDRESS"
echo -e "  XPGems:  https://blockscout.lisk.com/address/$XPGEMS_ADDRESS"
echo -e "  Badge:   https://blockscout.lisk.com/address/$BADGE_ADDRESS"
echo -e "  Manager: https://blockscout.lisk.com/address/$MANAGER_ADDRESS"

echo -e "\n${GREEN}To upgrade contracts in the future:${NC}"
echo -e "1. Deploy new implementation contracts"
echo -e "2. Call upgradeToAndCall on the proxy with the new implementation address"
echo -e "3. Always test upgrades on testnet first!"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}Deployment script completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
