const hre = require("hardhat");

async function main() {
  const LootBox = await hre.ethers.getContractFactory(
    "LootBox"
  );
  const deployedLootBox = await LootBox.deploy(
  );

  await deployedLootBox.deployed();

  console.log(
    "Deployed LootBox Address:",
    deployedLootBox.address
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });