import axios from 'axios';

const BASE = 'https://doge-electrs-testnet-demo.qed.me';

export interface UTXO {
  txid:   string;
  vout:   number;
  value:  number;
  status: { confirmed: boolean; block_height?: number };
}

export async function getUTXOs(address: string): Promise<UTXO[]> {
  const res = await axios.get<UTXO[]>(`${BASE}/address/${address}/utxo`);
  return res.data;
}

export async function getTxHex(txid: string): Promise<string> {
  const res = await axios.get<string>(`${BASE}/tx/${txid}/hex`);
  return res.data;
}

export async function broadcast(txHex: string): Promise<string> {
  try {
    const res = await axios.post<string>(`${BASE}/tx`, txHex, {
      headers: { 'Content-Type': 'text/plain' },
    });
    return res.data;
  } catch (err: any) {
    const detail = err.response?.data ?? err.message;
    throw new Error(`broadcast failed: ${detail}`);
  }
}

export async function getBalance(address: string): Promise<number> {
  const utxos = await getUTXOs(address);
  return utxos.reduce((sum, u) => sum + u.value, 0);
}

export function explorerUrl(txid: string): string {
  return `https://doge-testnet-explorer.qed.me/tx/${txid}`;
}

export interface OutspendStatus {
  spent:  boolean;
  txid?:  string;
  vin?:   number;
  status?: { confirmed: boolean; block_height?: number };
}

export async function getOutspend(
  fundingTxid: string,
  fundingVout: number,
): Promise<OutspendStatus> {
  const res = await axios.get<OutspendStatus>(
    `${BASE}/tx/${fundingTxid}/outspend/${fundingVout}`,
  );
  return res.data;
}

export interface TxVin {
  txid:         string;
  vout:         number;
  scriptsig:    string;
  scriptsig_asm?: string;
  sequence:     number;
}

export interface TxDetails {
  txid:     string;
  version:  number;
  locktime: number;
  vin:      TxVin[];
  vout:     Array<{ value: number; scriptpubkey: string }>;
  status:   { confirmed: boolean; block_height?: number };
}

export async function getTxDetails(txid: string): Promise<TxDetails> {
  const res = await axios.get<TxDetails>(`${BASE}/tx/${txid}`);
  return res.data;
}

export class ElectrsAPI {
  constructor(_baseUrl: string = BASE) {}

  getUTXOs(address: string)               { return getUTXOs(address); }
  getTxHex(txid: string)                  { return getTxHex(txid); }
  broadcast(txHex: string)                { return broadcast(txHex); }
  getBalance(address: string)             { return getBalance(address); }
  getOutspend(txid: string, vout: number) { return getOutspend(txid, vout); }
  getTxDetails(txid: string)              { return getTxDetails(txid); }
}

export const testnetAPI = new ElectrsAPI();