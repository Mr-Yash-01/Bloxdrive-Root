const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {
  // Ensure "Lock" matches the contract's name in your Solidity code
  const lock = m.contract("Smooth",[], {});  
  return { lock };
});
