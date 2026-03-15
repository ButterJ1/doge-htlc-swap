import * as bitcoin from 'bitcoinjs-lib';
import { ECPairFactory } from 'ecpair';
import * as ecc from 'tiny-secp256k1';
import type { Network } from 'bitcoinjs-lib';
import type { HTLCResult } from './htlc.js';
import { ElectrsAPI, testnetAPI } from './api.js';

const ECPair = ECPairFactory(ecc);

export interface FundParams {
  senderWIF:   string;
  htlc:        HTLCResult;
  amountSats:  number;
  network:     Network;
  api?:        ElectrsAPI;
}

export interface FundResult {
  txid:     string;
  txHex:    string;
  vout:     number;
  amount:   number;
}

const FEE_RATE_SAT_PER_VBYTE = 10;
const DUST_THRESHOLD_SATS = 546;

export async function fundHTLC(params: FundParams): Promise<FundResult> {
  const { senderWIF, htlc, amountSats, network, api = testnetAPI } = params;

  const keyPair  = ECPair.fromWIF(senderWIF, network);
  const senderP2PKH = bitcoin.payments.p2pkh({
    pubkey:  Buffer.from(keyPair.publicKey),
    network,
  });
  const senderAddress = senderP2PKH.address!;

  const utxos = await api.getUTXOs(senderAddress);
  if (utxos.length === 0) {
    throw new Error(
      `No UTXOs found for ${senderAddress}. ` +
      'Get testnet DOGE from https://faucet.doge.toys',
    );
  }
  utxos.sort((a, b) => b.value - a.value);

  const selected: typeof utxos = [];
  let selectedTotal = 0;

  for (const utxo of utxos) {
    selected.push(utxo);
    selectedTotal += utxo.value;

    const estimatedSize = 10 + selected.length * 148 + 32 + 34;
    const estimatedFee  = estimatedSize * FEE_RATE_SAT_PER_VBYTE;

    if (selectedTotal >= amountSats + estimatedFee) {
      break;
    }
  }

  const estimatedSize = 10 + selected.length * 148 + 32 + 34;
  const fee           = estimatedSize * FEE_RATE_SAT_PER_VBYTE;
  const change        = selectedTotal - amountSats - fee;

  if (change < 0) {
    throw new Error(
      `Insufficient funds. Have ${selectedTotal} sat, need ${amountSats + fee} sat ` +
      `(${amountSats} amount + ${fee} fee)`,
    );
  }

  const psbt = new bitcoin.Psbt({ network });

  for (const utxo of selected) {
    const rawTxHex = await api.getTxHex(utxo.txid);
    psbt.addInput({
      hash:            utxo.txid,
      index:           utxo.vout,
      nonWitnessUtxo:  Buffer.from(rawTxHex, 'hex'),
    });
  }

  psbt.addOutput({
    address: htlc.p2shAddress,
    value:   amountSats,
  });

  if (change > DUST_THRESHOLD_SATS) {
    psbt.addOutput({
      address: senderAddress,
      value:   change,
    });
  }

  for (let i = 0; i < selected.length; i++) {
    psbt.signInput(i, keyPair);
  }
  psbt.finalizeAllInputs();

  const tx    = psbt.extractTransaction();
  const txHex = tx.toHex();
  const txid  = await api.broadcast(txHex);

  console.log(`Funded HTLC at ${htlc.p2shAddress}`);
  console.log(`TxID: https://doge-testnet-explorer.qed.me/tx/${txid}`);

  return { txid, txHex, vout: 0, amount: amountSats };
}