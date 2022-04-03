const ethers = hre.ethers;

const WETHAddress = '0xa722c13135930332Eb3d749B2F0906559D2C5b99';
const ComptrollerAddress = '0x26a562B713648d7F3D1E1031DCc0860A4F3Fa340';

async function main() {
	const [me] = await ethers.getSigners();
    console.log('[+] My address: ', me.address);

    const Launcher = await ethers.getContractFactory("Launcher");
    const launcher = await Launcher.deploy();

    await launcher.prepare({
        value: ethers.utils.parseEther("50000")
    });

    await launcher.main();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });