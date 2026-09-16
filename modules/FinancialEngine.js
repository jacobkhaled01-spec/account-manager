/**
 * FinancialEngine.js
 * المحرك المالي النقي لنظام القسام
 * يدعم العمل المزدوج (Browser + Node.js)
 */

class FinancialEngine {
  /**
   * حساب المقابل بالبر مع استقطاع السنتات وتقفيل المئات
   * @param {number} amount المبلغ بالعملة الأصلية
   * @param {number} rate سعر الصرف
   * @param {string} currency العملة (ريال سعودي / دولار أمريكي / بر إثيوبي)
   * @returns {{ birrEquivalent: number, cutCents: number, rawBirr: number }}
   */
  static calculateBirr(amount, rate, currency = 'ريال سعودي') {
    const numAmount = Number(amount) || 0;
    const numRate = Number(rate) || 1;

    // إذا كانت العملة بالبر الإثيوبي مباشرة
    if (this.isBirr(currency)) {
      return {
        birrEquivalent: numAmount,
        cutCents: 0,
        rawBirr: numAmount
      };
    }

    const rawBirr = numAmount * numRate;
    // تقفيل المئات: استقطاع العشرات والآحاد والكسور
    const birrEquivalent = Math.floor(rawBirr / 100) * 100;
    // السنتات المقطوعة بدقة
    const cutCents = Math.round((rawBirr - birrEquivalent) * 100) / 100;

    return {
      birrEquivalent,
      cutCents,
      rawBirr
    };
  }

  /**
   * فحص إذا كانت العملة بر إثيوبي
   * @param {string} currency
   * @returns {boolean}
   */
  static isBirr(currency) {
    if (!currency) return false;
    const c = String(currency).trim().toLowerCase();
    return c === 'etb' || c === 'birr' || c === 'بر' || c === 'بر إثيوبي' || c.includes('بر');
  }

  /**
   * تطبيع العملة وتوحيد مسماها
   * @param {string} rawCurr
   * @param {string} defaultCurrency
   * @returns {string}
   */
  static normalizeCurrency(rawCurr, defaultCurrency = 'ريال سعودي') {
    if (!rawCurr) return defaultCurrency;
    const c = String(rawCurr).trim();

    if (/^(sar|ر\.س|سعودي|ريال|ريال سعودي)$/i.test(c)) {
      return 'ريال سعودي';
    }
    if (/^(usd|\$|دولار|دولار أمريكي)$/i.test(c)) {
      return 'دولار أمريكي';
    }
    if (/^(etb|birr|بر|بر إثيوبي)$/i.test(c)) {
      return 'بر إثيوبي';
    }
    return c;
  }

  /**
   * تطبيع واستخراج الرقم من أي نص مالي
   * @param {string|number} raw
   * @returns {number}
   */
  static normalizeAmount(raw) {
    if (typeof raw === 'number') return isNaN(raw) ? 0 : raw;
    if (!raw) return 0;

    let str = String(raw).trim();
    // معالجة الفاصلة العشرية الأوروبية/اللاتينية إن وجدت في نهاية الرقم
    if (/,\d{1,2}$/.test(str)) {
      const lastComma = str.lastIndexOf(',');
      str = str.substring(0, lastComma).replace(/,/g, '') + '.' + str.substring(lastComma + 1);
    } else {
      str = str.replace(/,/g, '');
    }

    str = str.replace(/[^\d\.]/g, '');
    const num = parseFloat(str);
    return isNaN(num) ? 0 : num;
  }

  /**
   * تنسيق الأرقام مع فواصل الآلاف
   * @param {number} num
   * @param {number} decimals
   * @returns {string}
   */
  static formatNumber(num, decimals = 0) {
    if (num === null || num === undefined || isNaN(num)) return '0';
    return Number(num).toLocaleString('en-US', {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    });
  }

  /**
   * حساب الإجماليات لمجموعة سجلات
   * @param {Array} records
   * @returns {{ totalAmount: number, totalBirr: number, totalCutCents: number, count: number }}
   */
  static calculateTotals(records = []) {
    let totalAmount = 0;
    let totalBirr = 0;
    let totalCutCents = 0;

    for (const r of records) {
      totalAmount += Number(r.amount) || 0;
      totalBirr += Number(r.birrEquivalent) || 0;
      totalCutCents += Number(r.cutCents) || 0;
    }

    return {
      totalAmount: Math.round(totalAmount * 100) / 100,
      totalBirr: Math.round(totalBirr),
      totalCutCents: Math.round(totalCutCents * 100) / 100,
      count: records.length
    };
  }
}

// تصدير متوافق للبيئتين (Node.js & Browser)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FinancialEngine;
}
if (typeof window !== 'undefined') {
  window.FinancialEngine = FinancialEngine;
}
