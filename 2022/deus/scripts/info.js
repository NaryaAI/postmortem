const ethers = hre.ethers;
const deiLenderAddress = '0xeC1Fc57249CEa005fC16b2980470504806fcA20d';

function toHexString(byteArray) {
    return Array
        .from(
            byteArray,
            function(byte) {
                return ('0' + (byte & 0xFF).toString(16)).slice(-2);
            })
        .join('')
}

async function main() {
    const DeiLenderSolidex =
        await ethers.getContractFactory('DeiLenderSolidex');
    let deiLender = DeiLenderSolidex.attach(deiLenderAddress);

    // 0x5CEB2b0308a7f21CcC0915DB29fa5095bEAdb48D
    const Oracle = await ethers.getContractFactory('Oracle');
    const oracleAddress = await deiLender.oracle();
    console.log('[+] Oracle: ' + oracleAddress);
    let oracle = Oracle.attach(oracleAddress);

    // 0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3
    const deiAddress = await oracle.dei();
    console.log('[+] Oracle DEI address: ' + deiAddress);

    // 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75
    const USDCAddress = await oracle.usdc();
    console.log('[+] Oracle USDC address: ' + USDCAddress);

    // 0x5821573d8F04947952e76d94f3ABC6d7b43bF8d0
    const oraclePairAddress = await oracle.pair();
    console.log('[+] Oracle pair (swap): ' + oraclePairAddress);
    let baseV1Pair =
        await ethers.getContractAt('IBaseV1Pair', oraclePairAddress);

    // 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75 (USDC)
    const pairToken0 = await baseV1Pair.token0();
    console.log('[+] Oracle pair token 0: ', pairToken0);

    // 0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3 (DEI)
    const pairToken1 = await baseV1Pair.token1();
    console.log('[+] Oracle pair token 1: ', pairToken1);

    // 0xD82001B651F7fb67Db99C679133F384244e20E79
    const collateralAddress = await deiLender.collateral();
    console.log('[+] Collateral address: ', collateralAddress);

    // 0x26E1A0d851CF28E697870e1b7F053B605C8b060F
    const lpDepositorAddress = await deiLender.lpDepositor();
    console.log('[+] lpDepositor address: ', lpDepositorAddress);
}

main().then(() => process.exit(0)).catch((error) => {
    console.error(error);
    process.exit(1);
});
