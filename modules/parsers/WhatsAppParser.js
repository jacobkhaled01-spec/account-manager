/**
 * WhatsAppParser.js
 * محلل رسائل الواتساب الذكي لنظام القسام
 * مبني ومختبر لمعالجة جميع أشكال الرسائل المجزأة والمتتالية والمرسلة بأي اسم أو لغة
 * يدعم العمل المزدوج (Browser + Node.js)
 */

class WhatsAppParser {
  /**
   * التعبير النمطي الشامل لترويسات رسائل الواتساب بمختلف صيغها (تاريخ، وقت، اسم المرسل مهما كان)
   */
  static WHATSAPP_HEADER_REGEX = /(?:^|\n)(?:\[\d{1,4}[\/\-\.]\d{1,2}(?:[\/\-\.]\d{2,4})?,?[^\]]*\]|\b\d{1,4}[\/\-\.]\d{1,2}(?:[\/\-\.]\d{2,4})?,?[^-\n]*-)\s*[^:\n]+:\s*/gi;

  /**
   * تنظيف الرموز غير المرئية أو رموز الاتجاهية
   * @param {string} str
   * @returns {string}
   */
  static cleanInvisible(str) {
    if (!str) return '';
    return str.replace(/[\u200E\u200F\u202A-\u202E\u202F\u00A0]/g, ' ').trim();
  }

  /**
   * تقسيم النص الكامل إلى فقاعات رسائل منفصلة مع دعم التجزئة الذكية للبلوكات المركبة
   * @param {string} text
   * @returns {Array<string>}
   */
  static parseWhatsAppBubbles(text) {
    let rawClean = this.cleanInvisible(text);

    // 1. استبعاد أسطر المجاميع الختامية (مثل total=227,620 أو المجموع: ...)
    rawClean = rawClean.replace(/^\s*(?:total|المجموع|الإجمالي|الصافي|التقرير)\s*[:=].*$/gmi, '');

    // 2. تحويل خطوط الفواصل النجمية أو الشرطات (مثل ***** أو ------) إلى فواصل فقرات
    rawClean = rawClean.replace(/\n\s*[\*\-_=~]{3,}\s*(?=\n|$)/g, '\n\n');

    const regex = new RegExp(this.WHATSAPP_HEADER_REGEX.source, 'gi');
    const matches = [];
    let match;

    while ((match = regex.exec(rawClean)) !== null) {
      matches.push({ index: match.index, length: match[0].length });
    }

    const rawBubbles = [];
    if (matches.length > 0) {
      for (let i = 0; i < matches.length; i++) {
        const start = matches[i].index + matches[i].length;
        const end = (i + 1 < matches.length) ? matches[i + 1].index : rawClean.length;
        const content = rawClean.slice(start, end).trim();
        if (content) rawBubbles.push(content);
      }
    } else {
      // إذا لم تكن هناك ترويسات واتساب، التقسيم بأسطر فارغة
      const parts = rawClean.split(/\n\s*\n/).map(b => b.trim()).filter(Boolean);
      rawBubbles.push(...parts);
    }

    // 3. التجزئة الذكية للبلوكات التي تحتوي على عدة حوالات بدون أسطر فارغة بينها
    const bubbles = [];
    for (const block of rawBubbles) {
      const accs = block.match(/\b(1000\d{6,12}|\d{10,16})\b/g);
      if (accs && accs.length > 1) {
        const lines = block.split('\n');
        let currentItem = [];
        for (const line of lines) {
          if (/^\s*\d+['.,\)\-\s]/.test(line) && currentItem.length > 0) {
            const currentText = currentItem.join('\n');
            if (/\b(1000\d{6,12}|\d{10,16})\b/.test(currentText)) {
              bubbles.push(currentText.trim());
              currentItem = [line];
              continue;
            }
          }
          currentItem.push(line);
        }
        if (currentItem.length > 0) {
          bubbles.push(currentItem.join('\n').trim());
        }
      } else {
        bubbles.push(block);
      }
    }

    return bubbles;
  }

  /**
   * استخراج المبلغ والعملة بدقة متقدمة
   * @param {string} bubbleText
   * @returns {{ amount: number, currency: string, original: string } | null}
   */
  static parseAmountAndCurrency(bubbleText, account = '') {
    let cleaned = this.cleanInvisible(bubbleText);
    if (account) {
      cleaned = cleaned.replace(account, ' ');
    }

    // 1. فحص الملايين: 10 مليون بر / 2.5 مليون
    const millionMatch = cleaned.match(/(\d+(?:\.\d+)?)\s*مليون(?:\s*(بر+|birr?|ريال|سعودي|sar))?/i);
    if (millionMatch) {
      const num = parseFloat(millionMatch[1]) * 1000000;
      const rawCurr = millionMatch[2] || '';
      let currency = 'ETB';
      if (/ريال|سعودي|sar/i.test(rawCurr)) currency = 'SAR';
      return { amount: num, currency, original: millionMatch[0] };
    }

    // 2. مبالغ مع عملات صريحة: 500 ريال، 4975 SAR، 6000ryl، 120,000. بر بر بر، 100,000 bir
    const currMatch = cleaned.match(/([\d,]+(?:\.\d+)?)\s*(?:[.\s]*)(ريال\s*سعودي|سعودي|ريال|sar|ryl|بر(?:\s*بر)*|بر+|birr?|\$|دولار)/i);
    if (currMatch) {
      const rawNum = currMatch[1].replace(/,/g, '');
      const num = parseFloat(rawNum);
      const currStr = currMatch[2].toLowerCase();
      let currency = 'SAR';
      if (/بر|bir/i.test(currStr)) currency = 'ETB';
      else if (/\$|دولار/i.test(currStr)) currency = 'USD';
      else currency = 'SAR';
      return { amount: num, currency, original: currMatch[0] };
    }

    // 3. رقم مجرد بعد اسم أو مساواة: TEAME TESFAY HAGOS=1490 أو =4975
    const equalNumMatch = cleaned.match(/=\s*([\d,]+(?:\.\d+)?)/);
    if (equalNumMatch) {
      const num = parseFloat(equalNumMatch[1].replace(/,/g, ''));
      return { amount: num, currency: 'SAR', original: equalNumMatch[0] };
    }

    // 4. رقم مستقل في سطر منفرد داخل الرسالة (سطر يحتوي فقط على رقم من 2 إلى 9 أرقام)
    const lines = cleaned.split('\n').map(l => l.trim()).filter(Boolean);
    for (const line of lines) {
      const lineNumMatch = line.match(/^([\d,]{2,9}(?:\.\d+)?)$/);
      if (lineNumMatch) {
        const raw = lineNumMatch[1].replace(/,/g, '');
        const num = parseFloat(raw);
        if (raw.length < 10) {
          return { amount: num, currency: 'SAR', original: line };
        }
      }
    }

    // 5. رقم مجرد مكون من 2 إلى 9 خانات في سطر مشترك (مثل: TEAME TESFAY 1000181711713 4975)
    const standaloneMatch = cleaned.match(/\b([\d,]{2,9}(?:\.\d+)?)\b/);
    if (standaloneMatch) {
      const raw = standaloneMatch[1].replace(/,/g, '');
      const num = parseFloat(raw);
      if (raw.length < 10) {
        return { amount: num, currency: 'SAR', original: standaloneMatch[0] };
      }
    }

    return null;
  }

  /**
   * تنظيف واستخراج اسم المستفيد بدقة مع استبعاد الترقيم والتواريخ
   * @param {string} nameCandidate
   * @param {string} account
   * @param {object} amountObj
   * @returns {string}
   */
  static cleanPersonName(nameCandidate, account, amountObj) {
    let lines = nameCandidate.split('\n').map(l => l.trim()).filter(Boolean);

    // استبعاد السطور التي هي عبارة عن أرقام حسابات فقط أو تواريخ أو فواصل
    lines = lines.filter(l => {
      if (account && l.includes(account)) return false;
      if (/^\d{1,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,4}$/.test(l)) return false;
      if (/^[\*\-_=~]+$/.test(l)) return false;
      return true;
    });

    // اختيار السطر الذي يحتوي على الاسم (الذي فيه علامة = أو حروف اسم)
    let nameLine = '';
    for (const l of lines) {
      if (l.includes('=') || /[a-zA-Z\u0600-\u06FF]{2,}/.test(l)) {
        nameLine = l;
        break;
      }
    }
    if (!nameLine && lines.length > 0) nameLine = lines[0];

    let cleaned = nameLine || nameCandidate;
    if (account) {
      cleaned = cleaned.replace(account, ' ');
    }
    if (amountObj && amountObj.original) {
      cleaned = cleaned.replace(amountObj.original, ' ');
    }

    cleaned = cleaned
      .replace(/=/g, ' ')
      .replace(/^\s*\d+['.,\)\-\s]*/, '') // إزالة الترقيم التسلسلي من بداية الاسم مثل: 1' أو 2. أو 24'
      .replace(/10\s*مليون/g, ' ')
      .replace(/\bمليون\b/g, ' ')
      .replace(/\b(SAR|ryl|birr?|سعودي|ريال|دولار|usd|etb)\b/gi, ' ')
      .replace(/بر+/g, ' ')
      .replace(/[.,]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    if (/[a-zA-Z\u0600-\u06FF]{2,}/.test(cleaned)) {
      return cleaned;
    }
    return '';
  }

  /**
   * استخراج حقول الحوالة (الاسم، الحساب، المبلغ) من فقاعة رسالة أياً كان ترتيبها
   * @param {string} bubble
   * @returns {{ name: string, account: string, amount: number|null, currency: string }}
   */
  static extractFieldsFromBubble(bubble) {
    const text = this.cleanInvisible(bubble).trim();

    // 1. استخراج رقم الحساب (10 إلى 16 خانة، أو يبدأ بـ 100)
    let account = '';
    const accMatch = text.match(/\b(100\d{7,14}|\d{10,16})\b/);
    if (accMatch) {
      account = accMatch[1];
    }

    // 2. استخراج المبلغ والعملة مع عزل رقم الحساب
    const amountObj = this.parseAmountAndCurrency(text, account);

    // 3. استخراج الاسم المنقح
    const cleanName = this.cleanPersonName(text, account, amountObj);

    return {
      name: cleanName,
      account: account,
      amount: amountObj ? amountObj.amount : null,
      currency: amountObj ? amountObj.currency : 'SAR'
    };
  }

  /**
   * المحلل الرئيسي لرسائل واتساب المنسوخة (بما في ذلك الرسائل المفرقة والمتتالية بأي ترتيب كان)
   * @param {string} text النص المنسوخ من واتساب
   * @param {object} options خيارات (سعر الصرف، العملة، التاريخ)
   * @returns {Array<object>} سجلات الحوالات المعيارية
   */
  static parse(text, options = {}) {
    if (!text || !text.trim()) return [];

    const rate = Number(options.rate) || 48;
    const defaultDate = options.date || new Date().toISOString().split('T')[0].replace(/-/g, '/');

    const bubbles = this.parseWhatsAppBubbles(text);
    const results = [];
    let pending = null;

    for (let bIdx = 0; bIdx < bubbles.length; bIdx++) {
      const bubble = bubbles[bIdx];
      const f = this.extractFieldsFromBubble(bubble);

      // إذا كانت الفقاعة مكتملة (اسم + حساب + مبلغ) أياً كان ترتيبها
      if (f.name && f.account && f.amount !== null) {
        if (pending) {
          if (pending.name || pending.account || pending.amount !== null) {
            results.push(pending);
          }
          pending = null;
        }
        results.push(f);
        continue;
      }

      // إذا لم يكن هناك عنصر معلق، نبدأ به
      if (!pending) {
        pending = {
          name: f.name || '',
          account: f.account || '',
          amount: f.amount,
          currency: f.currency || 'SAR'
        };
      } else {
        // فحص التعارض: إذا كان العنصر المعلق يحتوي بالفعل على نفس الحقل ووصلت قيمة جديدة له،
        // فهذا يعني أن الفقاعة تنتمي لحوالة تالية!
        const hasConflict = (f.name && pending.name) ||
                            (f.account && pending.account) ||
                            (f.amount !== null && pending.amount !== null);

        if (hasConflict) {
          results.push(pending);
          pending = {
            name: f.name || '',
            account: f.account || '',
            amount: f.amount,
            currency: f.currency || 'SAR'
          };
        } else {
          // دمج الحقول في العنصر المعلق أياً كان ترتيب وصولها
          if (f.name) pending.name = f.name;
          if (f.account) pending.account = f.account;
          if (f.amount !== null) {
            pending.amount = f.amount;
            pending.currency = f.currency;
          }
        }
      }

      // إذا اكتمل العنصر المعلق (اسم + حساب + مبلغ)
      if (pending.name && pending.account && pending.amount !== null) {
        results.push(pending);
        pending = null;
      }
    }

    if (pending && (pending.account || pending.amount !== null || pending.name)) {
      results.push(pending);
    }

    // استبعاد أي عناصر فارغة لم يتم إقرانها
    const validResults = results.filter(item => (item.amount > 0 || (item.name && item.account)));

    // تحويل النتائج إلى السجلات المعيارية للنظام
    const standardRecords = validResults.map((item, idx) => {
      const amt = item.amount || 0;
      let currName = 'ريال سعودي';
      let birrEquivalent = 0;
      let cutCents = 0;

      if (item.currency === 'ETB') {
        currName = 'بر إثيوبي';
        birrEquivalent = amt;
        cutCents = 0;
      } else if (item.currency === 'USD') {
        currName = 'دولار أمريكي';
        const rawBirr = amt * rate;
        birrEquivalent = Math.floor(rawBirr / 100) * 100;
        cutCents = Math.round((rawBirr - birrEquivalent) * 100) / 100;
      } else {
        currName = 'ريال سعودي';
        const rawBirr = amt * rate;
        birrEquivalent = Math.floor(rawBirr / 100) * 100;
        cutCents = Math.round((rawBirr - birrEquivalent) * 100) / 100;
      }

      return {
        seq: idx + 1,
        date: defaultDate,
        name: item.name,
        id: item.account,
        amount: amt,
        currency: currName,
        rate: rate,
        birrEquivalent: birrEquivalent,
        cutCents: cutCents
      };
    });

    return standardRecords;
  }
}

// تصدير متوافق للبيئتين (Node.js & Browser)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = WhatsAppParser;
}
if (typeof window !== 'undefined') {
  window.WhatsAppParser = WhatsAppParser;
}
