// @ts-nocheck
// ^ Activating Goblin Mode

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { execSync } from "child_process";
import { ethers, Signer, Wallet } from "ethers";

import * as fs from "fs";

import {
    geoNftABI,
    treasuryABI,
    oracleABI,
    reserve2TokenABI,
    reserve2ABI
} from "./lib/abis";
import { exit } from "process";
import { FunctionFragment } from "ethers/lib/utils";

/**
 * Setup:
 * -----
 *  1. Clone the repo
 *  2. `cd` into the repo
 *  3. Run `forge install` to install contract dependencies
 *  4. Run `yarn` to install hardhat dependencies
 *  5. Run `source dev.env` to setup environment variables
 *  6. Start an anvil node with `anvil` in a new terminal session
 *  7. Adjust `simulation.config` file
 *  8. Execute simulation with `npx hardhat simulation`
 */

// Contract addresses
const ADDRESS_RESERVE2 = "0xa51c1fc2f0d1a1b8494ed1fe312d7c3a78ed91c0";

const ADDRESS_TREASURY = "0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6";
const ADDRESS_ORACLE_TREASURY_TOKEN = "0x610178da211fef7d417bc0e6fed39f05609ad788";

const ADDRESS_GEONFT = "0x0165878a594ca255338adfa4d48449f69242eb8f";
const ADDRESS_ORACLE_GEONFT_1 = "0xdc64a140aa3e981100a9beca4e685f962f0cf6c9";

const ADDRESS_RESERVE2_TOKEN = "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0";
const ADDRESS_ORACLE_RESERVE2_TOKEN = "0x5fbdb2315678afecb367f032d93f642f64180aa3";

const ADDRESS_ERC20 = "0x959922be3caee4b8cd9a407cc3ac1c251c2007b1";
const ADDRESS_ORACLE_ERC20 = "0x9a676e781a523b5d0c0e43731313a708cb607508";

// Contract instances
let reserve2;
let treasury, oracleTreasuryToken;
let geoNft, oracleGeoNFT1;
let reserve2Token, oracleReserve2Token;
let erc20, oracleERC20;

// Account instances
let owner, oracleProvider, user;

function getAssetAndOracle(asset: string) {
    if (asset === "Treasury") {
        return [treasury, oracleTreasuryToken];
    }
    if (asset === "Reserve2Token") {
        return [reserve2Token, oracleReserve2Token];
    }
    if (asset === "ERC20") {
        return [erc20, oracleERC20];
    }
    if (asset === "GeoNFT1") {
        // Note that this branch also returns the ERC721Id for the GeoNFT1.
        const geoNFTERC721Id = { erc721: geoNft.address, id: 1 };
        return [geoNft, oracleGeoNFT1, geoNFTERC721Id];
    }
    if (asset === "Reserve2") {
        return [reserve2];
    }
    console.info("[ERROR] Unknown asset: " + asset);
}

const genericInstructionsERC20 = {
    "transfer": (token, sender, receiver, amount) => {
        return async () => {
            await (await token.connect(sender).transfer(receiver.address, amount)).wait();
            console.info("[INFO] Send tokens");
        };
    },
    "transferFrom": (token, sender, spender, receiver, amount) => {
        return async () => {
            await (await token.connect(sender).transerFrom(spender.address, receiver.address, amount)).wait();
            console.info("[INFO] Send token from");
        };
    },
    "approve": (token, sender, spender, amount) => {
        return async () => {
            await (await token.connect(sender).approve(spender.address, amount)).wait();
            console.info["[INFO] Approved tokens"];
        };
    },
    "balanceOf": (token, who) => {
        return async () => {
            const balance = await token.balanceOf(who.address);
            console.info("[INFO] BalanceOf: " + balance);
        };
    },
};

const instructions = {
    "Treasury": {
        // Adds an ERC20 contract as being supported and supported for un/bonding
        "support": (asset, oracle) => {
            return async () => {
                await (await treasury.connect(owner).supportAsset(asset.address, oracle.address)).wait();
                await (await treasury.connect(owner).supportAssetForBonding(asset.address)).wait();
                await (await treasury.connect(owner).supportAssetForUnbonding(asset.address)).wait();
                console.info("[INFO] Added asset as being supported by Treasury");
            };
        },
        // Removes an ERC20 contract as being unsupported and unsupported for un/bonding
        "unsupport": (asset) => {
            return async () => {
                await (await treasury.connect(owner).unsupportAssetForBonding(asset.address)).wait();
                await (await treasury.connect(owner).unsupportAssetForUnbonding(asset.address)).wait();
                await (await treasury.connect(owner).unsupportAsset(asset.address)).wait();
                console.info("[INFO] Removed asset from being supported by Treasury");
            };
        },
        // Bonds an amount of ERC20s from owner
        // Needs token approval!
        "bond": (asset, amount) => {
            return async () => {
                // Listen to event
                treasury.on("Rebase", (_epoch, supply) => {
                    console.info("[EVENT INFO] Treasury token rebased:");
                    console.info("             => new Supply: " + supply);
                });

                await (await treasury.connect(owner).bond(asset.address, amount)).wait();
                console.info("[INFO] Bonded " + amount.toString() + " of assets into Treasury");
            };
        },
        // Unbonds an amount of TreasuryTokens from owner
        // Needs token approval!
        "unbond": (asset, amount) => {
            return async () => {
                // Listen to event
                treasury.on("Rebase", (_epoch, supply) => {
                    console.info("[EVENT INFO] Treasury token rebased:");
                    console.info("             => new Supply: " + supply);
                });

                await (await treasury.connect(owner).unbond(asset.address, amount)).wait();
                console.info("[INFO] Unbonded " + amount.toString() + " of TreasuryTokens from Reserve");
            };
        },
        // @todo + Generic ERC20
    },

    "Oracle": {
        "setPrice": (oracle, amount) => {
            return async () => {
                await (await oracle.connect(oracleProvider).purgeReports()).wait();
                await (await oracle.connect(oracleProvider).pushReport(amount)).wait();
                console.info("[INFO] Set price of asset to " + amount.toString());
            };
        },
    },

    "Reserve2": {
        "supportERC20": (asset, oracle) => {
            return async () => {
                await (await reserve2.connect(owner).supportERC20(asset.address, oracle.address)).wait();
                await (await reserve2.connect(owner).supportERC20ForBonding(asset.address, true)).wait();
                await (await reserve2.connect(owner).supportERC20ForUnbonding(asset.address, true)).wait();
                console.info("[INFO] Set asset as being supported by Reserve2");
            };
        },
        "unsupportERC20": (asset) => {
            return async () => {
                await (await reserve2.connect(owner).supportERC20ForBonding(asset.address, false)).wait();
                await (await reserve2.connect(owner).supportERC20ForUnbonding(asset.address, false)).wait();
                await (await reserve2.connect(owner).unsupportERC20(asset.address)).wait();
                console.info("[INFO] Set asset as being unsupported by Reserve2");
            };
        },
        "supportERC721": (erc721Id, oracle) => {
            return async () => {
                await (await reserve2.connect(owner).supportERC721Id(erc721Id, oracle.address)).wait();
                await (await reserve2.connect(owner).supportERC721IdForBonding(erc721Id, true)).wait();
                await (await reserve2.connect(owner).supportERC721IdForUnbonding(erc721Id, true)).wait();
                console.info("[INFO] Set erc721Id as being supported by Reserve2");
            };
        },
        "unsupportERC721": (erc721Id) => {
            return async () => {
                await (await reserve2.connect(owner).supportERC721IdForBonding(erc721Id, false)).wait();
                await (await reserve2.connect(owner).supportERC721IdForUnbonding(erc721Id, false)).wait();
                await (await reserve2.connect(owner).unsupportERC721Id(erc721Id)).wait();
                console.info("[INFO] Set erc721Id as being unsupported by Reserve2");
            };
        },
        "bondERC20": (asset, amount) => {
            return async () => {
                // Listen to event
                reserve2.on("BackingUpdated", (oldBacking, newBacking) => {
                    console.info("[EVENT INFO] Reserve2's backing updated:");
                    console.info("             => oldBacking: " + oldBacking);
                    console.info("             => newBacking: " + newBacking);
                });

                await (await reserve2.connect(owner).bondERC20(asset.address, amount)).wait();
                console.info("[INFO] Bonded asset into Reserve2");
            };
        },
        "unbondERC20": (asset, amount) => {
            return async () => {
                // Listen to event
                reserve2.on("BackingUpdated", (oldBacking, newBacking) => {
                    console.info("[EVENT INFO] Reserve2's backing updated:");
                    console.info("             => oldBacking: " + oldBacking);
                    console.info("             => newBacking: " + newBacking);
                });

                await (await reserve2.connect(owner).unbondERC20(asset.address, amount)).wait();
                console.info("[INFO] Unbonded asset from Reserve2");
            };
        },
        "bondERC721": (erc721Id) => {
            return async () => {
                await (await reserve2.connect(owner).bondERC721Id(erc721Id)).wait();
                console.info("[INFO] Bonded GeoNFT into Reserve2");
            };
        },
        "unbondERC721": (erc721Id, amount) => {
            return async () => {

            };
        },
        "incurDebt": (amount) => {
            return async () => {
                // Listen to event
                reserve2.on("BackingUpdated", (oldBacking, newBacking) => {
                    console.info("[EVENT INFO] Reserve2's backing updated:");
                    console.info("             => oldBacking: " + oldBacking);
                    console.info("             => newBacking: " + newBacking);
                });

                await (await reserve2.connect(owner).incurDebt(amount)).wait();
                console.info("[INFO] Incured debt");
            };
        },
        "payDebt": (amount) => {
            return async () => {
                // Listen to event
                reserve2.on("BackingUpdated", (oldBacking, newBacking) => {
                    console.info("[EVENT INFO] Reserve2's backing updated:");
                    console.info("             => oldBacking: " + oldBacking);
                    console.info("             => newBacking: " + newBacking);
                });

                await (await reserve2.connect(owner).payDebt(amount)).wait();
                console.info("[INFO] Payed debt");
            };
        },
        "status": () => {
            return async () => {
                const [reserveValuation, supplyValuation, backing] =
                    await (await reserve2.connect(owner).reserveStatus()).wait();
                console.info("[STATUS INFO]");
                console.info("             reserveValuation: " + reserveValuation);
                console.info("             supplyValuation : " + supplyValuation);
                console.info("             backing         : " + backing);
            };
        },
    },

    "Reserve2Token": {
        // @todo R2Token
    },

    "GeoNFT": {
        "approve": (spender, id) => {
            return async () => {
                await (await geoNft.connect(owner).approve(spender.address, 1)).wait();
                console.info("[INFO] Approve GeoNFT");
            };
        },
    },

    "ERC20": {
        "mint": (amount) => {
            return async () => {
                await (await erc20.connect(owner).mint(owner.address, amount)).wait();
                console.info("[INFO] Minted " + amount + " ERC20s");
            };
        },
        "burn": (amount) => {
            return async () => {
                await (await erc20.connect(owner).burn(owner.address, amount)).wait();
                console.info("[INFO] Burned " + amount + " ERC20s");
            };
        },
        "approve": (spender, amount) => {
            return async () => {
                await (await erc20.connect(owner).approve(spender.address, amount)).wait();
                console.info("[INFO] Approved ERC20s");
            };
        },
        "balanceOf": () => {
            return async () => {
                const balance = await erc20.balanceOf(owner.address);
                console.info("[INFO] BalanceOf: " + balance);
            };
        },
    }
};

function getInstruction(
    contractIdentifier: string,
    functionIdentifier: string,
    values: string[]
) {
    // Treasury
    if (contractIdentifier === "Treasury") {
        if (functionIdentifier === "support") {
            const [asset, oracle] = getAssetAndOracle(values[0]);
            return instructions["Treasury"]["support"](asset, oracle);
        }
        if (functionIdentifier === "unsupport") {
            const [asset, _oracle] = getAssetAndOracle(values[0]);
            return instructions["Treasury"]["unsupport"](asset);
        }
        if (functionIdentifier === "bond") {
            const [asset, _oracle] = getAssetAndOracle(values[0]);
            const amount = ethers.utils.parseEther(values[1]);
            return instructions["Treasury"]["bond"](asset, amount);
        }
        if (functionIdentifier === "unbond") {
            const [asset, _oracle] = getAssetAndOracle(values[0]);
            const amount = ethers.utils.parseEther(values[1]);
            return instructions["Treasury"]["unbond"](asset, amount);
        }
        return () => {
            console.info("[ERROR] Unknown instruction for Treasury: " + functionIdentifier)
            exit(1);
        };
    }

    // Oracle
    if (contractIdentifier.startsWith("Oracle")) {
        const amount = ethers.utils.parseEther(values[0]);

        if (contractIdentifier.endsWith("ERC20)")) {
            const [_asset, oracle] = getAssetAndOracle("ERC20");
            return instructions["Oracle"]["setPrice"](oracle, amount);
        }
        if (contractIdentifier.endsWith("GeoNFT1)")) {
            const [_asset, oracle] = getAssetAndOracle("GeoNFT1");
            return instructions["Oracle"]["setPrice"](oracle, amount);
        }
        if (contractIdentifier.endsWith("Reserve2Token)")) {
            const [_asset, oracle] = getAssetAndOracle("Reserve2Token");
            return instructions["Oracle"]["setPrice"](oracle, amount);
        }
        if (contractIdentifier.endsWith("Treasury)")) {
            const [_asset, oracle] = getAssetAndOracle("Treasury");
            return instructions["Oracle"]["setPrice"](oracle, amount);
        }
        return () => {
            console.info("[ERROR] Unknown Oracle identifier: " + contractIdentifier);
            exit(1);
        };
    }

    // Reserve2
    if (contractIdentifier === "Reserve2") {
        if (functionIdentifier === "supportERC20") {
            const [asset, oracle] = getAssetAndOracle(values[0]);
            return instructions["Reserve2"]["supportERC20"](asset, oracle);
        }
        if (functionIdentifier === "unsupportERC20") {
            const [asset, _oracle] = getAssetAndOracle(values[0]);
            return instructions["Reserve2"]["unsupportERC20"](asset);
        }
        if (functionIdentifier === "supportERC721") {
            const [_asset, oracle, erc721Id] = getAssetAndOracle(values[0]);
            return instructions["Reserve2"]["supportERC721"](erc721Id, oracle);
        }
        if (functionIdentifier === "unsupportERC721") {
            const [_asset, _oracle, erc721Id] = getAssetAndOracle(values[0]);
            return instructions["Reserve2"]["unsupportERC721"](erc721Id);
        }
        if (functionIdentifier === "bondERC20") {
            const [asset] = getAssetAndOracle(values[0]);
            const amount = ethers.utils.parseEther(values[1]);
            return instructions["Reserve2"]["bondERC20"](asset, amount);
        }
        if (functionIdentifier === "unbondERC20") {
            const [asset] = getAssetAndOracle(values[0]);
            const amount = ethers.utils.parseEther(values[1]);
            return instructions["Reserve2"]["unbondERC20"](asset, amount);
        }
        if (functionIdentifier === "bondERC721") {
            const [_asset, _oracle, erc721Id] = getAssetAndOracle(values[0]);
            return instructions["Reserve2"]["bondERC721"](erc721Id);
        }
        if (functionIdentifier === "unbondERC721") {
            // @todo Reserve2::unbondERC721
        }
        if (functionIdentifier === "incurDebt") {
            const amount = ethers.utils.parseEther(values[0]);
            return instructions["Reserve2"]["incurDebt"](amount);
        }
        if (functionIdentifier === "payDebt") {
            const amount = ethers.utils.parseEther(values[0]);
            return instructions["Reserve2"]["payDebt"](amount);
        }
        if (functionIdentifier === "status") {
            return instructions["Reserve2"]["status"]();
        }
        return () => {
            console.info("[ERROR] Unknown instruction for Reserve2: " + functionIdentifier);
            exit(1);
        }
    }

    // @todo Reserve2Token

    // GeoNFT
    if (contractIdentifier === "GeoNFT") {
        if (functionIdentifier === "approve") {
            const [asset] = getAssetAndOracle(values[0]);
            const id = values[1];
            return instructions["GeoNFT"]["approve"](asset, id);
        }
        return () => {
            console.info("[ERROR] Unknown instruction for GeoNFT: " + functionIdentifier);
            exit(1);
        };
    }

    // ERC20
    if (contractIdentifier === "ERC20") {
        if (functionIdentifier === "mint") {
            const amount = ethers.utils.parseEther(values[0]);
            return instructions["ERC20"]["mint"](amount);
        }
        if (functionIdentifier === "burn") {
            const amount = ethers.utils.parseEther(values[0]);
            return instructions["ERC20"]["burn"](amount);
        }
        if (functionIdentifier === "approve") {
            const [asset, _oracle] = getAssetAndOracle(values[0]);
            const amount = ethers.utils.parseEther(values[1]);
            return instructions["ERC20"]["approve"](asset, amount);
        }
        if (functionIdentifier === "balanceOf") {
            return instructions["ERC20"]["balanceOf"]();
        }
        return () => {
            console.info("[ERROR] Unknown instruction for ERC20: " + functionIdentifier);
            exit(1);
        }
    }

    return () => {
        console.info("[ERROR] Unknown contract: " + contractIdentifier);
        exit(1);
    }
}

/**
 * Parses a config file and returns a list of executable functions
 */
function parse(file: string) {
    let funcs = [];

    const lines = fs.readFileSync(file, 'utf-8').replace(/\r\n/g, '\n').split('\n');

    for (let line of lines) {
        const words = line.split(' ');

        // Omit comments and empty lines
        if (words[0].startsWith("#") || words[0].length === 0) {
            continue;
        }

        if (words.length > 2) {
            funcs.push(getInstruction(words[0], words[1], words.slice(2, words.len)));
        } else {
            funcs.push(getInstruction(words[0], words[1]));
        }
    }

    return funcs;
}

export default async function simulation(
    params: any,
    hre: HardhatRuntimeEnvironment
): Promise<void> {
    const ethers = hre.ethers;
    const provider = new ethers.providers.WebSocketProvider("ws://127.0.0.1:8545");

    // Setup state variables
    setUpWallets(hre, provider);
    await setUpEnvironment(hre, provider, owner);

    // Event filters
    console.info("==== Setup done ====");
    console.info("=> Starting to execute simulation.config...");
    console.info("");

    const file = "simulation.config";
    const funcs = parse(file);

    for (let i = 0; i < funcs.length; i++) {
        await funcs[i]();
    }
}

function setUpWallets(hre: HardhatRuntimeEnvironment, provider: any): [Wallet, Wallet, Wallet] {
    const ethers = hre.ethers;

    // anvil's second default wallet
    owner = new ethers.Wallet("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", provider);
    // anvil's third default wallet
    oracleProvider = new ethers.Wallet("0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a", provider);
    // anvil's forth default wallet
    user = new ethers.Wallet("0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6", provider);
}

async function setUpEnvironment(hre: HardhatRuntimeEnvironment, provider: any, owner: Wallet) {
    const ethers = hre.ethers;

    console.info("[INFO] Deploying all contracts. This takes a moment...");

    // Deploy base contracts
    execSync("sh ./tasks/deployBaseContracts.sh");

    // Deploy ERC20 mock token with corresponding oracle
    execSync("sh ./tasks/deployTokenWithOracle.sh");

    console.info("[INFO] All contracts deployed and owner switch initiated");

    // Set deployed contract objects to state variables
    reserve2 = new ethers.Contract(ADDRESS_RESERVE2, reserve2ABI(), provider);

    treasury = new ethers.Contract(ADDRESS_TREASURY, treasuryABI(), provider);
    oracleTreasuryToken = new ethers.Contract(ADDRESS_ORACLE_TREASURY_TOKEN, oracleABI(), provider);

    geoNft = new ethers.Contract(ADDRESS_GEONFT, geoNftABI(), provider);
    oracleGeoNFT1 = new ethers.Contract(ADDRESS_ORACLE_GEONFT_1, oracleABI(), provider);

    reserve2Token = new ethers.Contract(ADDRESS_RESERVE2_TOKEN, reserve2TokenABI(), provider);
    oracleReserve2Token = new ethers.Contract(ADDRESS_ORACLE_RESERVE2_TOKEN, oracleABI(), provider);

    erc20 = new ethers.Contract(ADDRESS_ERC20, reserve2TokenABI(), provider);
    oracleERC20 = new ethers.Contract(ADDRESS_ORACLE_ERC20, oracleABI(), provider);

    // Complete owner switch for each contract
    await (await reserve2.connect(owner).acceptOwnership()).wait();

    await (await treasury.connect(owner).acceptOwnership()).wait();
    await (await oracleTreasuryToken.connect(owner).acceptOwnership()).wait();

    await (await geoNft.connect(owner).acceptOwnership()).wait();
    await (await oracleGeoNFT1.connect(owner).acceptOwnership()).wait();

    await (await reserve2Token.connect(owner).acceptOwnership()).wait();
    await (await oracleReserve2Token.connect(owner).acceptOwnership()).wait();

    await (await oracleERC20.connect(owner).acceptOwnership()).wait();
    console.info("[INFO] Owner switches completed");

    // Set reserve2 to mintBurner of reserve2Token
    await (await reserve2Token.connect(owner).setMintBurner(reserve2.address)).wait();
    console.info("[INFO] Reserve2Token's mintBurner set to reserve2 instance");

    // Setup oracleProvider as provider for all oracles
    await (await oracleReserve2Token.connect(owner).addProvider(oracleProvider.address)).wait();
    await (await oracleTreasuryToken.connect(owner).addProvider(oracleProvider.address)).wait();
    await (await oracleERC20.connect(owner).addProvider(oracleProvider.address)).wait();
    await (await oracleGeoNFT1.connect(owner).addProvider(oracleProvider.address)).wait();
    console.info("[INFO] Oracle provider set up");

    // Add owner to treasury whitelist
    await (await treasury.connect(owner).addToWhitelist(owner.address)).wait();
    console.info("[INFO] Owner whitelisted for Treasury un/bonding operations");

    // Mint geoNFT to owner
    await (await geoNft.connect(owner).mint(owner.address, 0, 0, "First GeoNFT")).wait();
    console.info("[INFO] Minted GeoNFT with ID 1 to owner");
}
