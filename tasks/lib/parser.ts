import * as fs from "fs";

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
