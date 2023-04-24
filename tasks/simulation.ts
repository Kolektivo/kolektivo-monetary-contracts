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
  reserveTokenABI,
  reserveABI,
} from "./lib/abis";
import { config, exit } from "process";
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
 *     Note that it is mandatory to start a new anvil session for every simulation!
 *  7. Adjust the `file` constant below
 *  8. Execute simulation with `npx hardhat simulation`
 */

//const file = "simulations/incurring-debt.simulation";
const file = "simulations/treasury-rebasing.simulation";

// Contract addresses
const ADDRESS_RESERVE = "0xa51c1fc2f0d1a1b8494ed1fe312d7c3a78ed91c0";

const ADDRESS_TREASURY = "0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6";
const ADDRESS_ORACLE_TREASURY_TOKEN =
  "0x610178da211fef7d417bc0e6fed39f05609ad788";

const ADDRESS_GEONFT = "0x0165878a594ca255338adfa4d48449f69242eb8f";
const ADDRESS_ORACLE_GEONFT_1 = "0xdc64a140aa3e981100a9beca4e685f962f0cf6c9";

const ADDRESS_RESERVE_TOKEN = "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0";
const ADDRESS_ORACLE_RESERVE_TOKEN =
  "0x5fbdb2315678afecb367f032d93f642f64180aa3";

const ADDRESS_ERC20 = "0x959922be3caee4b8cd9a407cc3ac1c251c2007b1";
const ADDRESS_ORACLE_ERC20 = "0x9a676e781a523b5d0c0e43731313a708cb607508";

// Contract instances
let reserve;
let treasury, oracleTreasuryToken;
let geoNft, oracleGeoNFT1;
let reserveToken, oracleReserveToken;
let erc20, oracleERC20;

// Account instances
let owner, oracleProvider, user;

function getAssetAndOracle(asset: string) {
  if (asset === "Treasury") {
    return [treasury, oracleTreasuryToken];
  }
  if (asset === "CuracaoReserveToken") {
    return [reserveToken, oracleReserveToken];
  }
  if (asset === "ERC20") {
    return [erc20, oracleERC20];
  }
  if (asset === "GeoNFT1") {
    // Note that this branch also returns the ERC721Id for the GeoNFT1.
    const geoNFTERC721Id = { erc721: geoNft.address, id: 1 };
    return [geoNft, oracleGeoNFT1, geoNFTERC721Id];
  }
  if (asset === "Reserve") {
    return [reserve];
  }
  console.info("[ERROR] Unknown asset: " + asset);
}

const genericInstructionsERC20 = {
  transfer: (token, sender, receiver, amount) => {
    return async () => {
      await (
        await token.connect(sender).transfer(receiver.address, amount)
      ).wait();
      console.info("Send tokens");
    };
  },
  transferFrom: (token, sender, spender, receiver, amount) => {
    return async () => {
      await (
        await token
          .connect(sender)
          .transerFrom(spender.address, receiver.address, amount)
      ).wait();
      console.info("Send token from");
    };
  },
  approve: (token, sender, spender, amount) => {
    return async () => {
      await (
        await token.connect(sender).approve(spender.address, amount)
      ).wait();
      console.info["Approved tokens"];
    };
  },
  balanceOf: (token, who) => {
    return async () => {
      const balance = await token.balanceOf(who.address);
      console.info("BalanceOf: " + balance);
    };
  },
};

const instructions = {
  Treasury: {
    // Registerd an ERC20 token and lists it as bondable + redeemable.
    register: (asset, oracle) => {
      return async () => {
        console.info("Treasury: Registering and listing asset");
        console.info("=> Asset : " + asset.address);
        await (
          await treasury
            .connect(owner)
            .registerAsset(asset.address, oracle.address)
        ).wait();
        await (
          await treasury.connect(owner).listAssetAsBondable(asset.address)
        ).wait();
        await (
          await treasury.connect(owner).listAssetAsRedeemable(asset.address)
        ).wait();
      };
    },
    // Deregisterd an ERC20 token and delists it as bondable + redeemable.
    deregister: (asset) => {
      return async () => {
        console.info("Treasury: Deregistering and delisting asset");
        console.info("=> Asset : " + asset.address);
        await (
          await treasury.connect(owner).delistAssetAsBondable(asset.address)
        ).wait();
        await (
          await treasury.connect(owner).delistAssetAsRedeemable(asset.address)
        ).wait();
        await (
          await treasury.connect(owner).deregisterAsset(asset.address)
        ).wait();
      };
    },
    // Bonds an amount of ERC20s from owner
    // Needs token approval!
    bond: (asset, amount) => {
      return async () => {
        console.info("Treasury: Bonding assets");
        console.info("=> Bonder: " + owner.address);
        console.info("=> Asset : " + asset.address);
        console.info("=> Amount: " + amount);
        await (
          await treasury.connect(owner).bond(asset.address, amount)
        ).wait();
      };
    },
    // Redeems an amount of TreasuryTokens from owner
    // Needs token approval!
    redeem: (asset, amount) => {
      return async () => {
        console.info("Treasury: Redeeming assets");
        console.info("=> Bonder: " + owner.address);
        console.info("=> Asset : " + asset.address);
        console.info("=> Amount: " + amount);
        await (
          await treasury.connect(owner).redeem(asset.address, amount)
        ).wait();
      };
    },
    rebase: () => {
      return async () => {
        console.info("Treasury: Rebasing manually");
        await (await treasury.connect(owner).rebase()).wait();
      };
    },
    // @todo + Generic ERC20
    balanceOf: () => {
      return async () => {
        const balance = await treasury.balanceOf(owner.address);
        console.info("Treasury: BalanceOf");
        console.info("=> Owner : " + owner.address);
        console.info("=> Amount: " + balance);
      };
    },
  },

  Oracle: {
    setPrice: (oracle, amount) => {
      return async () => {
        console.info("Oracle: Setting price of asset");
        console.info("=> Oracle: " + oracle.address);
        console.info("=> Price : " + amount);
        await (await oracle.connect(oracleProvider).purgeReports()).wait();
        await (await oracle.connect(oracleProvider).pushReport(amount)).wait();
      };
    },
  },

  Reserve: {
    registerERC20: (asset, oracle) => {
      return async () => {
        console.info("Reserve: Registering and listing ERC20 asset");
        console.info("=> Asset: " + asset.address);
        await (
          await reserve
            .connect(owner)
            .registerERC20(asset.address, oracle.address)
        ).wait();
        await (
          await reserve.connect(owner).listERC20AsBondable(asset.address)
        ).wait();
        await (
          await reserve.connect(owner).listERC20AsRedeemable(asset.address)
        ).wait();
      };
    },
    deregisterERC20: (asset) => {
      return async () => {
        console.info("Reserve: Deregistering and delisting ERC20 asset");
        console.info("=> Asset: " + asset.address);
        await (
          await reserve.connect(owner).delistERC20AsBondable(asset.address)
        ).wait();
        await (
          await reserve.connect(owner).delistERC20AsRedeemable(asset.address)
        ).wait();
        await (
          await reserve.connect(owner).deregisterERC20(asset.address)
        ).wait();
      };
    },
    registerERC721: (erc721Id, oracle) => {
      return async () => {
        console.info("Reserve: Registering and listing ERC721 asset");
        console.info("=> Asset: " + JSON.stringify(erc721Id));
        await (
          await reserve
            .connect(owner)
            .registerERC721Id(erc721Id, oracle.address)
        ).wait();
        await (
          await reserve.connect(owner).listERC721IdAsBondable(erc721Id)
        ).wait();
        await (
          await reserve.connect(owner).listERC721IdAsRedeemable(erc721Id)
        ).wait();
      };
    },
    deregisterERC721: (erc721Id) => {
      return async () => {
        console.info("Reserve: Deregistering and delisting ERC721 asset");
        console.info("=> Asset: " + JSON.stringify(erc721Id));
        await (
          await reserve.connect(owner).delistERC721IdAsBondable(erc721Id)
        ).wait();
        await (
          await reserve.connect(owner).delistERC721IdAsRedeemable(erc721Id)
        ).wait();
        await (
          await reserve.connect(owner).deregisterERC721Id(erc721Id)
        ).wait();
      };
    },
    bondERC20: (asset, amount) => {
      return async () => {
        console.info("Reserve: Bonding ERC20 assets");
        console.info("=> Bonder: " + owner.address);
        console.info("=> Asset : " + asset.address);
        console.info("=> Amount: " + amount);
        await (
          await reserve.connect(owner).bondERC20(asset.address, amount)
        ).wait();
      };
    },
    redeemERC20: (asset, amount) => {
      return async () => {
        console.info("Reserve: Redeeming ERC20 assets");
        console.info("=> Bonder: " + owner.address);
        console.info("=> Asset : " + asset.address);
        console.info("=> Amount: " + amount);
        await (
          await reserve.connect(owner).redeemERC20(asset.address, amount)
        ).wait();
      };
    },
    bondERC721: (erc721Id) => {
      return async () => {
        console.info("Reserve: Bonding ERC721 NFT");
        console.info("=> Bonder: " + owner.address);
        console.info("=> Asset : " + JSON.stringify(erc721Id));
        await (await reserve.connect(owner).bondERC721Id(erc721Id)).wait();
      };
    },
    redeemERC721: (erc721Id, amount) => {
      return async () => {};
    },
    incurDebt: (amount) => {
      return async () => {
        console.info("Reserve: Incurring debt");
        console.info("=> Amount: " + amount);
        await (await reserve.connect(owner).incurDebt(amount)).wait();
      };
    },
    payDebt: (amount) => {
      return async () => {
        console.info("Reserve: Paying debt");
        console.info("=> Amount: " + amount);
        await (await reserve.connect(owner).payDebt(amount)).wait();
      };
    },
    status: () => {
      return async () => {
        const [reserveValuation, supplyValuation, backing] =
          await reserve.reserveStatus();
        console.info("Reserve: Current status");
        console.info("=> Reserve Valuation: " + reserveValuation);
        console.info("=> Supply Valuation : " + supplyValuation);
        console.info("=> Backing          : " + backing);
      };
    },
  },

  CuracaoReserveToken: {
    // @todo CuracaoReserveToken
  },

  GeoNFT: {
    approve: (spender, id) => {
      return async () => {
        console.info("GeoNFT: Approving NFT");
        await (await geoNft.connect(owner).approve(spender.address, 1)).wait();
      };
    },
  },

  ERC20: {
    mint: (amount) => {
      return async () => {
        console.info("ERC20: Minting tokens");
        console.info("=> Receiver: " + owner.address);
        console.info("=> Amount  : " + amount);
        await (await erc20.connect(owner).mint(owner.address, amount)).wait();
      };
    },
    burn: (amount) => {
      return async () => {
        console.info("ERC20: Burning tokens");
        console.info("=> From  : " + owner.address);
        console.info("=> Amount: " + amount);
        await (await erc20.connect(owner).burn(owner.address, amount)).wait();
      };
    },
    approve: (spender, amount) => {
      return async () => {
        console.info("ERC20: Approving tokens");
        console.info("=> Owner  : " + owner.address);
        console.info("=> Spender: " + spender.address);
        console.info("=> Amount : " + amount);
        await (
          await erc20.connect(owner).approve(spender.address, amount)
        ).wait();
      };
    },
    balanceOf: () => {
      return async () => {
        const balance = await erc20.balanceOf(owner.address);
        console.info("ERC20: BalanceOf");
        console.info("=> Owner : " + owner.address);
        console.info("=> Amount: " + balance);
      };
    },
  },
};

function getInstruction(
  contractIdentifier: string,
  functionIdentifier: string,
  values: string[]
) {
  // Treasury
  if (contractIdentifier === "Treasury") {
    if (functionIdentifier === "register") {
      const [asset, oracle] = getAssetAndOracle(values[0]);
      return instructions["Treasury"]["register"](asset, oracle);
    }
    if (functionIdentifier === "deregister") {
      const [asset, _oracle] = getAssetAndOracle(values[0]);
      return instructions["Treasury"]["deregister"](asset);
    }
    if (functionIdentifier === "bond") {
      const [asset, _oracle] = getAssetAndOracle(values[0]);
      const amount = ethers.utils.parseEther(values[1]);
      return instructions["Treasury"]["bond"](asset, amount);
    }
    if (functionIdentifier === "redeem") {
      const [asset, _oracle] = getAssetAndOracle(values[0]);
      const amount = ethers.utils.parseEther(values[1]);
      return instructions["Treasury"]["redeem"](asset, amount);
    }
    if (functionIdentifier === "rebase") {
      return instructions["Treasury"]["rebase"]();
    }
    if (functionIdentifier === "balanceOf") {
      return instructions["Treasury"]["balanceOf"]();
    }
    return () => {
      console.info(
        "[ERROR] Unknown instruction for Treasury: " + functionIdentifier
      );
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
    if (contractIdentifier.endsWith("CuracaoReserveToken)")) {
      const [_asset, oracle] = getAssetAndOracle("CuracaoReserveToken");
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

  // Reserve
  if (contractIdentifier === "Reserve") {
    if (functionIdentifier === "registerERC20") {
      const [asset, oracle] = getAssetAndOracle(values[0]);
      return instructions["Reserve"]["registerERC20"](asset, oracle);
    }
    if (functionIdentifier === "deregisterERC20") {
      const [asset, _oracle] = getAssetAndOracle(values[0]);
      return instructions["Reserve"]["deregisterERC20"](asset);
    }
    if (functionIdentifier === "registerERC721") {
      const [_asset, oracle, erc721Id] = getAssetAndOracle(values[0]);
      return instructions["Reserve"]["registerERC721"](erc721Id, oracle);
    }
    if (functionIdentifier === "deregisterERC721") {
      const [_asset, _oracle, erc721Id] = getAssetAndOracle(values[0]);
      return instructions["Reserve"]["deregisterERC721"](erc721Id);
    }
    if (functionIdentifier === "bondERC20") {
      const [asset] = getAssetAndOracle(values[0]);
      const amount = ethers.utils.parseEther(values[1]);
      return instructions["Reserve"]["bondERC20"](asset, amount);
    }
    if (functionIdentifier === "redeemERC20") {
      const [asset] = getAssetAndOracle(values[0]);
      const amount = ethers.utils.parseEther(values[1]);
      return instructions["Reserve"]["redeemERC20"](asset, amount);
    }
    if (functionIdentifier === "bondERC721") {
      const [_asset, _oracle, erc721Id] = getAssetAndOracle(values[0]);
      return instructions["Reserve"]["bondERC721"](erc721Id);
    }
    if (functionIdentifier === "redeemERC721") {
      // @todo Reserve::redeemERC721
    }
    if (functionIdentifier === "incurDebt") {
      const amount = ethers.utils.parseEther(values[0]);
      return instructions["Reserve"]["incurDebt"](amount);
    }
    if (functionIdentifier === "payDebt") {
      const amount = ethers.utils.parseEther(values[0]);
      return instructions["Reserve"]["payDebt"](amount);
    }
    if (functionIdentifier === "status") {
      return instructions["Reserve"]["status"]();
    }
    return () => {
      console.info(
        "[ERROR] Unknown instruction for Reserve: " + functionIdentifier
      );
      exit(1);
    };
  }

  // @todo CuracaoReserveToken

  // GeoNFT
  if (contractIdentifier === "GeoNFT") {
    if (functionIdentifier === "approve") {
      const [asset] = getAssetAndOracle(values[0]);
      const id = values[1];
      return instructions["GeoNFT"]["approve"](asset, id);
    }
    return () => {
      console.info(
        "[ERROR] Unknown instruction for GeoNFT: " + functionIdentifier
      );
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
      console.info(
        "[ERROR] Unknown instruction for ERC20: " + functionIdentifier
      );
      exit(1);
    };
  }

  return () => {
    console.info("[ERROR] Unknown contract: " + contractIdentifier);
    exit(1);
  };
}

/**
 * Parses a config file and returns a list of executable functions
 */
function parse(file: string) {
  let funcs = [];

  const lines = fs
    .readFileSync(file, "utf-8")
    .replace(/\r\n/g, "\n")
    .split("\n");

  for (let line of lines) {
    const words = line.split(" ");

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
  //configFile: string
): Promise<void> {
  const ethers = hre.ethers;
  const provider = new ethers.providers.WebSocketProvider(
    "ws://127.0.0.1:8545"
  );

  console.info("Running simulation: " + file);
  console.info();

  console.info("============ SETUP ============");
  console.info();

  // Setup state variables
  setUpWallets(hre, provider);
  await setUpEnvironment(hre, provider, owner);

  // Event listener
  reserve.on("BackingUpdated", (oldBacking, newBacking) => {
    console.info("   => [EVENT] Reserve's backing updated:");
    console.info("              => oldBacking: " + oldBacking);
    console.info("              => newBacking: " + newBacking);
  });
  treasury.on("Rebase", (_epoch, supply) => {
    console.info("   => [EVENT] Treasury token rebased:");
    console.info("              => new Supply: " + supply);
  });

  console.info();
  console.info("========== ADDRESSES ==========");
  console.info();
  console.info("Monetray Contracts");
  console.info("  Reserve       : " + reserve.address);
  console.info("  Treasury      : " + treasury.address);
  console.info();
  console.info("Oracle Contracts");
  console.info("  CuracaoReserveToken  : " + oracleReserveToken.address);
  console.info("  Treasury      : " + oracleTreasuryToken.address);
  console.info("  ERC20         : " + oracleERC20.address);
  console.info("  GeoNFT1       : " + oracleGeoNFT1.address);
  console.info();
  console.info("Token Contracts");
  console.info("  CuracaoReserveToken  : " + reserveToken.address);
  console.info("  ERC20         : " + erc20.address);
  console.info("  GeoNFT ID 1   : " + geoNft.address);
  console.info();
  console.info("User");
  console.info("  Owner         : " + owner.address);
  console.info();
  console.info("========== SIMULATION =========");

  const funcs = parse(file);

  for (let i = 0; i < funcs.length; i++) {
    // Sleep for 2 seconds before each tx to give time to receive events
    await new Promise((resolve) => setTimeout(resolve, 2000));
    console.info();
    await funcs[i]();
  }

  // Sleep again 2 seconds in case last tx emits an event
  await new Promise((resolve) => setTimeout(resolve, 2000));

  console.info();
  console.info("===============================");
}

function setUpWallets(
  hre: HardhatRuntimeEnvironment,
  provider: any
): [Wallet, Wallet, Wallet] {
  const ethers = hre.ethers;

  // anvil's second default wallet
  owner = new ethers.Wallet(
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    provider
  );
  // anvil's third default wallet
  oracleProvider = new ethers.Wallet(
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
    provider
  );
  // anvil's forth default wallet
  user = new ethers.Wallet(
    "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
    provider
  );
}

async function setUpEnvironment(
  hre: HardhatRuntimeEnvironment,
  provider: any,
  owner: Wallet
) {
  const ethers = hre.ethers;

  console.info("Deploying all contracts. This takes a moment...");

  // Deploy base contracts
  execSync("sh ./tasks/deployBaseContracts.sh");

  // Deploy ERC20 mock token with corresponding oracle
  execSync("sh ./tasks/deployTokenWithOracle.sh");

  console.info("...All contracts deployed");

  console.info("Initiating owner switch...");
  // Set deployed contract objects to state variables
  reserve = new ethers.Contract(ADDRESS_RESERVE, reserveABI(), provider);

  treasury = new ethers.Contract(ADDRESS_TREASURY, treasuryABI(), provider);
  oracleTreasuryToken = new ethers.Contract(
    ADDRESS_ORACLE_TREASURY_TOKEN,
    oracleABI(),
    provider
  );

  geoNft = new ethers.Contract(ADDRESS_GEONFT, geoNftABI(), provider);
  oracleGeoNFT1 = new ethers.Contract(
    ADDRESS_ORACLE_GEONFT_1,
    oracleABI(),
    provider
  );

  reserveToken = new ethers.Contract(
    ADDRESS_RESERVE_TOKEN,
    reserveTokenABI(),
    provider
  );
  oracleReserveToken = new ethers.Contract(
    ADDRESS_ORACLE_RESERVE_TOKEN,
    oracleABI(),
    provider
  );

  erc20 = new ethers.Contract(ADDRESS_ERC20, reserveTokenABI(), provider);
  oracleERC20 = new ethers.Contract(
    ADDRESS_ORACLE_ERC20,
    oracleABI(),
    provider
  );

  // Complete owner switch for each contract
  await (await reserve.connect(owner).acceptOwnership()).wait();

  await (await treasury.connect(owner).acceptOwnership()).wait();
  await (await oracleTreasuryToken.connect(owner).acceptOwnership()).wait();

  await (await geoNft.connect(owner).acceptOwnership()).wait();
  await (await oracleGeoNFT1.connect(owner).acceptOwnership()).wait();

  await (await reserveToken.connect(owner).acceptOwnership()).wait();
  await (await oracleReserveToken.connect(owner).acceptOwnership()).wait();

  await (await oracleERC20.connect(owner).acceptOwnership()).wait();
  console.info("...Owner switch completed");

  // Set reserve to mintBurner of reserveToken
  console.info("Setting CuracaoReserveToken's mintBurner allowance to Reserve");
  await (
    await reserveToken.connect(owner).setMintBurner(reserve.address)
  ).wait();

  // Setup oracleProvider as provider for all oracles
  console.info("Setting up the Oracle providers");
  await (
    await oracleReserveToken.connect(owner).addProvider(oracleProvider.address)
  ).wait();
  await (
    await oracleTreasuryToken.connect(owner).addProvider(oracleProvider.address)
  ).wait();
  await (
    await oracleERC20.connect(owner).addProvider(oracleProvider.address)
  ).wait();
  await (
    await oracleGeoNFT1.connect(owner).addProvider(oracleProvider.address)
  ).wait();

  // Mint geoNFT to owner
  console.info("Minting first GeoNFT");
  await (
    await geoNft.connect(owner).mint(owner.address, 0, 0, "First GeoNFT")
  ).wait();
}
