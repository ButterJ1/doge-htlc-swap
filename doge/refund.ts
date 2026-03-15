import * as bitcoin from 'bitcoinjs-lib';
import { ECPairFactory } from 'ecpair';
import * as ecc from 'tiny-secp256k1';
import type { Network } from 'bitcoinjs-lib';

import type { HTLCResult } from './htlc.js';
import { ElectrsAPI, testnetAPI } from './api.js';

const ECPair = ECPairFactory(ecc);

export interface RefundParams {
  refundWIF:     string;
  htlc:          HTLCResult;
  locktime:      number;
  toAddress:     string;
  fundingTxid:   string;
  fundingVout:   number;
  network:       Network;
  api?:          ElectrsAPI;
}

const FEE_RATE_SAT_PER_VBYTE = 10;

export interface RefundResult {
  txid:   string;
  txHex:  string;
}

export async function refundHTLC(params: RefundParams): Promise<RefundResult> {
  const {
    refundWIF, htlc, locktime, toAddress,
    fundingTxid, fundingVout, network, api = testnetAPI,
  } = params;

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (nowSeconds < locktime) {
    const remainingMinutes = Math.ceil((locktime - nowSeconds) / 60);
    throw new Error(
      `Timelock has not expired yet. ` +
      `${remainingMinutes} minutes remaining until ${new Date(locktime * 1000).toISOString()}`,
    );
  }

  const keyPair = ECPair.fromWIF(refundWIF, network);

  const fundingTxHex = await api.getTxHex(fundingTxid);
  const fundingTx    = bitcoin.Transaction.fromHex(fundingTxHex);
  const outputValue  = fundingTx.outs[fundingVout].value;
  const estimatedSize = 312;
  const fee           = estimatedSize * FEE_RATE_SAT_PER_VBYTE;
  const outputAmount  = outputValue - fee;

  if (outputAmount <= 0) {
    throw new Error(`UTXO value ${outputValue} sat is less than fee ${fee} sat`);
  }

  const psbt = new bitcoin.Psbt({ network });

  psbt.setLocktime(locktime);

  psbt.addInput({
    hash:            fundingTxid,
    index:           fundingVout,
    sequence:        0xfffffffe,

    nonWitnessUtxo:  Buffer.from(fundingTxHex, 'hex'),
    redeemScript:    htlc.redeemScript,
  });

  psbt.addOutput({ address: toAddress, value: outputAmount });

  psbt.signInput(0, keyPair);

  type InputWithPartialSig = { partialSig?: Array<{ pubkey: Buffer; signature: Buffer }> };
  psbt.finalizeInput(0, (_inputIndex: number, input: InputWithPartialSig) => {
    const sig = input.partialSig![0].signature;
    const scriptSig = bitcoin.script.compile([
      sig,
      bitcoin.opcodes.OP_FALSE,
    ]);

    return {
      finalScriptSig:     scriptSig,
      finalScriptWitness: undefined,
    };
  });

  const tx    = psbt.extractTransaction();
  const txHex = tx.toHex();
  const txid  = await api.broadcast(txHex);

  console.log(`Refunded HTLC — DOGE returned to ${toAddress}`);
  console.log(`TxID: https://doge-testnet-explorer.qed.me/tx/${txid}`);

  return { txid, txHex };
}