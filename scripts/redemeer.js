const hre = require("hardhat");

async function main() {
  const LootBoxRedemer = await hre.ethers.getContractFactory(
    "LootBoxRedemer"
  );
  const deployedLootBoxRedemer = await LootBoxRedemer.deploy(
  );

  await deployedLootBoxRedemer.deployed();

  console.log(
    "Deployed LootBoxRedemer Address:",
    deployedLootBoxRedemer.address
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });