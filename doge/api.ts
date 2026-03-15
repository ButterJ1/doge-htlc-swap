import axios from 'axios';
export const TESTNET_API = 'https://doge-electrs-testnet-demo.qed.me';
export const MAINNET_API = 'https://dogechain.info/api/v1';

export interface UTXO {
  txid:   string;
  vout:   number;
  value:  number;
  status: {
    confirmed:    boolean;
    block_height: number;
    block_hash:   string;
    block_time:   number;
  };
}

export interface AddressInfo {
  address:              string;
  chain_stats: {
    funded_txo_sum:  number;
    spent_txo_sum:   number;
    tx_count:        number;
  };
  mempool_stats: {
    funded_txo_sum:  number;
    spent_txo_sum:   number;
    tx_count:        number;
  };
}

export class ElectrsAPI {
  private base: string;

  constructor(baseUrl: string = TESTNET_API) {
    this.base = baseUrl.replace(/\/$/, '');
  }

  async getUTXOs(address: string): Promise<UTXO[]> {
    const url = `${this.base}/address/${address}/utxo`;
    const res = await axios.get<UTXO[]>(url);
    return res.data;
  }

  async getAddressInfo(address: string): Promise<AddressInfo> {
    const url = `${this.base}/address/${address}`;
    const res = await axios.get<AddressInfo>(url);
    return res.data;
  }

  async getTxHex(txid: string): Promise<string> {
    const url = `${this.base}/tx/${txid}/hex`;
    const res = await axios.get<string>(url);
    return res.data;
  }

  async broadcast(txHex: string): Promise<string> {
    const url = `${this.base}/tx`;
    try {
      const res = await axios.post<string>(url, txHex, {
        headers: { 'Content-Type': 'text/plain' },
      });
      return res.data;
    } catch (err: unknown) {
      if (axios.isAxiosError(err) && err.response) {
        throw new Error(
          `Broadcast failed [${err.response.status}]: ${JSON.stringify(err.response.data)}`,
        );
      }
      throw err;
    }
  }

  async getBalance(address: string): Promise<number> {
    const utxos = await this.getUTXOs(address);
    return utxos.reduce((sum, u) => sum + u.value, 0);
  }
}

export const testnetAPI = new ElectrsAPI(TESTNET_API);