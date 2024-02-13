require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

const {
    PK1,
    MAINNET_URL,
    SEPOLIA_URL,
    ETH_API_KEY,
} = process.env;

module.exports = {
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            accounts: {
                count: 5,
            },
        },
        mainnet: {
            url: MAINNET_URL,
            accounts: [PK1],
        },
        sepolia: {
            url: SEPOLIA_URL,
            accounts: [`0x${PK1}`],
            maxFeePerGas: 8000000000, // Total max fee per gas (base + priority)
            maxPriorityFeePerGas: 3000000000, // Max priority fee per gas
            gasLimit: 3000000, // 3M
        },
    },
    mocha: {
        timeout: 200000,
    },
    etherscan: {
        apiKey: {
            mainnet: ETH_API_KEY,
            sepolia: ETH_API_KEY,
        },
    },
};
