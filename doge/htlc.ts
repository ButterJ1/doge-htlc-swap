import * as bitcoin from 'bitcoinjs-lib';
import type { Network } from 'bitcoinjs-lib';
import { crypto } from 'bitcoinjs-lib';
import { randomBytes } from 'crypto';

export interface HTLCParams {
  hashlock:        Buffer;
  recipientPubkey: Buffer;
  refundPubkey:    Buffer;
  locktime:        number;
  network:         Network;
}

export interface HTLCResult {
  redeemScript: Buffer;
  p2shAddress:  string;
  scriptPubKey: string;
}

export function buildHTLC(params: HTLCParams): HTLCResult {
  const { hashlock, recipientPubkey, refundPubkey, locktime, network } = params;

  if (hashlock.length !== 32) {
    throw new Error(`hashlock must be 32 bytes, got ${hashlock.length}`);
  }
  if (recipientPubkey.length !== 33) {
    throw new Error('recipientPubkey must be a compressed 33-byte public key');
  }
  if (refundPubkey.length !== 33) {
    throw new Error('refundPubkey must be a compressed 33-byte public key');
  }
  if (locktime < 500_000_000) {
    throw new Error(
      `locktime ${locktime} looks like a block height. ` +
      'Use a Unix timestamp (>= 500_000_000) so Dogecoin treats it as time.',
    );
  }

  const recipientPKH = crypto.hash160(recipientPubkey);
  const refundPKH    = crypto.hash160(refundPubkey);

  const locktimeBytes = bitcoin.script.number.encode(locktime);

  const redeemScript = bitcoin.script.compile([
    bitcoin.opcodes.OP_IF,

      bitcoin.opcodes.OP_SIZE,
      bitcoin.script.number.encode(32),
      bitcoin.opcodes.OP_EQUALVERIFY,

      bitcoin.opcodes.OP_SHA256,
      hashlock,                           
      bitcoin.opcodes.OP_EQUALVERIFY,

      bitcoin.opcodes.OP_DUP,
      bitcoin.opcodes.OP_HASH160,
      recipientPKH,
      bitcoin.opcodes.OP_EQUALVERIFY,
      bitcoin.opcodes.OP_CHECKSIG,

    bitcoin.opcodes.OP_ELSE,

      locktimeBytes,                      
      bitcoin.opcodes.OP_CHECKLOCKTIMEVERIFY,
      bitcoin.opcodes.OP_DROP,

      bitcoin.opcodes.OP_DUP,
      bitcoin.opcodes.OP_HASH160,
      refundPKH,                          
      bitcoin.opcodes.OP_EQUALVERIFY,
      bitcoin.opcodes.OP_CHECKSIG,

    bitcoin.opcodes.OP_ENDIF,
  ]);

  const p2sh = bitcoin.payments.p2sh({ redeem: { output: redeemScript }, network });

  if (!p2sh.address) throw new Error('Failed to derive P2SH address');

  return {
    redeemScript,
    p2shAddress:  p2sh.address,
    scriptPubKey: p2sh.output!.toString('hex'),
  };
}

export function computeHashlock(secret: Buffer): Buffer {
  if (secret.length !== 32) {
    throw new Error(`secret must be 32 bytes, got ${secret.length}`);
  }
  return crypto.sha256(secret);
}

export function generateSecret(): Buffer {
  return randomBytes(32);
}