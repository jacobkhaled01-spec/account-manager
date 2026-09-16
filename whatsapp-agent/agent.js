/**
 * agent.js
 * إيجنت واتساب الذكي المجاني 100% لنظام القسام
 * يعمل في الخلفية عبر Baileys بدون أي اشتراكات أو تكلفة
 */

const fs = require('fs');
const path = require('path');
const http = require('http');

// تحميل المحركات البرمجية المستقلة
const WhatsAppParser = require('../modules/parsers/WhatsAppParser.js');
const FinancialEngine = require('../modules/FinancialEngine.js');
const WhatsAppReportFormatter = require('./formatter.js');

// تحميل الإعدادات
const CONFIG_PATH = path.join(__dirname, 'config.json');
let config = {};
try {
  config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
} catch (e) {
  config = {
    sourceGroupName: 'مجموعة العملاء (أ)',
    targetGroupName: 'مجموعة الصرافين (ب)',
    exchangeRate: 48,
    defaultCurrency: 'ريال سعودي',
    autoReplyAcknowledge: true,
    bridgeServerPort: 4124
  };
}

// مسار حفظ البيانات
const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}
const REMITTANCES_DB_PATH = path.join(DATA_DIR, 'remittances.json');

function saveRemittancesBatch(batch) {
  let list = [];
  try {
    if (fs.existsSync(REMITTANCES_DB_PATH)) {
      list = JSON.parse(fs.readFileSync(REMITTANCES_DB_PATH, 'utf8'));
    }
  } catch (e) {
    list = [];
  }
  list.unshift(batch);
  if (list.length > 500) list = list.slice(0, 500);
  fs.writeFileSync(REMITTANCES_DB_PATH, JSON.stringify(list, null, 2), 'utf8');
}

// إعداد خادم جسر محلي (Local Bridge HTTP / WebSocket Server) للربط مع لوحة التحكم
let connectedSockets = [];
const bridgeServer = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.url === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      status: 'running',
      agent: 'نظام القسام الذكي للواتساب',
      version: '1.5.0',
      config: config
    }));
    return;
  }

  if (req.url === '/api/latest') {
    let list = [];
    try {
      if (fs.existsSync(REMITTANCES_DB_PATH)) {
        list = JSON.parse(fs.readFileSync(REMITTANCES_DB_PATH, 'utf8'));
      }
    } catch (e) {}
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ count: list.length, latest: list.slice(0, 20) }));
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

const PORT = config.bridgeServerPort || 4124;
bridgeServer.listen(PORT, () => {
  console.log(`📡 [Bridge Server] خادم الجسر المحلي يعمل على http://localhost:${PORT}`);
});

/**
 * معالجة رسالة واردة من واتساب
 * @param {string} text النص
 * @param {string} fromJid معرّف المحادثة
 * @param {string} senderName اسم المرسل
 * @param {Function} replyFn دالة الرد
 * @param {Function} forwardToTargetFn دالة التوجيه للمجموعة ب
 */
async function handleIncomingMessage(text, fromJid, senderName, replyFn, forwardToTargetFn) {
  if (!text || !text.trim()) return;

  console.log(`📩 [رسالة جديدة] من: ${senderName} (${fromJid})`);

  // استدعاء محلل الواتساب الذكي
  const records = WhatsAppParser.parse(text, {
    rate: config.exchangeRate,
    currency: config.defaultCurrency
  });

  if (!records || records.length === 0) {
    return;
  }

  console.log(`✨ [اكتشاف حوالات] تم استخراج ${records.length} حوالة بنجاح!`);
  const totals = FinancialEngine.calculateTotals(records);
  const batchId = `REF-${Date.now().toString().slice(-6)}`;

  const batchData = {
    batchId,
    timestamp: new Date().toISOString(),
    sourceJid: fromJid,
    senderName,
    records,
    totals
  };

  // حفظ في قاعدة البيانات المحلية
  saveRemittancesBatch(batchData);

  // تنسيق الرسالة الاحترافية للمجموعة (ب)
  const reportForGroupB = WhatsAppReportFormatter.formatForTargetGroup(records, totals, config);
  console.log(`\n============== [تقرير المجموعة ب] ==============\n${reportForGroupB}\n================================================\n`);

  if (forwardToTargetFn) {
    try {
      await forwardToTargetFn(reportForGroupB);
      console.log(`🚀 [توجيه تلقائي] تم إرسال الكشف إلى مجموعة المنفذين بنجاح.`);
    } catch (err) {
      console.error(`❌ [خطأ توجيه] فشل الإرسال للمجموعة ب:`, err.message);
    }
  }

  // إرسال إشعار التأكيد في المجموعة (أ)
  if (config.autoReplyAcknowledge && replyFn) {
    const ackMsg = WhatsAppReportFormatter.formatAcknowledgment(records, totals, batchId, config);
    try {
      await replyFn(ackMsg);
      console.log(`💬 [رد تأكيدي] تم إرسال إشعار القيد للمجموعة أ.`);
    } catch (err) {
      console.error(`❌ [خطأ في الرد]:`, err.message);
    }
  }
}

/**
 * تشغيل الإيجنت مع محرك Baileys
 */
async function startWhatsAppAgent() {
  let makeWASocket, useMultiFileAuthState, DisconnectReason;
  try {
    const baileys = require('@whiskeysockets/baileys');
    makeWASocket = baileys.default || baileys.makeWASocket;
    useMultiFileAuthState = baileys.useMultiFileAuthState;
    DisconnectReason = baileys.DisconnectReason;
  } catch (e) {
    console.log(`\n⚠️  [ملاحظة التشغيل]: حزمة @whiskeysockets/baileys غير مثبتة بعد.`);
    console.log(`   لتثبيتها وتشغيل الاتصال الحي بواتساب، نفّذ الأمر التالي:`);
    console.log(`   cd whatsapp-agent && npm install\n`);
    console.log(`⚡ [محاكي الإيجنت يعمل حالياً في وضع الجاهزية والاستعداد]`);
    return;
  }

  const qrcode = require('qrcode-terminal');
  const pino = require('pino');

  const authDir = path.join(__dirname, 'auth_session');
  const { state, saveCreds } = await useMultiFileAuthState(authDir);

  const sock = makeWASocket({
    auth: state,
    printQRInTerminal: false,
    logger: pino({ level: 'silent' })
  });

  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      console.log('\n📲 [امسح رمز QR Code للربط بواتساب مجاناً لمرة واحدة]:\n');
      qrcode.generate(qr, { small: true });
    }

    if (connection === 'close') {
      const shouldReconnect = lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
      console.log('⚠️ [انقطاع الاتصال]:', lastDisconnect?.error, '| جاري إعادة الاتصال:', shouldReconnect);
      if (shouldReconnect) {
        startWhatsAppAgent();
      }
    } else if (connection === 'open') {
      console.log('✅ [تم الاتصال بنجاح بواتساب]: الإيجنت الآن في وضع الاستماع المباشر!');
    }
  });

  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify') return;

    for (const msg of messages) {
      if (!msg.message || msg.key.fromMe) continue;

      const fromJid = msg.key.remoteJid;
      const text = msg.message.conversation ||
                   msg.message.extendedTextMessage?.text ||
                   '';

      if (!text) continue;

      const senderName = msg.pushName || 'عميل';

      await handleIncomingMessage(
        text,
        fromJid,
        senderName,
        async (replyText) => {
          await sock.sendMessage(fromJid, { text: replyText }, { quoted: msg });
        },
        async (outgoingText) => {
          if (config.targetGroupId) {
            await sock.sendMessage(config.targetGroupId, { text: outgoingText });
          }
        }
      );
    }
  });
}

// تشغيل الإيجنت
startWhatsAppAgent();

module.exports = {
  handleIncomingMessage,
  startWhatsAppAgent
};
