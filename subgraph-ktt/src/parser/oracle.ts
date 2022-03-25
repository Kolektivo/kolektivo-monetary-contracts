import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { NewOwner, NewPendingOwner } from "../../generated/Oracle/Oracle";
import { Oracle } from "../../generated/schema"

//------------------------------------------------------------------------------
// Initialization

function initOracle(id: string): Oracle {
  let oracle = new Oracle(id)

  // TODO: Init oracle

  return oracle
}

//------------------------------------------------------------------------------
// solrocket/Ownable

export function parseNewOwner(event: NewOwner): Oracle {
  let id = event.address.toHexString()
  let oracle = Oracle.load(id)
  if (oracle == null) {
    // TODO: Not sure if error should/can be thrown.
    // However, this code is unreachable. The object must exist already.
    throw new Error()
  }

  // Update Metadata
  oracle.block = event.block.number
  oracle.timestamp = event.block.timestamp
  oracle.transaction = event.transaction.hash

  // Update owner AND pending owner
  oracle.owner = event.params.newOwner
  oracle.pendingOwner = Bytes.empty()

  return oracle
}

export function parseNewPendingOwner(event: NewPendingOwner): Oracle {
  let id = event.address.toHexString()
  let oracle = Oracle.load(id)
  if (oracle == null) {
    // TODO: Not sure if error should/can be thrown.
    // However, this code is unreachable. The object must exist already.
    throw new Error()
  }

  // Update Metadata
  oracle.block = event.block.number
  oracle.timestamp = event.block.timestamp
  oracle.transaction = event.transaction.hash

  // Update pending owner
  oracle.pendingOwner = event.params.newPendingOwner

  return oracle
}
