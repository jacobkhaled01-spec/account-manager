const WhatsAppParser = require('./modules/parsers/WhatsAppParser');

const testMsg = `ዓዲ ዝሕወሎም ዝርዝር
01/13/18
1 'Maekelesh Ftwi=7,667
1000608369582

2 kiros berhe=9,584
1000039884996

3 Letay Grmay=1,917
1000256679896

4'Tesfay G/hiwet G/kidan=9,584
1000266078033

5 mahlet Mengsh=9,584
1000774822066

6 Tuem Berhe=14,375
1000701515618

7 Shushay G/anenya=14,375
1000264694508

8 'Guesh Legish=9,584
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
*****
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
********
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

const records = WhatsAppParser.parse(testMsg, { rate: 48 });
console.log('Total records parsed:', records.length);
records.forEach((r, idx) => {
  console.log(`${idx + 1}: ${r.name} | ${r.id} | ${r.amount}`);
});
