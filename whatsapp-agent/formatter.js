/**
 * formatter.js
 * منسق رسائل وتقارير الواتساب الاحترافية لإيجنت نظام القسام
 */

const FinancialEngine = require('../modules/FinancialEngine.js');

class WhatsAppReportFormatter {
  /**
   * تنسيق كشف الحوالات الموجه إلى مجموعة المنفذين / الصرافين (المجموعة ب)
   * @param {Array<object>} records
   * @param {object} totals
   * @param {object} config
   * @returns {string}
   */
  static formatForTargetGroup(records, totals, config = {}) {
    const header = config?.messageTemplates?.incomingReportHeader || config?.messageTemplates?.outgoingReportHeader || '📋 *كشف حوالات واردة جديد — نظام القسام*';
    const footer = config?.messageTemplates?.reportFooter || config?.messageTemplates?.outgoingReportFooter || '✅ *تم التحقق والتقفيل آلياً عبر نظام القسام الذكي*';
    const now = new Date();
    const dateStr = now.toLocaleDateString('en-CA');
    const timeStr = now.toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });

    let msg = `${header}\n`;
    msg += `📅 التاريخ: ${dateStr} | ⏰ الوقت: ${timeStr}\n`;
    msg += `🔢 عدد الحوالات: ${records.length}\n`;
    msg += `━━━━━━━━━━━━━━━━━━━━\n\n`;

    records.forEach((r, idx) => {
      const numEmoji = this.getNumberEmoji(idx + 1);
      msg += `${numEmoji} *${r.name || 'بدون اسم'}*\n`;
      if (r.id) {
        msg += `💳 الحساب: \`${r.id}\`\n`;
      }
      msg += `💵 المبلغ: *${FinancialEngine.formatNumber(r.amount, 2)}* ${r.currency}\n`;
      msg += `🇪🇹 المقابل: *${FinancialEngine.formatNumber(r.birrEquivalent)}* بر (سعر: ${r.rate})\n`;
      if (r.cutCents > 0) {
        msg += `✂️ مقطوع: ${r.cutCents} بر\n`;
      }
      msg += `\n`;
    });

    msg += `━━━━━━━━━━━━━━━━━━━━\n`;
    msg += `📊 *ملخص العمليات:*\n`;
    msg += `💰 *إجمالي المقابل بالبر:* ${FinancialEngine.formatNumber(totals.totalBirr)} بر\n`;
    if (totals.totalCutCents > 0) {
      msg += `✂️ *إجمالي السنتات المقطوعة:* ${totals.totalCutCents} بر\n`;
    }
    msg += `💵 *إجمالي المبالغ الأصلية:* ${FinancialEngine.formatNumber(totals.totalAmount, 2)}\n\n`;
    msg += `${footer}`;

    return msg;
  }

  /**
   * تنسيق كشف الحوالات الصادرة وشبكات الصرافة لمجموعة الحوالات الصادرة
   * @param {Array<object>} records
   * @param {object} config
   * @returns {string}
   */
  static formatOutgoingReport(records, config = {}) {
    const header = config?.messageTemplates?.outgoingReportHeader || '📤 *كشف حوالات صادرة (شبكات) — نظام القسام*';
    const footer = config?.messageTemplates?.reportFooter || config?.messageTemplates?.outgoingReportFooter || '✅ *تم التحقق والتقفيل آلياً عبر نظام القسام الذكي*';
    const now = new Date();
    const dateStr = now.toLocaleDateString('en-CA');
    const timeStr = now.toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });

    let msg = `${header}\n`;
    msg += `📅 التاريخ: ${dateStr} | ⏰ الوقت: ${timeStr}\n`;
    msg += `🔢 عدد الحوالات الصادرة: ${records.length}\n`;
    msg += `━━━━━━━━━━━━━━━━━━━━\n\n`;

    let totalAmount = 0;
    records.forEach((r, idx) => {
      const numEmoji = this.getNumberEmoji(idx + 1);
      msg += `${numEmoji} *المستلم: ${r.recipient || 'بدون اسم'}*\n`;
      if (r.sender) {
        msg += `👤 المرسل: ${r.sender}\n`;
      }
      msg += `💵 المبلغ: *${FinancialEngine.formatNumber(r.amount, 2)}* ${r.currency}\n`;
      if (r.network && r.network !== '-') {
        msg += `🌐 الشبكة: ${r.network}\n`;
      }
      if (r.transferNo && r.transferNo !== '-') {
        msg += `🔖 رقم الحوالة: \`${r.transferNo}\`\n`;
      }
      if (r.commission && r.commission !== '-') {
        msg += `🏷️ العمولة: ${r.commission}\n`;
      }
      msg += `\n`;
      totalAmount += (r.amount || 0);
    });

    msg += `━━━━━━━━━━━━━━━━━━━━\n`;
    msg += `📊 *إجمالي المبالغ الصادرة:* ${FinancialEngine.formatNumber(totalAmount, 2)}\n\n`;
    msg += `${footer}`;

    return msg;
  }

  /**
   * تنسيق إشعار التأكيد والرد في مجموعة المصدر (المجموعة أ)
   * @param {Array<object>} records
   * @param {object} totals
   * @param {string} batchId
   * @param {object} config
   * @returns {string}
   */
  static formatAcknowledgment(records, totals, batchId, config = {}) {
    let tpl = config?.messageTemplates?.acknowledgmentReply ||
      '✅ تم استلام وقيد عدد ({count}) حوالات بنجاح.\n💰 إجمالي المقابل: {totalBirr} بر إثيوبي.\n🔢 رقم المعاملة: {batchId}';

    return tpl
      .replace('{count}', records.length)
      .replace('{totalBirr}', FinancialEngine.formatNumber(totals.totalBirr))
      .replace('{batchId}', batchId);
  }

  /**
   * تنسيق إشعار استلام حوالات صادرة
   * @param {Array<object>} records
   * @param {string} batchId
   * @param {object} config
   * @returns {string}
   */
  static formatOutgoingAcknowledgment(records, batchId, config = {}) {
    let tpl = config?.messageTemplates?.outgoingAcknowledgmentReply ||
      '✅ تم استلام وقيد عدد ({count}) حوالات صادرة بنجاح.\n🔢 رقم المعاملة: {batchId}';

    return tpl
      .replace('{count}', records.length)
      .replace('{batchId}', batchId);
  }

  /**
   * توليد إيموجي للأرقام (1️⃣, 2️⃣, ...)
   * @param {number} num
   * @returns {string}
   */
  static getNumberEmoji(num) {
    const emojis = ['0️⃣', '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];
    if (num <= 10) return emojis[num] || `[${num}]`;
    return `[${num}]`;
  }
}

module.exports = WhatsAppReportFormatter;
