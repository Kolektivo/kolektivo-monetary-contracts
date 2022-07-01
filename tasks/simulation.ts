// @ts-nocheck
// ^ Activating Goblin Mode

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { exec, execSync } from "child_process";
import { ethers, Signer, Wallet } from "ethers";

import * as fs from "fs";

import {
    geoNftABI,
    treasuryABI,
    oracleABI,
    reserve2TokenABI,
    reserve2ABI
} from "./lib/abis";
import { Provider } from "@ethersproject/abstract-provider";

/**
 * Setup:
 * -----
 *  1. Clone the repo
 *  2. `cd` into the repo
 *  3. Run `forge install` to install contract dependencies
 *  4. Run `yarn` to install hardhat dependencies
 *  5. Run `source dev.env` to setup environment variables
 *  6. Start an anvil node with `anvil` in a new terminal session
 *  7. Execute simulation with `npx hardhat simulation`
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
    if (asset === "ERC20") {
        return [erc20, oracleERC20];
    }
    // @todo Continue
}

const instructions = {
    // The set of instructions for the Treasury contract
    "Treasury": {
        // Adds an ERC20 contract as being supported and supported for un/bonding
        "support": (asset, oracle) => {
            return async () => {
                await (await treasury.connect(owner).supportAsset(asset.address, oracle.address)).wait();
                await (await treasury.connect(owner).supportAssetForBonding(asset.address)).wait();
                await (await treasury.connect(owner).supportAssetForUnbonding(asset.address)).wait();
            };
        },
        // Removes an ERC20 contract as being supported and supported for un/bonding
        "unsupport": (asset) => {
            return async () => {
                await (await treasury.connect(owner).unsupportAssetForBonding(asset.address)).wait();
                await (await treasury.connect(owner).unsupportAssetForUnbonding(asset.address)).wait();
                await (await treasury.connect(owner).unsupportAsset(asset.address)).wait();
            };
        },
        "bond": (asset, amount) => {
            return async () => {
                await (await asset.connect(owner).approve(treasury.address, amount)).wait();
                await (await treasury.connect(owner).bond(asset.address, amount)).wait();
            };
        },
        "unbond": "",
        // + Generic ERC20
    }
    // @todo Continue
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

            console.info(asset);
            console.info(oracleTreasuryToken);

            return instructions["Treasury"]["support"](asset, oracle);
        }
        if (functionIdentifier === "unsupport") {
            const [asset, _oracle] = getAssetAndOracle(values[0]);

            return instructions["Treasury"]["unsupport"](asset);
        }
        if (functionIdentifier === "bond") {
            //const asset = assets[values[0]];
            const amount = ethers.utils.parseEther(values[1]);
            return instructions["Treasury"]["bond"](owner, treasury, erc20, amount);
        }
        if (functionIdentifier === "unbond") {

        }
        // @todo Continue
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
        if (words[0] === "#" || words[0].length === 0) {
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
    const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");

    // Setup state variables
    setUpWallets(hre, provider);
    await setUpEnvironment(hre, provider, owner);

    // Set price of ERC20
    await (await oracleERC20.connect(owner).addProvider(oracleProvider.address)).wait();
    let price = ethers.utils.parseUnits("1", "ether"); // 1 USD
    await (await oracleERC20.connect(oracleProvider).pushReport(price)).wait();

    const file = "simulation.config";
    const funcs = parse(file);

    for (let i = 0; i < funcs.length; i++) {
        await funcs[i]();

        console.info(i + "th Config Instruction executed");
    }

    return;

    // Setup oracleProvider as provider for all oracles
    await (await oracleReserve2Token.connect(owner).addProvider(oracleProvider.address)).wait();
    await (await oracleTreasuryToken.connect(owner).addProvider(oracleProvider.address)).wait();
    await (await oracleERC20.connect(owner).addProvider(oracleProvider.address)).wait();
    await (await oracleGeoNFT1.connect(owner).addProvider(oracleProvider.address)).wait();
    console.info("[INFO] Oracle provider set up");

    // Add owner to treasury whitelist
    await (await treasury.connect(owner).addToWhitelist(owner.address)).wait();
    console.info("[INFO] Owner whitelisted for Treasury un/bonding operations");

    // Set price of erc20 in oracle
    // Note that the price is denominated in 18 decimal precision, i.e. ether
    let priceERC20 = ethers.utils.parseUnits("1", "ether"); // 1 USD
    await (await oracleERC20.connect(oracleProvider).pushReport(priceERC20)).wait();
    console.info("[INFO] ERC20 price of 1 USD pushed to Oracle");

    // Set price of Reserve2Token in oracle
    let priceOfReserve2Token = ethers.utils.parseUnits("1", "ether"); // 1 USD
    await (await oracleReserve2Token.connect(oracleProvider).pushReport(priceOfReserve2Token)).wait();
    console.log("[INFO] Reserve2Token price of 1 USD pushed to Oracle");

    // Set price of TreasuryToken in oracle
    let priceOfTreasuryToken = ethers.utils.parseUnits("1", "ether"); // 1 USD
    await (await oracleTreasuryToken.connect(oracleProvider).pushReport(priceOfTreasuryToken)).wait();
    console.log("[INFO] TreasuryToken price of 1 USD pushed to Oracle");

    // Add erc20 as being supported by treasury and supported for un/bonding
    await (await treasury.connect(owner).supportAsset(erc20.address, oracleERC20.address)).wait();
    await (await treasury.connect(owner).supportAssetForBonding(erc20.address)).wait();
    await (await treasury.connect(owner).supportAssetForUnbonding(erc20.address)).wait();
    console.info("[INFO] Treasury supports ERC20 for un/bonding operations");

    // Mint erc20s to owner
    let erc20OwnerBalance = ethers.utils.parseUnits("100", "ether"); // 100 tokens
    await (await erc20.connect(owner).mint(owner.address, erc20OwnerBalance)).wait();
    console.info("[INFO] ERC20 minted to owner");
    console.info("       -> ERC20.balanceOf(owner): " + await erc20.balanceOf(owner.address));

    // Approve erc20s from owner to treasury
    await (await erc20.connect(owner).approve(treasury.address, erc20OwnerBalance)).wait();
    console.info("[INFO] Owner approved ERC20 for Treasury");

    // Owner bonds erc20 into treasury -> owner receives elastic receipt tokens
    await (await treasury.connect(owner).bond(erc20.address, erc20OwnerBalance)).wait();
    console.info("[INFO] Owner bonded ERC20 into Treasury")
    let ownerBalanceOfTreasuryTokens = await treasury.balanceOf(owner.address);
    console.info("       -> Treasury.balanceOf(owner): " + ownerBalanceOfTreasuryTokens);
    console.info("       -> ERC20.balanceOf(owner)   : " + await erc20.balanceOf(owner.address));
    console.info("       -> ERC20.balanceOf(treasury): " + await erc20.balanceOf(treasury.address));

    // Change price of erc20 by +100%
    priceERC20 = ethers.utils.parseUnits("2", "ether"); // 2 USD
    // Note to first purge the old report of 1 USD. This needs to be done as we do not control
    // the timestamp leading to the oracle taking both reports into consideration and reporting
    // the average of the two reports as price, i.e. price would be (1 + 2) / 2 = 1.5 instead of 1.
    await (await oracleERC20.connect(oracleProvider).purgeReports()).wait();
    await (await oracleERC20.connect(oracleProvider).pushReport(priceERC20)).wait();
    console.info("[INFO] Increased ERC20's price by +100% to 2 USD");
    console.info("       -> This will double owner's Treasury's token balance on the next state mutating function");

    // Send previous balance of elastic receipt tokens from owner to user
    await (await treasury.connect(owner).transfer(user.address, ownerBalanceOfTreasuryTokens)).wait();
    console.info("[INFO] Send previous balance of Treasury tokens from owner to user");
    ownerBalanceOfTreasuryTokens = await treasury.balanceOf(owner.address);
    let userBalanceOfTreasuryTokens = await treasury.balanceOf(user.address);
    console.info("       -> Treasury.balanceOf(owner): " + ownerBalanceOfTreasuryTokens);
    console.info("       -> Treasury.balanceOf(user) : " + userBalanceOfTreasuryTokens);
    //                   -> owner has 50% of elastic tokens, user has 50% of elastic tokens
    console.info("       ---> Note that owner's Treasury token's balance doubled. Half send to user, half kept");

    // Mint geoNFT to owner
    const geoNFTERC721Id = { erc721: geoNft.address, id: 1 };
    await (await geoNft.connect(owner).mint(owner.address, 0, 0, "First GeoNFT")).wait();
    console.info("[INFO] Minted GeoNFT with ID 1 to owner");
    // Set price of geoNFT
    let priceGeoNFT1 = ethers.utils.parseUnits("100000", "ether"); // 100,000 USD
    await (await oracleGeoNFT1.connect(oracleProvider).pushReport(priceGeoNFT1)).wait();
    console.info("       -> Price of GeoNFT(1) set to 100,000 USD");
    // Support nft by reserve2, also support for un/bonding
    await (await reserve2.connect(owner).supportERC721Id(geoNFTERC721Id, oracleGeoNFT1.address)).wait();
    console.info("       -> GeoNFT(1) set as supported by Reserve2");
    await (await reserve2.connect(owner).supportERC721IdForBonding(geoNFTERC721Id, true)).wait();
    console.info("       -> GeoNFT(1) set as supported for bonding by Reserve2");
    await (await reserve2.connect(owner).supportERC721IdForUnbonding(geoNFTERC721Id, true)).wait();
    console.info("       -> GeoNFT(1) set as supported for unbonding by Reserve2");

    // Owner bonds nft into reserve2
    console.info("[INFO] Bonding GeoNFT(1) from owner into Reserve2");
    await (await geoNft.connect(owner).approve(reserve2.address, 1)).wait();
    console.info("       -> GeoNFT(1) approved from owner for Reserve2");
    await (await reserve2.connect(owner).bondERC721Id(geoNFTERC721Id)).wait();
    console.info("       -> GeoNFT(1) bonding from owner into Reserve2");
    //                   -> owner receives reserve2Tokens
    let ownerBalanceReserve2Token = await reserve2Token.balanceOf(owner.address);
    console.info("       ---> Reserve2Token.balanceOf(owner): " + ownerBalanceReserve2Token);
    console.info("       ---> GeoNFT.ownerOf(1): Reserve2(" + await geoNft.ownerOf(1) + ")");

    // Owner bonds user's treasury tokens into reserve2
    console.info("[INFO] Owner bonds user's all of user's Treasury tokens into Reserve2");
    await (await treasury.connect(user).approve(reserve2.address, ethers.utils.parseUnits("1000000000", "ether"))).wait();
    console.info("       -> User approves Reserve2 to spend Treasury tokens");
    await (await reserve2.connect(owner).supportERC20(treasury.address, oracleTreasuryToken.address)).wait();
    console.info("       -> Treasury token set as supported by Reserve2");
    await (await reserve2.connect(owner).supportERC20ForBonding(treasury.address, true)).wait();
    console.info("       -> Treasury token set as supported for bonding by Reserve2");
    await (await reserve2.connect(owner).supportERC20ForUnbonding(treasury.address, true)).wait();
    console.info("       -> Treasury token set as supported for unbonding by Reserve2");
    await (await reserve2.connect(owner).bondERC20FromTo(treasury.address, user.address, user.address, ethers.utils.parseUnits("100", "ether"))).wait();
    console.info("       -> Owner bonds user's Treasury tokens into Reserve2");
    console.info("       ---> Reserve2Token.balanceOf(user): " + await reserve2Token.balanceOf(user.address));

    // owner incurs debt in reserve2
    // owner fails to incur too much debt

    // change price of nft so that reserve2 is below min backing
    // owner pays back some debt
    // -> reserve2 above min backing
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
}
