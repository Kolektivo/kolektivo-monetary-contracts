"""
Simulation
"""
from brownie import *

deployer = accounts[0]
owner = accounts[1]

# Contracts
reserve = Reserve2.at("0xdc64a140aa3e981100a9beca4e685f962f0cf6c9")
# TODO: Other contracts.

def switch_owner():
    # Reserve2
    reserve.setPendingOwner(owner.address, {'from': deployer, 'priority_fee': "100 gwei"})
    reserve.acceptOwnership({'from': owner, 'priority_fee': "100 gwei"})
    # TODO: Other contracts

def main():
    switch_owner()
