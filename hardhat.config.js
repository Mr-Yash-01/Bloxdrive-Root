require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {},
    sepolia:{
      url:"https://sepolia.infura.io/v3/cdf2a29bbe4a45218e91aaaa2aa87b9a",
      accounts:["5c93769363cbb7a9abbbdfeae15f18fa44d0cfe08e64332d491fc11b10b366f0"]
    }
  }
};
