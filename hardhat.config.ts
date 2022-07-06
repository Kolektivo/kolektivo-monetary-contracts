import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import { task } from "hardhat/config";

import simulation from "./tasks/simulation";

task("simulation", "Run a simulation").setAction(simulation);
