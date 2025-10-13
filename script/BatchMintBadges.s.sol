// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface ILearnWayManager {
    function batchRegisterUsers(
        address[] calldata users,
        uint256[] calldata initialGems,
        bool[] calldata kycStatuses
    ) external;
}

contract BatchMintBadges is Script {
    // Proxy addresses on Lisk Sepolia Testnet
    address constant MANAGER_PROXY_ADDRESS = 0xabe92E420273c6593c31933D3F4A4E3f7D88E34e;
    
    // JSON file with addresses
    string constant ADDRESSES_FILE = "./eth-eoa/active_eoa_addresses.json";
    
    // Batch size for processing
    uint256 constant BATCH_SIZE = 30;
    
    function run() external {
        // Read and parse the JSON file
        string memory json = vm.readFile(ADDRESSES_FILE);
        address[] memory allAddresses = abi.decode(
            vm.parseJson(json, ".addresses"),
            (address[])
        );
        
        console.log("Total addresses to process:", allAddresses.length);
        console.log("Processing in batches of:", BATCH_SIZE);
        
        // Get the private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        ILearnWayManager manager = ILearnWayManager(MANAGER_PROXY_ADDRESS);
        
        // Process addresses in batches
        uint256 totalBatches = (allAddresses.length + BATCH_SIZE - 1) / BATCH_SIZE;
        
        for (uint256 i = 0; i < totalBatches; i++) {
            uint256 start = i * BATCH_SIZE;
            uint256 end = start + BATCH_SIZE;
            if (end > allAddresses.length) {
                end = allAddresses.length;
            }
            
            uint256 currentBatchSize = end - start;
            
            // Prepare batch arrays
            address[] memory batchAddresses = new address[](currentBatchSize);
            uint256[] memory initialGems = new uint256[](currentBatchSize);
            bool[] memory kycStatuses = new bool[](currentBatchSize);
            
            // Fill batch arrays
            for (uint256 j = 0; j < currentBatchSize; j++) {
                batchAddresses[j] = allAddresses[start + j];
                initialGems[j] = 100; // Initial gems amount
                kycStatuses[j] = false; // Set KYC status as false initially
            }
            
            console.log(
                string.concat(
                    "Processing batch ",
                    vm.toString(i + 1),
                    " of ",
                    vm.toString(totalBatches),
                    " (",
                    vm.toString(currentBatchSize),
                    " addresses)"
                )
            );
            
            // Call batchRegisterUsers
            try manager.batchRegisterUsers(
                batchAddresses,
                initialGems,
                kycStatuses
            ) {
                console.log("Batch", i + 1, "successful");
            } catch Error(string memory reason) {
                console.log("Batch", i + 1, "failed:", reason);
            } catch {
                console.log("Batch", i + 1, "failed: Unknown error");
            }
            
            // Add a small delay between batches to avoid potential rate limiting
            if (i < totalBatches - 1) {
                vm.warp(block.timestamp + 1);
            }
        }
        
        vm.stopBroadcast();
        
        console.log("=================================");
        console.log("Batch minting completed!");
        console.log("Total addresses processed:", allAddresses.length);
        console.log("Total batches:", totalBatches);
        console.log("=================================");
    }
    
    // Alternative run function with custom parameters
    function runWithParams(
        uint256 _initialGems,
        bool _kycStatus,
        uint256 _startIndex,
        uint256 _endIndex
    ) external {
        // Read and parse the JSON file
        string memory json = vm.readFile(ADDRESSES_FILE);
        address[] memory allAddresses = abi.decode(
            vm.parseJson(json, ".addresses"),
            (address[])
        );
        
        require(_startIndex < allAddresses.length, "Start index out of bounds");
        require(_endIndex <= allAddresses.length, "End index out of bounds");
        require(_startIndex < _endIndex, "Invalid index range");
        
        uint256 totalToProcess = _endIndex - _startIndex;
        console.log("Processing addresses from index", _startIndex, "to", _endIndex);
        console.log("Total addresses to process:", totalToProcess);
        
        // Get the private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        ILearnWayManager manager = ILearnWayManager(MANAGER_PROXY_ADDRESS);
        
        // Process addresses in batches
        uint256 totalBatches = (totalToProcess + BATCH_SIZE - 1) / BATCH_SIZE;
        
        for (uint256 i = 0; i < totalBatches; i++) {
            uint256 start = _startIndex + (i * BATCH_SIZE);
            uint256 end = start + BATCH_SIZE;
            if (end > _endIndex) {
                end = _endIndex;
            }
            
            uint256 currentBatchSize = end - start;
            
            // Prepare batch arrays
            address[] memory batchAddresses = new address[](currentBatchSize);
            uint256[] memory initialGems = new uint256[](currentBatchSize);
            bool[] memory kycStatuses = new bool[](currentBatchSize);
            
            // Fill batch arrays
            for (uint256 j = 0; j < currentBatchSize; j++) {
                batchAddresses[j] = allAddresses[start + j];
                initialGems[j] = _initialGems;
                kycStatuses[j] = _kycStatus;
            }
            
            console.log(
                string.concat(
                    "Processing batch ",
                    vm.toString(i + 1),
                    " of ",
                    vm.toString(totalBatches)
                )
            );
            
            // Call batchRegisterUsers
            try manager.batchRegisterUsers(
                batchAddresses,
                initialGems,
                kycStatuses
            ) {
                console.log("Batch", i + 1, "successful");
            } catch Error(string memory reason) {
                console.log("Batch", i + 1, "failed:", reason);
            } catch {
                console.log("Batch", i + 1, "failed: Unknown error");
            }
        }
        
        vm.stopBroadcast();
        
        console.log("=================================");
        console.log("Custom batch minting completed!");
        console.log("Total addresses processed:", totalToProcess);
        console.log("=================================");
    }
}