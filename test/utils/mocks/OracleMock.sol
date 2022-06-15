// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

interface IOracle {
    function getData() external view returns (uint, bool);
}

contract OracleMock is IOracle {
    uint public data;
    bool public valid;

    function setDataAndValid(uint data_, bool valid_) external {
        data = data_;
        valid = valid_;
    }

    function setData(uint data_) external {
        data = data_;
    }

    function setValid(bool valid_) external {
        valid = valid_;
    }

    //--------------------------------------------------------------------------
    // IOracle Functions

    function getData() external view returns (uint, bool) {
        return (data, valid);
    }

}
