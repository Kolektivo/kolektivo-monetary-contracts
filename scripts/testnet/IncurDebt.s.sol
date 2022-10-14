pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve} from "../../src/Reserve.sol";
import {ReserveToken} from "../../src/ReserveToken.sol";
import {Oracle} from "../../src/Oracle.sol";

/**
 * @dev Mints ERC20Mock tokens and approves them to the Reserve.
 *      Registers the ERC20Mock inside the Reserve and lists them as bondable.
 *      Bonds the tokens into the Reserve.
 *      Incurs some debt inside the Reserve.
 */
contract IncurDebt is Script {
    function run() external {
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        ReserveToken reserveToken = ReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));

        Oracle reserveTokenOracle =
            Oracle(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN_ORACLE"));

        uint desiredBackingAmount = vm.envUint("DEPLOYMENT_DESIRED_BACKING_AMOUNT_RESERVE");


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

        // Send kCUR to Reserve (just to store them there)
        reserveToken.transfer(address(reserve), reserveToken.balanceOf(vm.envAddress("WALLET_DEPLOYER")));

        vm.stopBroadcast();
    }
}
