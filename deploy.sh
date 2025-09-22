#!/bin/bash

# Exit on error
set -e

# Load environment variables
source ./.env

# Build contracts
forge build

# Deploy contracts
DEPLOY_OUTPUT=$(forge script script/DeployLearnWayBadge.s.sol:DeployLearnWayBadge \
    --rpc-url "$LISK_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast)

echo "$DEPLOY_OUTPUT"

# Extract addresses
ADMIN_PROXY=$(echo "$DEPLOY_OUTPUT" | grep -A 1 "Returns:" | tail -n 1 | awk '{print $1}')
ADMIN_IMPL=$(echo "$DEPLOY_OUTPUT" | grep -A 1 "Returns:" | tail -n 1 | awk '{print $2}')
BADGE_PROXY=$(echo "$DEPLOY_OUTPUT" | grep -A 1 "Returns:" | tail -n 1 | awk '{print $3}')
BADGE_IMPL=$(echo "$DEPLOY_OUTPUT" | grep -A 1 "Returns:" | tail -n 1 | awk '{print $4}')
GEMS_PROXY=$(echo "$DEPLOY_OUTPUT" | grep -A 1 "Returns:" | tail -n 1 | awk '{print $5}')
GEMS_IMPL=$(echo "$DEPLOY_OUTPUT" | grep -A 1 "Returns:" | tail -n 1 | awk '{print $6}')

# Save addresses to file
echo "{\"admin_proxy\": \"$ADMIN_PROXY\", \"admin_implementation\": \"$ADMIN_IMPL\", \"badge_proxy\": \"$BADGE_PROXY\", \"badge_implementation\": \"$BADGE_IMPL\", \"gems_proxy\": \"$GEMS_PROXY\", \"gems_implementation\": \"$GEMS_IMPL\"}" > deployment_addresses.json

# Log addresses
echo "Deployment addresses:"
echo "  Admin Proxy: $ADMIN_PROXY"
echo "  Admin Implementation: $ADMIN_IMPL"
echo "  Badge Proxy: $BADGE_PROXY"
echo "  Badge Implementation: $BADGE_IMPL"
echo "  Gems Proxy: $GEMS_PROXY"
echo "  Gems Implementation: $GEMS_IMPL"

# Verify contracts
forge verify-contract --rpc-url https://rpc.sepolia-api.lisk.com \
  --verifier blockscout \
  --verifier-url 'https://sepolia-blockscout.lisk.com/api/' \
  $ADMIN_IMPL \
  src/LearnWayAdmin.sol:LearnWayAdmin

forge verify-contract --rpc-url https://rpc.sepolia-api.lisk.com \
    --verifier blockscout \
    --verifier-url 'https://sepolia-blockscout.lisk.com/api/' \
    $BADGE_IMPL \
    src/LearnWayBadge.sol:LearnWayBadge

forge verify-contract --rpc-url https://rpc.sepolia-api.lisk.com \
    --verifier blockscout \
    --verifier-url 'https://sepolia-blockscout.lisk.com/api/' \
    $GEMS_IMPL \
    src/GemsContract.sol:GemsContract


echo "Deployment and verification complete!"
