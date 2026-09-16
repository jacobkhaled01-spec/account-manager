/**
 * OutgoingParser.js
 * محلل الحوالات الصادرة وشبكات الصرافة وفصل النصوص المركبة
 * يعمل في المتصفح و Node.js
 */

class OutgoingParser {
  /**
   * تحليل نصوص الحوالات الصادرة واستخراج بيانات المستلم والمرسل والشبكة والمبلغ
   * @param {string} text
   * @returns {Array<object>}
   */
  static parseOutgoingText(text) {
    if (!text || !text.trim()) return [];

    const records = [];
    const normalized = text.replace(/\r\n/g, '\n');
    const rawBlocks = normalized.split(/(?=(?:\*\(ارسال حوالة\)\*|\(ارسال حوالة\)|ارسال حوالة|^المستلم\b|^[^\n\=]{2,}\=[\d,]+|(?:\n\s*[-_=*]{3,}\s*\n)))/m);

    for (let rawBlock of rawBlocks) {
      let block = rawBlock.trim();
      if (!block) continue;
      block = block.replace(/^[-_=*]{3,}\s*/, '').trim();
      if (!block) continue;

      // قالب إشعار إرسال حوالة عبر شبكة صرافة (الأكوع، المحيط، الخ)
      if (/ارسال\s*حوال[ةه]|حوال[ةه]\s*صادرة/i.test(block) || /خصم\s*[\d,]+/.test(block)) {
        let amount = 0;
        let currency = 'ريال سعودي';
        let commission = '';
        let network = '';
        let transferNo = '';
        let recipient = '';
        let sender = '';

        // استخراج المبلغ والعملة والعمولة
        const discountMatch = block.match(/خصم\s*([\d,]+(?:\.\d+)?)\s*\*?([^\*\n\r]+?)\*?\s*عمول[ةه]\s*([\d,]+(?:\.\d+)?\s*[^\n\r]*)/i);
        if (discountMatch) {
          amount = parseFloat(discountMatch[1].replace(/,/g, '')) || 0;
          currency = discountMatch[2].replace(/\*/g, '').trim();
          commission = discountMatch[3].trim();
        } else {
          const amtMatch = block.match(/خصم\s*([\d,]+(?:\.\d+)?)\s*\*?([^\*\n\r]+?)\*?(?:\s|$)/i);
          if (amtMatch) {
            amount = parseFloat(amtMatch[1].replace(/,/g, '')) || 0;
            currency = amtMatch[2].replace(/\*/g, '').trim();
          }
          const commMatch = block.match(/عمول[ةه]\s*([\d,]+(?:\.\d+)?\s*[^\n\r]*)/i);
          if (commMatch) commission = commMatch[1].trim();
        }

        // اسم الشبكة
        const netMatch = block.match(/(?:حوال[ةه]\s*صادرة\s*)?عبر\s*(?:الادارة|الإدارة|شبكة)?\s*:\s*([^\n\r]+)/i);
        if (netMatch) {
          network = netMatch[1].trim();
        }

        // رقم الحوالة / المرجع
        const refMatch = block.match(/(?:رقم\s*الحوال[ةه]|رقم\s*الاشعار|رقم\s*العملي[ةه]|المرجع)\s*:\s*([^\n\r]+)/i);
        if (refMatch) {
          transferNo = refMatch[1].trim();
        }

        // المستلم
        const recMatch = block.match(/\*?المستلم\*?\s*:\s*([^\n\r]+)/i);
        if (recMatch) {
          recipient = recMatch[1].replace(/\*/g, '').trim();
        }

        // المرسل
        const sndMatch = block.match(/\*?المرسل\*?\s*:\s*([^\n\r]+)/i);
        if (sndMatch) {
          sender = sndMatch[1].replace(/\*/g, '').trim();
        }

        if (recipient || sender || amount > 0) {
          records.push({
            type: 'outgoing',
            recipient,
            sender,
            amount,
            currency,
            commission: commission || '-',
            network: network || '-',
            transferNo: transferNo || '-',
            date: new Date().toLocaleDateString('en-CA'),
            notes: ''
          });
          continue;
        }
      }

      // قالب المستلم والمرسل الرأسي
      if (/المستلم/i.test(block) && /المرسل/i.test(block)) {
        const lines = block.split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0 && !/^[-_=*]{3,}$/.test(l));
        let recipient = '';
        let sender = '';
        let amount = 0;
        let currency = '';
        let network = '';

        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];

          if (/^المستلم\s*[:\-]?$/i.test(line) && i + 1 < lines.length) {
            recipient = lines[i + 1];
            i++;
            continue;
          } else if (/^المستلم\s*[:\-]\s*(.+)/i.test(line)) {
            recipient = line.match(/^المستلم\s*[:\-]\s*(.+)/i)[1].trim();
            continue;
          }

          if (/^المرسل\s*[:\-]?$/i.test(line) && i + 1 < lines.length) {
            sender = lines[i + 1];
            i++;
            continue;
          } else if (/^المرسل\s*[:\-]\s*(.+)/i.test(line)) {
            sender = line.match(/^المرسل\s*[:\-]\s*(.+)/i)[1].trim();
            continue;
          }

          const amtMatch = line.match(/^([\d,]+(?:\.\d+)?)\s*(\$|USD|SAR|EUR|AED|دولار|سعودي|درهم|ريال)?$/i);
          if (amtMatch) {
            amount = parseFloat(amtMatch[1].replace(/,/g, '')) || 0;
            const currSymbol = (amtMatch[2] || '').trim();
            if (currSymbol === '$' || /^usd$/i.test(currSymbol) || /دولار/i.test(currSymbol)) {
              currency = 'دولار ($)';
            } else if (/^sar$/i.test(currSymbol) || /سعودي/i.test(currSymbol)) {
              currency = 'سعودي (SAR)';
            } else {
              currency = currSymbol || 'ريال سعودي';
            }
            continue;
          }

          if (!line.includes('=') && !/^(المستلم|المرسل|total|\d+)/i.test(line)) {
            network = line;
          }
        }

        if (recipient || sender || amount > 0) {
          records.push({
            type: 'outgoing',
            recipient,
            sender,
            amount,
            currency: currency || 'ريال سعودي',
            commission: '-',
            network: network || '-',
            transferNo: '-',
            date: new Date().toLocaleDateString('en-CA'),
            notes: ''
          });
          continue;
        }
      }

      // قالب الحوالة بالصيغة (Name=Amount Currency \n AccountNo)
      if (block.includes('=')) {
        const lines = block.split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0 && !/^[-_=*]{3,}$/.test(l));
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          if (line.includes('=')) {
            const parts = line.split('=');
            const name = parts[0].replace(/^\d+[\s\,\'\.\-\_]+/, '').trim();
            const rightPart = parts[1].trim();
            const amtMatch = rightPart.match(/^([\d,]+(?:\.\d+)?)\s*([A-Za-z\u0600-\u06FF\$]+)?/);
            const amount = amtMatch ? parseFloat(amtMatch[1].replace(/,/g, '')) : 0;
            const curr = amtMatch && amtMatch[2] ? amtMatch[2].trim() : 'SAR';
            let accNo = '';
            if (i + 1 < lines.length && /^[\d\s\-]{6,}$/.test(lines[i + 1])) {
              accNo = lines[i + 1].replace(/[\s\-]/g, '');
              i++;
            }
            records.push({
              type: 'outgoing',
              recipient: name,
              sender: '-',
              amount,
              currency: curr,
              commission: '-',
              network: '-',
              transferNo: accNo,
              date: new Date().toLocaleDateString('en-CA'),
              notes: ''
            });
          }
        }
      }
    }

    return records;
  }

  /**
   * تقسيم النصوص المختلطة التي تحتوي على حوالات واردة وحوالات صادرة معاً
   * @param {string} rawText
   * @returns {{ incomingBlocks: Array<string>, outgoingBlocks: Array<string> }}
   */
  static splitMixedText(rawText) {
    if (!rawText) return { incomingBlocks: [], outgoingBlocks: [] };

    const rawBlocks = rawText.split(/(?:\r?\n)(?:[-=_*~]{3,}|_{3,}|={3,})(?:\r?\n)/);
    const incomingBlocks = [];
    const outgoingBlocks = [];

    for (let block of rawBlocks) {
      const trimmed = block.trim();
      if (!trimmed) continue;

      const hasOutgoingSigns = /ارسال\s*حوال[ةه]|حوال[ةه]\s*صادرة|خصم\s*[\d,]+|(?:المستلم[\s\S]*?المرسل)|(?:المرسل[\s\S]*?المستلم)/i.test(trimmed);
      const hasIncomingSigns = /\b\d+[\,\'\.\-\_].+=\s*[\d,]+|ዓዲ|total\s*=\s*[\d,]+/i.test(trimmed);

      if (hasOutgoingSigns && !hasIncomingSigns) {
        outgoingBlocks.push(trimmed);
      } else if (hasIncomingSigns && !hasOutgoingSigns) {
        incomingBlocks.push(trimmed);
      } else if (hasOutgoingSigns && hasIncomingSigns) {
        const lines = trimmed.split('\n');
        let curLines = [];
        let curType = null;

        const flush = () => {
          if (curLines.length === 0) return;
          const txt = curLines.join('\n').trim();
          if (txt) {
            if (curType === 'outgoing') outgoingBlocks.push(txt);
            else incomingBlocks.push(txt);
          }
          curLines = [];
        };

        for (let line of lines) {
          const lTrim = line.trim();
          if (/^\*?\(\s*ارسال\s*حوال[ةه]\s*\)\*?/i.test(lTrim) || /^(\*)?المستلم(\*)?\s*$/i.test(lTrim)) {
            flush();
            curType = 'outgoing';
            curLines.push(line);
          } else if (/^\d+[\,\'\.\-\_].+=[\d,]+/i.test(lTrim) || /^ዓዲ/i.test(lTrim)) {
            flush();
            curType = 'incoming';
            curLines.push(line);
          } else {
            curLines.push(line);
          }
        }
        flush();
      } else {
        if (trimmed.includes('=')) {
          incomingBlocks.push(trimmed);
        } else {
          outgoingBlocks.push(trimmed);
        }
      }
    }

    return {
      incomingBlocks,
      outgoingBlocks,
      incomingText: incomingBlocks.join('\n\n'),
      outgoingText: outgoingBlocks.join('\n\n-----------------\n\n'),
      hasIncoming: incomingBlocks.length > 0,
      hasOutgoing: outgoingBlocks.length > 0
    };
  }
}

// تصدير متوافق للبيئتين (Node.js & Browser)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = OutgoingParser;
}
if (typeof window !== 'undefined') {
  window.OutgoingParser = OutgoingParser;
}
