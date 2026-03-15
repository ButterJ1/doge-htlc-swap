import type { Network } from 'bitcoinjs-lib';

export const dogecoinMainnet: Network = {
  messagePrefix: '\x19Dogecoin Signed Message:\n',
  bech32: 'doge',
  bip32: {
    public:  0x02facafd,
    private: 0x02fac398,
  },
  pubKeyHash: 0x1e,
  scriptHash: 0x16,
  wif: 0x9e,
};

export const dogecoinTestnet: Network = {
  messagePrefix: '\x19Dogecoin Signed Message:\n',
  bech32: 'tdoge',
  bip32: {
    public:  0x043587cf,
    private: 0x04358394,
  },
  pubKeyHash: 0x71,
  scriptHash: 0xc4,
  wif: 0xf1,
};

export function getNetwork(name: 'mainnet' | 'testnet'): Network {
  return name === 'mainnet' ? dogecoinMainnet : dogecoinTestnet;
}