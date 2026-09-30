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
const OutgoingParser = require('../modules/parsers/OutgoingParser.js');
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
    sourceGroupId: '',
    targetGroupName: 'مجموعة الصرافين (ب)',
    targetGroupId: '',
    exchangeRate: 48,
    defaultCurrency: 'ريال سعودي',
    autoReplyAcknowledge: true,
    listenToAllGroups: true,
    bridgeServerPort: 4124
  };
}

function loadConfig() {
  try {
    const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
    config = JSON.parse(raw);
  } catch (e) {}
  return config;
}

// متغير لحفظ آخر رمز QR لعرضه على المتصفح إن لزم الأمر
let latestQr = null;
let isConnected = false;
let deletedMessagesCount = 0;
let globalTriggerScan = null;

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

// حماية العملية من الانهيار عند انقطاع الشبكة أو حدوث أخطاء غير متوقعة في مكتبة Baileys
process.on('uncaughtException', (err) => {
  console.error('⚠️ [تحذير النظام]: استثناء تم احتواؤه لمنع توقف الإيجنت:', err?.message || err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('⚠️ [تحذير النظام]: رفض وعد تم احتواؤه لمنع توقف الإيجنت:', reason?.message || reason);
});

// إعداد خادم جسر محلي (Bridge Server)
const bridgeServer = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // قراءة ديناميكية للإعدادات لضمان تطبيق أي تعديل يجريه المستخدم فوراً دون إعادة تشغيل
  const currentConfig = loadConfig();

  // API لتشغيل الفحص الشامل وحذف رسائل الخطأ يدوياً أو عبر الواجهة
  if (req.url === '/api/scan-and-clean') {
    if (typeof globalTriggerScan === 'function') {
      globalTriggerScan();
    }
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ success: true, deletedCount: deletedMessagesCount }));
    return;
  }

  // لوحة المراقبة الرئيسية لإيجنت الواتساب
  if (req.url === '/' || req.url === '/dashboard') {
    let list = [];
    try {
      if (fs.existsSync(REMITTANCES_DB_PATH)) {
        list = JSON.parse(fs.readFileSync(REMITTANCES_DB_PATH, 'utf8'));
      }
    } catch (e) {}

    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`
      <!DOCTYPE html>
      <html lang="ar" dir="rtl">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>لوحة إيجنت الواتساب الذكي — نظام القسام</title>
        <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800&family=JetBrains+Mono:wght@600&display=swap" rel="stylesheet">
        <style>
          :root {
            --primary: #2563eb;
            --success: #16a34a;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --border: #e2e8f0;
            --text: #0f172a;
            --text-muted: #64748b;
          }
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: 'Cairo', sans-serif; background: var(--bg); color: var(--text); padding: 1.5rem; line-height: 1.6; }
          .container { max-width: 960px; margin: 0 auto; }
          .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem; }
          .title-wrap h1 { font-size: 1.5rem; font-weight: 800; color: #1e293b; display: flex; align-items: center; gap: 0.5rem; }
          .status-badge { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.4rem 0.85rem; border-radius: 9999px; font-size: 0.85rem; font-weight: 700; }
          .status-connected { background: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; }
          .status-waiting { background: #fef3c7; color: #b45309; border: 1px solid #fde68a; }
          .cards-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
          .card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 12px; padding: 1.25rem; box-shadow: 0 2px 4px rgba(0,0,0,0.02); }
          .card-title { font-size: 0.88rem; color: var(--text-muted); font-weight: 600; margin-bottom: 0.5rem; display: flex; align-items: center; justify-content: space-between; }
          .card-value { font-size: 1.15rem; font-weight: 700; color: #1e293b; word-break: break-all; }
          .card-id { font-family: 'JetBrains Mono', monospace; font-size: 0.78rem; color: #64748b; background: #f1f5f9; padding: 0.2rem 0.4rem; border-radius: 6px; display: inline-block; margin-top: 0.35rem; direction: ltr; }
          .nav-btns { display: flex; gap: 0.75rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
          .btn { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.6rem 1.1rem; border-radius: 8px; font-weight: 600; font-size: 0.9rem; text-decoration: none; cursor: pointer; border: none; transition: 0.2s ease; }
          .btn-primary { background: var(--primary); color: #fff; }
          .btn-primary:hover { background: #1d4ed8; }
          .btn-outline { background: #fff; color: var(--text); border: 1px solid var(--border); }
          .btn-outline:hover { background: #f1f5f9; }
          .btn-danger { background: #fef2f2; color: #b91c1c; border: 1px solid #fca5a5; }
          .btn-danger:hover { background: #fee2e2; }
          .table-box { background: var(--card-bg); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.02); }
          .table-header { padding: 1rem 1.25rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
          table { width: 100%; border-collapse: collapse; text-align: right; }
          th { background: #f8fafc; padding: 0.75rem 1rem; font-size: 0.82rem; color: var(--text-muted); font-weight: 700; border-bottom: 1px solid var(--border); }
          td { padding: 0.85rem 1rem; font-size: 0.88rem; border-bottom: 1px solid var(--border); }
          tr:last-child td { border-bottom: none; }
          .empty-state { padding: 3rem 1rem; text-align: center; color: var(--text-muted); }
        </style>
      </head>
      <body>
        <div class="container">
          <header class="header">
            <div class="title-wrap">
              <h1>🤖 إيجنت الواتساب الذكي — نظام القسام</h1>
              <p style="color:var(--text-muted);font-size:0.88rem;">مراقبة الحوالات الواردة وإرسالها التلقائي بين المجموعات</p>
            </div>
            <div>
              ${isConnected
                ? '<span class="status-badge status-connected">🟢 واتساب متصل ويعمل</span>'
                : '<a href="/qr" class="status-badge status-waiting">🟡 بانتظار مسح رمز QR</a>'}
            </div>
          </header>

          <div class="nav-btns">
            <a href="http://localhost:4123/" target="_blank" class="btn btn-primary">📊 فتح شاشة نظام القسام الرئيسية</a>
            <a href="/qr" class="btn btn-outline">📱 فحص اتصال الواتساب (QR)</a>
            <button onclick="triggerCleanup()" class="btn btn-danger">🧹 فحص وحذف رسائل الخطأ السابقة للجميع</button>
            <button onclick="location.reload()" class="btn btn-outline">🔄 تحديث الصفحة</button>
          </div>

          <div class="cards-grid">
            <div class="card" style="background:#fff1f2;border-color:#fecdd3;">
              <div class="card-title">
                <span style="color:#9f1239;font-weight:700;">رسائل الخطأ المحذوفة للجميع</span>
                <span>🗑️</span>
              </div>
              <div class="card-value" style="color:#e11d48;" id="deletedCounter">${deletedMessagesCount} رسالة</div>
              <div style="font-size:0.8rem;color:#be123c;margin-top:0.25rem;">محرك الحذف للجميع يعمل تلقائياً (تطابق 100%)</div>
            </div>

            <div class="card">
              <div class="card-title">
                <span>1. استقبال الرسائل (المصدر)</span>
                <span>📥</span>
              </div>
              <div class="card-value">${currentConfig.sourceGroupName || 'غير محدد'}</div>
              <div class="card-id">${currentConfig.sourceGroupId || 'بانتظار الإدخال في config.json'}</div>
            </div>

            <div class="card">
              <div class="card-title">
                <span>2. مجموعة الحوالات الواردة</span>
                <span>🇪🇹</span>
              </div>
              <div class="card-value">${currentConfig.incomingGroupName || currentConfig.targetGroupName || 'غير محدد'}</div>
              <div class="card-id">${currentConfig.incomingGroupId || currentConfig.targetGroupId || 'بانتظار الإدخال في config.json'}</div>
            </div>

            <div class="card">
              <div class="card-title">
                <span>3. مجموعة الحوالات الصادرة</span>
                <span>📤</span>
              </div>
              <div class="card-value">${currentConfig.outgoingGroupName || 'مجموعة الحوالات الصادرة'}</div>
              <div class="card-id">${currentConfig.outgoingGroupId || 'بانتظار الإدخال في config.json'}</div>
            </div>

            <div class="card">
              <div class="card-title">
                <span>سعر المصارفة والرد التلقائي</span>
                <span>💱</span>
              </div>
              <div class="card-value">${currentConfig.exchangeRate} بر إثيوبي</div>
              <div style="font-size:0.8rem;color:var(--text-muted);margin-top:0.25rem;">الرد التأكيدي: ${currentConfig.autoReplyAcknowledge ? 'مفعل ✅' : 'معطل ❌'}</div>
            </div>
          </div>

          <div class="table-box">
            <div class="table-header">
              <h3 style="font-size:1rem;font-weight:700;">سجل الحوالات المقروءة آلياً من واتساب (${list.length})</h3>
              <span style="font-size:0.8rem;color:var(--text-muted);">تحديث تلقائي</span>
            </div>
            ${list.length === 0 ? `
              <div class="empty-state">
                <div style="font-size:2.5rem;margin-bottom:0.5rem;">⏳</div>
                <p style="font-weight:600;">لا توجد حوالات مقروءة حتى الآن.</p>
                <p style="font-size:0.82rem;margin-top:0.25rem;">أرسل رسالة حوالات في مجموعة <strong>[${currentConfig.sourceGroupName || 'المصدر'}]</strong> وسيقوم الإيجنت بقراءتها وإرسال كشفها للمجموعة الهدف فوراً!</p>
              </div>
            ` : `
              <table>
                <thead>
                  <tr>
                    <th>رقم المرجع</th>
                    <th>النوع</th>
                    <th>الوقت والتاريخ</th>
                    <th>المرسل</th>
                    <th>العدد</th>
                    <th>المبلغ / المقابل</th>
                  </tr>
                </thead>
                <tbody>
                  ${list.map(b => `
                    <tr>
                      <td style="font-family:'JetBrains Mono';font-weight:700;color:var(--primary);">${b.batchId}</td>
                      <td>
                        <span style="font-size:0.75rem;padding:0.2rem 0.5rem;border-radius:4px;font-weight:700;background:${b.type === 'outgoing' ? '#dbeafe;color:#1e40af;' : '#dcfce7;color:#166534;'}">
                          ${b.type === 'outgoing' ? '📤 صادر' : '📥 وارد'}
                        </span>
                      </td>
                      <td style="font-size:0.82rem;color:var(--text-muted);">${new Date(b.timestamp).toLocaleTimeString('ar-EG')} - ${new Date(b.timestamp).toLocaleDateString('en-CA')}</td>
                      <td><strong>${b.senderName || 'عميل'}</strong></td>
                      <td>${b.records.length} حوالة</td>
                      <td style="font-weight:700;color:${b.type === 'outgoing' ? '#2563eb' : '#16a34a'};">
                        ${b.type === 'outgoing' 
                          ? `${(b.totals?.totalAmount || 0).toLocaleString()} ${b.records[0]?.currency || 'ريال'}` 
                          : `${(b.totals?.totalBirr || 0).toLocaleString()} بر`}
                      </td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            `}
          </div>
        </div>
        <script>
          function triggerCleanup() {
            if (confirm('هل تريد بدء الفحص التلقائي الشامل لجميع المحادثات وحذف أي رسالة خطأ سابقة للجميع؟')) {
              fetch('/api/scan-and-clean')
                .then(r => r.json())
                .then(d => {
                  alert('🚀 تم إطلاق الفحص الشامل في الخلفية! جاري مسح كافة المحادثات وتدوير الرسائل وحذفها للجميع.');
                  setTimeout(() => location.reload(), 2500);
                });
            }
          }
        </script>
      </body>
      </html>
    `);
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

const PORT = config.bridgeServerPort || 4124;
if (require.main === module) {
  bridgeServer.listen(PORT, () => {
    console.log(`📡 [Bridge Server] خادم الجسر المحلي يعمل على http://localhost:${PORT}`);
    console.log(`🌐 [صفحة رمز QR]: يمكنك أيضاً مسح الرمز من المتصفح عبر http://localhost:${PORT}/qr`);
  });
}

/**
 * استخراج النص من أي نوع من رسائل واتساب (بما فيها الرسائل المؤقتة وصور الكشوف)
 */
function extractMessageText(msg) {
  if (!msg || !msg.message) return '';
  const m = msg.message;
  const real = m.ephemeralMessage?.message || m.viewOnceMessage?.message || m.viewOnceMessageV2?.message || m;
  return real.conversation ||
         real.extendedTextMessage?.text ||
         real.imageMessage?.caption ||
         real.videoMessage?.caption ||
         real.documentMessage?.caption ||
         '';
}

/**
 * ذاكرة الحالات التفاعلية للرسائل المعلقة بانتظار تحديد النوع (1 أو 2)
 * يتم حفظها في ملف دائم حتى لا تُفقد عند إعادة تشغيل الإيجنت
 */
const PENDING_DB_PATH = path.join(DATA_DIR, 'pending_confirmations.json');
const pendingConfirmations = new Map();

function loadPendingConfirmations() {
  try {
    if (fs.existsSync(PENDING_DB_PATH)) {
      const data = JSON.parse(fs.readFileSync(PENDING_DB_PATH, 'utf8'));
      for (const [k, v] of Object.entries(data)) {
        pendingConfirmations.set(k, v);
      }
    }
  } catch (e) {}
}

function savePendingConfirmations() {
  try {
    const obj = Object.fromEntries(pendingConfirmations);
    fs.writeFileSync(PENDING_DB_PATH, JSON.stringify(obj, null, 2), 'utf8');
  } catch (e) {}
}

loadPendingConfirmations();

function cleanupPendingConfirmations() {
  const now = Date.now();
  let changed = false;
  for (const [key, val] of pendingConfirmations.entries()) {
    if (now - val.timestamp > 30 * 60 * 1000) { // صلاحية 30 دقيقة
      pendingConfirmations.delete(key);
      changed = true;
    }
  }
  if (changed) savePendingConfirmations();
}

/**
 * معالجة وتوجيه الحوالات الواردة
 */
async function processIncoming(text, fromJid, senderName, replyFn, forwardToIncomingFn, currentConfig, label = '') {
  const records = WhatsAppParser.parse(text, {
    rate: currentConfig.exchangeRate,
    currency: currentConfig.defaultCurrency
  });

  if (!records || records.length === 0) {
    if (replyFn) await replyFn(`⚠️ تعذر استخراج بيانات صالحة لحوالة واردة من هذا النص.`);
    return;
  }

  const totals = FinancialEngine.calculateTotals(records);
  const batchId = `REF-${Date.now().toString().slice(-6)}`;

  const batchData = {
    batchId,
    type: 'incoming',
    timestamp: new Date().toISOString(),
    sourceJid: fromJid,
    senderName,
    records,
    totals
  };
  saveRemittancesBatch(batchData);

  const reportForIncoming = WhatsAppReportFormatter.formatForTargetGroup(records, totals, currentConfig);
  console.log(`\n============== [تقرير الحوالات الواردة ${label}] ==============\n${reportForIncoming}\n=====================================================\n`);

  if (forwardToIncomingFn) {
    try {
      await forwardToIncomingFn(reportForIncoming);
      console.log(`🚀 [توجيه الوارد] تم إرسال كشف الحوالات الواردة لمجموعتها بنجاح.`);
    } catch (err) {
      console.error(`❌ [خطأ توجيه الوارد]:`, err.message);
    }
  }

  if (currentConfig.autoReplyAcknowledge && replyFn) {
    const ackMsg = WhatsAppReportFormatter.formatAcknowledgment(records, totals, batchId, currentConfig);
    try {
      await replyFn(ackMsg);
      console.log(`💬 [رد تأكيدي] تم إرسال إشعار القيد لمجموعة الاستقبال.`);
    } catch (err) {
      console.error(`❌ [خطأ في الرد التأكيدي]:`, err.message);
    }
  }
}

/**
 * معالجة وتوجيه الحوالات الصادرة
 */
async function processOutgoing(text, fromJid, senderName, replyFn, forwardToOutgoingFn, currentConfig, label = '') {
  let records = OutgoingParser.parseOutgoingText(text);

  if (!records || records.length === 0) {
    const simple = WhatsAppParser.parse(text, {
      rate: currentConfig.exchangeRate,
      currency: currentConfig.defaultCurrency
    });
    if (simple && simple.length > 0) {
      records = simple.map(s => ({
        type: 'outgoing',
        recipient: s.name || 'بدون اسم',
        sender: senderName || '-',
        amount: s.amount,
        currency: s.currency,
        commission: '-',
        network: '-',
        transferNo: s.id || '-',
        date: new Date().toLocaleDateString('en-CA'),
        notes: ''
      }));
    }
  }

  if (!records || records.length === 0) {
    // تم إلغاء إرسال رسالة الخطأ في الواتساب
    return;
  }

  const batchId = `REF-${Date.now().toString().slice(-6)}`;
  console.log(`📤 [اكتشاف حوالات صادرة ${label}] تم استخراج ${records.length} حوالة صادرة بنجاح!`);

  const batchData = {
    batchId,
    type: 'outgoing',
    timestamp: new Date().toISOString(),
    sourceJid: fromJid,
    senderName,
    records,
    totals: {
      count: records.length,
      totalAmount: records.reduce((sum, r) => sum + (parseFloat(r.amount) || 0), 0)
    }
  };
  saveRemittancesBatch(batchData);

  const outgoingReport = WhatsAppReportFormatter.formatOutgoingReport(records, currentConfig);
  console.log(`\n============== [تقرير الحوالات الصادرة ${label}] ==============\n${outgoingReport}\n=====================================================\n`);

  if (forwardToOutgoingFn) {
    try {
      await forwardToOutgoingFn(outgoingReport);
      console.log(`🚀 [توجيه الصادر] تم إرسال كشف الحوالات الصادرة لمجموعتها بنجاح.`);
    } catch (err) {
      console.error(`❌ [خطأ توجيه الصادر]:`, err.message);
    }
  }

  if (currentConfig.autoReplyAcknowledge && replyFn) {
    const ackMsg = WhatsAppReportFormatter.formatOutgoingAcknowledgment(records, batchId, currentConfig);
    try {
      await replyFn(ackMsg);
      console.log(`💬 [رد تأكيدي] تم إرسال إشعار القيد لمجموعة الاستقبال.`);
    } catch (err) {
      console.error(`❌ [خطأ في الرد التأكيدي]:`, err.message);
    }
  }
}

/**
 * معالجة رسالة واردة من واتساب وفق المنظومة التفاعلية والهجينة
 */
async function handleIncomingMessage(text, fromJid, senderName, replyFn, forwardToIncomingFn, forwardToOutgoingFn) {
  if (!text || !text.trim()) return;

  const currentConfig = loadConfig();

  // منع الدوران التلقائي: تجاهل تقارير الإيجنت أو إشعاراته السابقة أو الأسئلة التفاعلية
  if (text.includes('كشف حوالات') || text.includes('تم استلام وقيد') || text.includes('يرجى تحديد نوع هذه المعاملة')) {
    return;
  }

  // حصر المعالجة بمجموعات النظام المعتمدة فقط (مجموعة الاستقبال والصادر والوارد)
  const allowedGroups = [
    currentConfig.sourceGroupId,
    currentConfig.incomingGroupId,
    currentConfig.outgoingGroupId,
    currentConfig.targetGroupId
  ].filter(Boolean);

  if (!fromJid.endsWith('@g.us') || (allowedGroups.length > 0 && !allowedGroups.includes(fromJid))) {
    return;
  }

  console.log(`📩 [رسالة مرصودة في واتساب]: من ${senderName} (${fromJid})`);

  cleanupPendingConfirmations();

  // 1. فحص هل الرسالة إجابة على سؤال تفاعلي معلق (1 أو 2)
  const cleanInput = text.trim();
  const isReply1 = /^(1|\[1\]|1️⃣|١|وارد|واردة|الوارد|واحد)$/i.test(cleanInput);
  const isReply2 = /^(2|\[2\]|2️⃣|٢|صادر|صادرة|الصادر|اثنين|إثنين)$/i.test(cleanInput);

  if (isReply1 || isReply2) {
    let pendingKey = null;
    let pending = null;

    if (pendingConfirmations.has(fromJid)) {
      pendingKey = fromJid;
      pending = pendingConfirmations.get(fromJid);
    } else if (pendingConfirmations.size > 0) {
      // إذا رد المستخدم من محادثة خاصة أو معرف مختلف، نربطه بآخر سؤال معلق
      const lastEntry = Array.from(pendingConfirmations.entries()).pop();
      pendingKey = lastEntry[0];
      pending = lastEntry[1];
    }

    if (pending) {
      pendingConfirmations.delete(pendingKey);
      savePendingConfirmations();
      console.log(`🎯 [رد تفاعلي مستلم]: المستخدم اختار [${isReply1 ? '1 - وارد' : '2 - صادر'}] للمعاملة المعلقة!`);

      if (isReply1) {
        await processIncoming(pending.text, pendingKey, pending.senderName, replyFn, forwardToIncomingFn, currentConfig, '(بتأكيد تفاعلي - وارد)');
      } else {
        await processOutgoing(pending.text, pendingKey, pending.senderName, replyFn, forwardToOutgoingFn, currentConfig, '(بتأكيد تفاعلي - صادر)');
      }
      return;
    }
  }

  // 2. فحص وجود كلمات مفتاحية صريحة في بداية الرسالة (وارد أو صادر) للتوجيه الفوري المباشر
  if (/^(\*|#)?(وارد|الوارد|واردة|واردات)[\s:\-\_]/i.test(text) || /^(\*|#)?(وارد|الوارد|واردة)\b/i.test(text)) {
    const cleanText = text.replace(/^(\*|#)?(وارد|الوارد|واردة|واردات)[\s:\-\_]*/i, '').trim();
    return await processIncoming(cleanText || text, fromJid, senderName, replyFn, forwardToIncomingFn, currentConfig, '(أمر صريح - وارد)');
  }
  if (/^(\*|#)?(صادر|الصادر|صادرة|صادرات)[\s:\-\_]/i.test(text) || /^(\*|#)?(صادر|الصادر|صادرة)\b/i.test(text)) {
    const cleanText = text.replace(/^(\*|#)?(صادر|الصادر|صادرة|صادرات)[\s:\-\_]*/i, '').trim();
    return await processOutgoing(cleanText || text, fromJid, senderName, replyFn, forwardToOutgoingFn, currentConfig, '(أمر صريح - صادر)');
  }

  // 3. القاعدة الذهبية المعتمدة من العميل:
  // أ. الحوالات الواردة: رقم حساب يبدأ بـ 100 واسم الحساب بالإنجليزية
  const hasAccount100 = /(?:^|[^\d])100\d{6,14}(?:[^\d]|$)/.test(text);
  const hasEnglishName = /[a-zA-Z]{2,}/.test(text);
  const isIncomingRule = hasAccount100 && hasEnglishName;

  // ب. الحوالات الصادرة: الأسماء بالعربية وفيها اسم المرسل والمستقبل
  const hasArabicChars = /[\u0600-\u06FF]{3,}/.test(text);
  const hasSenderReceiver = (/(?:المستلم|المستقبل)/i.test(text) && /المرسل/i.test(text)) ||
                            /(?:ارسال\s*حوال[ةه]|حوال[ةه]\s*صادرة|خصم\s*[\d,]+|عبر\s*(?:الادارة|الإدارة|شبكة)?\s*:)/i.test(text);
  const isOutgoingRule = hasArabicChars && hasSenderReceiver;

  // في حال وجود وارد وصادر معاً في نفس الرسالة
  if (isIncomingRule && isOutgoingRule) {
    console.log(`🔀 [كشف مختلط]: جاري فصل الحوالات الواردة والصادرة آلياً...`);
    const analysis = OutgoingParser.splitMixedText(text);

    let incCount = 0;
    let outCount = 0;
    let incTotals = null;

    if (analysis.hasIncoming) {
      const records = WhatsAppParser.parse(analysis.incomingText, { rate: currentConfig.exchangeRate, currency: currentConfig.defaultCurrency });
      if (records.length > 0) {
        incCount = records.length;
        incTotals = FinancialEngine.calculateTotals(records);
        const report = WhatsAppReportFormatter.formatForTargetGroup(records, incTotals, currentConfig);
        if (forwardToIncomingFn) await forwardToIncomingFn(report);
      }
    }

    if (analysis.hasOutgoing) {
      const records = OutgoingParser.parseOutgoingText(analysis.outgoingText);
      if (records.length > 0) {
        outCount = records.length;
        const report = WhatsAppReportFormatter.formatOutgoingReport(records, currentConfig);
        if (forwardToOutgoingFn) await forwardToOutgoingFn(report);
      }
    }

    if (currentConfig.autoReplyAcknowledge && replyFn) {
      const batchId = `REF-${Date.now().toString().slice(-6)}`;
      const ackMsg = `✅ تم استلام وقيد المعاملة المختلطة بنجاح:\n📥 عدد الحوالات الواردة: ${incCount} (${FinancialEngine.formatNumber(incTotals?.totalBirr || 0)} بر)\n📤 عدد الحوالات الصادرة: ${outCount}\n🔢 رقم المعاملة: ${batchId}`;
      await replyFn(ackMsg);
    }
    return;
  }

  // إذا تطابقت مع قاعدة الوارد: حساب يبدأ بـ 100 + اسم إنجليزي ⬅️ توجيه فوري لمجموعة الوارد دون سؤال
  if (isIncomingRule) {
    console.log(`🎯 [تطابق قاعدة الوارد]: حساب 100 + اسم إنجليزي ⬅️ توجيه فوري لمجموعة الوارد دون سؤال`);
    return await processIncoming(text, fromJid, senderName, replyFn, forwardToIncomingFn, currentConfig, '(حساب 100 + اسم إنجليزي)');
  }

  // إذا تطابقت مع قاعدة الصادر: عربي + مرسل ومستقبل ⬅️ توجيه فوري لمجموعة الصادر دون سؤال
  if (isOutgoingRule) {
    console.log(`🎯 [تطابق قاعدة الصادر]: لغة عربية + مرسل ومستقبل ⬅️ توجيه فوري لمجموعة الصادر دون سؤال`);
    return await processOutgoing(text, fromJid, senderName, replyFn, forwardToOutgoingFn, currentConfig, '(عربي + مرسل ومستقبل)');
  }

  // 4. السؤال التفاعلي للحالات غير المحددة صراحة
  const hasRemittanceSigns = /\b(1000\d{6,12}|\d{10,16})\b/.test(text) ||
                             /[a-zA-Z\u0600-\u06FF]{2,}\s*=\s*[\d,]+/.test(text) ||
                             /(?:خصم|عمول[ةه]|حوال[ةه]|المستلم|المرسل|شبك[ةه]|sar|etb|بر|ريال)/i.test(text) ||
                             (/\b\d{2,9}\b/.test(text) && /[a-zA-Z\u0600-\u06FF]{2,}/.test(text));

  if (hasRemittanceSigns) {
    pendingConfirmations.set(fromJid, {
      text,
      senderName,
      timestamp: Date.now()
    });
    savePendingConfirmations();
    console.log(`❓ [حوالة غير محددة صراحة]: لم تتطابق مع (حساب 100+إنجليزي) أو (عربي+مرسل ومستقبل). جاري سؤال المستخدم تفاعلياً...`);
    if (replyFn) {
      const questionMsg = `❓ *يرجى تحديد نوع هذه المعاملة بالرد برقم:*\n\n1️⃣ كشف حوالات *واردة* (إثيوبيا / بر)\n2️⃣ كشف حوالات *صادرة* (شبكات الصرافة)\n\n_(أرسل 1 أو 2 وسيتم التوجيه فوراً)_`;
      await replyFn(questionMsg);
    }
    return;
  }

  // إذا كانت محادثة خاصة عادية لا علاقة لها بالحوالات، نتجاهلها بهدوء
  if (!fromJid.endsWith('@g.us')) {
    return;
  }

  console.log(`ℹ️ [تنبيه]: لم يتم العثور على بيانات حوالات صالحة في هذه الرسالة.`);
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
    console.log(`   لتثبيتها، شغّل الأمر التالي:`);
    console.log(`   cd whatsapp-agent ; npm install\n`);
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
    logger: pino({ level: 'silent' }),
    getMessage: async (key) => undefined
  });

  sock.ev.on('connection.update', async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      latestQr = qr;
      isConnected = false;
      console.log('\n📲 [امسح رمز QR Code في التيرمنال أدناه أو افتح http://localhost:' + PORT + '/qr في المتصفح]:\n');
      qrcode.generate(qr, { small: true });
    }

    if (connection === 'close') {
      isConnected = false;
      const shouldReconnect = lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
      console.log('⚠️ [انقطاع الاتصال]:', lastDisconnect?.error?.message || 'closed', '| إعادة الاتصال:', shouldReconnect);
      if (shouldReconnect) {
        setTimeout(() => {
          startWhatsAppAgent();
        }, 3000);
      }
    } else if (connection === 'open') {
      isConnected = true;
      latestQr = null;
      console.log('\n======================================================');
      console.log('✅ [تم الاتصال بنجاح بواتساب]: الإيجنت الآن متصل بحسابك!');
      console.log('======================================================\n');

      // تشغيل الفحص التلقائي الشامل لجميع المحادثات بعد 3 ثوانٍ لحذف رسائل الخطأ السابقة للجميع
      setTimeout(() => {
        triggerFullHistoryScan();
      }, 3500);

      // اكتشاف ذكي لقائمة المجموعات لمساعدة المستخدم في ضبط المجموعات فوراً
      try {
        console.log('🔍 [جاري فحص المجموعات المشارك بها الحساب للتعرف التلقائي عليها]...');
        const groups = await sock.groupFetchAllParticipating();
        const groupList = Object.values(groups);
        console.log(`\n📋 عُثر على (${groupList.length}) مجموعة في حسابك:`);

        let updatedConfig = false;
        groupList.forEach((g, idx) => {
          console.log(`   ${idx + 1}. 👥 [${g.subject}]`);
          console.log(`      🆔 المعرف: ${g.id}`);

          // مطابقة تلقائية باسم المجموعة
          if (config.sourceGroupName && g.subject.includes(config.sourceGroupName.trim()) && !config.sourceGroupId) {
            config.sourceGroupId = g.id;
            updatedConfig = true;
            console.log(`      🎯 [تطابق تلقائي]: تم ربطها كمجموعة المصدر (أ)!`);
          }
          const incName = config.incomingGroupName || config.targetGroupName;
          if (incName && g.subject.includes(incName.trim()) && !config.incomingGroupId) {
            config.incomingGroupId = g.id;
            config.targetGroupId = g.id;
            updatedConfig = true;
            console.log(`      🎯 [تطابق تلقائي]: تم ربطها كمجموعة الحوالات الواردة!`);
          }
          if (config.outgoingGroupName && g.subject.includes(config.outgoingGroupName.trim()) && !config.outgoingGroupId) {
            config.outgoingGroupId = g.id;
            updatedConfig = true;
            console.log(`      🎯 [تطابق تلقائي]: تم ربطها كمجموعة الحوالات الصادرة!`);
          }
        });

        if (updatedConfig) {
          fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), 'utf8');
          console.log('\n💾 [تم حفظ معرفات المجموعات تلقائياً في config.json]!');
        } else {
          console.log('\n💡 [تلميح]: يمكنك نسخ المعرف (ID) للمجموعة ووضعه في config.json في حقل sourceGroupId أو targetGroupId.');
        }
      } catch (err) {
        console.warn('⚠️ ملاحظة أثناء استعراض المجموعات:', err.message);
      }
    }
  });

  const TARGET_DELETE_TEXT = '⚠️ تعذر استخراج بيانات صالحة لحوالة صادرة من هذا النص.';
  const scannedChatPages = new Map();

  async function checkAndDeleteTargetMessage(msg) {
    if (!msg || !msg.message || !msg.key) return false;
    const text = extractMessageText(msg);
    // شرط التطابق 100% كما طلب العميل بدقة تامة وبدون حذف أي رسالة لا تتطابق
    if (text && text.trim() === TARGET_DELETE_TEXT) {
      const fromJid = msg.key.remoteJid;
      const deleteKey = {
        remoteJid: fromJid,
        fromMe: true,
        id: msg.key.id
      };
      if (msg.key.participant) {
        deleteKey.participant = msg.key.participant;
      }
      console.log(`🗑️ [حذف للجميع]: عُثر على رسالة خطأ سابقة في ${fromJid} (معرف: ${msg.key.id}). جاري الحذف للجميع...`);
      try {
        await sock.sendMessage(fromJid, {
          delete: deleteKey
        });
        deletedMessagesCount++;
        console.log(`✅ [تم الحذف بنجاح للجميع]: حُذفت الرسالة ${msg.key.id} من واتساب! (إجمالي المحذوف حتى الآن: ${deletedMessagesCount})`);
        return true;
      } catch (err) {
        console.error(`❌ [فشل حذف الرسالة للجميع]:`, err.message);
      }
    }
    return false;
  }

  async function triggerFullHistoryScan() {
    console.log('\n🧹 [محرك الفحص الشامل]: جاري مسح كافة المحادثات والمجموعات لاكتشاف وحذف رسائل الخطأ السابقة...');
    try {
      const allChats = new Set();
      try {
        const groups = await sock.groupFetchAllParticipating();
        Object.keys(groups).forEach(id => allChats.add(id));
      } catch (e) {}

      const cfg = loadConfig();
      if (cfg.sourceGroupId) allChats.add(cfg.sourceGroupId);
      if (cfg.incomingGroupId) allChats.add(cfg.incomingGroupId);
      if (cfg.outgoingGroupId) allChats.add(cfg.outgoingGroupId);
      if (cfg.targetGroupId) allChats.add(cfg.targetGroupId);

      console.log(`📡 [فحص السجل]: سيتم استدعاء السجل التراجعي لعدد (${allChats.size}) محادثة ومجموعة.`);

      for (const chatJid of allChats) {
        try {
          // استدعاء أحدث 100 رسالة لكل محادثة لتدويرها وفحصها وحذف رسائل الخطأ منها
          await sock.fetchMessageHistory(100, { remoteJid: chatJid, fromMe: true, id: '' }, Date.now());
          await new Promise(r => setTimeout(r, 800));
        } catch (err) {
          // تجاهل الأخطاء العادية إن كانت المحادثة غير متزامنة
        }
      }
    } catch (err) {
      console.error('⚠️ خطأ في تشغيل الفحص الشامل:', err.message);
    }
  }

  globalTriggerScan = triggerFullHistoryScan;

  async function paginateOlderMessages(messages) {
    if (!Array.isArray(messages) || messages.length === 0) return;

    const chatsOldest = new Map();
    for (const m of messages) {
      if (!m.key?.remoteJid || !m.messageTimestamp) continue;
      const jid = m.key.remoteJid;
      const ts = typeof m.messageTimestamp === 'object' ? m.messageTimestamp.low || 0 : Number(m.messageTimestamp);
      if (!chatsOldest.has(jid) || ts < chatsOldest.get(jid).ts) {
        chatsOldest.set(jid, { key: m.key, ts });
      }
    }

    for (const [jid, { key, ts }] of chatsOldest.entries()) {
      const pages = scannedChatPages.get(jid) || 0;
      if (pages < 20) { // فحص حتى 2000 رسالة في كل محادثة لضمان شمول الـ 100+ رسالة
        scannedChatPages.set(jid, pages + 1);
        try {
          console.log(`📜 [تدوير تراجعي]: جلب الصفحة (${pages + 1}) من سجل ${jid}...`);
          await sock.fetchMessageHistory(100, key, ts);
          await new Promise(r => setTimeout(r, 600));
        } catch (e) {}
      }
    }
  }

  // فحص سجل الرسائل عند الاتصال وسحب الدفعات السابقة لحذف أي رسالة مطابقة للجميع فوراً
  sock.ev.on('messaging-history.set', async ({ chats, contacts, messages, syncType }) => {
    console.log(`📜 [استلام سجل الرسائل]: تم استلام دفعة من واتساب (النوع: ${syncType}, رسائل: ${messages?.length || 0})`);
    if (Array.isArray(messages)) {
      for (const m of messages) {
        await checkAndDeleteTargetMessage(m);
      }
      await paginateOlderMessages(messages);
    }
  });

  sock.ev.on('creds.update', saveCreds);

  const processedMsgIds = new Set();

  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    for (const msg of messages) {
      if (!msg.message) continue;

      // حذف فوري للرسالة للجميع إن كانت مطابقة 100%
      const wasDeleted = await checkAndDeleteTargetMessage(msg);
      if (wasDeleted) continue;

      const msgId = msg.key?.id;
      if (msgId) {
        if (processedMsgIds.has(msgId)) continue;
        processedMsgIds.add(msgId);
        if (processedMsgIds.size > 2000) {
          const first = processedMsgIds.values().next().value;
          processedMsgIds.delete(first);
        }
      }

      const fromJid = msg.key.remoteJid;
      if (!fromJid || fromJid === 'status@broadcast') continue;

      // 🗑️ ميزة الحذف السريع: حذف أي رسالة عند الرد عليها (اقتباسها) بكلمة "احذف" أو "حذف"
      const ctx = msg.message?.extendedTextMessage?.contextInfo;
      const quotedText = ctx?.quotedMessage?.conversation ||
                         ctx?.quotedMessage?.extendedTextMessage?.text || '';
      const cleanText = extractMessageText(msg).trim();
      const isDeleteCmd = /^(احذف|حذف|delete|del)$/i.test(cleanText);

      if (ctx?.stanzaId && (quotedText.trim() === TARGET_DELETE_TEXT || isDeleteCmd)) {
        console.log(`🗑️ [حذف للجميع عبر الرد]: جاري حذف الرسالة المحددة (${ctx.stanzaId}) في ${fromJid}...`);
        try {
          await sock.sendMessage(fromJid, {
            delete: {
              remoteJid: fromJid,
              fromMe: true,
              id: ctx.stanzaId,
              participant: ctx.participant
            }
          });
          if (isDeleteCmd) {
            await sock.sendMessage(fromJid, { delete: msg.key });
          }
          console.log(`✅ [تم الحذف بنجاح للجميع]: حُذفت الرسالة من واتساب!`);
          continue;
        } catch (err) {
          console.error(`❌ [تعذر حذف الرسالة المحددة]:`, err.message);
        }
      }

      // 🧹 أمر التنظيف الشامل التلقائي عبر رسالة واتساب
      if (/^(نظف|تنظيف|احذف رسائل الخطأ|حذف رسائل الخطأ|cleanup)$/i.test(cleanText)) {
        console.log(`🧹 [طلب تنظيف]: تم استلام أمر فحص وتنظيف شامل من ${fromJid}`);
        try {
          await sock.sendMessage(fromJid, { text: `🧹 تم إطلاق الفحص الشامل التلقائي لكافة المحادثات لحذف رسائل الخطأ السابقة للجميع!` }, { quoted: msg });
        } catch (e) {}
        if (typeof globalTriggerScan === 'function') {
          globalTriggerScan();
        }
        continue;
      }

      // 🛑 الأمان والخصوصية: الإيجنت يعمل حصرياً وقطعياً داخل المجموعات المخصصة للنظام فقط!
      // تجاهل تام لأي محادثات خاصة فردية أو حالات واتساب
      if (!fromJid.endsWith('@g.us')) {
        continue;
      }

      const cfg = loadConfig();
      // حصر الاستماع بمجموعات النظام المعتمدة فقط (مجموعة الاستقبال، الصادر، والوارد)
      const allowedGroups = [
        cfg.sourceGroupId,
        cfg.incomingGroupId,
        cfg.outgoingGroupId,
        cfg.targetGroupId
      ].filter(Boolean);

      if (allowedGroups.length > 0 && !allowedGroups.includes(fromJid)) {
        // تجاهل أي مجموعة أخرى في حساب الواتساب غير مخصصة في النظام
        continue;
      }

      const text = extractMessageText(msg);

      if (!text || !text.trim()) continue;

      console.log(`📥 [وارد مجموعة معتمدة]: ${fromJid} | نص: "${text.substring(0, 45)}..."`);

      const senderName = msg.pushName || (msg.key.fromMe ? 'أنا (المرسل)' : 'عميل');

      await handleIncomingMessage(
        text,
        fromJid,
        senderName,
        async (replyText) => {
          await sock.sendMessage(fromJid, { text: replyText }, { quoted: msg });
        },
        async (incomingText) => {
          const cfg = loadConfig();
          const target = cfg.incomingGroupId || cfg.targetGroupId;
          if (target) {
            await sock.sendMessage(target, { text: incomingText });
          } else {
            console.warn('⚠️ لم يتم تحديد incomingGroupId لإرسال كشف الوارد إليه في config.json');
          }
        },
        async (outgoingText) => {
          const cfg = loadConfig();
          if (cfg.outgoingGroupId) {
            await sock.sendMessage(cfg.outgoingGroupId, { text: outgoingText });
          } else {
            console.warn('⚠️ لم يتم تحديد outgoingGroupId لإرسال كشف الصادر إليه في config.json');
          }
        }
      );
    }
  });
}

// تشغيل الإيجنت عند التشغيل المباشر
if (require.main === module) {
  startWhatsAppAgent();
}

module.exports = {
  handleIncomingMessage,
  startWhatsAppAgent
};
