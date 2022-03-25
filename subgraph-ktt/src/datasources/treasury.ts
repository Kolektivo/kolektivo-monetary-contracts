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
import {
  KTT,
  Asset,
  Oracle,
  Provider,
  AccountBalance,
  AccountApproval
} from "../../generated/schema"
import { parseNewOwner, parseNewPendingOwner } from "../parser/treasury"

export function handleAddressAddedToWhitelist(
  event: AddressAddedToWhitelist
): void {
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

export function handleRebase(event: Rebase): void {
  // Unused
}

export function handleTransfer(event: Transfer): void {}

//------------------------------------------------------------------------------
// solrocket/Ownable

export function handleNewOwner(event: NewOwner): void {
  parseNewOwner(event).save()
}

export function handleNewPendingOwner(event: NewPendingOwner): void {
  parseNewPendingOwner(event).save()
}
