import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'HappyShop';

export class Logger {
  static debug(msg: string, arg?: Object): void {
    let args: Object[] = arg !== undefined ? [arg] : [];
    hilog.debug(DOMAIN, TAG, '%{public}s', Logger.format(msg, args));
  }

  static info(msg: string, arg?: Object): void {
    let args: Object[] = arg !== undefined ? [arg] : [];
    hilog.info(DOMAIN, TAG, '%{public}s', Logger.format(msg, args));
  }

  static warn(msg: string, arg?: Object): void {
    let args: Object[] = arg !== undefined ? [arg] : [];
    hilog.warn(DOMAIN, TAG, '%{public}s', Logger.format(msg, args));
  }

  static error(msg: string, arg?: Object): void {
    let args: Object[] = arg !== undefined ? [arg] : [];
    hilog.error(DOMAIN, TAG, '%{public}s', Logger.format(msg, args));
  }

  private static format(msg: string, args: Object[]): string {
    if (args.length === 0) return msg;
    let result = msg;
    for (let i = 0; i < args.length; i++) {
      let val: string;
      try {
        val = JSON.stringify(args[i]);
      } catch {
        val = String(args[i]);
      }
      let regex = new RegExp('\\{' + i + '\\}', 'g');
      result = result.replace(regex, () => val);
    }
    return result;
  }
}
