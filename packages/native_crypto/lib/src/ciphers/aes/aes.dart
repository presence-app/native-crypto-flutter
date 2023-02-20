// Author: Hugo Pointcheval
// Email: git@pcl.ovh
// -----
// File: aes.dart
// Created Date: 16/12/2021 16:28:00
// Last Modified: 27/05/2022 12:13:28
// -----
// Copyright (c) 2022

import 'dart:typed_data';

import 'package:native_crypto/src/ciphers/aes/aes_key_size.dart';
import 'package:native_crypto/src/ciphers/aes/aes_mode.dart';
import 'package:native_crypto/src/ciphers/aes/aes_padding.dart';
import 'package:native_crypto/src/core/cipher_text.dart';
import 'package:native_crypto/src/core/cipher_text_wrapper.dart';
import 'package:native_crypto/src/interfaces/cipher.dart';
import 'package:native_crypto/src/keys/secret_key.dart';
import 'package:native_crypto/src/platform.dart';
import 'package:native_crypto/src/utils/cipher_algorithm.dart';
import 'package:native_crypto/src/utils/extensions.dart';
import 'package:native_crypto_platform_interface/native_crypto_platform_interface.dart';

export 'aes_key_size.dart';
export 'aes_mode.dart';
export 'aes_padding.dart';

/// An AES cipher.
///
/// [AES] is a [Cipher] that can be used to encrypt or decrypt data.
class AES implements Cipher {
  final SecretKey _key;
  final AESMode mode;
  final AESPadding padding;

  @override
  CipherAlgorithm get algorithm => CipherAlgorithm.aes;

  AES(SecretKey key, [this.mode = AESMode.gcm, this.padding = AESPadding.none])
      : _key = key {
    if (!AESKeySize.supportedSizes.contains(key.bitLength)) {
      throw NativeCryptoException(
        message: 'Invalid key size! '
            'Expected: ${AESKeySize.supportedSizes.join(', ')} bits',
      //  code: NativeCryptoExceptionCode.invalid_key_length.code,
      );
    }

    if (!mode.supportedPaddings.contains(padding)) {
      throw NativeCryptoException(
        message: 'Invalid padding! '
            'Expected: ${mode.supportedPaddings.join(', ')}',
     //   code: NativeCryptoExceptionCode.invalid_padding.code,
      );
    }
  }

  Future<Uint8List> _decrypt(
    CipherText cipherText, {
    int chunkCount = 0,
  }) async {
    Uint8List? decrypted;

    try {
      decrypted = await platform.decrypt(
        cipherText.bytes,
        _key.bytes,
        algorithm.name,
      );
    } catch (e, s) {
      throw NativeCryptoException(
        message: '$e',
      //  code: NativeCryptoExceptionCode.platform_throws.code,
        stackTrace: s,
      );
    }

    if (decrypted.isNull) {
      throw NativeCryptoException(
        message: 'Platform returned null when decrypting chunk #$chunkCount',
      //  code: NativeCryptoExceptionCode.platform_returned_null.code,
      );
    } else if (decrypted!.isEmpty) {
      throw NativeCryptoException(
        message: 'Platform returned no data when decrypting chunk #$chunkCount',
     //   code: NativeCryptoExceptionCode.platform_returned_empty_data.code,
      );
    } else {
      return decrypted;
    }
  }

  Future<CipherText> _encrypt(Uint8List data, {int chunkCount = 0}) async {
    Uint8List? encrypted;

    try {
      encrypted = await platform.encrypt(
        data,
        _key.bytes,
        algorithm.name,
      );
    } catch (e, s) {
      throw NativeCryptoException(
        message: '$e on chunk #$chunkCount',
     //   code: NativeCryptoExceptionCode.platform_throws.code,
        stackTrace: s,
      );
    }

    if (encrypted.isNull) {
      throw NativeCryptoException(
        message: 'Platform returned null when encrypting chunk #$chunkCount',
     //   code: NativeCryptoExceptionCode.platform_returned_null.code,
      );
    } else if (encrypted!.isEmpty) {
      throw NativeCryptoException(
        message: 'Platform returned no data when encrypting chunk #$chunkCount',
     //  code: NativeCryptoExceptionCode.platform_returned_empty_data.code,
      );
    } else {
      try {
        return CipherText.fromBytes(
          encrypted,
          ivLength: 12,
          messageLength: encrypted.length - 28,
          tagLength: 16,
          cipherAlgorithm: CipherAlgorithm.aes,
        );
      } on NativeCryptoException catch (e, s) {
        throw NativeCryptoException(
          message: '${e.message} on chunk #$chunkCount',
          code: e.code,
          stackTrace: s,
        );
      }
    }
  }

  @override
  Future<Uint8List> decrypt(CipherTextWrapper cipherText) async {
    final BytesBuilder decryptedData = BytesBuilder(copy: false);

    if (cipherText.isList) {
      int chunkCount = 0;
      for (final CipherText chunk in cipherText.list) {
        decryptedData.add(await _decrypt(chunk, chunkCount: chunkCount++));
      }
    } else {
      decryptedData.add(await _decrypt(cipherText.single));
    }

    return decryptedData.toBytes();
  }

  @override
  Future<CipherTextWrapper> encrypt(Uint8List data) async {
    if (data.isEmpty) {
      return CipherTextWrapper.empty();
    }
    CipherTextWrapper cipherTextWrapper;
    Uint8List dataToEncrypt;
    final int chunkNb = (data.length / Cipher.bytesCountPerChunk).ceil();

    if (chunkNb > 1) {
      cipherTextWrapper = CipherTextWrapper.empty();
      for (var i = 0; i < chunkNb; i++) {
        dataToEncrypt = i < (chunkNb - 1)
            ? data.sublist(
                i * Cipher.bytesCountPerChunk,
                (i + 1) * Cipher.bytesCountPerChunk,
              )
            : data.sublist(i * Cipher.bytesCountPerChunk);
        cipherTextWrapper.add(await _encrypt(dataToEncrypt, chunkCount: i));
      }
    } else {
      cipherTextWrapper = CipherTextWrapper.single(await _encrypt(data));
    }

    return cipherTextWrapper;
  }
}
