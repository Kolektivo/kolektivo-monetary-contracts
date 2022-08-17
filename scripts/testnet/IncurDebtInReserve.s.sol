pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve} from "../../src/Reserve.sol";
import {Oracle} from "../../src/Oracle.sol";

import {ERC20Mock} from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @dev Mints ERC20Mock tokens and approves them to the Reserve.
 *      Registers the ERC20Mock inside the Reserve and lists them as bondable.
 *      Bonds the tokens into the Reserve.
 *      Incurs some debt inside the Reserve.
 */
contract BondAssetsIntoTreasury is Script {

    // Note that the addresses are copied from the DEPLOYMENT.md doc file.
    Reserve   reserve     = Reserve  (0x61f99350eb8a181693639dF40F0C25371844fc32);
    ERC20Mock token       = ERC20Mock(0xD5A8842F698D6170661376880b5aE20C17fD1FC3);
    Oracle    tokenOracle = Oracle   (0x917443A163adC3BeBFCb5ffD3a9D8161bE503D79);

    function run() external {
        vm.startBroadcast();
        {
            // Mint 1,000 tokens to msg.sender, i.e. the address with which's
            // private key the script is executed.
            token.mint(msg.sender, 1_000e18);

            // Approve tokens to Reserve.
            token.approve(address(reserve), type(uint).max);

            // Register token inside the Reserve.
            reserve.registerERC20(address(token), address(tokenOracle));

            // List token as bondable inside the Reserve.
            reserve.listERC20AsBondable(address(token));

            // Bond tokens into Reserve.
            reserve.bondERC20(address(token), 1_000e18);

            // Incur some debt.
            // Note that the token's price is set as 2$.
            // 24% of 2,000$ = 480$.
            // Backing should now be 76%.
            reserve.incurDebt(480e18);
        }
        vm.stopBroadcast();

    }

}
