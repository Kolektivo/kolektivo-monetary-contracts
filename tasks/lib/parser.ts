/**
 * # Config Grammar
 *
 * <ContractIdentifier> <Function> <Values...>
 *
 * ## ContractIdentifiers
 *
 * OracleIdentifier = Oracle(Treasury)
 *                  | Oracle(GeoNFT1)
 *                  | Oracle(Reserve2Token)
 *                  | Oracle(ERC20)
 *
 * TreasuryIdentifier      = Treasury
 * Reserve2Identifier      = Reserve2
 * GeoNFT Identifier       = GeoNFT
 * Reserve2TokenIdentifier = Reserve2Token
 * ERC20Identifier         = ERC20

 * ## Functions per Contract
 *
 * ### Generic ERC20 Functions
 * transfer     address_to      amount_in_ether
 * transferFrom address_from    address_to      amount_in_ether
 * approve      address_spender amount_in_ether
 * balanceOf
 *
 * ### Oracle
 * - setPrice price_in_ether
 *
 * ### Treasury is ERC20Contract
 * - support    ERC20Contract
 * - unsupport  ERC20Contract
 * - bond       ERC20Contract amount_in_ether
 * - unbond     ERC20Contract amount_in_ether
 * + Generic ERC20 Functions
 *
 * ### Reserve2
 * - supportERC20    ERC20Contract
 * - unsupportERC20  ERC20Contract
 * - supportERC721   GeoNFT
 * - unsupportERC721 GeoNFT
 * - bondERC20       ERC20Contract amount_in_ether
 * - @todo other un/bondings
 * - incurDebt       amount_in_ether
 * - payDebt         amount_in_ether
 * + Generic ERC20 Functions
 *
 * ### Reserve2Token is ERC20Contract
 * + Generic ERC20 Functions
 *
 * ### ERC20 is ERC20Contract
 * + Generic ERC20 Functions
 */

/*
// Set price of erc20 in oracle
// Note that the price is denominated in 18 decimal precision, i.e. ether
let priceERC20 = ethers.utils.parseUnits("1", "ether"); // 1 USD
await(await oracleERC20.connect(oracleProvider).pushReport(priceERC20)).wait();
console.info("[INFO] ERC20 price of 1 USD pushed to Oracle");

// Set price of Reserve2Token in oracle
let priceOfReserve2Token = ethers.utils.parseUnits("1", "ether"); // 1 USD
await(await oracleReserve2Token.connect(oracleProvider).pushReport(priceOfReserve2Token)).wait();
console.log("[INFO] Reserve2Token price of 1 USD pushed to Oracle");

// Set price of TreasuryToken in oracle
let priceOfTreasuryToken = ethers.utils.parseUnits("1", "ether"); // 1 USD
await(await oracleTreasuryToken.connect(oracleProvider).pushReport(priceOfTreasuryToken)).wait();
console.log("[INFO] TreasuryToken price of 1 USD pushed to Oracle");

// Add erc20 as being supported by treasury and supported for un/bonding
await(await treasury.connect(owner).supportAsset(erc20.address, oracleERC20.address)).wait();
await(await treasury.connect(owner).supportAssetForBonding(erc20.address)).wait();
await(await treasury.connect(owner).supportAssetForUnbonding(erc20.address)).wait();
console.info("[INFO] Treasury supports ERC20 for un/bonding operations");

// Mint erc20s to owner
let erc20OwnerBalance = ethers.utils.parseUnits("100", "ether"); // 100 tokens
await(await erc20.connect(owner).mint(owner.address, erc20OwnerBalance)).wait();
console.info("[INFO] ERC20 minted to owner");
console.info("       -> ERC20.balanceOf(owner): " + await erc20.balanceOf(owner.address));

// Approve erc20s from owner to treasury
await(await erc20.connect(owner).approve(treasury.address, erc20OwnerBalance)).wait();
console.info("[INFO] Owner approved ERC20 for Treasury");

// Owner bonds erc20 into treasury -> owner receives elastic receipt tokens
await(await treasury.connect(owner).bond(erc20.address, erc20OwnerBalance)).wait();
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
await(await oracleERC20.connect(oracleProvider).purgeReports()).wait();
await(await oracleERC20.connect(oracleProvider).pushReport(priceERC20)).wait();
console.info("[INFO] Increased ERC20's price by +100% to 2 USD");
console.info("       -> This will double owner's Treasury's token balance on the next state mutating function");

// Send previous balance of elastic receipt tokens from owner to user
await(await treasury.connect(owner).transfer(user.address, ownerBalanceOfTreasuryTokens)).wait();
console.info("[INFO] Send previous balance of Treasury tokens from owner to user");
ownerBalanceOfTreasuryTokens = await treasury.balanceOf(owner.address);
let userBalanceOfTreasuryTokens = await treasury.balanceOf(user.address);
console.info("       -> Treasury.balanceOf(owner): " + ownerBalanceOfTreasuryTokens);
console.info("       -> Treasury.balanceOf(user) : " + userBalanceOfTreasuryTokens);
//                   -> owner has 50% of elastic tokens, user has 50% of elastic tokens
console.info("       ---> Note that owner's Treasury token's balance doubled. Half send to user, half kept");

// Mint geoNFT to owner
const geoNFTERC721Id = { erc721: geoNft.address, id: 1 };
await(await geoNft.connect(owner).mint(owner.address, 0, 0, "First GeoNFT")).wait();
console.info("[INFO] Minted GeoNFT with ID 1 to owner");
// Set price of geoNFT
let priceGeoNFT1 = ethers.utils.parseUnits("100000", "ether"); // 100,000 USD
await(await oracleGeoNFT1.connect(oracleProvider).pushReport(priceGeoNFT1)).wait();
console.info("       -> Price of GeoNFT(1) set to 100,000 USD");
// Support nft by reserve2, also support for un/bonding
await(await reserve2.connect(owner).supportERC721Id(geoNFTERC721Id, oracleGeoNFT1.address)).wait();
console.info("       -> GeoNFT(1) set as supported by Reserve2");
await(await reserve2.connect(owner).supportERC721IdForBonding(geoNFTERC721Id, true)).wait();
console.info("       -> GeoNFT(1) set as supported for bonding by Reserve2");
await(await reserve2.connect(owner).supportERC721IdForUnbonding(geoNFTERC721Id, true)).wait();
console.info("       -> GeoNFT(1) set as supported for unbonding by Reserve2");

// Owner bonds nft into reserve2
console.info("[INFO] Bonding GeoNFT(1) from owner into Reserve2");
await(await geoNft.connect(owner).approve(reserve2.address, 1)).wait();
console.info("       -> GeoNFT(1) approved from owner for Reserve2");
await(await reserve2.connect(owner).bondERC721Id(geoNFTERC721Id)).wait();
console.info("       -> GeoNFT(1) bonding from owner into Reserve2");
//                   -> owner receives reserve2Tokens
let ownerBalanceReserve2Token = await reserve2Token.balanceOf(owner.address);
console.info("       ---> Reserve2Token.balanceOf(owner): " + ownerBalanceReserve2Token);
console.info("       ---> GeoNFT.ownerOf(1): Reserve2(" + await geoNft.ownerOf(1) + ")");

// Owner bonds user's treasury tokens into reserve2
console.info("[INFO] Owner bonds user's all of user's Treasury tokens into Reserve2");
await(await treasury.connect(user).approve(reserve2.address, ethers.utils.parseUnits("1000000000", "ether"))).wait();
console.info("       -> User approves Reserve2 to spend Treasury tokens");
await(await reserve2.connect(owner).supportERC20(treasury.address, oracleTreasuryToken.address)).wait();
console.info("       -> Treasury token set as supported by Reserve2");
await(await reserve2.connect(owner).supportERC20ForBonding(treasury.address, true)).wait();
console.info("       -> Treasury token set as supported for bonding by Reserve2");
await(await reserve2.connect(owner).supportERC20ForUnbonding(treasury.address, true)).wait();
console.info("       -> Treasury token set as supported for unbonding by Reserve2");
await(await reserve2.connect(owner).bondERC20FromTo(treasury.address, user.address, user.address, ethers.utils.parseUnits("100", "ether"))).wait();
console.info("       -> Owner bonds user's Treasury tokens into Reserve2");
console.info("       ---> Reserve2Token.balanceOf(user): " + await reserve2Token.balanceOf(user.address));

    // owner incurs debt in reserve2
    // owner fails to incur too much debt

    // change price of nft so that reserve2 is below min backing
    // owner pays back some debt
    // -> reserve2 above min backing
*/

/*

    const filterReserve2BackingUpdated = {
        address: reserve2.address,
        topics: [
            ethers.utils.id("BackingUpdated(address,address)"),
        ],
    };
    const filterTreasuryRebase = {
        address: treasury.address,
        topics: [
            ethers.utils.id("Rebase(uint,uint)"),
        ],
    };
    provider.on(filterReserve2BackingUpdated, (oldBacking, newBacking) => {
        console.info("[EVENT INFO] Reserve2's backing updated:");
        console.info("             => oldBacking: " + oldBacking);
        console.info("             => newBacking: " + newBacking);
    });
    provider.on(filterTreasuryRebase, (_epoch, supply) => {
        console.info("[EVENT INFO] Treasury token rebased:");
        console.info("             => new Supply: " + supply);
    });

*/
