// src/scrapeEOAs.ts
// SPDX-License-Identifier: MIT
import dotenv from "dotenv";
dotenv.config();

import fs from "fs";
import { JsonRpcProvider, isAddress } from "ethers";

const RPC_URL = process.env.RPC_URL;
if (!RPC_URL) {
  throw new Error("Please set RPC_URL in your .env file");
}

const TARGET = Number(process.env.TARGET || 300);
const MAX_BLOCKS = Number(process.env.MAX_BLOCKS || 8000);

const provider = new JsonRpcProvider(RPC_URL);

// small cache to avoid repeated getCode RPC calls
const isEOACache = new Map<string, boolean>();

async function isEOA(address: string): Promise<boolean> {
  const a = address.toLowerCase();
  if (isEOACache.has(a)) return isEOACache.get(a)!;
  try {
    const code = await provider.getCode(a);
    const result = code === "0x";
    isEOACache.set(a, result);
    return result;
  } catch (err) {
    console.warn(`getCode failed for ${a}: ${(err as Error).message}`);
    isEOACache.set(a, false);
    return false;
  }
}

function toHex(n: number): string {
  return "0x" + n.toString(16);
}

/**
 * Fetch a block with full transaction objects using raw RPC call.
 * Returns null on error.
 */
async function fetchBlockWithTx(blockNumber: number): Promise<any | null> {
  try {
    // eth_getBlockByNumber supports the second param `true` to return full tx objects
    const hex = toHex(blockNumber);
    const block = await provider.send("eth_getBlockByNumber", [hex, true]);
    return block;
  } catch (err) {
    console.warn(
      `eth_getBlockByNumber failed for ${blockNumber}: ${
        (err as Error).message
      }`
    );
    return null;
  }
}

async function scrapeEOAs(): Promise<void> {
  const result = new Set<string>();
  let latest = await provider.getBlockNumber();
  let current = latest;
  let scanned = 0;

  console.log(`Starting from block ${latest}. Target EOAs: ${TARGET}`);

  while (result.size < TARGET && scanned < MAX_BLOCKS && current >= 0) {
    const block = await fetchBlockWithTx(current);
    if (block && Array.isArray(block.transactions)) {
      for (const tx of block.transactions) {
        if (result.size >= TARGET) break;

        // tx may already be an object (eth_getBlockByNumber true)
        // but be defensive: if the provider returned hashes, fallback to getTransaction
        let from: string | undefined;
        let to: string | undefined | null;

        if (typeof tx === "string") {
          // tx is just a hash — fetch full tx
          try {
            const txObj = await provider.getTransaction(tx);
            from = txObj?.from;
            to = txObj?.to ?? undefined;
          } catch (e) {
            // skip this tx on error
            continue;
          }
        } else {
          // full tx object returned by eth_getBlockByNumber
          from = tx.from;
          // note: RPC returns `null` for to when contract creation; treat null as undefined
          to = tx.to === null ? undefined : tx.to;
        }

        if (from && isAddress(from)) {
          if (await isEOA(from)) result.add(from.toLowerCase());
        }
        if (to && isAddress(to)) {
          if (await isEOA(to)) result.add(to.toLowerCase());
        }
      }
    }

    scanned++;
    if (scanned % 10 === 0) {
      console.log(
        `Scanned ${scanned} blocks (down from ${latest}), found ${result.size} EOAs`
      );
    }

    current--;
  }

  const addresses = Array.from(result).slice(0, TARGET);
  const out = {
    collectedAt: new Date().toISOString(),
    rpc: RPC_URL,
    target: TARGET,
    actual: addresses.length,
    lastScannedBlock: current + 1,
    addresses,
  };

  fs.writeFileSync("active_eoa_addresses.json", JSON.stringify(out, null, 2));
  console.log(`Saved ${addresses.length} EOAs → active_eoa_addresses.json`);
}

scrapeEOAs().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
