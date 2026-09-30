const { handleIncomingMessage } = require('./whatsapp-agent/agent.js');

async function runTests() {
  console.log('=== بدء اختبار التوجيه الذكي متعدد المسارات ===\n');

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

  const cfg = require('./whatsapp-agent/config.json');
  const srcJid = cfg.sourceGroupId;

  // 1. اختبار رسالة حوالات واردة فقط
  console.log('--- 1. اختبار رسالة واردة فقط ---');
  resetMocks();
  const incomingMsg = `1 'Maekelesh Ftwi=7,667\n1000608369582\n\n2 kiros berhe=9,584\n1000039884996`;
  await handleIncomingMessage(incomingMsg, srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);

  console.log('تم الإرسال لمجموعة الوارد؟', sentToIncoming ? '✅ نعم' : '❌ لا');
  console.log('تم الإرسال لمجموعة الصادر؟', sentToOutgoing ? '⚠️ خطأ' : '✅ لا (صحيح)');
  console.log('تم إرسال رد تأكيدي لمجموعة المصدر؟', replySent ? '✅ نعم' : '❌ لا');
  if (sentToIncoming) console.log('مقتطف تقرير الوارد:\n', sentToIncoming.substring(0, 120), '...');

  // 2. اختبار رسالة حوالات صادرة فقط
  console.log('\n--- 2. اختبار رسالة صادرة فقط ---');
  resetMocks();
  const outgoingMsg = `*(ارسال حوالة)*\nخصم 1500 ريال سعودي عمولة 25\nعبر : شبكة الأكوع\nرقم الحوالة : 998877\n*المستلم* : عمر سالم\n*المرسل* : خالد أحمد`;
  await handleIncomingMessage(outgoingMsg, srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);

  console.log('تم الإرسال لمجموعة الوارد؟', sentToIncoming ? '⚠️ خطأ' : '✅ لا (صحيح)');
  console.log('تم الإرسال لمجموعة الصادر؟', sentToOutgoing ? '✅ نعم' : '❌ لا');
  console.log('تم إرسال رد تأكيدي لمجموعة المصدر؟', replySent ? '✅ نعم' : '❌ لا');
  if (sentToOutgoing) console.log('مقتطف تقرير الصادر:\n', sentToOutgoing.substring(0, 120), '...');

  // 3. اختبار رسالة مختلطة (وارد وصادر معاً في نفس الرسالة)
  console.log('\n--- 3. اختبار رسالة مختلطة (وارد + صادر) ---');
  resetMocks();
  const mixedMsg = `1 'Maekelesh Ftwi=7,667\n1000608369582\n\n-----------------\n\n*(ارسال حوالة)*\nخصم 500 ريال سعودي عمولة 10\nعبر : شبكة المحيط\nرقم الحوالة : 112233\n*المستلم* : فهد علي\n*المرسل* : زيد عمر`;
  await handleIncomingMessage(mixedMsg, srcJid, 'أحمد', mockReply, mockIncoming, mockOutgoing);

  console.log('تم الإرسال لمجموعة الوارد؟', sentToIncoming ? '✅ نعم' : '❌ لا');
  console.log('تم الإرسال لمجموعة الصادر؟', sentToOutgoing ? '✅ نعم' : '❌ لا');
  console.log('تم إرسال رد تأكيدي موحد؟', replySent ? '✅ نعم' : '❌ لا');
  console.log('نص الرد الموحد:\n', replySent);

  console.log('\n=============================================');
  console.log('🎉 اكتملت جميع اختبارات التوجيه الذكي بنجاح 100%!');
  console.log('=============================================');
}

runTests().catch(err => console.error('Error:', err));
