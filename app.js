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

class SharafApp {
  constructor() {
    this.records = [];
    this.settings = this.loadSettings();
    this.searchQuery = '';
    this.sortColumn = null;
    this.sortAsc = true;
    this.originalHeaderText = '';

    this.initElements();
    this.bindEvents();
    this.applySettingsToUI();
    this.switchTab('tab-paste');
    this.render();
  }

  // ==================== 1. الإعدادات والتهيئة ====================
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

    document.getElementById('btn-theme-toggle').addEventListener('click', () => this.toggleTheme());
    document.getElementById('btn-open-settings').addEventListener('click', () => this.switchTab('tab-settings'));
  }

  switchTab(tabId) {
    this.navTabs.forEach(t => t.classList.toggle('active', t.getAttribute('data-tab') === tabId));
    this.tabPanes.forEach(p => p.classList.toggle('active', p.id === tabId));

    // إخفاء كروت الإحصائيات العلوية في صفحة الإعدادات لتوفير مساحة شاشة الهاتف
    const metricsGrid = document.querySelector('.metrics-grid');
    if (metricsGrid) {
      if (tabId === 'tab-settings' || tabId === 'tab-help') {
        metricsGrid.classList.add('hidden-on-settings');
      } else {
        metricsGrid.classList.remove('hidden-on-settings');
      }
    }
  }

  // ==================== 3. خوارزمية التحليل الذكي للنصوص ====================
  parseFinancialText(text, options = {}) {
    const rate = options.rate || this.settings.defaultRate || 48;
    const currency = options.currency || this.settings.defaultCurrency || 'ريال سعودي';
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

      // تجاهل أسطر الإجماليات الفرعية أو أسطر السنتات لتفادي قراءتها كسجلات مستفيدين
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

        // استخراج الرقم التسلسلي / الآيدي الأصلي المذكور في بداية السطر (مثل: 1 أو 2 أو 3 أو 34)
        const seqMatch = leftPart.match(/^(\d+)[\s\,\'\.\-\_]*/);
        const originalSeq = seqMatch ? parseInt(seqMatch[1]) : (parsedRecords.length + 1);

        let cleanedName = leftPart.replace(/^\d+[\s\,\'\.\-\_]+/, '').trim();
        cleanedName = cleanedName.replace(/^[\'\"\‘\’]+/, '').trim();

        // تطبيع المبلغ واستقطاع الكسور / السنتات بعد الفاصلة العشرية وأي أجزاء أقل من 100 سنت
        let norm = rightPart.trim();
        if (/,\d{1,2}$/.test(norm)) {
          const idx = norm.lastIndexOf(',');
          norm = norm.substring(0, idx).replace(/,/g, '') + '.' + norm.substring(idx + 1);
        } else {
          norm = norm.replace(/,/g, '');
        }
        norm = norm.replace(/[^\d\.]/g, '');

        const amount = parseFloat(norm) || 0; // المبلغ للعملة الأصلية بدون استقطاع

        // استقطاع الكسور والسنتات للبر فقط (< 100 سنت)
        const rawBirr = amount * rate;
        const birrEquivalent = Math.trunc(rawBirr); // استقطاع الأجزاء بعد الفاصلة والتي أقل من 100 سنت للبر فقط
        const cutCents = Math.round((rawBirr - birrEquivalent) * 100) / 100; // سنتات البر المقطوعة

        pendingRecord = {
          originalSeq: originalSeq, // الحفاظ على التسلسل/الآيدي الأصلي
          date: detectedDate,
          name: cleanedName,
          id: '',
          amount: amount,
          currency: currency,
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
        } else if (!line.includes('=') && !/^(ዓዲ|ዝሕወሎም|total)/i.test(line)) {
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

  processRawText() {
    const rawText = this.rawTextInput.value.trim();
    if (!rawText) {
      this.showToast('يرجى لصق النص المالي أولاً', 'error');
      this.rawTextInput.focus();
      return;
    }

    const autoDate = document.getElementById('opt-auto-date').checked;
    const customDate = document.getElementById('input-custom-date').value.trim();
    const batchCurr = document.getElementById('input-batch-currency').value.trim() || this.settings.defaultCurrency;
    const batchRate = parseFloat(document.getElementById('input-batch-rate').value) || this.settings.defaultRate;

    const result = this.parseFinancialText(rawText, {
      rate: batchRate,
      currency: batchCurr,
      autoDate: autoDate,
      customDate: customDate
    });

    if (result.count === 0) {
      this.showToast('لم يتم العثور على سجلات مطابقة في النص. تأكد من وجود علامة = بين الاسم والمبلغ', 'error');
      return;
    }

    this.originalHeaderText = result.detectedHeader || '';
    this.records = result.records;
    this.render();

    let msg = `تم استخراج ${result.count} سجلاً بنجاح! الإجمالي: ${this.formatNumber(result.calculatedTotalAmount)} ${batchCurr}`;
    if (result.calculatedTotalCutCents > 0) {
      msg += ` (السنتات المقطوعة: ${result.calculatedTotalCutCents.toFixed(2)} [${Math.round(result.calculatedTotalCutCents * 100)} سنت])`;
    }
    if (result.textTotal !== null) {
      if (Math.abs(result.textTotal - result.calculatedTotalAmount) === 0) {
        msg += ` (مطابق لمجموع النص: ${this.formatNumber(result.textTotal)} ✓)`;
      } else {
        msg += ` (تنبيه: مجموع النص المدون هو ${this.formatNumber(result.textTotal)})`;
      }
    }

    this.parseStatusMsg.textContent = msg;
    this.parseStatusMsg.className = 'status-msg success';
    this.parseStatusMsg.classList.remove('hidden');

    this.showToast(`تم استيراد ${result.count} حساب بنجاح`, 'success');

    setTimeout(() => {
      this.switchTab('tab-table');
    }, 600);
  }

  loadSampleData() {
    this.rawTextInput.value = SAMPLE_RAW_TEXT;
    this.showToast('تم تحميل بيانات النموذج الإثيوبي (34 حساب)', 'success');
  }

  loadSampleDataAndSwitch() {
    this.loadSampleData();
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
      record.birrEquivalent = Math.trunc(rawBirr); // استقطاع الكسور للبر فقط
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
      this.records[index].birrEquivalent = Math.trunc(rawBirr);
      this.records[index].cutCents = Math.round((rawBirr - this.records[index].birrEquivalent) * 100) / 100;
      this.render();
    }
  }

  // ==================== 5. العرض والرندرة مع فصل الصغير والكبير ====================
  render() {
    let filtered = this.records.filter(r => {
      if (!this.searchQuery) return true;
      const q = this.searchQuery;
      return (
        r.name.toLowerCase().includes(q) ||
        r.id.toLowerCase().includes(q) ||
        r.amount.toString().includes(q) ||
        r.date.includes(q) ||
        r.currency.toLowerCase().includes(q)
      );
    });

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

    // حساب الإجماليات العامة
    const totalCount = this.records.length;
    const totalAmount = this.records.reduce((sum, r) => sum + (r.amount || 0), 0);
    const totalBirr = this.records.reduce((sum, r) => sum + (r.birrEquivalent || 0), 0);
    const totalCutCents = Math.round(this.records.reduce((sum, r) => sum + (r.cutCents || 0), 0) * 100) / 100;
    const totalCentsCount = Math.round(totalCutCents * 100);
    const currencyName = this.records[0]?.currency || this.settings.defaultCurrency || 'ريال سعودي';

    this.statCount.textContent = totalCount;
    this.statTotalAmount.textContent = this.formatNumber(totalAmount);
    this.statTotalBirr.textContent = this.formatNumber(totalBirr);
    this.navCountBadge.textContent = totalCount;

    const birrLabel = (this.settings.birrLabel || 'birr').trim();
    const statCutBirrEl = document.getElementById('stat-cut-cents-birr');
    if (statCutBirrEl) {
      statCutBirrEl.textContent = `المقطوع بالبر: ${totalCutCents.toFixed(2)} ${birrLabel}${totalCentsCount > 0 ? ` (${totalCentsCount} سنت)` : ''}`;
    }

    this.footerCount.textContent = totalCount;
    this.footerTotalAmount.textContent = `${this.formatNumber(totalAmount)} ${currencyName}`;
    this.footerTotalBirr.textContent = `${this.formatNumber(totalBirr)} بر`;

    const footerCutValEl = document.getElementById('footer-cut-cents-val');
    const footerCutDescEl = document.getElementById('footer-cut-cents-desc');
    if (footerCutValEl) footerCutValEl.textContent = `${totalCutCents.toFixed(2)} بر`;
    if (footerCutDescEl) {
      footerCutDescEl.textContent = totalCentsCount > 0 ? `(${totalCentsCount} سنت)` : `(0 سنت)`;
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
        totalCentsCount > 0 ? `الكسور المقتطعة: ${totalCentsCount} سنت` : '0 سنت',
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
    if (this.records.length === 0) return '';

    const currencyLabel = (this.settings.birrLabel || 'birr').trim();
    const threshold = this.settings.splitThreshold || 100000;
    const header = this.originalHeaderText || '';

    const smallRecords = this.records.filter(r => (r.birrEquivalent || 0) <= threshold);
    const largeRecords = this.records.filter(r => (r.birrEquivalent || 0) > threshold);

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
    const totalBirr = this.records.reduce((sum, r) => sum + (r.birrEquivalent || 0), 0);
    lines.push(`total=${this.formatNumber(totalBirr)} ${currencyLabel}`);

    // 5. إجمالي المبلغ المقطوع بالبر (الكسور والأجزاء أقل من 100 سنت)
    const totalCutCents = Math.round(this.records.reduce((sum, r) => sum + (r.cutCents || 0), 0) * 100) / 100;
    const totalCentsCount = Math.round(totalCutCents * 100);
    const birrLabel = (this.settings.birrLabel || 'birr').trim();
    lines.push(`اجمالي المبلغ المقطوع بالبر=${totalCutCents.toFixed(2)} ${birrLabel}${totalCentsCount > 0 ? ` (${totalCentsCount} سنت)` : ''}`);
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
    const amt = Math.trunc(rawAmt);
    const rate = parseFloat(document.getElementById('edit-rate').value) || 0;
    document.getElementById('edit-birr').value = this.formatNumber(Math.trunc(amt * rate));
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
    const birr = Math.trunc(rawBirr);
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
      this.showToast('تمت إضافة السجل بنجاح', 'success');
    } else {
      this.records[index] = rowData;
      this.showToast('تم تعديل السجل بنجاح', 'success');
    }

    this.closeRowModal();
    this.render();
  }

  deleteRow(index) {
    const r = this.records[index];
    if (!r) return;
    if (confirm(`هل أنت متأكد من حذف حساب: "${r.name}"؟`)) {
      this.records.splice(index, 1);
      this.render();
      this.showToast('تم حذف السجل', 'success');
    }
  }

  clearAllRecords() {
    if (this.records.length === 0) return;
    if (confirm('تحذير: هل أنت متأكد من مسح جميع السجلات من الجدول؟')) {
      this.records = [];
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
    }, 3200);
  }
}

// تهيئة التطبيق بمجرد اكتمال تحميل المستند
document.addEventListener('DOMContentLoaded', () => {
  window.app = new SharafApp();
});
