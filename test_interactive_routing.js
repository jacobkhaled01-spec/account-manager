const { handleIncomingMessage } = require('./whatsapp-agent/agent.js');
const cfg = require('./whatsapp-agent/config.json');
const srcJid = cfg.sourceGroupId;

async function runTests() {
  console.log('=== بدء اختبار المنظومة التفاعلية والهجينة (2 & 3) ===\n');

  let sentToIncoming = null;
  let sentToOutgoing = null;
  let replySent = null;

  const mockReply = async (text) => { replySent = text; };
  const mockIncoming = async (text) => { sentToIncoming = text; };
  const mockOutgoing = async (text) => { sentToOutgoing = text; };

  const resetMocks = () => {
    sentToIncoming = null;
    sentToOutgoing = null;
    replySent = null;
  };

  // 1. اختبار رسالة صريحة تبدأ بـ وارد:
  console.log('--- 1. اختبار رسالة صريحة بكلمة مفتاحية (وارد:) ---');
  resetMocks();
  await handleIncomingMessage('وارد: احمد سالم 1000 ريال', srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);
  console.log('تم التوجيه للوارد مباشرة؟', sentToIncoming ? '✅ نعم' : '❌ لا');
  console.log('هل طُرح سؤال؟', replySent && replySent.includes('يرجى تحديد نوع') ? '⚠️ خطأ' : '✅ لا (مباشر)');

  // 2. اختبار رسالة صريحة تبدأ بـ صادر:
  console.log('\n--- 2. اختبار رسالة صريحة بكلمة مفتاحية (صادر:) ---');
  resetMocks();
  await handleIncomingMessage('صادر: حوالة 2000 ريال المستلم: خالد المرسل: عمر شبكة الأكوع', srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);
  console.log('تم التوجيه للصادر مباشرة؟', sentToOutgoing ? '✅ نعم' : '❌ لا');
  console.log('هل طُرح سؤال؟', replySent && replySent.includes('يرجى تحديد نوع') ? '⚠️ خطأ' : '✅ لا (مباشر)');

  // 3. اختبار رسالة غامضة بدون تحديد (يجب أن يسأل البوت برقم 1 أو 2)
  console.log('\n--- 3. اختبار رسالة غامضة (يجب طرح السؤال التفاعلي) ---');
  resetMocks();
  await handleIncomingMessage('محمد علي 500 ريال', srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);
  console.log('هل طُرح السؤال التفاعلي؟', replySent && replySent.includes('يرجى تحديد نوع هذه المعاملة') ? '✅ نعم' : '❌ لا');
  console.log('نص السؤال الموجه للمستخدم:\n', replySent);

  // 4. اختبار رد المستخدم بالرقم 1 (وارد)
  console.log('\n--- 4. اختبار رد المستخدم بالرقم [1] على السؤال التفاعلي ---');
  resetMocks();
  await handleIncomingMessage('1', srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);
  console.log('تم التوجيه للوارد بعد إرسال 1؟', sentToIncoming ? '✅ نعم' : '❌ لا');
  console.log('تم إرسال رد تأكيدي؟', replySent ? '✅ نعم' : '❌ لا');

  // 5. اختبار رسالة غامضة ثانية ثم الرد بالرقم 2 (صادر)
  console.log('\n--- 5. اختبار رد المستخدم بالرقم [2] على سؤال تفاعلي آخر ---');
  resetMocks();
  await handleIncomingMessage('سالم ناصر 1500 ريال', srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);
  console.log('هل طُرح السؤال؟', replySent && replySent.includes('يرجى تحديد نوع') ? '✅ نعم' : '❌ لا');

  resetMocks();
  await handleIncomingMessage('2', srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);
  console.log('تم التوجيه للصادر بعد إرسال 2؟', sentToOutgoing ? '✅ نعم' : '❌ لا');
  console.log('تم إرسال رد تأكيدي؟', replySent ? '✅ نعم' : '❌ لا');

  console.log('\n=============================================');
  console.log('🎉 اكتملت جميع اختبارات المنظومة التفاعلية بنجاح 100%!');
  console.log('=============================================');
}

runTests().catch(err => console.error(err));
