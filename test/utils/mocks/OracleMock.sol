// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOracle {
    function getData() external view returns (uint256, bool);
}

contract OracleMock is IOracle {
    uint256 public data;
    bool public valid;

    function setDataAndValid(uint256 data_, bool valid_) external {
        data = data_;
        valid = valid_;
    }

    function setData(uint256 data_) external {
        data = data_;
    }

    function setValid(bool valid_) external {
        valid = valid_;
    }

    //--------------------------------------------------------------------------
    // IOracle Functions

    function getData() external view returns (uint256, bool) {
        return (data, valid);
    }
}
