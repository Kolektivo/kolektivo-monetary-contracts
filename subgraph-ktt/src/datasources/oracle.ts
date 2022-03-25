import { BigInt } from "@graphprotocol/graph-ts"
import {
  Oracle,
  MinimumProvidersChanged,
  NewOwner,
  NewPendingOwner,
  OracleMarkedAsInvalid,
  OracleMarkedAsValid,
  ProviderAdded,
  ProviderRemoved,
  ProviderReportPushed,
  ProviderReportsPurged,
  ReportTimestampOutOfRange
} from "../../generated/Oracle/Oracle"
import { parseNewOwner } from "../parser/oracle"
import { parseNewPendingOwner } from "../parser/treasury"

export function handleMinimumProvidersChanged(
  event: MinimumProvidersChanged
): void {}

export function handleOracleMarkedAsInvalid(
  event: OracleMarkedAsInvalid
): void {}

export function handleOracleMarkedAsValid(event: OracleMarkedAsValid): void {}

export function handleProviderAdded(event: ProviderAdded): void {}

export function handleProviderRemoved(event: ProviderRemoved): void {}

export function handleProviderReportPushed(event: ProviderReportPushed): void {}

export function handleProviderReportsPurged(
  event: ProviderReportsPurged
): void {}

export function handleReportTimestampOutOfRange(
  event: ReportTimestampOutOfRange
): void {}

//------------------------------------------------------------------------------
// solrocket/Ownable

export function handleNewOwner(event: NewOwner): void {
  parseNewOwner(event).save()
}

export function handleNewPendingOwner(event: NewPendingOwner): void {
  parseNewPendingOwner(event).save()
}
