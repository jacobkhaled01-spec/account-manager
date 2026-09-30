function splitIntoItems(text) {
  // 1. استبعاد أسطر المجاميع الختامية
  let cleaned = text.replace(/^\s*(?:total|المجموع|الإجمالي|الصافي|التقرير)\s*[:=].*$/gmi, '');

  // 2. تحويل خطوط الفواصل النجمية أو الشرطات إلى فواصل فقرات
  cleaned = cleaned.replace(/\n\s*[\*\-_=~]{3,}\s*(?=\n|$)/g, '\n\n');

  // 3. تقسيم حسب الترويسات أو الأسطر الفارغة
  const rawBlocks = cleaned.split(/\n\s*\n/).map(b => b.trim()).filter(Boolean);
  
  const items = [];
  for (const block of rawBlocks) {
    // هل يحتوي البلوك على أكثر من حساب أو أكثر من بند مرقم؟
    // فحص كم حساب بنكي موجود في هذا البلوك
    const accs = block.match(/\b(1000\d{6,12}|\d{10,16})\b/g);
    if (accs && accs.length > 1) {
      // تقسيم البلوك بناءً على بداية البنود المرقمة: مثلاً 24' أو 24. أو 24- أو 24 
      const lines = block.split('\n');
      let currentItem = [];
      for (const line of lines) {
        if (/^\s*\d+['.,\)\-\s]/.test(line) && currentItem.length > 0) {
          // تحقق هل العنصر الحالي يحتوي بالفعل على حساب
          const currentText = currentItem.join('\n');
          if (/\b(1000\d{6,12}|\d{10,16})\b/.test(currentText)) {
            items.push(currentText.trim());
            currentItem = [line];
            continue;
          }
        }
        currentItem.push(line);
      }
      if (currentItem.length > 0) {
        items.push(currentItem.join('\n').trim());
      }
    } else {
      items.push(block);
    }
  }

  return items;
}

const fs = require('fs');
const scratch = fs.readFileSync('./scratch_test_message.js', 'utf8');
const msg = scratch.match(/const testMsg = `([\s\S]*?)`;/)[1];
const items = splitIntoItems(msg);
console.log('Items count:', items.length);
console.log('First item:\n', items[0]);
console.log('---');
console.log('Item 23:\n', items[22]);
console.log('Item 24:\n', items[23]);
console.log('---');
console.log('Item 34:\n', items[33]);
