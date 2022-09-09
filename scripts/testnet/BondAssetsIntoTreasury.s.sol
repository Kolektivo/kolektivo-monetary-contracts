pragma solidity 0.8.10;

import "forge-std/Script.sol";

import { Treasury } from "../../src/Treasury.sol";
import { Oracle } from "../../src/Oracle.sol";

import { ERC20Mock } from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @dev Initializes the ERC20Mock token oracle with some price and mints some
 *      ERC20Mock tokens. Aftwards the ERC20Mock is registered inside the
 *      Treasury, approved to be spent by the Treasury and then bonded into
 *      the Treasury.
 *
 *      The ERC20Mock token's price is set to a new value and a Treasury rebase
 *      triggered manually.
 */
contract BondAssetsIntoTreasury is Script {
    // Note that the addresses are copied from the DEPLOYMENT.md doc file.
    Treasury treasury = Treasury(0x030Cd6F06FFf3728ac7bF50EF7b2a38DFD517237);
    ERC20Mock token1 = ERC20Mock(0x434f234916Bbf0190BE3f058DeD9d8889953c4b4);
    ERC20Mock token2 = ERC20Mock(0xd4482BAEa5c6426687a8F66de80bb857fE1942f1);
    ERC20Mock token3 = ERC20Mock(0x290DB975a9Aa2cb6e34FC0A09794945B383d7cCE);
    Treasury.AssetType assetTypeToken1 = Treasury.AssetType.Default;
    Treasury.AssetType assetTypeToken2 = Treasury.AssetType.Stable;
    Treasury.AssetType assetTypeToken3 = Treasury.AssetType.Ecological;
    Oracle token1Oracle = Oracle(0x2066a9c878c26FA29D4fd923031C3C40375d1c0D);
    Oracle token2Oracle = Oracle(0xce37a77D34f05325Ff1CC0744edb2845349307F7);
    Oracle token3Oracle = Oracle(0x923b14F630beA5ED3D47338469c111D6d082B3E8);

    uint token1Amount = 617e18; // 617
    uint token2Amount = 150_000e18; // 150k
    uint token3Amount = 1_450_000e18; // 1.45m

    uint token1Price = 413_764e16; // $4,137.64
    uint token2Price = 1e18; // $1
    uint token3Price = 5e16; // $0.05

    function run() external {
        vm.startBroadcast();
        {
            // Set initial token prices
            token1Oracle.pushReport(token1Price);
            token2Oracle.pushReport(token2Price);
            token3Oracle.pushReport(token3Price);

            // Mint tokens to msg.sender, i.e. the address with which's
            // private key the script is executed.
            token1.mint(msg.sender, token1Amount);
            token2.mint(msg.sender, token2Amount);
            token3.mint(msg.sender, token3Amount);

            // Approve tokens to Treasury.
            token1.approve(address(treasury), type(uint).max);
            token2.approve(address(treasury), type(uint).max);
            token3.approve(address(treasury), type(uint).max);

            // Register token inside the Treasury.
            treasury.registerERC20(
                address(token1),
                address(token1Oracle),
                assetTypeToken1
            );
            treasury.registerERC20(
                address(token2),
                address(token2Oracle),
                assetTypeToken2
            );
            treasury.registerERC20(
                address(token3),
                address(token3Oracle),
                assetTypeToken3
            );

            // List token as bondable inside the Treasury.
            treasury.listERC20AsBondable(address(token1));
            treasury.listERC20AsBondable(address(token2));
            treasury.listERC20AsBondable(address(token3));

            // Bond tokens into Treasury.
            treasury.bondERC20(address(token1), token1Amount);
            treasury.bondERC20(address(token2), token2Amount);
            treasury.bondERC20(address(token3), token3Amount);
        }
        vm.stopBroadcast();

        // Check balances.
        require(
            treasury.balanceOf(msg.sender) ==
                (token1Price * token1Amount) /
                    1e18 +
                    (token2Price * token2Amount) /
                    1e18 +
                    (token3Price * token3Amount) /
                    1e18,
            "BondAssetsIntoTreasury: Invalid amount of treasury tokens received through bonding"
        );
        require(
            token1.balanceOf(address(treasury)) == token1Amount,
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );
        require(
            token2.balanceOf(address(treasury)) == token2Amount,
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );
        require(
            token3.balanceOf(address(treasury)) == token3Amount,
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );

        vm.startBroadcast();
        {
            // Change token's price
            token1Oracle.purgeReports();
            token1Oracle.pushReport(token1Price / 2);

            // Trigger a Treasury rebase.
            treasury.rebase();
        }
        vm.stopBroadcast();

        // Check balance.
        require(
            treasury.balanceOf(msg.sender) ==
                ((token1Price / 2) * token1Amount) /
                    1e18 +
                    (token2Price * token2Amount) /
                    1e18 +
                    (token3Price * token3Amount) /
                    1e18,
            "BondAssetsIntoTreasury: Invalid amount of treasury tokens after rebase"
        );
    }
}
