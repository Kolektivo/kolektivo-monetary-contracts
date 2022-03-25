import { BigInt } from "@graphprotocol/graph-ts"
import {
  Treasury,
  AddressAddedToWhitelist,
  AddressRemovedFromWhitelist,
  Approval,
  AssetMarkedAsSupported,
  AssetMarkedAsSupportedForBonding,
  AssetMarkedAsSupportedForUnbonding,
  AssetMarkedAsUnsupported,
  AssetMarkedAsUnsupportedForBonding,
  AssetMarkedAsUnsupportedForUnbonding,
  AssetOracleUpdated,
  AssetsBonded,
  AssetsUnbonded,
  NewOwner,
  NewPendingOwner,
  Rebase,
  Transfer
} from "../../generated/Treasury/Treasury"
import { ExampleEntity } from "../../generated/schema"

export function handleAddressAddedToWhitelist(
  event: AddressAddedToWhitelist
): void {
  // Entities can be loaded from the store using a string ID; this ID
  // needs to be unique across all entities of the same type
  let entity = ExampleEntity.load(event.transaction.from.toHex())

  // Entities only exist after they have been saved to the store;
  // `null` checks allow to create entities on demand
  if (!entity) {
    entity = new ExampleEntity(event.transaction.from.toHex())

    // Entity fields can be set using simple assignments
    entity.count = BigInt.fromI32(0)
  }

  // BigInt and BigDecimal math are supported
  entity.count = entity.count + BigInt.fromI32(1)

  // Entity fields can be set based on event parameters
  entity.who = event.params.who

  // Entities can be written to the store with `.save()`
  entity.save()

  // Note: If a handler doesn't require existing field values, it is faster
  // _not_ to load the entity from the store. Instead, create it fresh with
  // `new Entity(...)`, set the fields that should be updated and save the
  // entity back to the store. Fields that were not set or unset remain
  // unchanged, allowing for partial updates to be applied.

  // It is also possible to access smart contracts from mappings. For
  // example, the contract that has emitted the event can be connected to
  // with:
  //
  // let contract = Contract.bind(event.address)
  //
  // The following functions can then be called on this contract to access
  // state variables and other data:
  //
  // - contract.DOMAIN_SEPARATOR(...)
  // - contract.EIP712_DOMAIN(...)
  // - contract.EIP712_REVISION(...)
  // - contract.PERMIT_TYPEHASH(...)
  // - contract.allowance(...)
  // - contract.approve(...)
  // - contract.balanceOf(...)
  // - contract.decimals(...)
  // - contract.decreaseAllowance(...)
  // - contract.increaseAllowance(...)
  // - contract.isSupportedForBonding(...)
  // - contract.isSupportedForUnbonding(...)
  // - contract.lastPricePerAsset(...)
  // - contract.name(...)
  // - contract.nonces(...)
  // - contract.oraclePerAsset(...)
  // - contract.owner(...)
  // - contract.pendingOwner(...)
  // - contract.scaledBalanceOf(...)
  // - contract.scaledTotalSupply(...)
  // - contract.supportedAssets(...)
  // - contract.symbol(...)
  // - contract.totalSupply(...)
  // - contract.totalValuation(...)
  // - contract.transfer(...)
  // - contract.transferAll(...)
  // - contract.transferAllFrom(...)
  // - contract.transferFrom(...)
  // - contract.whitelist(...)
}

export function handleAddressRemovedFromWhitelist(
  event: AddressRemovedFromWhitelist
): void {}

export function handleApproval(event: Approval): void {}

export function handleAssetMarkedAsSupported(
  event: AssetMarkedAsSupported
): void {}

export function handleAssetMarkedAsSupportedForBonding(
  event: AssetMarkedAsSupportedForBonding
): void {}

export function handleAssetMarkedAsSupportedForUnbonding(
  event: AssetMarkedAsSupportedForUnbonding
): void {}

export function handleAssetMarkedAsUnsupported(
  event: AssetMarkedAsUnsupported
): void {}

export function handleAssetMarkedAsUnsupportedForBonding(
  event: AssetMarkedAsUnsupportedForBonding
): void {}

export function handleAssetMarkedAsUnsupportedForUnbonding(
  event: AssetMarkedAsUnsupportedForUnbonding
): void {}

export function handleAssetOracleUpdated(event: AssetOracleUpdated): void {}

export function handleAssetsBonded(event: AssetsBonded): void {}

export function handleAssetsUnbonded(event: AssetsUnbonded): void {}

export function handleNewOwner(event: NewOwner): void {}

export function handleNewPendingOwner(event: NewPendingOwner): void {}

export function handleRebase(event: Rebase): void {}

export function handleTransfer(event: Transfer): void {}
