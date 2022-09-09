pragma solidity 0.8.10;

import "forge-std/Script.sol";

import { Reserve } from "../../src/Reserve.sol";
import { ReserveToken } from "../../src/ReserveToken.sol";
import { IReserve } from "../../src/interfaces/IReserve.sol";
import { Treasury } from "../../src/Treasury.sol";
import { Oracle } from "../../src/Oracle.sol";

import { ERC20Mock } from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @dev Mints ERC20Mock tokens and approves them to the Reserve.
 *      Registers the ERC20Mock inside the Reserve and lists them as bondable.
 *      Bonds the tokens into the Reserve.
 *      Incurs some debt inside the Reserve.
 */
contract BondAssetsIntoReserve is Script {
    // Note that the addresses are copied from the DEPLOYMENT.md doc file.
    Reserve reserve = Reserve(0xBccd7dA2A8065C588caFD210c33FC08b00d36Df9);
    Oracle reserveTokenOracle =
        Oracle(0xA6B5122385c8aF4a42E9e9217301217B9cdDbC49);

    Treasury treasury = Treasury(0x030Cd6F06FFf3728ac7bF50EF7b2a38DFD517237);
    Oracle treasuryTokenOracle =
        Oracle(0xED282D1EAbd32C3740Ee82fa1A95bd885A69f3bB);

    ERC20Mock token1 = ERC20Mock(0x434f234916Bbf0190BE3f058DeD9d8889953c4b4);
    ERC20Mock token2 = ERC20Mock(0xd4482BAEa5c6426687a8F66de80bb857fE1942f1);
    ERC20Mock token3 = ERC20Mock(0x290DB975a9Aa2cb6e34FC0A09794945B383d7cCE);
    IReserve.AssetType assetTypeToken1 = IReserve.AssetType.Default;
    IReserve.AssetType assetTypeToken2 = IReserve.AssetType.Stable;
    IReserve.AssetType assetTypeToken3 = IReserve.AssetType.Ecological;
    Oracle token1Oracle = Oracle(0x2066a9c878c26FA29D4fd923031C3C40375d1c0D);
    Oracle token2Oracle = Oracle(0xce37a77D34f05325Ff1CC0744edb2845349307F7);
    Oracle token3Oracle = Oracle(0x923b14F630beA5ED3D47338469c111D6d082B3E8);

    uint token1Amount = 119e18; // 119
    uint token2Amount = 31_000e18; // 31k
    uint token3Amount = 152_500e18; // 152.5k

    function run() external {
        vm.startBroadcast();
        {
            // Mint tokens to msg.sender, i.e. the address with which's
            // private key the script is executed.
            token1.mint(msg.sender, token1Amount);
            token2.mint(msg.sender, token2Amount);
            token3.mint(msg.sender, token3Amount);

            // Approve tokens to Reserve.
            token1.approve(address(reserve), type(uint).max);
            token2.approve(address(reserve), type(uint).max);
            token3.approve(address(reserve), type(uint).max);
            treasury.approve(address(reserve), type(uint).max);

            reserveTokenOracle.pushReport(312e16);
            treasuryTokenOracle.pushReport(1e18);

            // Register token inside the Reserve.
            reserve.registerERC20(
                address(token1),
                address(token1Oracle),
                assetTypeToken1
            );

            reserve.registerERC20(
                address(token2),
                address(token2Oracle),
                assetTypeToken2
            );

            reserve.registerERC20(
                address(token3),
                address(token3Oracle),
                assetTypeToken3
            );

            reserve.registerERC20(
                address(treasury),
                address(treasuryTokenOracle),
                assetTypeToken1
            );

            // List token as bondable inside the Reserve.
            reserve.listERC20AsBondable(address(token1));
            reserve.listERC20AsBondable(address(token2));
            reserve.listERC20AsBondable(address(token3));
            reserve.listERC20AsBondable(address(treasury));

            // Bond tokens into Reserve.
            reserve.bondERC20(address(token1), token1Amount);
            reserve.bondERC20(address(token2), token2Amount);
            reserve.bondERC20(address(token3), token3Amount);
            reserve.bondERC20All(address(treasury));
            // Incur some debt.
            // Note that the token's price is set as 2$.
            // 24% of 2,000$ = 480$.
            // Backing should now be 76%.
            // reserve.incurDebt(480e18);
        }
        vm.stopBroadcast();
    }
}
