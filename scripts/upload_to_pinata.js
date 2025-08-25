const fs = require('fs');
const path = require('path');
const { PinataSDK } = require('pinata');
require("dotenv").config({ path: path.join(__dirname, '.env.local') })

// Pinata configuration
const PINATA_JWT = process.env.PINATA_JWT;
const PINATA_GATEWAY_URL = process.env.PINATA_GATEWAY_URL;
const PINATA_GATEWAY_KEY = process.env.PINATA_GATEWAY_KEY;
const PINATA_LEARNWAY_GROUP_ID = process.env.PINATA_LEARNWAY_GROUP_ID;

if (!PINATA_JWT && !PINATA_GATEWAY_URL && !PINATA_GATEWAY_KEY) {
    console.error('Please set PINATA environment variable');
    console.error('You can get your JWT from https://app.pinata.cloud/developers/api-keys');
    process.exit(1);
}

console.log('PINATA_JWT:', PINATA_JWT);
console.log('PINATA_GATEWAY_KEY:', PINATA_GATEWAY_KEY);

// Initialize Pinata SDK
const pinata = new PinataSDK({
    pinataJwt: PINATA_JWT,
    pinataGateway: PINATA_GATEWAY_URL,
    pinataGatewayKey: PINATA_GATEWAY_KEY,
});

async function uploadJSONToPinata(jsonData, filename) {
    try {
        const upload = await pinata.upload.public
            .json(jsonData)
            .name(filename)
            .group(PINATA_LEARNWAY_GROUP_ID)
            .keyvalues({
                type: 'nft-metadata',
                collection: 'LearnWay Badges'
            });

        return {
            success: true,
            ipfsHash: upload.cid,
            pinataUrl: `${PINATA_GATEWAY_URL}${upload.cid}`,
            filename: filename
        };
    } catch (error) {
        console.error(`Error uploading ${filename} to Pinata:`, error.message);
        return {
            success: false,
            error: error.message,
            filename: filename
        };
    }
}

async function uploadAllMetadata() {
    const metadataDir = path.join(__dirname, '..', 'metadata');
    const results = [];

    try {
        const files = fs.readdirSync(metadataDir).filter(file => file.endsWith('.json'));

        console.log(`Found ${files.length} JSON files to upload to Pinata...`);

        for (const file of files) {
            const filePath = path.join(metadataDir, file);
            const jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));

            console.log(`Uploading ${file}...`);
            const result = await uploadJSONToPinata(jsonData, file);
            results.push(result);

            if (result.success) {
                console.log(`✓ ${file} uploaded successfully`);
                console.log(`  IPFS Hash: ${result.ipfsHash}`);
                console.log(`  Pinata URL: ${result.pinataUrl}`);
            } else {
                console.log(`✗ Failed to upload ${file}`);
            }

            // Add delay to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        // Generate summary
        const successful = results.filter(r => r.success);
        const failed = results.filter(r => !r.success);

        console.log('\n=== UPLOAD SUMMARY ===');
        console.log(`Total files: ${files.length}`);
        console.log(`Successful uploads: ${successful.length}`);
        console.log(`Failed uploads: ${failed.length}`);

        if (successful.length > 0) {
            console.log('\n=== SUCCESSFUL UPLOADS ===');
            successful.forEach(result => {
                console.log(`${result.filename}: ${result.ipfsHash}`);
            });

            // Suggest base URI
            const baseUri = PINATA_GATEWAY_URL;
            console.log(`\n=== SUGGESTED CONTRACT UPDATE ===`);
            console.log(`Update contract baseURI to: ${baseUri}`);
            console.log(`Contract function: setBaseURI("${baseUri}")`);
        }

        if (failed.length > 0) {
            console.log('\n=== FAILED UPLOADS ===');
            failed.forEach(result => {
                console.log(`${result.filename}: ${result.error}`);
            });
        }

        // Save results to file
        const resultsFile = path.join(__dirname, 'pinata_upload_results.json');
        fs.writeFileSync(resultsFile, JSON.stringify(results, null, 2));
        console.log(`\nDetailed results saved to: ${resultsFile}`);

    } catch (error) {
        console.error('Error reading metadata directory:', error);
        process.exit(1);
    }
}

// Run the upload process
uploadAllMetadata().catch(error => {
    console.error('Upload process failed:', error);
    process.exit(1);
});
