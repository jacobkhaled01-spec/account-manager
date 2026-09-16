/**
 * EthiopianParser.js
 * محلل الكشوف الإثيوبية والبنكية التقليدية (الصيغ المجدولة والحسابات المقترنة)
 * يعمل في المتصفح و Node.js
 */

class EthiopianParser {
  /**
   * تحليل نصوص الحوالات الواردة التقليدية
   * @param {string} text
   * @param {object} options خيارات (سعر الصرف، العملة، التاريخ)
   * @returns {{ records: Array<object>, detectedDate: string, detectedHeader: string, textTotal: number|null, calculatedTotalAmount: number, calculatedTotalBirr: number, calculatedTotalCutCents: number, count: number }}
   */
  static parse(text, options = {}) {
    if (!text || !text.trim()) {
      return {
        records: [],
        detectedDate: '',
        detectedHeader: '',
        textTotal: null,
        calculatedTotalAmount: 0,
        calculatedTotalBirr: 0,
        calculatedTotalCutCents: 0,
        count: 0
      };
    }

    const rate = Number(options.rate) || 48;
    const currency = options.currency || 'ريال سعودي';
    const autoDate = options.autoDate !== undefined ? options.autoDate : true;
    let customDate = options.customDate || '';

    let detectedDate = customDate;
    if (!detectedDate && autoDate) {
      const dateMatch = text.match(/\b(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})\b/);
      if (dateMatch) {
        detectedDate = dateMatch[1];
      }
    }
    if (!detectedDate) {
      const today = new Date();
      detectedDate = today.toLocaleDateString('en-CA');
    }

    const lines = text.split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0);
    const parsedRecords = [];
    let pendingRecord = null;
    let textTotal = null;
    let detectedHeader = '';

    if (lines.length > 0 && !lines[0].includes('=') && !/^\d+$/.test(lines[0])) {
      detectedHeader = lines[0];
    }

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (/^[\*\-\=\_\#\.]+$/.test(line)) {
        continue;
      }

      // تجاهل أسطر الإجماليات الفرعية أو أسطر السنتات
      if (/^(?:total\s+small|total\s+large|total\s+cut\s+cents|اجمالي\s+السنتات|إجمالي\s+السنتات)/i.test(line)) {
        continue;
      }

      const totalMatch = line.match(/^(?:total|المجموع|الإجمالي)\s*[:=]\s*([\d,]+(?:\.\d+)?)/i);
      if (totalMatch) {
        textTotal = Math.trunc(parseFloat(totalMatch[1].replace(/,/g, '')));
        continue;
      }

      if (line.includes('=')) {
        if (pendingRecord) {
          parsedRecords.push(pendingRecord);
          pendingRecord = null;
        }

        const eqIndex = line.indexOf('=');
        const leftPart = line.substring(0, eqIndex).trim();
        const rightPart = line.substring(eqIndex + 1).trim();

        const seqMatch = leftPart.match(/^(\d+)[\s\,\'\.\-\_]*/);
        const originalSeq = seqMatch ? parseInt(seqMatch[1]) : (parsedRecords.length + 1);

        let cleanedName = leftPart.replace(/^\d+[\s\,\'\.\-\_]+/, '').trim();
        cleanedName = cleanedName.replace(/^[\'\"\‘\’]+/, '').trim();

        let rowCurrency = currency;
        const currMatch = rightPart.match(/[A-Za-z\u0600-\u06FF\$]{2,}/);
        if (currMatch) {
          const rawCurr = currMatch[0].trim();
          if (/^sar$/i.test(rawCurr) || /سعودي/i.test(rawCurr)) {
            rowCurrency = 'ريال سعودي';
          } else if (/^usd$/i.test(rawCurr) || /دولار/i.test(rawCurr) || rawCurr === '$') {
            rowCurrency = 'دولار أمريكي';
          } else {
            rowCurrency = rawCurr;
          }
        }

        let norm = rightPart.trim();
        if (/,\d{1,2}$/.test(norm)) {
          const idx = norm.lastIndexOf(',');
          norm = norm.substring(0, idx).replace(/,/g, '') + '.' + norm.substring(idx + 1);
        } else {
          norm = norm.replace(/,/g, '');
        }
        norm = norm.replace(/[^\d\.]/g, '');

        const amount = parseFloat(norm) || 0;

        let birrEquivalent = 0;
        let cutCents = 0;

        if (typeof FinancialEngine !== 'undefined' && FinancialEngine.calculateBirr) {
          const calc = FinancialEngine.calculateBirr(amount, rate, rowCurrency);
          birrEquivalent = calc.birrEquivalent;
          cutCents = calc.cutCents;
        } else {
          const rawBirr = amount * rate;
          birrEquivalent = Math.floor(rawBirr / 100) * 100;
          cutCents = Math.round((rawBirr - birrEquivalent) * 100) / 100;
        }

        pendingRecord = {
          originalSeq: originalSeq,
          date: detectedDate,
          name: cleanedName,
          id: '',
          amount: amount,
          currency: rowCurrency,
          rate: rate,
          birrEquivalent: birrEquivalent,
          cutCents: cutCents
        };
        continue;
      }

      if (pendingRecord) {
        const accountMatch = line.match(/^[\d\s\-]{6,}$/);
        if (accountMatch) {
          pendingRecord.id = line.replace(/[\s\-]/g, '');
          parsedRecords.push(pendingRecord);
          pendingRecord = null;
          continue;
        } else if (!line.includes('=') && !/^(ዓዲ|ዝሕወሎم|total)/i.test(line)) {
          pendingRecord.id = line;
          parsedRecords.push(pendingRecord);
          pendingRecord = null;
          continue;
        }
      }
    }

    if (pendingRecord) {
      parsedRecords.push(pendingRecord);
    }

    const calculatedTotalAmount = parsedRecords.reduce((sum, r) => sum + r.amount, 0);
    const calculatedTotalBirr = parsedRecords.reduce((sum, r) => sum + r.birrEquivalent, 0);
    const calculatedTotalCutCents = Math.round(parsedRecords.reduce((sum, r) => sum + (r.cutCents || 0), 0) * 100) / 100;

    return {
      records: parsedRecords,
      detectedDate,
      detectedHeader,
      textTotal,
      calculatedTotalAmount,
      calculatedTotalBirr,
      calculatedTotalCutCents,
      count: parsedRecords.length
    };
  }
}

// تصدير متوافق للبيئتين (Node.js & Browser)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = EthiopianParser;
}
if (typeof window !== 'undefined') {
  window.EthiopianParser = EthiopianParser;
}
