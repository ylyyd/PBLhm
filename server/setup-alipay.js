const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function prompt(q) {
  return new Promise(resolve => rl.question(q, resolve));
}

function generateRSAKeyPair() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
  });

  const privateKeyFormatted = privateKey
    .replace('-----BEGIN PRIVATE KEY-----', '-----BEGIN RSA PRIVATE KEY-----')
    .replace('-----END PRIVATE KEY-----', '-----END RSA PRIVATE KEY-----');

  return { privateKey: privateKeyFormatted.trim(), publicKey: publicKey.trim() };
}

async function main() {
  console.log('========================================');
  console.log('  支付宝沙箱环境配置工具');
  console.log('========================================\n');

  console.log('【第一步】请前往支付宝开放平台获取沙箱应用信息：');
  console.log('  1. 打开 https://open.alipay.com 并登录');
  console.log('  2. 进入"沙箱环境" > "沙箱应用"');
  console.log('  3. 创建或查看沙箱应用，记录 APP_ID\n');

  const appId = await prompt('请输入你的沙箱应用 APP_ID: ');

  if (!appId || appId.length < 10) {
    console.error('\n错误: APP_ID 无效，请检查后重试');
    rl.close();
    return;
  }

  console.log('\n【第二步】正在生成 RSA 密钥对...\n');
  const { privateKey, publicKey: appPublicKey } = generateRSAKeyPair();

  console.log('【第三步】请将以下"应用公钥"复制到支付宝沙箱应用配置中：');
  console.log('  1. 在支付宝沙箱应用页面，找到"接口加签方式"');
  console.log('  2. 选择"公钥模式"，将下方公钥粘贴保存');
  console.log('  3. 保存后，支付宝会生成一个"支付宝公钥"');
  console.log('  4. 请将支付宝公钥复制下来\n');

  console.log('--- 应用公钥 (复制到支付宝沙箱) ---');
  console.log(appPublicKey);
  console.log('-----------------------------------------\n');

  const alipayPublicKey = await prompt('请粘贴支付宝公钥（支付宝平台生成的，不是刚刚生成的）: ');
  if (!alipayPublicKey || alipayPublicKey.length < 50) {
    console.error('\n错误: 支付宝公钥无效');
    rl.close();
    return;
  }

  const envPath = path.join(__dirname, '.env');
  let envContent = fs.readFileSync(envPath, 'utf-8');

  const newConfigLines = [
    `# 支付宝沙箱配置（由 setup-alipay.js 生成）`,
    `ALIPAY_APP_ID=${appId}`,
    `ALIPAY_PRIVATE_KEY=${privateKey.replace(/\n/g, '\\n')}`,
    `ALIPAY_PUBLIC_KEY=${alipayPublicKey.replace(/\n/g, '\\n')}`,
    `ALIPAY_GATEWAY=https://openapi-sandbox.dl.alipaydev.com/gateway.do`,
    `NOTIFY_HOST=http://10.0.2.2:3000`,
  ];

  let newSection = '\n' + newConfigLines.join('\n') + '\n';
  envContent = envContent.replace(/# 支付宝沙箱配置[\s\S]*?(?=\n\S|\n*$)/, newSection);
  if (!envContent.includes('ALIPAY_APP_ID=')) {
    envContent += newSection;
  }

  fs.writeFileSync(envPath, envContent);
  console.log('\n配置已写入 .env 文件！\n');

  console.log('========================================');
  console.log('  配置完成！后续步骤：');
  console.log('========================================');
  console.log('  1. 确保支付宝沙箱应用已配置好应用公钥');
  console.log('  2. 重启服务器使新配置生效');
  console.log('  3. 使用沙箱买家账号进行测试支付');
  console.log('  4. 沙箱买家账号可在支付宝开放平台查看\n');

  rl.close();
}

main().catch(err => {
  console.error('错误:', err);
  rl.close();
  process.exit(1);
});
