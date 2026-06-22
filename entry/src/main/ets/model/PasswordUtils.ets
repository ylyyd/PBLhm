import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../common/Logger';

function bytesToHex(bytes: Uint8Array): string {
  let hex = '';
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, '0');
  }
  return hex;
}

export class PasswordUtils {
  static async hash(password: string): Promise<string> {
    try {
      let salt = util.generateRandomUUID();
      let md = cryptoFramework.createMd('SHA256');
      let encoder = new util.TextEncoder();
      let input = encoder.encodeInto(password + salt);
      await md.update({ data: input });
      let digest = await md.digest();
      let hexDigest = bytesToHex(digest.data);
      return salt + ':' + hexDigest;
    } catch (err) {
      Logger.error('PasswordUtils.hash failed: {0}', err)
      return ''
    }
  }

  static async verify(password: string, stored: string): Promise<boolean> {
    try {
      let parts = stored.split(':');
      if (parts.length !== 2) {
        return false;
      }
      let salt = parts[0];
      let expectedHex = parts[1];
      let md = cryptoFramework.createMd('SHA256');
      let encoder = new util.TextEncoder();
      let input = encoder.encodeInto(password + salt);
      await md.update({ data: input });
      let digest = await md.digest();
      let actualHex = bytesToHex(digest.data);
      return actualHex === expectedHex;
    } catch (err) {
      Logger.error('PasswordUtils.verify failed: {0}', err)
      return false
    }
  }
}
