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
   * تقسيم النص الكامل إلى فقاعات رسائل منفصلة
   * @param {string} text
   * @returns {Array<string>}
   */
  static parseWhatsAppBubbles(text) {
    const rawClean = this.cleanInvisible(text);
    const regex = new RegExp(this.WHATSAPP_HEADER_REGEX.source, 'gi');
    const matches = [];
    let match;

    while ((match = regex.exec(rawClean)) !== null) {
      matches.push({ index: match.index, length: match[0].length });
    }

    const bubbles = [];
    if (matches.length > 0) {
      for (let i = 0; i < matches.length; i++) {
        const start = matches[i].index + matches[i].length;
        const end = (i + 1 < matches.length) ? matches[i + 1].index : rawClean.length;
        const content = rawClean.slice(start, end).trim();
        if (content) bubbles.push(content);
      }
    } else {
      // إذا لم تكن هناك ترويسات واتساب، التقسيم بأسطر فارغة
      const parts = rawClean.split(/\n\s*\n/).map(b => b.trim()).filter(Boolean);
      bubbles.push(...parts);
    }
    return bubbles;
  }

  /**
   * استخراج المبلغ والعملة بدقة متقدمة
   * @param {string} bubbleText
   * @returns {{ amount: number, currency: string, original: string } | null}
   */
  static parseAmountAndCurrency(bubbleText) {
    const cleaned = this.cleanInvisible(bubbleText);

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

    return null;
  }

  /**
   * تنظيف واستخراج اسم المستفيد
   * @param {string} nameCandidate
   * @param {string} account
   * @param {object} amountObj
   * @returns {string}
   */
  static cleanPersonName(nameCandidate, account, amountObj) {
    let cleaned = nameCandidate;
    if (account) {
      cleaned = cleaned.replace(account, ' ');
    }
    if (amountObj && amountObj.original) {
      cleaned = cleaned.replace(amountObj.original, ' ');
    }

    cleaned = cleaned
      .replace(/=/g, ' ')
      .replace(/10\s*مليون/g, ' ')
      .replace(/\bمليون\b/g, ' ')
      .replace(/\b(SAR|ryl|birr?|سعودي|ريال|دولار|usd|etb)\b/gi, ' ')
      .replace(/بر+/g, ' ')
      .replace(/[.,]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    if (/[a-zA-Z\u0600-\u06FF]/.test(cleaned)) {
      return cleaned;
    }
    return '';
  }

  /**
   * المحلل الرئيسي لرسائل واتساب المنسوخة (بما في ذلك الرسائل المفرقة والمتتالية)
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
    let unassignedPending = []; // عناصر معلقة تنتظر مبالغ

    for (let bIdx = 0; bIdx < bubbles.length; bIdx++) {
      const bubble = bubbles[bIdx];

      // استخراج رقم الحساب (10 إلى 16 خانة غالباً تبدأ بـ 1000)
      let account = '';
      const accMatch = bubble.match(/\b(1000\d{6,12}|\d{10,16})\b/);
      if (accMatch) {
        account = accMatch[1];
      }

      // استخراج المبلغ والعملة
      const amountObj = this.parseAmountAndCurrency(bubble);

      // استخراج الاسم المنقح
      const cleanName = this.cleanPersonName(bubble, account, amountObj);

      // حالة 1: الفقاعة تحتوي على مبلغ فقط (بدون اسم وبدون حساب)
      if (amountObj && !cleanName && !account) {
        if (unassignedPending.length > 0) {
          const target = unassignedPending.pop();
          target.amount = amountObj.amount;
          target.currency = amountObj.currency;
          continue;
        }
      }

      // حالة 2: الفقاعة تحتوي على حساب فقط
      if (account && !cleanName && !amountObj) {
        const matchNoAcc = unassignedPending.find(item => item.name && !item.account);
        if (matchNoAcc) {
          matchNoAcc.account = account;
          unassignedPending = unassignedPending.filter(i => i !== matchNoAcc);
        } else {
          const item = { account, name: '', amount: null, currency: 'SAR' };
          results.push(item);
          unassignedPending.push(item);
        }
        continue;
      }

      // حالة 3: الفقاعة تحتوي على اسم فقط (بدون حساب وبدون مبلغ)
      if (cleanName && !account && !amountObj) {
        const matchOnlyAcc = unassignedPending.find(item => item.account && !item.name);
        if (matchOnlyAcc) {
          matchOnlyAcc.name = cleanName;
        } else {
          const item = { account: '', name: cleanName, amount: null, currency: 'SAR' };
          results.push(item);
          unassignedPending.push(item);
        }
        continue;
      }

      // حالة 4: الفقاعة تحتوي على حساب واسم ولكن بدون مبلغ
      if (account && cleanName && !amountObj) {
        const item = { account, name: cleanName, amount: null, currency: 'SAR' };
        results.push(item);
        unassignedPending.push(item);
        continue;
      }

      // حالة 5: الفقاعة تحتوي على اسم ومبلغ ولكن بدون حساب
      if (cleanName && amountObj && !account) {
        const matchOnlyAcc = unassignedPending.find(item => item.account && !item.name && !item.amount);
        if (matchOnlyAcc) {
          matchOnlyAcc.name = cleanName;
          matchOnlyAcc.amount = amountObj.amount;
          matchOnlyAcc.currency = amountObj.currency;
          unassignedPending = unassignedPending.filter(i => i !== matchOnlyAcc);
        } else {
          results.push({
            account: '',
            name: cleanName,
            amount: amountObj.amount,
            currency: amountObj.currency
          });
        }
        continue;
      }

      // حالة 6: الفقاعة مكتملة (حساب + مبلغ، وربما اسم أيضاً)
      if (amountObj && account) {
        const item = {
          account: account,
          name: cleanName || '',
          amount: amountObj.amount,
          currency: amountObj.currency
        };

        const lastItem = results[results.length - 1];
        if (lastItem && lastItem.account === item.account && lastItem.name.toLowerCase() === item.name.toLowerCase()) {
          lastItem.amount = item.amount;
          lastItem.currency = item.currency;
        } else {
          results.push(item);
        }
        continue;
      }
    }

    // تحويل النتائج إلى السجلات المعيارية للنظام
    const standardRecords = results.map((item, idx) => {
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
