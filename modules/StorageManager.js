/**
 * StorageManager.js
 * مدير التخزين والحفظ التلقائي وسجل العمليات
 * يعمل في المتصفح ويوفر واجهة حفظ واسترجاع آمنة
 */

class StorageManager {
  static KEYS = {
    INCOMING: 'sharaf_incoming_records',
    OUTGOING: 'sharaf_outgoing_records',
    AUDIT_LOG: 'sharaf_audit_log',
    SETTINGS: 'sharaf_settings',
    THEME: 'sharaf_theme'
  };

  /**
   * قراءة آمنة من localStorage
   * @param {string} key
   * @param {*} fallback
   * @returns {*}
   */
  static get(key, fallback = null) {
    if (typeof localStorage === 'undefined') return fallback;
    try {
      const val = localStorage.getItem(key);
      return val ? JSON.parse(val) : fallback;
    } catch (e) {
      console.warn(`[StorageManager] Failed to read "${key}":`, e);
      return fallback;
    }
  }

  /**
   * كتابة آمنة إلى localStorage
   * @param {string} key
   * @param {*} value
   * @returns {boolean}
   */
  static set(key, value) {
    if (typeof localStorage === 'undefined') return false;
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (e) {
      console.warn(`[StorageManager] Failed to write "${key}":`, e);
      return false;
    }
  }

  /**
   * حذف مفتاح من localStorage
   * @param {string} key
   */
  static remove(key) {
    if (typeof localStorage === 'undefined') return;
    try {
      localStorage.removeItem(key);
    } catch (e) {
      console.warn(`[StorageManager] Failed to remove "${key}":`, e);
    }
  }

  /**
   * استرجاع سجلات الحوالات الواردة
   * @returns {Array<object>}
   */
  static loadIncomingRecords() {
    return this.get(this.KEYS.INCOMING, []);
  }

  /**
   * حفظ سجلات الحوالات الواردة
   * @param {Array<object>} records
   */
  static saveIncomingRecords(records) {
    return this.set(this.KEYS.INCOMING, records);
  }

  /**
   * استرجاع سجلات الحوالات الصادرة
   * @returns {Array<object>}
   */
  static loadOutgoingRecords() {
    return this.get(this.KEYS.OUTGOING, []);
  }

  /**
   * حفظ سجلات الحوالات الصادرة
   * @param {Array<object>} records
   */
  static saveOutgoingRecords(records) {
    return this.set(this.KEYS.OUTGOING, records);
  }

  /**
   * استرجاع سجل العمليات التاريخي
   * @returns {Array<object>}
   */
  static loadAuditLog() {
    return this.get(this.KEYS.AUDIT_LOG, []);
  }

  /**
   * حفظ سجل العمليات التاريخي
   * @param {Array<object>} log
   */
  static saveAuditLog(log) {
    return this.set(this.KEYS.AUDIT_LOG, log);
  }

  /**
   * استرجاع الإعدادات
   * @param {object} defaults
   * @returns {object}
   */
  static loadSettings(defaults = {}) {
    return Object.assign({}, defaults, this.get(this.KEYS.SETTINGS, {}));
  }

  /**
   * حفظ الإعدادات
   * @param {object} settings
   */
  static saveSettings(settings) {
    return this.set(this.KEYS.SETTINGS, settings);
  }

  /**
   * تصدير نسخة احتياطية كاملة (JSON Snapshot)
   * @returns {string}
   */
  static exportFullBackup() {
    const backup = {
      version: '1.5.0',
      exportedAt: new Date().toISOString(),
      incoming: this.loadIncomingRecords(),
      outgoing: this.loadOutgoingRecords(),
      settings: this.loadSettings(),
      auditLog: this.loadAuditLog()
    };
    return JSON.stringify(backup, null, 2);
  }

  /**
   * استيراد نسخة احتياطية كاملة
   * @param {string} jsonString
   * @returns {boolean}
   */
  static importFullBackup(jsonString) {
    try {
      const data = JSON.parse(jsonString);
      if (Array.isArray(data.incoming)) this.saveIncomingRecords(data.incoming);
      if (Array.isArray(data.outgoing)) this.saveOutgoingRecords(data.outgoing);
      if (data.settings && typeof data.settings === 'object') this.saveSettings(data.settings);
      if (Array.isArray(data.auditLog)) this.saveAuditLog(data.auditLog);
      return true;
    } catch (e) {
      console.error('[StorageManager] Failed to import backup:', e);
      return false;
    }
  }
}

// تصدير متوافق للبيئتين (Node.js & Browser)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = StorageManager;
}
if (typeof window !== 'undefined') {
  window.StorageManager = StorageManager;
}
