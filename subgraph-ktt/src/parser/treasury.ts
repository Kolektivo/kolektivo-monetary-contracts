import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { NewOwner, NewPendingOwner } from "../../generated/Oracle/Oracle";
import { KTT } from "../../generated/schema"

//------------------------------------------------------------------------------
// Initialization

function initKTT(id: string): KTT {
  let ktt = new KTT(id)

  // TODO: Init ktt

  return ktt
}

//------------------------------------------------------------------------------
// solrocket/Ownable

export function parseNewOwner(event: NewOwner): KTT {
  let id = event.address.toHexString()
  let ktt = KTT.load(id)
  if (ktt == null) {
    // TODO: Not sure if error should/can be thrown.
    // However, this code is unreachable. The object must exist already.
    throw new Error()
  }

  // Update Metadata
  ktt.block = event.block.number
  ktt.timestamp = event.block.timestamp
  ktt.transaction = event.transaction.hash

  // Update owner AND pending owner
  ktt.owner = event.params.newOwner
  ktt.pendingOwner = Bytes.empty()

  return ktt
}

export function parseNewPendingOwner(event: NewPendingOwner): KTT {
  let id = event.address.toHexString()
  let ktt = KTT.load(id)
  if (ktt == null) {
    // TODO: Not sure if error should/can be thrown.
    // However, this code is unreachable. The object must exist already.
    throw new Error()
  }

  // Update Metadata
  ktt.block = event.block.number
  ktt.timestamp = event.block.timestamp
  ktt.transaction = event.transaction.hash

  // Update pending owner
  ktt.pendingOwner = event.params.newPendingOwner

  return ktt
}
