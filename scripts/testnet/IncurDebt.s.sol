pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve} from "../../src/Reserve.sol";
import {Oracle} from "../../src/Oracle.sol";

/**
 * @dev Mints ERC20Mock tokens and approves them to the Reserve.
 *      Registers the ERC20Mock inside the Reserve and lists them as bondable.
 *      Bonds the tokens into the Reserve.
 *      Incurs some debt inside the Reserve.
 */
contract BondAssetsIntoReserve is Script {
    // Note that the addresses are copied from the DEPLOYMENT.md doc file.
    Reserve reserve = Reserve(0x9f4995f6a797Dd932A5301f22cA88104e7e42366);

    Oracle reserveTokenOracle =
        Oracle(0x8684e1f9da7036adFF3D95BA54Db9Ef0F503f5D4);

    uint desiredBackingAmount = 8100; // %

    function run() external {
        vm.startBroadcast();
        {
            uint oldReserveValuation;
            uint oldSupplyValuation;
            uint oldBacking;
            (oldReserveValuation, oldSupplyValuation, oldBacking) = reserve
                .reserveStatus();

            console2.log("Old Reserve Value: ", oldReserveValuation / 1e18);
            console2.log("Old Supply Value: ", oldSupplyValuation / 1e18);
            console2.log("Old Backing: ", oldBacking);

            if (oldBacking == desiredBackingAmount) {
                return;
            }
            uint requiredSupply = (oldReserveValuation * 10000) /
                desiredBackingAmount;

            console2.log("Required Supply Value: ", requiredSupply / 1e18);
            if (requiredSupply > oldSupplyValuation) {
                console2.log(
                    "Minting Value: ",
                    (requiredSupply - oldSupplyValuation) / 1e18
                );
                (uint price, bool valid) = reserveTokenOracle.getData();
                require(valid);
                console2.log(
                    "Minting Value: ",
                    (requiredSupply - oldSupplyValuation) / price
                );
                reserve.incurDebt(
                    ((requiredSupply - oldSupplyValuation) * 1e18) / price
                );
            } else {
                reserve.payDebt(oldSupplyValuation - requiredSupply);
            }
        }
        // 1_783_776
        // 1_783_776
        // 10000
        vm.stopBroadcast();
    }
}
