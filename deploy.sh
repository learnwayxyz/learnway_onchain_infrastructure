#!/bin/bash

# LearnWay Deployment Script for Lisk Sepolia Testnet
# This script deploys all LearnWay contracts and verifies them on Blockscout

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="https://rpc.sepolia-api.lisk.com"
VERIFIER="blockscout"
VERIFIER_URL="https://sepolia-blockscout.lisk.com/api/"
CHAIN_ID=4202

# File to store deployment addresses
DEPLOYMENT_FILE="deployment-addresses.txt"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}LearnWay Contract Deployment Script${NC}"
echo -e "${BLUE}Network: Lisk Sepolia Testnet${NC}"
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
    echo "# Network: Lisk Sepolia Testnet"
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
echo -e "${BLUE}DEPLOYMENT COMPLETE!${NC}"
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
    
    echo -e "${YELLOW}Verifying $CONTRACT_NAME at $CONTRACT_ADDRESS...${NC}"
    
    if [ -z "$CONTRACT_ADDRESS" ] || [ "$CONTRACT_ADDRESS" == "null" ]; then
        echo -e "${RED}Error: Contract address not found for $CONTRACT_NAME${NC}"
        return 1
    fi
    
    if [ -z "$CONSTRUCTOR_ARGS" ]; then
        forge verify-contract \
            --rpc-url $RPC_URL \
            --verifier $VERIFIER \
            --verifier-url $VERIFIER_URL \
            $CONTRACT_ADDRESS \
            $CONTRACT_PATH:$CONTRACT_NAME
    else
        forge verify-contract \
            --rpc-url $RPC_URL \
            --verifier $VERIFIER \
            --verifier-url $VERIFIER_URL \
            --constructor-args $CONSTRUCTOR_ARGS \
            $CONTRACT_ADDRESS \
            $CONTRACT_PATH:$CONTRACT_NAME
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $CONTRACT_NAME verified successfully${NC}"
    else
        echo -e "${RED}✗ Failed to verify $CONTRACT_NAME${NC}"
    fi
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
echo -e "${GREEN}Deployment and verification complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Save the deployment addresses from $DEPLOYMENT_FILE"
echo -e "2. Update your frontend/backend with the PROXY contract addresses"
echo -e "3. Set the base URI for badges if needed:"
echo -e "   cast send $BADGE_ADDRESS \"setBaseTokenURI(string)\" \"https://your-api.com/badges/\" --private-key \$PRIVATE_KEY --rpc-url $RPC_URL"
echo -e "4. Grant additional roles as needed through the Admin contract"
echo -e "5. To upgrade contracts in the future, deploy new implementations and call upgradeToAndCall on the proxy"

echo -e "\n${BLUE}View your contracts on Blockscout:${NC}"
echo -e "${BLUE}Implementation Contracts:${NC}"
echo -e "  Admin:   https://sepolia-blockscout.lisk.com/address/$ADMIN_IMPL_ADDRESS"
echo -e "  XPGems:  https://sepolia-blockscout.lisk.com/address/$XPGEMS_IMPL_ADDRESS"
echo -e "  Badge:   https://sepolia-blockscout.lisk.com/address/$BADGE_IMPL_ADDRESS"
echo -e "  Manager: https://sepolia-blockscout.lisk.com/address/$MANAGER_IMPL_ADDRESS"
echo -e ""
echo -e "${BLUE}Proxy Contracts (Use these):${NC}"
echo -e "  Admin:   https://sepolia-blockscout.lisk.com/address/$ADMIN_ADDRESS"
echo -e "  XPGems:  https://sepolia-blockscout.lisk.com/address/$XPGEMS_ADDRESS"
echo -e "  Badge:   https://sepolia-blockscout.lisk.com/address/$BADGE_ADDRESS"
echo -e "  Manager: https://sepolia-blockscout.lisk.com/address/$MANAGER_ADDRESS"
