function cleanName(rawBlock, account, amountObj) {
  let lines = rawBlock.split('\n').map(l => l.trim()).filter(Boolean);
  
  // استبعاد السطور التي هي عبارة عن أرقام حسابات فقط أو تواريخ أو فواصل
  lines = lines.filter(l => {
    if (account && l.includes(account)) return false;
    if (/^\d{1,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,4}$/.test(l)) return false; // سطر تاريخ
    if (/^[\*\-_=~]+$/.test(l)) return false; // سطر فواصل
    return true;
  });

  // البحث عن السطر الذي يحتوي على الاسم (عادة السطر الذي فيه علامة = أو الاسم الإنجليزي/العربي)
  let nameLine = '';
  for (const l of lines) {
    if (l.includes('=') || /[a-zA-Z\u0600-\u06FF]{3,}/.test(l)) {
      nameLine = l;
      break;
    }
  }
  if (!nameLine && lines.length > 0) nameLine = lines[0];

  let cleaned = nameLine;
  if (amountObj && amountObj.original) {
    cleaned = cleaned.replace(amountObj.original, ' ');
  }
  if (account) {
    cleaned = cleaned.replace(account, ' ');
  }

  cleaned = cleaned
    .replace(/=/g, ' ')
    .replace(/^\s*\d+['.,\)\-\s]*/, '') // إزالة الترقيم التسلسلي من بداية الاسم مثل: 1' أو 2. أو 24'
    .replace(/\b(SAR|ryl|birr?|سعودي|ريال|دولار|usd|etb)\b/gi, ' ')
    .replace(/[.,]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  return cleaned;
}

console.log('1:', cleanName(`ዓዲ ዝሕወሎም ዝርዝር\n01/13/18\n1 'Maekelesh Ftwi=7,667`, '1000608369582', { original: '=7,667' }));
console.log('2:', cleanName(`2 kiros berhe=9,584`, '1000039884996', { original: '=9,584' }));
console.log('4:', cleanName(`4'Tesfay G/hiwet G/kidan=9,584`, '1000266078033', { original: '=9,584' }));
console.log('19:', cleanName(`19,Saba G/maryam =9,584`, '1000018869679', { original: '=9,584' }));
console.log('34:', cleanName(`34'Orjinal Angesom Mezgebo=4,792\n1000738510465\ntotal=227,620`, '1000738510465', { original: '=4,792' }));
