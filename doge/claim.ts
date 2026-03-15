import * as bitcoin from 'bitcoinjs-lib';
import { ECPairFactory } from 'ecpair';
import * as ecc from 'tiny-secp256k1';
import type { Network } from 'bitcoinjs-lib';

import type { HTLCResult } from './htlc.js';
import { ElectrsAPI, testnetAPI } from './api.js';

const ECPair = ECPairFactory(ecc);

export interface ClaimParams {
  recipientWIF:  string;
  secret:        Buffer;
  htlc:          HTLCResult;
  toAddress:     string;
  fundingTxid:   string;
  fundingVout:   number;
  network:       Network;
  api?:          ElectrsAPI;
}

const FEE_RATE_SAT_PER_VBYTE = 10;

export interface ClaimResult {
  txid:   string;
  txHex:  string;
}

export async function claimHTLC(params: ClaimParams): Promise<ClaimResult> {
  const {
    recipientWIF, secret, htlc, toAddress,
    fundingTxid, fundingVout, network, api = testnetAPI,
  } = params;

  if (secret.length !== 32) {
    throw new Error(`secret must be 32 bytes, got ${secret.length}`);
  }

  const keyPair = ECPair.fromWIF(recipientWIF, network);
  const fundingTxHex = await api.getTxHex(fundingTxid);
  const fundingTx    = bitcoin.Transaction.fromHex(fundingTxHex);
  const outputValue  = fundingTx.outs[fundingVout].value;
  const estimatedSize = 344;
  const fee           = estimatedSize * FEE_RATE_SAT_PER_VBYTE;
  const outputAmount  = outputValue - fee;

  if (outputAmount <= 0) {
    throw new Error(
      `UTXO value ${outputValue} sat is less than the fee ${fee} sat`,
    );
  }

  const psbt = new bitcoin.Psbt({ network });

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
      secret,
      bitcoin.opcodes.OP_TRUE,
    ]);

    return {
      finalScriptSig:     scriptSig,
      finalScriptWitness: undefined,
    };
  });

  const tx    = psbt.extractTransaction();
  const txHex = tx.toHex();
  const txid  = await api.broadcast(txHex);

  console.log(`Claimed HTLC — secret is now public on Dogecoin chain`);
  console.log(`TxID: https://doge-testnet-explorer.qed.me/tx/${txid}`);
  console.log(`Secret (hex): ${secret.toString('hex')}`);

  return { txid, txHex };
}