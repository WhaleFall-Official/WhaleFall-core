require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-web3");
require("@openzeppelin/test-helpers");
const fs = require('fs');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            chainId: 31337,
            gas: 12000000,
            blockGasLimit: 0x1fffffffffffff,
            allowUnlimitedContractSize: true,
            timeout: 1800000
        }
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
        alice: {
            default: 1,
        },
        bob: {
            default: 2,
        },
        dev: {
            default: 3,
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
            {
                version: '0.6.6',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1,
                    },
                    evmVersion: "istanbul",
                    outputSelection: {
                        "*": {
                            "": [
                                "ast"
                            ],
                            "*": [
                                "evm.bytecode.object",
                                "evm.deployedBytecode.object",
                                "abi",
                                "evm.bytecode.sourceMap",
                                "evm.deployedBytecode.sourceMap",
                                "metadata"
                            ]
                        }
                    },
                }
            },
            {
                version: '0.4.24',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1,
                    },
                    outputSelection: {
                        "*": {
                            "": [
                                "ast"
                            ],
                            "*": [
                                "evm.bytecode.object",
                                "evm.deployedBytecode.object",
                                "abi",
                                "evm.bytecode.sourceMap",
                                "evm.deployedBytecode.sourceMap",
                                "metadata"
                            ]
                        }
                    },
                }
            },
            {
                version: '0.5.16',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1,
                    },
                    evmVersion: "istanbul",
                    outputSelection: {
                        "*": {
                            "": [
                                "ast"
                            ],
                            "*": [
                                "evm.bytecode.object",
                                "evm.deployedBytecode.object",
                                "abi",
                                "evm.bytecode.sourceMap",
                                "evm.deployedBytecode.sourceMap",
                                "metadata"
                            ]
                        }
                    },
                }
            },
        ],
    },
};

