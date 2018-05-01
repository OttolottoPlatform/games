module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8555,
      network_id: '*', // Match any network id
      gas: 4500000
    },
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
}
