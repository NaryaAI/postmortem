const ethers = hre.ethers;

async function main() {
    const Exploit = await ethers.getContractFactory("Exploit");
    const exploit = await Exploit.deploy();
    await exploit.run();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
