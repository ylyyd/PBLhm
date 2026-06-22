import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { Logger } from '../common/Logger';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    Logger.info('onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    Logger.info('onRestore ok {0}', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}