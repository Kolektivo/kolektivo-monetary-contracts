const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');
const { ethers } = require("ethers");
const ORACLE_ABI = [{"inputs":[{"internalType":"uint256","name":"reportExpirationTime_","type":"uint256"},{"internalType":"uint256","name":"reportDelay_","type":"uint256"},{"internalType":"uint256","name":"minimumProviders_","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"InvalidPendingOwner","type":"error"},{"inputs":[],"name":"OnlyCallableByOwner","type":"error"},{"inputs":[],"name":"OnlyCallableByPendingOwner","type":"error"},{"inputs":[{"internalType":"address","name":"invalidProvider","type":"address"}],"name":"Oracle__InvalidProvider","type":"error"},{"inputs":[],"name":"Oracle__NewReportTooSoonAfterPastReport","type":"error"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"oldMinimumProviders","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"newMinimumProviders","type":"uint256"}],"name":"MinimumProvidersChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"previousOwner","type":"address"},{"indexed":true,"internalType":"address","name":"newOwner","type":"address"}],"name":"NewOwner","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"previousPendingOwner","type":"address"},{"indexed":true,"internalType":"address","name":"newPendingOwner","type":"address"}],"name":"NewPendingOwner","type":"event"},{"anonymous":false,"inputs":[],"name":"OracleMarkedAsInvalid","type":"event"},{"anonymous":false,"inputs":[],"name":"OracleMarkedAsValid","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"provider","type":"address"}],"name":"ProviderAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"provider","type":"address"}],"name":"ProviderRemoved","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"provider","type":"address"},{"indexed":false,"internalType":"uint256","name":"payload","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"timestamp","type":"uint256"}],"name":"ProviderReportPushed","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"purger","type":"address"},{"indexed":true,"internalType":"address","name":"provider","type":"address"}],"name":"ProviderReportsPurged","type":"event"},{"inputs":[],"name":"acceptOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"provider","type":"address"}],"name":"addProvider","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"getData","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"isValid","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"minimumProviders","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"pendingOwner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"uint256","name":"","type":"uint256"}],"name":"providerReports","outputs":[{"internalType":"uint256","name":"timestamp","type":"uint256"},{"internalType":"uint256","name":"payload","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"providers","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"providersSize","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"purgeReports","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"provider","type":"address"}],"name":"purgeReportsFrom","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"payload","type":"uint256"}],"name":"pushReport","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"provider","type":"address"}],"name":"removeProvider","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"reportDelay","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"reportExpirationTime","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bool","name":"isValid_","type":"bool"}],"name":"setIsValid","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"minimumProviders_","type":"uint256"}],"name":"setMinimumProviders","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"pendingOwner_","type":"address"}],"name":"setPendingOwner","outputs":[],"stateMutability":"nonpayable","type":"function"}];
const REBASE_ABI = [{"inputs":[],"name":"rebase","outputs":[],"stateMutability":"nonpayable","type":"function"}];

exports.main = async function(signer) {   
const oracleAddresses = ["0x86baecC60c5c1CCe2c73f2Ff42588E6EBce18707", "0x377898651e03A9c1562F739a40bda70a18715cdD", "0xBb6fB0e7510744c8234dFA78D5088fF9AD550A88", "0xe898a9e58105414eA4066C8b6a15F0D9F2f4A5dc", "0xCf79C474994a7441E908C73Dd6cc3869dCfeD6cF", "0x1011AdbFe0E41c610FF633DC6EfA6D67A2CfA978"];
  await updateOracles(oracleAddresses, signer);
  const treasuryRebaseContract = new ethers.Contract("0x8Ddb762Fd4D56bd0D839732cC0c4538BCB5339cA", REBASE_ABI, signer);
  await treasuryRebaseContract.rebase();
  return 0;
}
async function updateOracles(oracles, signer) {
  for (const oracle of oracles) {
    const oracleContract = new ethers.Contract(oracle, ORACLE_ABI, signer);
    const returnValue = await oracleContract.getData();
    if(returnValue[1] && Math.random() < 0.75) {
      console.log("Processing: ", oracle);
      let nextPrice = getNextPrice(returnValue[0]);
      let formattedPrice = ethers.utils.parseEther(nextPrice.toString());
      await oracleContract.pushReport(formattedPrice);
    }
}

}

function getNextPrice(lastPrice) {
  let increase = Math.random() < 0.5;
  let price = parseFloat(ethers.utils.formatEther(lastPrice));
  console.log("Old Price: ", price)
  let change = 0.05;
   if (price <= 2) {
    change = 0.1
  }

  if(Math.random() < 0.15) {
    change = change * 4;
  }
  
  if(increase) {
    price = getRandomFloat(price, price*(1+change), 2);
  } else {
    price = getRandomFloat(price*(1-change), price, 2);
  }
  console.log("New Price: ", price)
  return price;
}

function getRandomFloat(min, max, decimals) {
  const str = (Math.random() * (max - min) + min).toFixed(decimals);

  return parseFloat(str);
}

exports.handler = async function(credentials) {
  const provider = new DefenderRelayProvider(credentials);
  const signer = new DefenderRelaySigner(credentials, provider, { speed: 'fast' });
  return exports.main(signer);
}