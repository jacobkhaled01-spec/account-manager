/**
 * نظام كشف الحوالات وحسابات الصرافين - المنطق البرمجي الكامل
 * Currency Bureau Accounts Engine - Decimal Truncation, Small/Large Splitting, Real-time Calculations
 */

// نموذج البيانات الافتراضي المأخوذ من طلب المستخدم الدقيق (34 مستفيد)
const SAMPLE_RAW_TEXT = `ዓዲ ዝሕወሎም ዝርዝር 01/13/18
1,'Maekelesh Ftwi=7,667
1000608369582

2,kiros berhe=9,584
1000039884996

3,Letay Grmay=1,917
1000256679896

4'Tesfay G/hiwet G/kidan=9,584
1000266078033

5,mahlet Mengsh=9,584
1000774822066

6,Tuem Berhe= 14,375
1000701515618

7,Shushay  G/anenya=14,375
1000264694508

8,'Guesh Legish=9,584
1000415408882

9'Natsnet Abebe=23,959
1000355462707

10'bahabolom Tesfaalem=4,792
1000726934847

11'Teklit G/medhn=4,792
1000768396225

12'brhane W/maryam=6,709
1000692127084

13'Ethiopia G/tnsaa=4,313
1000318461019

14'Binyam Ftsum=480
1000632937087

15'G/libanos G/slase=9,584
1000601393518

16'mebrhit G/tsadk=19,167
1000295993891

17'mebrahtu K/maryam=4,792
1000021000659

18'kidane Berhe=4,792
1000601202852

19,Saba G/maryam =9,584
1000018869679

20'Mulu g/slase=9,584
1000547946808

21,Merhawi berih=959
1000593852249

22'Tblets Adhanom=4,792
1000505052726

23'Asefa Brhane=7,667
1000537665304
*
24'Teklit tekleslasye=7,188
1000542835153

25'Desaley Hntsa=2,396
1000711754818

26'Berhe Mahari Welu=1,917
1000212261479

27'Rahwa G/hiwet =1,917
1000696250093

28'merhawi welu=1,917
1000580337329 

29'G/wahd Brhane=3,834
1000782289978
****
30'Melat G/medhn=4,792
1000353789612

31'Tsega H/maryam=480
1000783440478

32'Tsegay kahsay=959
1000338021888

33' Mlete Adhanom=4,792
1000215464998

34'Orjinal Angesom Mezgebo=4,792
1000738510465
total=227,620`;

// نموذج قوالب الحوالات الصادرة (الأكوع / مريسي / المحيط)
const SAMPLE_OUTGOING_TEXT = `المستلم 
حاميم شريف علي ثابت
المرسل 
نصير هشام محمد عبدالوهاب
8000$

مريسي

-----------------
*(ارسال حوالة)* 
خصم 15,000 *دولار ازرق* عموله 15 دولار ازرق 
حوالة صادرة عبر : الادارة الاكوع 
رقم الحوالة : 400688572189 
*المستلم*: صبري محمد مصلح مجلي المولد 
المرسل: صبري محمد مصلح مجلي المولد

------------
*(ارسال حوالة)* 
خصم 8,000 *سعودي* عموله 8 سعودي 
حوالة صادرة عبر : الادارة شبكة المحيط 
رقم الحوالة : 3413498736 
*المستلم*: حاميم شريف علي ثابت 
المرسل: نصير هشام محمد عبدالوهاب

----------------
TEAME TESFAY HAGOS=4975 SAR

1000181711713`;

// نموذج رسائل واتساب المنسوخة جماعياً متعددة الأسطر والمجزأة
const SAMPLE_WHATSAPP_TEXT = `[9/16, 1:39 AM] القسام: 1000712011867
Gebrihiwet asefa
[9/16, 1:39 AM] القسام: 500 ريال
[9/16, 1:39 AM] القسام: TEAME TESFAY HAGOS=4975 SAR

1000181711713
[9/16, 1:39 AM] القسام: 1000248400157 tsegay mehari
[9/16, 1:39 AM] القسام: Askol bsrat=


59700 سعودي 

1000197218529
[9/16, 1:39 AM] القسام: 6000ryl
[9/16, 1:39 AM] القسام: TEAME TESFAY HAGOS=1490

1000181711713
[9/16, 1:39 AM] القسام: 1000733766097

8950

aferyeme djana
[9/16, 1:39 AM] القسام: awet gebremdhin 120,000.  بر بر بر
[9/16, 1:39 AM] القسام: 1000194080208
[9/16, 1:39 AM] القسام: senayt teklay
[9/16, 1:39 AM] القسام: 100,000 bir
[9/16, 1:39 AM] القسام: 1000191564441
haftom fitwi
1490
[9/16, 1:39 AM] القسام: 1000191564441
haftom fitwi
1490 سعودي
[9/16, 1:39 AM] القسام: 1000303100157
liemet girmay 
995 ريال
[9/16, 1:39 AM] القسام: 1000164801954
Hussen Abdulwahab Hassen
[9/16, 1:39 AM] القسام: 1000239842007
[9/16, 1:39 AM] القسام: Ali serale Abdu
[9/16, 1:39 AM] القسام: 995 ريال سعودي
[9/16, 1:39 AM] القسام: 1000596982542 selam gebremkie
[9/16, 1:39 AM] القسام: 495 ريال
[9/16, 1:39 AM] القسام: 1000532490298
etsay mhery 350,000bir
[9/16, 1:39 AM] القسام: 1000743024625
Kamil Huseen Gandoo
[9/16, 1:39 AM] القسام: 1900 سعودي
[9/16, 1:39 AM] القسام: 1000033204837 
Bet lihem kiros
[9/16, 1:39 AM] القسام: 445 ريال
[9/16, 1:43 AM] القسام: 1000027896597
Shishay Ataklti


10 مليون برررر`;

class SharafApp {
  constructor() {
    this.records = this.loadIncomingRecords();
    this.outgoingRecords = this.loadOutgoingRecords();
    this.auditLog = this.loadAuditLog();
    this.incomingCurrFilter = 'ALL';
    this.outgoingCurrFilter = 'ALL';
    this.settings = this.loadSettings();
    this.searchQuery = '';
    this.outgoingSearchQuery = '';
    this.sortColumn = null;
    this.sortAsc = true;
    this.originalHeaderText = '';

    this.initElements();
    this.bindEvents();
    this.applySettingsToUI();
    this.switchTab('tab-paste');
    this.render();
    this.renderOutgoing();
    this.renderAuditLog();
  }

  // ==================== 1. التخزين، الإعدادات والحفظ التلقائي ====================
  loadIncomingRecords() {
    try {
      const saved = localStorage.getItem('sharaf_incoming_records');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      console.warn('Could not load incoming records from localStorage:', e);
      return [];
    }
  }

  saveIncomingRecords() {
    try {
      localStorage.setItem('sharaf_incoming_records', JSON.stringify(this.records));
      this.triggerAutoSaveIndicator();
    } catch (e) {
      console.warn('Could not save incoming records to localStorage:', e);
    }
  }

  loadAuditLog() {
    try {
      const saved = localStorage.getItem('sharaf_audit_log');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      console.warn('Could not load audit log from localStorage:', e);
      return [];
    }
  }

  saveAuditLog() {
    try {
      localStorage.setItem('sharaf_audit_log', JSON.stringify(this.auditLog));
    } catch (e) {
      console.warn('Could not save audit log to localStorage:', e);
    }
  }

  addAuditLog(entry) {
    const item = {
      id: Date.now(),
      timestamp: new Date().toISOString(),
      timeFormatted: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
      dateFormatted: new Date().toLocaleDateString('ar-EG', { year: 'numeric', month: 'short', day: 'numeric' }),
      type: entry.type || 'import',
      title: entry.title || 'عملية مالية',
      description: entry.description || '',
      tags: entry.tags || []
    };
    this.auditLog.unshift(item);
    if (this.auditLog.length > 200) {
      this.auditLog = this.auditLog.slice(0, 200);
    }
    this.saveAuditLog();
    this.renderAuditLog();
  }

  renderAuditLog() {
    const listEl = document.getElementById('history-timeline-list');
    const badgeEl = document.getElementById('nav-history-badge');
    if (badgeEl) badgeEl.textContent = this.auditLog.length;
    if (!listEl) return;

    if (this.auditLog.length === 0) {
      listEl.innerHTML = `
        <div class="history-empty-state">
          <div class="history-empty-icon">📜</div>
          <p>لا توجد عمليات مسجلة حتى الآن. أي استيراد أو تعديل أو إضافة سيتم توثيقه هنا تلقائياً.</p>
        </div>`;
      return;
    }

    const typeIcons = {
      import: '📥',
      edit: '✏️',
      delete: '🗑️',
      clear: '⚠️'
    };

    listEl.innerHTML = this.auditLog.map(item => `
      <div class="history-item type-${item.type}">
        <div class="history-icon-box">
          <span>${typeIcons[item.type] || '📌'}</span>
        </div>
        <div class="history-card">
          <div class="history-card-header">
            <span class="history-card-title">${this.escapeHtml(item.title)}</span>
            <span class="history-card-time">${item.dateFormatted} - ${item.timeFormatted}</span>
          </div>
          <div class="history-card-desc">${this.escapeHtml(item.description)}</div>
          ${item.tags && item.tags.length > 0 ? `
            <div class="history-card-tags">
              ${item.tags.map(t => `<span class="history-tag">${this.escapeHtml(t)}</span>`).join('')}
            </div>` : ''}
        </div>
      </div>
    `).join('');
  }

  clearAuditLog() {
    if (this.auditLog.length === 0) return;
    if (!confirm('تحذير: هل أنت متأكد من رغبتك في مسح السجل التاريخي بالكامل؟')) return;
    this.auditLog = [];
    this.saveAuditLog();
    this.renderAuditLog();
    this.showToast('تم مسح السجل التاريخي', 'info');
  }

  triggerAutoSaveIndicator() {
    const badge = document.getElementById('autosave-status');
    if (badge) {
      badge.classList.remove('saved-pulse');
      void badge.offsetWidth;
      badge.classList.add('saved-pulse');
    }
  }

  getImportMode() {
    const radios = document.getElementsByName('import-mode');
    for (let r of radios) {
      if (r.checked) return r.value;
    }
    return 'append';
  }

  loadSettings() {
    const defaultSettings = {
      defaultRate: 48,
      defaultCurrency: 'ريال سعودي',
      shopName: 'كشف الحوالات',
      dateMode: 'auto',
      excelColors: true,
      excelTotalRow: true,
      thousandsSep: true,
      splitThreshold: 100000,
      birrLabel: 'birr',
      theme: 'light'
    };

    try {
      const saved = localStorage.getItem('sharaf_settings');
      return saved ? { ...defaultSettings, ...JSON.parse(saved) } : defaultSettings;
    } catch (e) {
      console.warn('Could not load settings from localStorage:', e);
      return defaultSettings;
    }
  }

  saveSettings() {
    const rateVal = parseFloat(document.getElementById('setting-default-rate').value) || 48;
    const currVal = document.getElementById('setting-default-currency').value.trim() || 'ريال سعودي';
    const shopVal = document.getElementById('setting-shop-name').value.trim() || 'كشف الحوالات';
    const splitVal = parseFloat(document.getElementById('setting-split-threshold')?.value) || 100000;
    const birrLbl = document.getElementById('setting-birr-label')?.value.trim() || 'birr';

    const dateRadios = document.getElementsByName('date-mode');
    let dateMode = 'auto';
    for (let r of dateRadios) {
      if (r.checked) { dateMode = r.value; break; }
    }

    this.settings.defaultRate = rateVal;
    this.settings.defaultCurrency = currVal;
    this.settings.shopName = shopVal;
    this.settings.dateMode = dateMode;
    this.settings.splitThreshold = splitVal;
    this.settings.birrLabel = birrLbl;
    this.settings.excelColors = document.getElementById('setting-excel-colors').checked;
    this.settings.excelTotalRow = document.getElementById('setting-excel-total-row').checked;
    this.settings.thousandsSep = document.getElementById('setting-thousands-sep').checked;

    localStorage.setItem('sharaf_settings', JSON.stringify(this.settings));
    this.applySettingsToUI();
    this.render();
    this.showToast('تم حفظ الإعدادات بنجاح', 'success');
  }

  resetSettingsToDefault() {
    if (!confirm('هل أنت متأكد من رغبتك في استعادة الإعدادات الافتراضية؟')) return;
    localStorage.removeItem('sharaf_settings');
    this.settings = this.loadSettings();
    this.applySettingsToUI();
    this.render();
    this.showToast('تمت استعادة الإعدادات الافتراضية', 'success');
  }

  applySettingsToUI() {
    // تحديث حقول الرأس
    document.getElementById('header-rate-input').value = this.settings.defaultRate;
    document.getElementById('input-batch-rate').value = this.settings.defaultRate;
    document.getElementById('input-batch-currency').value = this.settings.defaultCurrency;
    document.getElementById('stat-rate-display').textContent = this.formatNumber(this.settings.defaultRate);
    document.getElementById('stat-currency-label').textContent = this.settings.defaultCurrency;
    document.getElementById('footer-currency').textContent = this.settings.defaultCurrency;
    document.getElementById('app-title-display').textContent = this.settings.shopName;

    // تحديث حقول صفحة الإعدادات
    document.getElementById('setting-default-rate').value = this.settings.defaultRate;
    document.getElementById('setting-default-currency').value = this.settings.defaultCurrency;
    document.getElementById('setting-shop-name').value = this.settings.shopName;
    document.getElementById('setting-excel-colors').checked = this.settings.excelColors;
    document.getElementById('setting-excel-total-row').checked = this.settings.excelTotalRow;
    document.getElementById('setting-thousands-sep').checked = this.settings.thousandsSep;

    const splitInput = document.getElementById('setting-split-threshold');
    if (splitInput) splitInput.value = this.settings.splitThreshold || 100000;
    const birrInput = document.getElementById('setting-birr-label');
    if (birrInput) birrInput.value = this.settings.birrLabel || 'birr';

    const dateRadios = document.getElementsByName('date-mode');
    for (let r of dateRadios) {
      if (r.value === this.settings.dateMode) r.checked = true;
    }

    // تطبيق الثيم
    document.body.className = `theme-${this.settings.theme}`;
  }

  toggleTheme() {
    this.settings.theme = this.settings.theme === 'light' ? 'dark' : 'light';
    document.body.className = `theme-${this.settings.theme}`;
    localStorage.setItem('sharaf_settings', JSON.stringify(this.settings));
  }

  // ==================== 2. ربط العناصر والأحداث ====================
  initElements() {
    this.navTabs = document.querySelectorAll('.nav-tab');
    this.tabPanes = document.querySelectorAll('.tab-pane');

    this.rawTextInput = document.getElementById('raw-text-input');
    this.btnProcessText = document.getElementById('btn-process-text');
    this.btnPasteClipboard = document.getElementById('btn-paste-clipboard');
    this.btnClearText = document.getElementById('btn-clear-text');
    this.parseStatusMsg = document.getElementById('parse-status-message');

    this.tableSearchInput = document.getElementById('table-search-input');
    this.btnClearSearch = document.getElementById('btn-clear-search');
    this.tableBody = document.getElementById('table-body');
    this.headerRateInput = document.getElementById('header-rate-input');

    this.btnExportExcel = document.getElementById('btn-export-excel');
    this.btnCopyTable = document.getElementById('btn-copy-table');
    this.btnCopyOriginal = document.getElementById('btn-copy-original');
    this.btnPreviewOriginal = document.getElementById('btn-preview-original');
    this.btnPrintTable = document.getElementById('btn-print-table');
    this.btnAddRow = document.getElementById('btn-add-row');
    this.btnClearAll = document.getElementById('btn-clear-all');

    this.statCount = document.getElementById('stat-count');
    this.statTotalAmount = document.getElementById('stat-total-amount');
    this.statTotalBirr = document.getElementById('stat-total-birr');
    this.navCountBadge = document.getElementById('nav-count-badge');

    this.footerCount = document.getElementById('footer-count');
    this.footerTotalAmount = document.getElementById('footer-total-amount');
    this.footerTotalBirr = document.getElementById('footer-total-birr');

    this.rowModal = document.getElementById('row-modal');
    this.previewModal = document.getElementById('preview-message-modal');
    this.previewTextarea = document.getElementById('preview-message-textarea');

    // عناصر كشف الحوالات الصادرة
    this.navOutgoingBadge = document.getElementById('nav-outgoing-badge');
    this.outgoingTableBody = document.getElementById('outgoing-table-body');
    this.outgoingSearchInput = document.getElementById('outgoing-search-input');
    this.btnClearOutgoingSearch = document.getElementById('btn-clear-outgoing-search');
    this.btnOutgoingExportExcel = document.getElementById('btn-outgoing-export-excel');
    this.btnOutgoingCopyMsg = document.getElementById('btn-outgoing-copy-msg');
    this.btnOutgoingPreviewMsg = document.getElementById('btn-outgoing-preview-msg');
    this.btnOutgoingPrint = document.getElementById('btn-outgoing-print');
    this.btnOutgoingAddRow = document.getElementById('btn-outgoing-add-row');
    this.btnOutgoingClearAll = document.getElementById('btn-outgoing-clear-all');
    this.outgoingModal = document.getElementById('modal-outgoing-row');
    this.outgoingPreviewModal = document.getElementById('preview-outgoing-modal');
  }

  bindEvents() {
    this.navTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        const tabId = tab.getAttribute('data-tab');
        this.switchTab(tabId);
      });
    });

    this.btnProcessText.addEventListener('click', () => this.processRawText());
    this.btnPasteClipboard.addEventListener('click', () => this.pasteFromClipboard());
    this.btnClearText.addEventListener('click', () => {
      this.rawTextInput.value = '';
      this.rawTextInput.focus();
    });

    this.headerRateInput.addEventListener('input', (e) => {
      const newRate = parseFloat(e.target.value);
      if (!isNaN(newRate) && newRate > 0) {
        this.settings.defaultRate = newRate;
        document.getElementById('input-batch-rate').value = newRate;
        document.getElementById('stat-rate-display').textContent = this.formatNumber(newRate);
        this.recalculateAllRecordsRate(newRate);
      }
    });

    this.tableSearchInput.addEventListener('input', (e) => {
      this.searchQuery = e.target.value.trim().toLowerCase();
      this.btnClearSearch.classList.toggle('hidden', this.searchQuery === '');
      this.render();
    });

    this.btnClearSearch.addEventListener('click', () => {
      this.tableSearchInput.value = '';
      this.searchQuery = '';
      this.btnClearSearch.classList.add('hidden');
      this.render();
      this.tableSearchInput.focus();
    });

    document.querySelectorAll('.table-columns-row th[data-sort]').forEach(th => {
      th.addEventListener('click', () => {
        const col = th.getAttribute('data-sort');
        this.sortByColumn(col);
      });
    });

    this.btnExportExcel.addEventListener('click', () => this.exportToExcel());
    this.btnCopyTable.addEventListener('click', () => this.copyTableToClipboard());
    if (this.btnCopyOriginal) {
      this.btnCopyOriginal.addEventListener('click', () => this.copyOriginalMessage());
    }
    if (this.btnPreviewOriginal) {
      this.btnPreviewOriginal.addEventListener('click', () => this.openPreviewModal());
    }
    this.btnPrintTable.addEventListener('click', () => window.print());
    this.btnAddRow.addEventListener('click', () => this.openAddRowModal());
    this.btnClearAll.addEventListener('click', () => this.clearAllRecords());

    // أحداث كشف الحوالات الصادرة
    if (this.btnOutgoingExportExcel) {
      this.btnOutgoingExportExcel.addEventListener('click', () => this.exportOutgoingExcel());
    }
    if (this.btnOutgoingCopyMsg) {
      this.btnOutgoingCopyMsg.addEventListener('click', () => this.copyOutgoingMessage());
    }
    if (this.btnOutgoingPreviewMsg) {
      this.btnOutgoingPreviewMsg.addEventListener('click', () => this.previewOutgoingMessage());
    }
    if (this.btnOutgoingPrint) {
      this.btnOutgoingPrint.addEventListener('click', () => this.printOutgoingTable());
    }
    if (this.btnOutgoingAddRow) {
      this.btnOutgoingAddRow.addEventListener('click', () => this.openOutgoingModal(-1));
    }
    if (this.btnOutgoingClearAll) {
      this.btnOutgoingClearAll.addEventListener('click', () => this.clearAllOutgoing());
    }
    if (this.outgoingSearchInput) {
      this.outgoingSearchInput.addEventListener('input', (e) => {
        this.outgoingSearchQuery = e.target.value.trim().toLowerCase();
        if (this.btnClearOutgoingSearch) {
          this.btnClearOutgoingSearch.classList.toggle('hidden', !this.outgoingSearchQuery);
        }
        this.renderOutgoing();
      });
    }
    if (this.btnClearOutgoingSearch) {
      this.btnClearOutgoingSearch.addEventListener('click', () => {
        this.outgoingSearchInput.value = '';
        this.outgoingSearchQuery = '';
        this.btnClearOutgoingSearch.classList.add('hidden');
        this.renderOutgoing();
        this.outgoingSearchInput.focus();
      });
    }

    document.getElementById('btn-theme-toggle').addEventListener('click', () => this.toggleTheme());
    document.getElementById('btn-open-settings').addEventListener('click', () => this.switchTab('tab-settings'));
    const btnClearHist = document.getElementById('btn-clear-history');
    if (btnClearHist) {
      btnClearHist.addEventListener('click', () => this.clearAuditLog());
    }
  }

  switchTab(tabId) {
    this.navTabs.forEach(t => t.classList.toggle('active', t.getAttribute('data-tab') === tabId));
    this.tabPanes.forEach(p => p.classList.toggle('active', p.id === tabId));

    // إخفاء كروت الإحصائيات العلوية في صفحة الإعدادات أو الحوالات الصادرة أو السجل لتوفير مساحة شاشة الهاتف
    const metricsGrid = document.querySelector('.metrics-grid');
    if (metricsGrid) {
      if (tabId === 'tab-settings' || tabId === 'tab-help' || tabId === 'tab-outgoing' || tabId === 'tab-history') {
        metricsGrid.classList.add('hidden-on-settings');
      } else {
        metricsGrid.classList.remove('hidden-on-settings');
      }
    }
  }

  // ==================== 3. خوارزميات التحليل المالي والتقسيم (Modular Delegations) ====================
  parseFinancialText(text, options = {}) {
    if (typeof EthiopianParser !== 'undefined') {
      const mergedOpts = Object.assign({
        rate: this.settings?.defaultRate || 48,
        currency: this.settings?.defaultCurrency || 'ريال سعودي'
      }, options);
      return EthiopianParser.parse(text, mergedOpts);
    }
    return { records: [], count: 0 };
  }

  parseOutgoingText(text) {
    if (typeof OutgoingParser !== 'undefined') {
      return OutgoingParser.parseOutgoingText(text);
    }
    return [];
  }

  splitMixedText(rawText) {
    if (typeof OutgoingParser !== 'undefined') {
      return OutgoingParser.splitMixedText(rawText);
    }
    return { incomingBlocks: [], outgoingBlocks: [], incomingText: '', outgoingText: '', hasIncoming: false, hasOutgoing: false };
  }

  // ==================== 4.1 خوارزمية تحليل رسائل واتساب المجمعة والمجزأة ====================
  parseWhatsAppChatExport(text, options = {}) {
    const rate = options.rate || this.settings?.defaultRate || 48;
    const defaultCurrency = options.currency || this.settings?.defaultCurrency || 'ريال سعودي';
    const autoDate = options.autoDate !== undefined ? options.autoDate : true;
    let customDate = options.customDate || '';

    let detectedDate = customDate;
    if (!detectedDate && autoDate) {
      const dateMatch = text.match(/(?:\[|\b)(\d{1,2}[\/\-\.]\d{1,2}(?:[\/\-\.]\d{2,4})?)/);
      if (dateMatch) {
        let rawD = dateMatch[1];
        if (!/\d{4}/.test(rawD)) {
          const yr = new Date().getFullYear();
          detectedDate = `${yr}/${rawD}`;
        } else {
          detectedDate = rawD;
        }
      }
    }
    if (!detectedDate) {
      detectedDate = new Date().toLocaleDateString('en-CA');
    }

    if (typeof WhatsAppParser !== 'undefined') {
      const incomingRecords = WhatsAppParser.parse(text, {
        rate,
        currency: defaultCurrency,
        date: detectedDate
      });

      const outgoingRecords = (typeof OutgoingParser !== 'undefined')
        ? OutgoingParser.parseOutgoingText(text)
        : [];

      return {
        incomingRecords,
        outgoingRecords,
        detectedDate
      };
    }

    return {
      incomingRecords: [],
      outgoingRecords: [],
      detectedDate
    };
  }

  // ==================== 5. معالج النصوص الرئيسي (Orchestrator + Helpers) ====================

  /**
   * _readParseOptions — يقرأ خيارات الاستيراد من واجهة المستخدم
   * @returns {{ targetType, importMode, autoDate, customDate, batchCurr, batchRate }}
   */
  _readParseOptions() {
    const targetRadios = document.getElementsByName('parse-target-type');
    let targetType = 'auto';
    for (const r of targetRadios) {
      if (r.checked) { targetType = r.value; break; }
    }

    return {
      targetType,
      importMode:  this.getImportMode(),
      autoDate:    document.getElementById('opt-auto-date')?.checked ?? true,
      customDate:  document.getElementById('input-custom-date')?.value.trim() || '',
      batchCurr:   document.getElementById('input-batch-currency')?.value.trim() || this.settings.defaultCurrency,
      batchRate:   parseFloat(document.getElementById('input-batch-rate')?.value) || this.settings.defaultRate,
    };
  }

  /**
   * _commitIncomingRecords — يضيف سجلات واردة للكشف ويحفظ ويعرض
   * @param {Array} newRecords
   * @param {'append'|'replace'} importMode
   */
  _commitIncomingRecords(newRecords, importMode) {
    if (importMode === 'append') {
      const startSeq = this.records.length;
      this.records = [
        ...this.records,
        ...newRecords.map((r, i) => ({ ...r, originalSeq: startSeq + i + 1 }))
      ];
    } else {
      this.records = newRecords;
    }
    this.saveIncomingRecords();
    this.render();
  }

  /**
   * _commitOutgoingRecords — يضيف سجلات صادرة للكشف ويحفظ ويعرض
   * @param {Array} newRecords
   * @param {'append'|'replace'} importMode
   */
  _commitOutgoingRecords(newRecords, importMode) {
    if (importMode === 'append') {
      this.outgoingRecords = [...this.outgoingRecords, ...newRecords];
    } else {
      this.outgoingRecords = newRecords;
    }
    this.saveOutgoingRecords();
    this.renderOutgoing();
  }

  /**
   * _setStatusMsg — يضبط رسالة الحالة تحت الزر
   * @param {string} text
   * @param {'success'|'error'} type
   */
  _setStatusMsg(text, type = 'success') {
    this.parseStatusMsg.textContent = text;
    this.parseStatusMsg.className = `status-msg ${type}`;
    this.parseStatusMsg.classList.remove('hidden');
  }

  /**
   * _handleWhatsAppImport — يعالج نصوص محادثة واتساب المجمعة
   * @returns {boolean} — true إذا نجح الاستيراد
   */
  _handleWhatsAppImport(rawText, opts) {
    const { importMode, batchRate, batchCurr, autoDate, customDate } = opts;

    const waResult = this.parseWhatsAppChatExport(rawText, {
      rate: batchRate, currency: batchCurr, autoDate, customDate
    });

    const inCount  = waResult.incomingRecords.length;
    const outCount = waResult.outgoingRecords.length;

    if (inCount === 0 && outCount === 0) return false;

    if (inCount > 0)  this._commitIncomingRecords(waResult.incomingRecords, importMode);
    if (outCount > 0) this._commitOutgoingRecords(waResult.outgoingRecords, importMode);

    const modeLabel = importMode === 'append' ? 'إضافة متتابعة' : 'استبدال';
    const tags = [
      ...(inCount  > 0 ? [`واردة: ${inCount}`]  : []),
      ...(outCount > 0 ? [`صادرة: ${outCount}`] : []),
      'محادثة واتساب',
      modeLabel
    ];

    this.addAuditLog({
      type: 'import',
      title: 'استيراد رسائل واتساب مجمعة',
      description: `تم استخراج وتجميع ${inCount} حوالة واردة ${outCount > 0 ? `و ${outCount} حوالة صادرة` : ''} من محادثة واتساب بنجاح.`,
      tags
    });

    this._setStatusMsg(
      `تم بنجاح استخراج وتجميع ${inCount} حوالة واردة ${outCount > 0 ? `و ${outCount} صادرة` : ''} من رسائل واتساب ✓ (${modeLabel})`
    );

    this.showToast(`تم استيراد ${inCount} حوالة من رسائل واتساب بنجاح`, 'success');
    setTimeout(() => this.switchTab(inCount >= outCount ? 'tab-table' : 'tab-outgoing'), 600);
    return true;
  }

  /**
   * _handleMixedImport — يعالج النصوص المختلطة (واردة + صادرة في نفس النص)
   * @returns {boolean} — true إذا نجح الاستيراد
   */
  _handleMixedImport(rawText, opts) {
    const { importMode, batchRate, batchCurr, autoDate, customDate } = opts;

    const split = this.splitMixedText(rawText);
    if (!split.hasIncoming || !split.hasOutgoing) return false;

    const outRecords = this.parseOutgoingText(split.outgoingText);
    const inResult   = this.parseFinancialText(split.incomingText, {
      rate: batchRate, currency: batchCurr, autoDate, customDate
    });

    if (outRecords.length === 0 && inResult.count === 0) return false;

    if (inResult.count > 0)    this._commitIncomingRecords(inResult.records, importMode);
    if (outRecords.length > 0) this._commitOutgoingRecords(outRecords, importMode);

    const modeLabel = importMode === 'append' ? 'إضافة متتابعة' : 'استبدال';
    const tags = [
      ...(inResult.count  > 0 ? [`واردة: ${inResult.count}`]   : []),
      ...(outRecords.length > 0 ? [`صادرة: ${outRecords.length}`] : []),
      modeLabel
    ];

    this.addAuditLog({
      type: 'import',
      title: 'استيراد كشف مختلط (واردة + صادرة)',
      description: `تم تلقائياً فرز واستيراد ${inResult.count} حوالة واردة و ${outRecords.length} حوالة صادرة.`,
      tags
    });

    this._setStatusMsg(
      `تم كشف وتوزيع: ${inResult.count} حوالة واردة + ${outRecords.length} حوالة صادرة بنجاح ✓ (${modeLabel})`
    );

    this.showToast(`تم استيراد ${inResult.count} واردة و ${outRecords.length} صادرة بنجاح`, 'success');
    setTimeout(() => this.switchTab(inResult.count >= outRecords.length ? 'tab-table' : 'tab-outgoing'), 600);
    return true;
  }

  /**
   * _handleOutgoingImport — يعالج نصوص الحوالات الصادرة الصريحة
   * @returns {boolean} — true إذا نجح الاستيراد
   */
  _handleOutgoingImport(rawText, opts) {
    const { importMode } = opts;
    const outRecords = this.parseOutgoingText(rawText);

    if (outRecords.length === 0) {
      this.showToast('تعذر العثور على حوالات صادرة مطابقة في النص المدخل', 'error');
      return true; // consumed — لا تمرر للمعالجات التالية
    }

    this._commitOutgoingRecords(outRecords, importMode);

    const modeLabel = importMode === 'append' ? 'إضافة متتابعة' : 'استبدال';

    this.addAuditLog({
      type: 'import',
      title: 'استيراد حوالات صادرة',
      description: `تم استيراد ${outRecords.length} حوالة صادرة (${modeLabel}).`,
      tags: [`صادرة: ${outRecords.length}`, modeLabel]
    });

    this._setStatusMsg(
      `تم استخراج ${outRecords.length} حوالة صادرة بنجاح ✓ (${modeLabel})`
    );

    this.showToast(`تم استيراد ${outRecords.length} حوالة صادرة بنجاح`, 'success');
    setTimeout(() => this.switchTab('tab-outgoing'), 600);
    return true;
  }

  /**
   * _handleIncomingImport — يعالج نصوص الحوالات الواردة (المسار الرئيسي)
   * @returns {boolean} — true إذا نجح الاستيراد
   */
  _handleIncomingImport(rawText, opts) {
    const { importMode, batchRate, batchCurr, autoDate, customDate } = opts;

    const result = this.parseFinancialText(rawText, {
      rate: batchRate, currency: batchCurr, autoDate, customDate
    });

    // Fallback: إذا لم يجد نتائج — جرب محلل واتساب كفولباك
    if (result.count === 0) {
      const fallback = this.parseWhatsAppChatExport(rawText, {
        rate: batchRate, currency: batchCurr, autoDate, customDate
      });

      if (fallback.incomingRecords.length > 0) {
        const inCount   = fallback.incomingRecords.length;
        const modeLabel = importMode === 'append' ? 'إضافة متتابعة' : 'استبدال';

        this._commitIncomingRecords(fallback.incomingRecords, importMode);

        this.addAuditLog({
          type: 'import',
          title: 'استيراد رسائل مجمعة ومجزأة',
          description: `تم استخراج ${inCount} حوالة واردة من النص المجزأ بنجاح (${modeLabel}).`,
          tags: [`واردة: ${inCount}`, modeLabel]
        });

        this._setStatusMsg(`تم استخراج ${inCount} حوالة واردة بنجاح ✓ (${modeLabel})`);
        this.showToast(`تم استيراد ${inCount} حساب بنجاح`, 'success');
        setTimeout(() => this.switchTab('tab-table'), 600);
        return true;
      }

      this.showToast('لم يتم العثور على سجلات مطابقة في النص. تأكد من وجود علامة = أو أرقام الحسابات والمبالغ', 'error');
      return true; // consumed
    }

    this.originalHeaderText = result.detectedHeader || '';
    this._commitIncomingRecords(result.records, importMode);

    const modeLabel = importMode === 'append' ? 'إضافة متتابعة' : 'استبدال';

    this.addAuditLog({
      type: 'import',
      title: 'استيراد حوالات واردة',
      description: `تم استيراد ${result.count} حساب وارد بإجمالي ${this.formatNumber(result.calculatedTotalAmount)} ${batchCurr} (${modeLabel}).`,
      tags: [`واردة: ${result.count}`, `${this.formatNumber(result.calculatedTotalAmount)} ${batchCurr}`, modeLabel]
    });

    // بناء رسالة الحالة مع تفاصيل السنتات والتحقق من المجموع
    let msg = `تم استخراج ${result.count} سجلاً بنجاح! الإجمالي: ${this.formatNumber(result.calculatedTotalAmount)} ${batchCurr}`;
    if (result.calculatedTotalCutCents > 0) {
      msg += ` (السنتات المقطوعة: ${result.calculatedTotalCutCents.toFixed(2)} [${Math.round(result.calculatedTotalCutCents * 100)} سنت])`;
    }
    if (result.textTotal !== null) {
      const diff = Math.abs(result.textTotal - result.calculatedTotalAmount);
      msg += diff === 0
        ? ` (مطابق لمجموع النص: ${this.formatNumber(result.textTotal)} ✓)`
        : ` (تنبيه: مجموع النص المدون هو ${this.formatNumber(result.textTotal)})`;
    }

    this._setStatusMsg(msg);
    this.showToast(`تم استيراد ${result.count} حساب بنجاح`, 'success');
    setTimeout(() => this.switchTab('tab-table'), 600);
    return true;
  }

  /**
   * processRawText — المُنسق الرئيسي (Orchestrator)
   * يقرأ الخيارات ويفوّض لأحد الـ 4 helpers بالترتيب الصحيح
   */
  processRawText() {
    const rawText = this.rawTextInput.value.trim();
    if (!rawText) {
      this.showToast('يرجى لصق النص المالي أولاً', 'error');
      this.rawTextInput.focus();
      return;
    }

    const opts = this._readParseOptions();
    const { targetType } = opts;

    // ① WhatsApp محادثة جماعية — أعلى أولوية
    const isWhatsAppExport = /(?:\[\d{1,4}[\/\-\.]\d{1,2}(?:[\/\-\.]\d{2,4})?,?[^\]]*\]|\b\d{1,4}[\/\-\.]\d{1,2}(?:[\/\-\.]\d{2,4})?,?[^-\n]*-)\s*[^:\n]+:/i.test(rawText);
    if (isWhatsAppExport) {
      if (this._handleWhatsAppImport(rawText, opts)) return;
    }

    // ② كشف مختلط تلقائي (واردة + صادرة)
    if (targetType === 'auto') {
      if (this._handleMixedImport(rawText, opts)) return;
    }

    // ③ صادرة صريحة أو مكتشفة تلقائياً
    const isOutgoing = targetType === 'outgoing' || (targetType === 'auto' && (
      /ارسال\s*حوال[ةه]|حوال[ةه]\s*صادرة|خصم\s*[\d,]+/i.test(rawText) ||
      (/المستلم/i.test(rawText) && /المرسل/i.test(rawText))
    ));
    if (isOutgoing) {
      if (this._handleOutgoingImport(rawText, opts)) return;
    }

    // ④ واردة — المسار الافتراضي
    this._handleIncomingImport(rawText, opts);
  }

  loadSampleData() {
    this.rawTextInput.value = SAMPLE_RAW_TEXT;
    this.showToast('تم تحميل بيانات النموذج الإثيوبي (34 حساب)', 'success');
  }

  loadSampleDataAndSwitch() {
    this.loadSampleData();
    const incomingRadio = document.querySelector('input[name="parse-target-type"][value="incoming"]');
    if (incomingRadio) incomingRadio.checked = true;
    this.processRawText();
  }

  loadOutgoingSampleAndSwitch() {
    this.rawTextInput.value = SAMPLE_OUTGOING_TEXT;
    const outgoingRadio = document.querySelector('input[name="parse-target-type"][value="outgoing"]');
    if (outgoingRadio) outgoingRadio.checked = true;
    this.processRawText();
  }

  loadWhatsAppSampleAndSwitch() {
    this.rawTextInput.value = SAMPLE_WHATSAPP_TEXT;
    const autoRadio = document.querySelector('input[name="parse-target-type"][value="auto"]');
    if (autoRadio) autoRadio.checked = true;
    this.processRawText();
  }

  async pasteFromClipboard() {
    try {
      const text = await navigator.clipboard.readText();
      if (text) {
        this.rawTextInput.value = text;
        this.showToast('تم اللصق من الحافظة', 'success');
      } else {
        this.showToast('الحافظة فارغة', 'error');
      }
    } catch (err) {
      this.showToast('تعذر الوصول للحافظة، يرجى اللصق يدوياً (Ctrl+V)', 'error');
    }
  }

  // ==================== 4. الحسابات الحية والتحديث الفوري ====================
  recalculateAllRecordsRate(newRate) {
    this.records.forEach(record => {
      record.rate = newRate;
      const rawBirr = record.amount * newRate;
      record.birrEquivalent = Math.floor(rawBirr / 100) * 100; // استقطاع ما دون 100 بر والكسور
      record.cutCents = Math.round((rawBirr - record.birrEquivalent) * 100) / 100;
    });
    this.render();
    this.showToast(`تم تحديث الأسعار بالمعامل: ${newRate}`, 'success');
  }

  applyRateToExistingRecords() {
    const rate = this.settings.defaultRate;
    this.recalculateAllRecordsRate(rate);
    this.showToast(`تم تطبيق المعامل (${rate}) على جميع السجلات المسجلة`, 'success');
  }

  updateRecordAmount(index, newAmount) {
    if (this.records[index]) {
      const amt = parseFloat(newAmount) || 0;
      this.records[index].amount = amt;
      const rawBirr = amt * this.records[index].rate;
      this.records[index].birrEquivalent = Math.floor(rawBirr / 100) * 100;
      this.records[index].cutCents = Math.round((rawBirr - this.records[index].birrEquivalent) * 100) / 100;
      this.render();
    }
  }

  setIncomingCurrFilter(curr) {
    this.incomingCurrFilter = curr;
    this.render();
  }

  buildIncomingCurrFilterBar() {
    const container = document.getElementById('incoming-curr-chips');
    if (!container) return;

    const currCounts = {};
    this.records.forEach(r => {
      const c = (r.currency || this.settings.defaultCurrency || 'ريال سعودي').trim();
      currCounts[c] = (currCounts[c] || 0) + 1;
    });

    const currencies = Object.keys(currCounts);
    let html = `<button type="button" class="curr-chip ${this.incomingCurrFilter === 'ALL' ? 'active' : ''}" onclick="app.setIncomingCurrFilter('ALL')">
      <span>جميع العملات (${this.records.length})</span>
    </button>`;

    currencies.forEach(curr => {
      const isActive = this.incomingCurrFilter === curr;
      html += `<button type="button" class="curr-chip ${isActive ? 'active' : ''}" onclick="app.setIncomingCurrFilter('${this.escapeHtml(curr)}')">
        <span>${this.escapeHtml(curr)} (${currCounts[curr]})</span>
      </button>`;
    });

    container.innerHTML = html;
  }

  // ==================== 5. العرض والرندرة مع فصل الصغير والكبير ====================
  render() {
    this.buildIncomingCurrFilterBar();

    let filtered = this.records;
    if (this.incomingCurrFilter && this.incomingCurrFilter !== 'ALL') {
      filtered = filtered.filter(r => (r.currency || this.settings.defaultCurrency || 'ريال سعودي').trim() === this.incomingCurrFilter);
    }

    if (this.searchQuery) {
      const q = this.searchQuery;
      filtered = filtered.filter(r => (
        r.name.toLowerCase().includes(q) ||
        r.id.toLowerCase().includes(q) ||
        r.amount.toString().includes(q) ||
        r.date.includes(q) ||
        r.currency.toLowerCase().includes(q)
      ));
    }

    if (this.sortColumn) {
      filtered.sort((a, b) => {
        let valA = a[this.sortColumn];
        let valB = b[this.sortColumn];

        if (typeof valA === 'number' && typeof valB === 'number') {
          return this.sortAsc ? valA - valB : valB - valA;
        }
        valA = (valA || '').toString().toLowerCase();
        valB = (valB || '').toString().toLowerCase();
        return this.sortAsc ? valA.localeCompare(valB) : valB.localeCompare(valA);
      });
    }

    if (filtered.length === 0) {
      if (this.records.length === 0) {
        this.tableBody.innerHTML = `
          <tr class="empty-row">
            <td colspan="9" class="empty-state">
              <div class="empty-content">
                <div class="empty-icon">📑</div>
                <p class="empty-text">لا توجد سجلات حالياً في الجدول</p>
                <p class="empty-subtext">قم بلصق كشف الحسابات في تبويب "لصق واستيراد البيانات" ليتم إدراجه تلقائياً</p>
              </div>
            </td>
          </tr>`;
      } else {
        this.tableBody.innerHTML = `
          <tr class="empty-row">
            <td colspan="9" class="empty-state">
              <p class="empty-text">لا توجد نتائج مطابقة لبحثك: "${this.searchQuery}"</p>
            </td>
          </tr>`;
      }
    } else {
      // فصل السجلات إلى فئتين: الصغيرة (1 إلى 100,000 بر) والكبيرة (100,000 فأكثر)
      const threshold = this.settings.splitThreshold || 100000;
      const smallRecords = filtered.filter(r => (r.birrEquivalent || 0) <= threshold);
      const largeRecords = filtered.filter(r => (r.birrEquivalent || 0) > threshold);

      const renderRow = (r, idx) => {
        const originalIndex = this.records.indexOf(r);
        const displaySeq = r.originalSeq !== undefined ? r.originalSeq : (idx + 1);
        const cutCentsBadge = (r.cutCents && r.cutCents > 0)
          ? `<span class="badge-cut-cents" title="سنتات مقطوعة بالبر: ${r.cutCents.toFixed(2)} بر (${Math.round(r.cutCents * 100)} سنت)">✂️ -${r.cutCents.toFixed(2)} بر</span>`
          : '';

        return `
          <tr data-index="${originalIndex}">
            <td class="col-seq-cell">${displaySeq}</td>
            <td class="col-date-cell">${this.escapeHtml(r.date)}</td>
            <td class="col-name-cell"><strong>${this.escapeHtml(r.name)}</strong></td>
            <td class="col-acc-cell">
              <div class="acc-number-wrap">
                <span class="acc-text">${this.escapeHtml(r.id || '-')}</span>
                ${r.id ? `<button class="copy-acc-btn" onclick="app.copyToClipboard('${r.id}', 'تم نسخ رقم الحساب')" title="نسخ رقم الحساب">📋</button>` : ''}
              </div>
            </td>
            <td class="col-amount-cell">${this.formatNumber(r.amount)}</td>
            <td class="col-curr-cell">${this.escapeHtml(r.currency)}</td>
            <td class="col-rate-cell">${this.formatNumber(r.rate)}</td>
            <td class="col-birr-cell">
              ${this.formatNumber(r.birrEquivalent)}
              ${cutCentsBadge}
            </td>
            <td class="row-actions-cell no-print">
              <button class="action-icon-btn" onclick="app.openEditRowModal(${originalIndex})" title="تعديل">✏️</button>
              <button class="action-icon-btn delete" onclick="app.deleteRow(${originalIndex})" title="حذف">🗑️</button>
            </td>
          </tr>`;
      };

      let html = '';

      // 1. قسم الحوالات الصغيرة في الأعلى
      if (smallRecords.length > 0) {
        const subAmt = smallRecords.reduce((s, r) => s + (r.amount || 0), 0);
        const subBirr = smallRecords.reduce((s, r) => s + (r.birrEquivalent || 0), 0);

        html += `
          <tr class="category-banner-row">
            <td colspan="9">
              📌 الحوالات الصغيرة (من 1 إلى ${this.formatNumber(threshold)} بر) — [${smallRecords.length} حساب]
            </td>
          </tr>`;

        smallRecords.forEach((r, idx) => {
          html += renderRow(r, idx);
        });

        html += `
          <tr class="subtotal-row">
            <td colspan="4" class="subtotal-label">
              <strong>مجموع الحوالات الصغيرة (${smallRecords.length} حساب)</strong>
            </td>
            <td class="col-amount-cell">${this.formatNumber(subAmt)}</td>
            <td class="col-curr-cell">${smallRecords[0]?.currency || ''}</td>
            <td class="col-rate-cell">-</td>
            <td class="col-birr-cell">${this.formatNumber(subBirr)} بر</td>
            <td class="no-print"></td>
          </tr>`;
      }

      // 2. فاصل بارز بين الفئتين
      if (smallRecords.length > 0 && largeRecords.length > 0) {
        html += `
          <tr class="category-divider-row">
            <td colspan="9"><span class="divider-badge">⚡ الحوالات الكبيرة في الأسفل ⚡</span></td>
          </tr>`;
      }

      // 3. قسم الحوالات الكبيرة في الأسفل
      if (largeRecords.length > 0) {
        const subAmt = largeRecords.reduce((s, r) => s + (r.amount || 0), 0);
        const subBirr = largeRecords.reduce((s, r) => s + (r.birrEquivalent || 0), 0);

        html += `
          <tr class="category-banner-row large-banner">
            <td colspan="9">
              ⭐ الحوالات الكبيرة (من ${this.formatNumber(threshold)} بر فأكثر) — [${largeRecords.length} حساب]
            </td>
          </tr>`;

        largeRecords.forEach((r, idx) => {
          html += renderRow(r, idx);
        });

        html += `
          <tr class="subtotal-row">
            <td colspan="4" class="subtotal-label">
              <strong>مجموع الحوالات الكبيرة (${largeRecords.length} حساب)</strong>
            </td>
            <td class="col-amount-cell">${this.formatNumber(subAmt)}</td>
            <td class="col-curr-cell">${largeRecords[0]?.currency || ''}</td>
            <td class="col-rate-cell">-</td>
            <td class="col-birr-cell">${this.formatNumber(subBirr)} بر</td>
            <td class="no-print"></td>
          </tr>`;
      }

      this.tableBody.innerHTML = html;
    }

    // حساب الإجماليات
    const totalCount = this.records.length;
    const isFiltered = this.incomingCurrFilter && this.incomingCurrFilter !== 'ALL';
    const recordsForTotals = isFiltered ? filtered : this.records;
    const totalAmount = recordsForTotals.reduce((sum, r) => sum + (r.amount || 0), 0);
    const totalBirr = recordsForTotals.reduce((sum, r) => sum + (r.birrEquivalent || 0), 0);
    const totalCutCents = Math.round(recordsForTotals.reduce((sum, r) => sum + (r.cutCents || 0), 0) * 100) / 100;
    const totalCentsCount = Math.round(totalCutCents * 100);
    const currencyName = isFiltered ? this.incomingCurrFilter : (this.records[0]?.currency || this.settings.defaultCurrency || 'ريال سعودي');

    this.statCount.textContent = isFiltered ? `${filtered.length} / ${totalCount}` : totalCount;
    this.statTotalAmount.textContent = this.formatNumber(totalAmount);
    this.statTotalBirr.textContent = this.formatNumber(totalBirr);
    this.navCountBadge.textContent = totalCount;

    const birrLabel = (this.settings.birrLabel || 'birr').trim();
    const statCutBirrEl = document.getElementById('stat-cut-cents-birr');
    if (statCutBirrEl) {
      statCutBirrEl.textContent = `✂️ مقطوع: ${totalCutCents.toFixed(2)} ${birrLabel}${totalCentsCount > 0 ? ` (${this.formatNumber(totalCentsCount)} سنت)` : ''}`;
    }

    this.footerCount.textContent = isFiltered ? `${filtered.length} (من ${totalCount})` : totalCount;
    this.footerTotalAmount.textContent = `${this.formatNumber(totalAmount)} ${currencyName}`;
    this.footerTotalBirr.textContent = `${this.formatNumber(totalBirr)} بر`;

    const footerCutValEl = document.getElementById('footer-cut-cents-val');
    const footerCutDescEl = document.getElementById('footer-cut-cents-desc');
    if (footerCutValEl) footerCutValEl.textContent = `${totalCutCents.toFixed(2)} بر`;
    if (footerCutDescEl) {
      footerCutDescEl.textContent = totalCentsCount > 0 ? `(${this.formatNumber(totalCentsCount)} سنت)` : `(0 سنت)`;
    }
  }

  sortByColumn(column) {
    if (this.sortColumn === column) {
      this.sortAsc = !this.sortAsc;
    } else {
      this.sortColumn = column;
      this.sortAsc = true;
    }
    this.render();
  }

  // ==================== 6. تصدير إكسل منسق مع التقسيم ====================
  exportToExcel() {
    if (this.records.length === 0) {
      this.showToast('لا توجد بيانات لتصديرها إلى إكسل', 'error');
      return;
    }

    if (typeof XLSX === 'undefined') {
      this.showToast('جاري تحميل مكتبة إكسل، يرجى المحاولة بعد لحظات', 'error');
      return;
    }

    const wb = XLSX.utils.book_new();
    const title = this.settings.shopName || 'كشف الحوالات';

    const headers = [
      'الآيدي (ID)',
      'التاريخ',
      'اسم الحساب',
      'رقم الحساب',
      'المبلغ',
      'العملة',
      'سعر المصارفة',
      'المقابل بالبر'
    ];

    const dataRows = [];
    dataRows.push([title, '', '', '', '', '', '', '']);
    dataRows.push(headers);

    const threshold = this.settings.splitThreshold || 100000;
    const smallRecords = this.records.filter(r => (r.birrEquivalent || 0) <= threshold);
    const largeRecords = this.records.filter(r => (r.birrEquivalent || 0) > threshold);

    // 1. الحوالات الصغيرة
    if (smallRecords.length > 0) {
      dataRows.push([`--- الحوالات الصغيرة (من 1 إلى ${this.formatNumber(threshold)} بر) ---`, '', '', '', '', '', '', '']);
      smallRecords.forEach(r => {
        dataRows.push([
          r.originalSeq !== undefined ? r.originalSeq : '',
          r.date,
          r.name,
          r.id ? String(r.id) : '',
          r.amount,
          r.currency,
          r.rate,
          r.birrEquivalent
        ]);
      });
      const subAmt = smallRecords.reduce((s, r) => s + r.amount, 0);
      const subBirr = smallRecords.reduce((s, r) => s + r.birrEquivalent, 0);
      dataRows.push([
        'مجموع الحوالات الصغيرة',
        `عدد: ${smallRecords.length}`,
        '',
        '',
        subAmt,
        smallRecords[0]?.currency || '',
        '',
        subBirr
      ]);
      dataRows.push(['', '', '', '', '', '', '', '']); // سطر فاصل
    }

    // 2. الحوالات الكبيرة
    if (largeRecords.length > 0) {
      dataRows.push([`--- الحوالات الكبيرة (من ${this.formatNumber(threshold)} بر فأكثر) ---`, '', '', '', '', '', '', '']);
      largeRecords.forEach(r => {
        dataRows.push([
          r.originalSeq !== undefined ? r.originalSeq : '',
          r.date,
          r.name,
          r.id ? String(r.id) : '',
          r.amount,
          r.currency,
          r.rate,
          r.birrEquivalent
        ]);
      });
      const subAmt = largeRecords.reduce((s, r) => s + r.amount, 0);
      const subBirr = largeRecords.reduce((s, r) => s + r.birrEquivalent, 0);
      dataRows.push([
        'مجموع الحوالات الكبيرة',
        `عدد: ${largeRecords.length}`,
        '',
        '',
        subAmt,
        largeRecords[0]?.currency || '',
        '',
        subBirr
      ]);
      dataRows.push(['', '', '', '', '', '', '', '']); // سطر فاصل
    }

    // 3. الإجمالي العام
    if (this.settings.excelTotalRow) {
      const totalAmount = this.records.reduce((sum, r) => sum + r.amount, 0);
      const totalBirr = this.records.reduce((sum, r) => sum + r.birrEquivalent, 0);
      const totalCutCents = Math.round(this.records.reduce((sum, r) => sum + (r.cutCents || 0), 0) * 100) / 100;
      const totalCentsCount = Math.round(totalCutCents * 100);
      const currencyName = this.records[0]?.currency || this.settings.defaultCurrency || 'ريال سعودي';

      dataRows.push([
        'الإجمالي العام الشامل',
        `عدد الحسابات الكلي: ${this.records.length}`,
        '',
        '',
        totalAmount,
        currencyName,
        '',
        totalBirr
      ]);

      const birrLabel = (this.settings.birrLabel || 'birr').trim();
      dataRows.push([
        'إجمالي المبلغ المقطوع بالبر',
        totalCentsCount > 0 ? `الكسور المقتطعة: ${this.formatNumber(totalCentsCount)} سنت` : '0 سنت',
        '',
        '',
        '',
        '',
        '',
        `${totalCutCents.toFixed(2)} ${birrLabel}`
      ]);
    }

    const ws = XLSX.utils.aoa_to_sheet(dataRows);
    ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: 7 } }];
    ws['!views'] = [{ rightToLeft: true }];
    ws['!cols'] = [
      { wch: 10 },
      { wch: 14 },
      { wch: 28 },
      { wch: 22 },
      { wch: 16 },
      { wch: 14 },
      { wch: 14 },
      { wch: 18 }
    ];

    XLSX.utils.book_append_sheet(wb, ws, 'كشف الحوالات');
    const todayStr = new Date().toISOString().split('T')[0];
    const fileName = `${title.replace(/\s+/g, '_')}_${todayStr}.xlsx`;
    XLSX.writeFile(wb, fileName);
    this.showToast(`تم تصدير ملف الإكسل: ${fileName}`, 'success');
  }

  // ==================== 7. نسخ الجدول للحافظة ====================
  copyTableToClipboard() {
    if (this.records.length === 0) {
      this.showToast('لا توجد بيانات لنسخها', 'error');
      return;
    }

    const headers = ['الآيدي (ID)', 'التاريخ', 'اسم الحساب', 'رقم الحساب', 'المبلغ', 'العملة', 'سعر المصارفة', 'المقابل بالبر'];
    let tsv = headers.join('\t') + '\n';

    this.records.forEach((r, idx) => {
      const seq = r.originalSeq !== undefined ? r.originalSeq : (idx + 1);
      tsv += [
        seq,
        r.date,
        r.name,
        r.id,
        r.amount,
        r.currency,
        r.rate,
        r.birrEquivalent
      ].join('\t') + '\n';
    });

    const totalAmount = this.records.reduce((sum, r) => sum + r.amount, 0);
    const totalBirr = this.records.reduce((sum, r) => sum + r.birrEquivalent, 0);
    tsv += `الإجمالي\t\t${this.records.length} حساب\t\t${totalAmount}\t\t\t${totalBirr}\n`;

    navigator.clipboard.writeText(tsv).then(() => {
      this.showToast('تم نسخ الجدول للحافظة (يمكنك لصقه مباشرة في إكسل)', 'success');
    }).catch(() => {
      this.showToast('تعذر النسخ للحافظة', 'error');
    });
  }

  copyToClipboard(text, msg) {
    navigator.clipboard.writeText(text).then(() => {
      this.showToast(msg || 'تم النسخ', 'success');
    });
  }

  // ==================== 7.1 نسخ ومعاينة الرسالة الأصلية بالبر ====================
  generateCustomBirrMessage() {
    let recordsToUse = this.records;
    if (this.incomingCurrFilter && this.incomingCurrFilter !== 'ALL') {
      recordsToUse = recordsToUse.filter(r => (r.currency || this.settings.defaultCurrency || 'ريال سعودي').trim() === this.incomingCurrFilter);
    }
    if (recordsToUse.length === 0) return '';

    const currencyLabel = (this.settings.birrLabel || 'birr').trim();
    const threshold = this.settings.splitThreshold || 100000;
    const header = this.originalHeaderText || '';

    const smallRecords = recordsToUse.filter(r => (r.birrEquivalent || 0) <= threshold);
    const largeRecords = recordsToUse.filter(r => (r.birrEquivalent || 0) > threshold);

    const lines = [];
    if (header) {
      lines.push(header);
      lines.push('');
    }

    // 1. الحوالات الصغيرة في الأعلى
    if (smallRecords.length > 0) {
      lines.push(`--- الحوالات الصغيرة (1 إلى ${this.formatNumber(threshold)} بر) ---`);
      lines.push('');

      smallRecords.forEach((r, idx) => {
        const seq = r.originalSeq !== undefined ? r.originalSeq : (idx + 1);
        lines.push(`${seq},${r.name}`);
        if (r.id) lines.push(r.id);
        lines.push(`${this.formatNumber(r.birrEquivalent)} ${currencyLabel}`);
        lines.push('');
      });

      const subSmallBirr = smallRecords.reduce((s, r) => s + (r.birrEquivalent || 0), 0);
      lines.push(`total small=${this.formatNumber(subSmallBirr)} ${currencyLabel}`);
      lines.push('');
    }

    // 2. فاصل بارز بين الجزأين
    if (smallRecords.length > 0 && largeRecords.length > 0) {
      lines.push('----------------------------------------');
      lines.push('');
    }

    // 3. الحوالات الكبيرة في الأسفل
    if (largeRecords.length > 0) {
      lines.push(`--- الحوالات الكبيرة (${this.formatNumber(threshold)} بر فأكثر) ---`);
      lines.push('');

      largeRecords.forEach((r, idx) => {
        const seq = r.originalSeq !== undefined ? r.originalSeq : (idx + 1);
        lines.push(`${seq},${r.name}`);
        if (r.id) lines.push(r.id);
        lines.push(`${this.formatNumber(r.birrEquivalent)} ${currencyLabel}`);
        lines.push('');
      });

      const subLargeBirr = largeRecords.reduce((s, r) => s + (r.birrEquivalent || 0), 0);
      lines.push(`total large=${this.formatNumber(subLargeBirr)} ${currencyLabel}`);
      lines.push('');
    }

    // 4. فاصل وإجمالي عام بعد فاصل
    lines.push('========================================');
    const totalBirr = recordsToUse.reduce((sum, r) => sum + (r.birrEquivalent || 0), 0);
    lines.push(`total=${this.formatNumber(totalBirr)} ${currencyLabel}`);

    // 5. إجمالي المبلغ المقطوع بالبر (الكسور والأجزاء أقل من 100 سنت)
    const totalCutCents = Math.round(recordsToUse.reduce((sum, r) => sum + (r.cutCents || 0), 0) * 100) / 100;
    const totalCentsCount = Math.round(totalCutCents * 100);
    const birrLabel = (this.settings.birrLabel || 'birr').trim();
    lines.push(`اجمالي المبلغ المقطوع بالبر=${totalCutCents.toFixed(2)} ${birrLabel}${totalCentsCount > 0 ? ` (${this.formatNumber(totalCentsCount)} سنت)` : ''}`);
    lines.push(`total cut cents=${totalCutCents.toFixed(2)} ${birrLabel}`);

    return lines.join('\n');
  }

  copyOriginalMessage() {
    if (this.records.length === 0) {
      this.showToast('لا توجد بيانات لنسخها، يرجى إدخال الحسابات أولاً', 'error');
      return;
    }

    const message = this.generateCustomBirrMessage();
    navigator.clipboard.writeText(message).then(() => {
      this.showToast('تم نسخ رسالة كشف الحوالات بالبر بنجاح!', 'success');
    }).catch(() => {
      this.showToast('تعذر النسخ المباشر، يمكنك استخدام زر "معاينة الرسالة"', 'error');
    });
  }

  openPreviewModal() {
    if (this.records.length === 0) {
      this.showToast('لا توجد بيانات لمعاينتها', 'error');
      return;
    }

    const message = this.generateCustomBirrMessage();
    if (this.previewTextarea) {
      this.previewTextarea.value = message;
    }
    if (this.previewModal) {
      this.previewModal.classList.remove('hidden');
    }
  }

  closePreviewModal() {
    if (this.previewModal) {
      this.previewModal.classList.add('hidden');
    }
  }

  copyFromPreviewModal() {
    if (!this.previewTextarea) return;
    const text = this.previewTextarea.value;
    navigator.clipboard.writeText(text).then(() => {
      this.showToast('تم نسخ النص بالكامل بنجاح!', 'success');
      this.closePreviewModal();
    }).catch(() => {
      this.showToast('تعذر النسخ للحافظة', 'error');
    });
  }

  // ==================== 8. إدارة السجلات (إضافة / تعديل / حذف) ====================
  openAddRowModal() {
    document.getElementById('modal-title').textContent = 'إضافة سطر جديد';
    document.getElementById('edit-row-index').value = '-1';
    document.getElementById('edit-date').value = new Date().toLocaleDateString('en-CA');
    document.getElementById('edit-name').value = '';
    document.getElementById('edit-acc-id').value = '';
    document.getElementById('edit-amount').value = '';
    document.getElementById('edit-currency').value = this.settings.defaultCurrency;
    document.getElementById('edit-rate').value = this.settings.defaultRate;
    document.getElementById('edit-birr').value = '0';

    this.rowModal.classList.remove('hidden');
    document.getElementById('edit-name').focus();
  }

  openEditRowModal(index) {
    const r = this.records[index];
    if (!r) return;

    document.getElementById('modal-title').textContent = 'تعديل السجل';
    document.getElementById('edit-row-index').value = index;
    document.getElementById('edit-date').value = r.date;
    document.getElementById('edit-name').value = r.name;
    document.getElementById('edit-acc-id').value = r.id;
    document.getElementById('edit-amount').value = r.amount;
    document.getElementById('edit-currency').value = r.currency;
    document.getElementById('edit-rate').value = r.rate;
    document.getElementById('edit-birr').value = this.formatNumber(r.birrEquivalent);

    this.rowModal.classList.remove('hidden');
  }

  updateModalBirr() {
    const rawAmt = parseFloat(document.getElementById('edit-amount').value) || 0;
    const rate = parseFloat(document.getElementById('edit-rate').value) || 0;
    const rawBirr = rawAmt * rate;
    const birr = Math.floor(rawBirr / 100) * 100;
    document.getElementById('edit-birr').value = this.formatNumber(birr);
  }

  closeRowModal() {
    this.rowModal.classList.add('hidden');
  }

  saveRowModal() {
    const index = parseInt(document.getElementById('edit-row-index').value);
    const date = document.getElementById('edit-date').value.trim();
    const name = document.getElementById('edit-name').value.trim();
    const id = document.getElementById('edit-acc-id').value.trim();
    const amount = parseFloat(document.getElementById('edit-amount').value) || 0;
    const currency = document.getElementById('edit-currency').value.trim() || 'ريال سعودي';
    const rate = parseFloat(document.getElementById('edit-rate').value) || 48;
    const rawBirr = amount * rate;
    const birr = Math.floor(rawBirr / 100) * 100;
    const cutCents = Math.round((rawBirr - birr) * 100) / 100;

    const existingSeq = index !== -1 ? (this.records[index]?.originalSeq ?? (index + 1)) : (this.records.length + 1);
    const rowData = {
      originalSeq: existingSeq,
      date,
      name,
      id,
      amount,
      currency,
      rate,
      birrEquivalent: birr,
      cutCents
    };

    if (index === -1) {
      this.records.push(rowData);
      this.addAuditLog({
        type: 'edit',
        title: 'إضافة حساب يدوي (وارد)',
        description: `تمت إضافة المستفيد: ${name} بمبلغ ${this.formatNumber(amount)} ${currency}.`,
        tags: [name, `${this.formatNumber(amount)} ${currency}`]
      });
      this.showToast('تمت إضافة السجل بنجاح', 'success');
    } else {
      this.records[index] = rowData;
      this.addAuditLog({
        type: 'edit',
        title: 'تعديل حساب (وارد)',
        description: `تم تعديل بيانات المستفيد: ${name} (المبلغ: ${this.formatNumber(amount)} ${currency}).`,
        tags: [name, `${this.formatNumber(amount)} ${currency}`]
      });
      this.showToast('تم تعديل السجل بنجاح', 'success');
    }

    this.saveIncomingRecords();
    this.closeRowModal();
    this.render();
  }

  deleteRow(index) {
    const r = this.records[index];
    if (!r) return;
    if (confirm(`هل أنت متأكد من حذف حساب: "${r.name}"؟`)) {
      this.records.splice(index, 1);
      this.saveIncomingRecords();
      this.addAuditLog({
        type: 'delete',
        title: 'حذف حساب (وارد)',
        description: `تم حذف المستفيد: ${r.name} بمبلغ ${this.formatNumber(r.amount)} ${r.currency}.`,
        tags: [r.name]
      });
      this.render();
      this.showToast('تم حذف السجل', 'success');
    }
  }

  clearAllRecords() {
    if (this.records.length === 0) return;
    if (confirm('تحذير: هل أنت متأكد من مسح جميع السجلات من الجدول؟')) {
      const prevCount = this.records.length;
      this.records = [];
      this.saveIncomingRecords();
      this.addAuditLog({
        type: 'clear',
        title: 'تفريغ جدول الوارد بالكامل',
        description: `تم مسح جميع الحسابات الواردة (${prevCount} حساب).`,
        tags: [`${prevCount} حساب`]
      });
      this.render();
      this.showToast('تم تفريغ الجدول بالكامل', 'success');
    }
  }

  // ==================== 9. أدوات مساعدة ====================
  formatNumber(val) {
    if (val === null || val === undefined || isNaN(val)) return '0';
    // استقطاع أي رقم بعد الفاصلة العشرية (Truncate Decimals)
    const intVal = Math.trunc(Number(val));
    if (!this.settings.thousandsSep) return intVal.toString();
    return intVal.toLocaleString('en-US', {
      maximumFractionDigits: 0,
      minimumFractionDigits: 0
    });
  }

  escapeHtml(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `<span>${message}</span>`;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 3000);
  }

  // ==================== 10. إدارة كشف الحوالات الصادرة ====================
  loadOutgoingRecords() {
    try {
      const saved = localStorage.getItem('sharaf_outgoing_records');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      console.warn('Could not load outgoing records from localStorage:', e);
      return [];
    }
  }

  saveOutgoingRecords() {
    try {
      localStorage.setItem('sharaf_outgoing_records', JSON.stringify(this.outgoingRecords));
    } catch (e) {
      console.warn('Could not save outgoing records to localStorage:', e);
    }
  }

  setOutgoingCurrFilter(curr) {
    this.outgoingCurrFilter = curr;
    this.renderOutgoing();
  }

  buildOutgoingCurrFilterBar() {
    const container = document.getElementById('outgoing-curr-chips');
    if (!container) return;

    const currCounts = {};
    this.outgoingRecords.forEach(r => {
      const c = (r.currency || 'سعودي').trim();
      currCounts[c] = (currCounts[c] || 0) + 1;
    });

    const currencies = Object.keys(currCounts);
    let html = `<button type="button" class="curr-chip ${this.outgoingCurrFilter === 'ALL' ? 'active' : ''}" onclick="app.setOutgoingCurrFilter('ALL')">
      <span>جميع العملات (${this.outgoingRecords.length})</span>
    </button>`;

    currencies.forEach(curr => {
      const isActive = this.outgoingCurrFilter === curr;
      html += `<button type="button" class="curr-chip ${isActive ? 'active' : ''}" onclick="app.setOutgoingCurrFilter('${this.escapeHtml(curr)}')">
        <span>${this.escapeHtml(curr)} (${currCounts[curr]})</span>
      </button>`;
    });

    container.innerHTML = html;
  }

  renderOutgoing() {
    if (!this.outgoingTableBody) return;

    this.buildOutgoingCurrFilterBar();

    let filtered = this.outgoingRecords;
    if (this.outgoingCurrFilter && this.outgoingCurrFilter !== 'ALL') {
      filtered = filtered.filter(r => (r.currency || 'سعودي').trim() === this.outgoingCurrFilter);
    }

    if (this.outgoingSearchQuery) {
      const q = this.outgoingSearchQuery;
      filtered = filtered.filter(r =>
        (r.recipient && r.recipient.toLowerCase().includes(q)) ||
        (r.sender && r.sender.toLowerCase().includes(q)) ||
        (r.transferNo && r.transferNo.toLowerCase().includes(q)) ||
        (r.network && r.network.toLowerCase().includes(q)) ||
        (r.notes && r.notes.toLowerCase().includes(q)) ||
        (String(r.amount).includes(q))
      );
    }

    if (filtered.length === 0) {
      this.outgoingTableBody.innerHTML = `
        <tr>
          <td colspan="11" class="empty-state-cell" style="padding: 2.5rem 1rem; text-align: center;">
            <div style="font-size: 2.2rem; margin-bottom: 0.5rem;">📤</div>
            <h4 style="margin: 0 0 0.5rem; font-size: 1.05rem; color: var(--text-primary);">لا توجد حوالات صادرة مطابقة حالياً</h4>
            <p style="color: var(--text-secondary); font-size: 0.88rem; max-width: 480px; margin: 0 auto 1rem;">
              يمكنك لصق نصوص الحوالات الصادرة في تبويب "لصق واستيراد البيانات" أو إضافة حوالة يدوياً.
            </p>
            <button type="button" class="btn btn-primary btn-sm" onclick="app.loadOutgoingSampleAndSwitch()">
              ✨ تجربة نماذج الصادر الجاهزة
            </button>
          </td>
        </tr>`;
    } else {
      let html = '';
      filtered.forEach((r, idx) => {
        const originalIndex = this.outgoingRecords.indexOf(r);
        let currClass = 'badge-curr-sar';
        if (/دولار\s*ازرق/i.test(r.currency)) currClass = 'badge-curr-blue-usd';
        else if (/دولار/i.test(r.currency) || (r.currency && r.currency.includes('$'))) currClass = 'badge-curr-usd';

        html += `
          <tr>
            <td style="font-weight: 700; color: var(--text-secondary); text-align: center;">${idx + 1}</td>
            <td style="font-size: 0.85rem; white-space: nowrap;">${this.escapeHtml(r.date || '-')}</td>
            <td style="font-weight: 700; color: var(--text-primary);">${this.escapeHtml(r.recipient || '-')}</td>
            <td style="color: var(--text-secondary);">${this.escapeHtml(r.sender || '-')}</td>
            <td class="cell-ref-code">${this.escapeHtml(r.transferNo || '-')}</td>
            <td><span class="badge-network">${this.escapeHtml(r.network || '-')}</span></td>
            <td style="font-weight: 800; font-family: var(--font-mono); color: var(--color-primary); font-size: 1rem;">
              ${this.formatNumber(r.amount)}
            </td>
            <td><span class="badge-curr-tag ${currClass}">${this.escapeHtml(r.currency || '-')}</span></td>
            <td class="cell-commission">${this.escapeHtml(r.commission || '-')}</td>
            <td style="font-size: 0.85rem; color: var(--text-secondary);">${this.escapeHtml(r.notes || '-')}</td>
            <td class="no-print" style="white-space: nowrap; text-align: center;">
              <button class="action-btn edit-btn" onclick="app.openOutgoingModal(${originalIndex})" title="تعديل">✏️</button>
              <button class="action-btn delete-btn" onclick="app.deleteOutgoingRow(${originalIndex})" title="حذف">🗑️</button>
            </td>
          </tr>`;
      });
      this.outgoingTableBody.innerHTML = html;
    }

    // الإحصائيات والتذييل
    const totalCount = this.outgoingRecords.length;
    const isFiltered = this.outgoingCurrFilter && this.outgoingCurrFilter !== 'ALL';
    const recordsForTotals = isFiltered ? filtered : this.outgoingRecords;

    if (this.navOutgoingBadge) {
      this.navOutgoingBadge.textContent = totalCount;
    }

    const statCountEl = document.getElementById('outgoing-stat-count');
    if (statCountEl) {
      statCountEl.textContent = isFiltered ? `${filtered.length} / ${totalCount} حوالة` : `${totalCount} حوالة`;
    }

    const footerCountEl = document.getElementById('outgoing-footer-count');
    if (footerCountEl) {
      footerCountEl.textContent = isFiltered ? `${filtered.length} (من ${totalCount})` : totalCount;
    }

    const currMap = {};
    const networksSet = new Set();
    let commissionsCount = 0;

    recordsForTotals.forEach(r => {
      const c = r.currency || 'غير محدد';
      currMap[c] = (currMap[c] || 0) + (r.amount || 0);
      if (r.network && r.network !== '-') networksSet.add(r.network);
      if (r.commission && r.commission !== '-') commissionsCount++;
    });

    const statAmountsEl = document.getElementById('outgoing-stat-amounts');
    if (statAmountsEl) {
      const parts = Object.entries(currMap).map(([c, amt]) => `${this.formatNumber(amt)} ${c}`);
      statAmountsEl.textContent = parts.length > 0 ? parts.join(' • ') : '0';
      statAmountsEl.style.fontSize = parts.length > 2 ? '0.95rem' : '1.35rem';
    }

    // تذييل الجدول: مطابق تماماً للأعمدة الـ 11
    const footerEl = document.getElementById('outgoing-table-foot');
    if (footerEl) {
      const currEntries = Object.entries(currMap);
      if (currEntries.length === 0) {
        footerEl.innerHTML = `<tr class="total-row">
          <td colspan="6" class="total-label"><strong>إجمالي الحوالات الصادرة (<span id="outgoing-footer-count">${totalCount}</span> حوالة)</strong></td>
          <td class="total-amount">-</td>
          <td class="total-amount">-</td>
          <td class="total-amount">-</td>
          <td colspan="2" class="no-print"></td>
        </tr>`;
      } else {
        let footerHtml = '';
        currEntries.forEach(([curr, amt], i) => {
          if (i === 0) {
            footerHtml += `<tr class="total-row">
              <td colspan="6" class="total-label" rowspan="${currEntries.length}">
                <strong>إجمالي الحوالات الصادرة (${isFiltered ? `${filtered.length} (من ${totalCount})` : `${totalCount} حوالة`})</strong>
              </td>
              <td class="total-amount" style="font-family:var(--font-mono);font-weight:800;font-size:1rem;">${this.formatNumber(amt)}</td>
              <td class="total-amount" style="font-weight:700;">${this.escapeHtml(curr)}</td>
              <td class="total-amount" rowspan="${currEntries.length}" style="color:#d97706;font-weight:700;">${commissionsCount} بعمولة</td>
              <td colspan="2" class="no-print" rowspan="${currEntries.length}"></td>
            </tr>`;
          } else {
            footerHtml += `<tr class="total-row">
              <td class="total-amount" style="font-family:var(--font-mono);font-weight:800;font-size:1rem;">${this.formatNumber(amt)}</td>
              <td class="total-amount" style="font-weight:700;">${this.escapeHtml(curr)}</td>
            </tr>`;
          }
        });
        footerEl.innerHTML = footerHtml;
      }
    }

    const statCommsEl = document.getElementById('outgoing-stat-commissions');
    if (statCommsEl) {
      statCommsEl.textContent = `${commissionsCount} حوالة بعمولة`;
    }

    const statNetsEl = document.getElementById('outgoing-stat-networks');
    if (statNetsEl) {
      statNetsEl.textContent = `${networksSet.size} شبكة`;
    }
  }

  openOutgoingModal(index = -1) {
    const editIndexEl = document.getElementById('outgoing-edit-index');
    if (!editIndexEl) return;
    editIndexEl.value = index;
    const titleEl = document.getElementById('outgoing-modal-title');

    if (index === -1) {
      if (titleEl) titleEl.textContent = 'إضافة حوالة صادرة جديدة';
      document.getElementById('outgoing-edit-date').value = new Date().toLocaleDateString('en-CA');
      document.getElementById('outgoing-edit-recipient').value = '';
      document.getElementById('outgoing-edit-sender').value = '';
      document.getElementById('outgoing-edit-ref').value = '';
      document.getElementById('outgoing-edit-network').value = '';
      document.getElementById('outgoing-edit-amount').value = '';
      document.getElementById('outgoing-edit-currency').value = this.outgoingCurrFilter !== 'ALL' ? this.outgoingCurrFilter : 'ريال سعودي';
      document.getElementById('outgoing-edit-commission').value = '';
      document.getElementById('outgoing-edit-notes').value = '';
    } else {
      const r = this.outgoingRecords[index];
      if (!r) return;
      document.getElementById('outgoing-edit-date').value = r.date || '';
      document.getElementById('outgoing-edit-recipient').value = r.recipient || '';
      document.getElementById('outgoing-edit-sender').value = r.sender !== '-' ? r.sender : '';
      document.getElementById('outgoing-edit-ref').value = r.transferNo !== '-' ? r.transferNo : '';
      document.getElementById('outgoing-edit-network').value = r.network !== '-' ? r.network : '';
      document.getElementById('outgoing-edit-amount').value = r.amount || '';
      document.getElementById('outgoing-edit-currency').value = r.currency || 'ريال سعودي';
      document.getElementById('outgoing-edit-commission').value = r.commission !== '-' ? r.commission : '';
      document.getElementById('outgoing-edit-notes').value = r.notes || '';
    }

    if (this.outgoingModal) {
      this.outgoingModal.classList.remove('hidden');
    }
  }

  closeOutgoingModal() {
    if (this.outgoingModal) {
      this.outgoingModal.classList.add('hidden');
    }
  }

  saveOutgoingModal() {
    const index = parseInt(document.getElementById('outgoing-edit-index').value);
    const date = document.getElementById('outgoing-edit-date').value.trim();
    const recipient = document.getElementById('outgoing-edit-recipient').value.trim();
    const sender = document.getElementById('outgoing-edit-sender').value.trim() || '-';
    const transferNo = document.getElementById('outgoing-edit-ref').value.trim() || '-';
    const network = document.getElementById('outgoing-edit-network').value.trim() || '-';
    const amount = parseFloat(document.getElementById('outgoing-edit-amount').value) || 0;
    const currency = document.getElementById('outgoing-edit-currency').value.trim() || 'ريال سعودي';
    const commission = document.getElementById('outgoing-edit-commission').value.trim() || '-';
    const notes = document.getElementById('outgoing-edit-notes').value.trim();

    if (!recipient) {
      this.showToast('يرجى إدخال اسم المستلم', 'error');
      return;
    }

    const record = {
      date,
      recipient,
      sender,
      transferNo,
      network,
      amount,
      currency,
      commission,
      notes
    };

    if (index === -1) {
      this.outgoingRecords.push(record);
      this.addAuditLog({
        type: 'edit',
        title: 'إضافة حوالة صادرة يدوية',
        description: `تمت إضافة حوالة صادرة للمستلم: ${recipient} بمبلغ ${this.formatNumber(amount)} ${currency}.`,
        tags: [recipient, `${this.formatNumber(amount)} ${currency}`]
      });
      this.showToast('تمت إضافة الحوالة الصادرة بنجاح', 'success');
    } else {
      this.outgoingRecords[index] = record;
      this.addAuditLog({
        type: 'edit',
        title: 'تعديل حوالة صادرة',
        description: `تم تعديل حوالة المستلم: ${recipient} (المبلغ: ${this.formatNumber(amount)} ${currency}).`,
        tags: [recipient, `${this.formatNumber(amount)} ${currency}`]
      });
      this.showToast('تم تعديل الحوالة الصادرة بنجاح', 'success');
    }

    this.saveOutgoingRecords();
    this.closeOutgoingModal();
    this.renderOutgoing();
  }

  deleteOutgoingRow(index) {
    const r = this.outgoingRecords[index];
    if (!r) return;
    if (confirm(`هل أنت متأكد من حذف حوالة: "${r.recipient}"؟`)) {
      this.outgoingRecords.splice(index, 1);
      this.saveOutgoingRecords();
      this.addAuditLog({
        type: 'delete',
        title: 'حذف حوالة صادرة',
        description: `تم حذف حوالة المستلم: ${r.recipient} بمبلغ ${this.formatNumber(r.amount)} ${r.currency}.`,
        tags: [r.recipient]
      });
      this.renderOutgoing();
      this.showToast('تم حذف الحوالة الصادرة', 'success');
    }
  }

  clearAllOutgoing() {
    if (this.outgoingRecords.length === 0) return;
    if (confirm('تحذير: هل أنت متأكد من مسح جميع الحوالات الصادرة من الكشف؟')) {
      const prevCount = this.outgoingRecords.length;
      this.outgoingRecords = [];
      this.saveOutgoingRecords();
      this.addAuditLog({
        type: 'clear',
        title: 'تفريغ كشف الحوالات الصادرة بالكامل',
        description: `تم مسح جميع الحوالات الصادرة (${prevCount} حوالة).`,
        tags: [`${prevCount} حوالة`]
      });
      this.renderOutgoing();
      this.showToast('تم تفريغ كشف الحوالات الصادرة بالكامل', 'success');
    }
  }

  generateOutgoingMessage() {
    let recordsToUse = this.outgoingRecords;
    if (this.outgoingCurrFilter && this.outgoingCurrFilter !== 'ALL') {
      recordsToUse = recordsToUse.filter(r => (r.currency || 'سعودي').trim() === this.outgoingCurrFilter);
    }
    if (recordsToUse.length === 0) return '';

    const today = new Date().toLocaleDateString('ar-EG');
    const lines = [];
    lines.push(`📤 *كشف الحوالات الصادرة*`);
    lines.push(`📅 التاريخ: ${today}`);
    lines.push(`🔢 إجمالي الحوالات: ${recordsToUse.length}`);
    if (this.outgoingCurrFilter && this.outgoingCurrFilter !== 'ALL') {
      lines.push(`💱 العملة المحددة: ${this.outgoingCurrFilter}`);
    }
    lines.push('----------------------------------------');
    lines.push('');

    recordsToUse.forEach((r, idx) => {
      lines.push(`*${idx + 1}) المستلم:* ${r.recipient}`);
      if (r.sender && r.sender !== '-') {
        lines.push(`*المرسل:* ${r.sender}`);
      }
      lines.push(`*المبلغ:* ${this.formatNumber(r.amount)} ${r.currency}${r.commission && r.commission !== '-' ? ` (عمولة: ${r.commission})` : ''}`);
      if (r.transferNo && r.transferNo !== '-') {
        lines.push(`*رقم الحوالة:* ${r.transferNo}`);
      }
      if (r.network && r.network !== '-') {
        lines.push(`*الشبكة (عبر):* ${r.network}`);
      }
      if (r.notes) {
        lines.push(`*ملاحظة:* ${r.notes}`);
      }
      lines.push('');
    });

    lines.push('========================================');
    lines.push('💰 *إجمالي المبالغ الصادرة حسب العملات:*');
    const currMap = {};
    recordsToUse.forEach(r => {
      const c = r.currency || 'غير محدد';
      currMap[c] = (currMap[c] || 0) + (r.amount || 0);
    });
    for (const [curr, amt] of Object.entries(currMap)) {
      lines.push(`• ${this.formatNumber(amt)} ${curr}`);
    }

    return lines.join('\n');
  }

  previewOutgoingMessage() {
    if (this.outgoingRecords.length === 0) {
      this.showToast('لا توجد حوالات صادرة لمعاينتها', 'error');
      return;
    }
    const msg = this.generateOutgoingMessage();
    const textarea = document.getElementById('preview-outgoing-textarea');
    if (textarea) textarea.value = msg;
    if (this.outgoingPreviewModal) {
      this.outgoingPreviewModal.classList.remove('hidden');
    }
  }

  closeOutgoingPreviewModal() {
    if (this.outgoingPreviewModal) {
      this.outgoingPreviewModal.classList.add('hidden');
    }
  }

  async copyFromOutgoingPreviewModal() {
    const textarea = document.getElementById('preview-outgoing-textarea');
    if (!textarea || !textarea.value) return;
    try {
      await navigator.clipboard.writeText(textarea.value);
      this.showToast('تم نسخ رسالة الحوالات الصادرة بنجاح! جاهزة للإرسال في واتساب', 'success');
      this.closeOutgoingPreviewModal();
    } catch (err) {
      textarea.select();
      document.execCommand('copy');
      this.showToast('تم النسخ للحافظة!', 'success');
      this.closeOutgoingPreviewModal();
    }
  }

  async copyOutgoingMessage() {
    if (this.outgoingRecords.length === 0) {
      this.showToast('لا توجد بيانات حوالات صادرة لنسخها', 'error');
      return;
    }
    const msg = this.generateOutgoingMessage();
    try {
      await navigator.clipboard.writeText(msg);
      this.showToast('تم نسخ رسالة كشف الحوالات الصادرة بنجاح!', 'success');
    } catch (err) {
      this.previewOutgoingMessage();
    }
  }

  printOutgoingTable() {
    window.print();
  }

  exportOutgoingExcel() {
    if (this.outgoingRecords.length === 0) {
      this.showToast('لا توجد بيانات حوالات صادرة لتصديرها، يرجى استيراد أو إضافة حوالات أولاً', 'error');
      return;
    }

    if (typeof XLSX === 'undefined') {
      this.showToast('جاري تحميل مكتبة إكسل، يرجى المحاولة بعد لحظات', 'error');
      return;
    }

    const wb = XLSX.utils.book_new();
    const title = 'كشف الحوالات الصادرة';

    const headers = [
      'م',
      'التاريخ',
      'اسم المستلم',
      'اسم المرسل',
      'رقم الحوالة / المرجع',
      'اسم الشبكة (عبر)',
      'المبلغ',
      'العملة',
      'العمولة',
      'ملاحظات'
    ];

    const dataRows = [];
    dataRows.push([title, '', '', '', '', '', '', '', '', '']);
    dataRows.push(headers);

    this.outgoingRecords.forEach((r, idx) => {
      dataRows.push([
        idx + 1,
        r.date || '',
        r.recipient || '',
        r.sender || '',
        r.transferNo || '',
        r.network || '',
        r.amount || 0,
        r.currency || '',
        r.commission || '',
        r.notes || ''
      ]);
    });

    const currMap = {};
    this.outgoingRecords.forEach(r => {
      const c = r.currency || 'غير محدد';
      currMap[c] = (currMap[c] || 0) + (r.amount || 0);
    });

    dataRows.push(['', '', '', '', '', '', '', '', '', '']);
    dataRows.push(['إجمالي الحوالات الصادرة', `العدد الكلي: ${this.outgoingRecords.length}`, '', '', '', '', '', '', '', '']);

    for (const [curr, amt] of Object.entries(currMap)) {
      dataRows.push(['', '', '', '', '', `إجمالي ${curr}:`, amt, curr, '', '']);
    }

    const ws = XLSX.utils.aoa_to_sheet(dataRows);
    ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: 9 } }];
    ws['!views'] = [{ rightToLeft: true }];
    ws['!cols'] = [
      { wch: 6 },
      { wch: 14 },
      { wch: 28 },
      { wch: 28 },
      { wch: 20 },
      { wch: 22 },
      { wch: 16 },
      { wch: 16 },
      { wch: 18 },
      { wch: 20 }
    ];

    XLSX.utils.book_append_sheet(wb, ws, 'الحوالات الصادرة');
    const todayStr = new Date().toISOString().split('T')[0];
    const fileName = `كشف_الحوالات_الصادرة_${todayStr}.xlsx`;
    XLSX.writeFile(wb, fileName);
    this.showToast(`تم تصدير ملف الإكسل: ${fileName}`, 'success');
  }
}

// تهيئة التطبيق بمجرد اكتمال تحميل المستند
document.addEventListener('DOMContentLoaded', () => {
  window.app = new SharafApp();
});
