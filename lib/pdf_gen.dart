import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'store.dart';

/// Noto Sans is downloaded once (needs internet the first time) and cached.
/// It contains Cyrillic incl. Kyrgyz letters ү, ө, ң.
Future<pw.Document> _newDoc() async {
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  return pw.Document(theme: pw.ThemeData.withFont(base: base, bold: bold));
}

pw.Widget _cell(String t, {bool bold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      child: pw.Text(t,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 9.5,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

Future<pw.Document> buildInvoicePdf(M sale, double prior) async {
  final doc = await _newDoc();
  final shop = store.settings;
  final phone = s_(shop['shopPhone']);
  final client = store.clients
      .where((c) => s_(c['name']).trim() == s_(sale['customer']).trim() && s_(sale['customer']).isNotEmpty)
      .firstOrNull;
  final outstanding = store.saleOutstanding(sale);
  final grandDebt = prior + outstanding;
  final items = its(sale);
  final totalQty = items.fold<int>(0, (a, i) => a + ni(i['qty']));
  const red = PdfColor.fromInt(0xFFAE3B26);
  const green = PdfColor.fromInt(0xFF14532D);

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(26),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Center(
          child: pw.Text('${tr('invoice_prefix')}${sale['orderNumber']}',
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 10),
      pw.Text(phone.isNotEmpty ? '${shop['shopName']} ($phone)' : s_(shop['shopName']),
          style: const pw.TextStyle(fontSize: 10)),
      if (s_(sale['customer']).isNotEmpty)
        pw.Text('${tr('buyer')} ${sale['customer']}', style: const pw.TextStyle(fontSize: 10)),
      if (client != null && s_(client['phone']).isNotEmpty)
        pw.Text('${tr('phone_number')} ${client['phone']}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text(
          '${tr('comment')} ${grandDebt > 0 ? '${tr('comment_debt')} ${fmt(grandDebt)}' : tr('comment_paid')}',
          style: pw.TextStyle(fontSize: 10, color: grandDebt > 0 ? red : green)),
      if (sale['status'] == 'debt' && n(sale['paidAmount']) > 0)
        pw.Text('${tr('paid_lbl')} ${fmt(n(sale['paidAmount']))}',
            style: const pw.TextStyle(fontSize: 10, color: green)),
      pw.Text('${tr('order_number')} №${sale['orderNumber']} ${tr('date_join')} ${fmtDate(s_(sale['date']))}',
          style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 12),
      pw.Table(
        border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(width: .4, color: PdfColors.grey500),
            bottom: pw.BorderSide(width: .8)),
        columnWidths: {
          0: const pw.FixedColumnWidth(20),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FixedColumnWidth(32),
          3: const pw.FixedColumnWidth(32),
          4: const pw.FlexColumnWidth(1.5),
          5: const pw.FlexColumnWidth(1.6),
        },
        children: [
          pw.TableRow(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
              children: [
                _cell(tr('th_num'), bold: true),
                _cell(tr('th_model'), bold: true),
                _cell(tr('th_unit'), bold: true, align: pw.TextAlign.center),
                _cell(tr('th_qty'), bold: true, align: pw.TextAlign.center),
                _cell(tr('th_price'), bold: true, align: pw.TextAlign.right),
                _cell(tr('th_sum'), bold: true, align: pw.TextAlign.right),
              ]),
          for (var i = 0; i < items.length; i++)
            pw.TableRow(children: [
              _cell('${i + 1}'),
              _cell(s_(items[i]['name'])),
              _cell(tr('pcs'), align: pw.TextAlign.center),
              _cell('${ni(items[i]['qty'])}', align: pw.TextAlign.center),
              _cell(fmt(n(items[i]['price'])), align: pw.TextAlign.right),
              _cell(fmt(n(items[i]['price']) * ni(items[i]['qty'])), align: pw.TextAlign.right),
            ]),
        ],
      ),
      pw.SizedBox(height: 8),
      if (n(sale['discountAmount']) > 0)
        pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('${tr('discount')}: −${fmt(n(sale['discountAmount']))}',
                style: const pw.TextStyle(fontSize: 10))),
      pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${tr('grand_total')}: ${fmt(n(sale['total']))}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 10),
      pw.Text(tr('invoice_summary', {'q': '$totalQty', 'a': fmt(n(sale['total']))}),
          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
      if (prior > 0) ...[
        pw.SizedBox(height: 8),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('${tr('receipt_prior')} ${fmt(prior)}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('${tr('receipt_new')} ${fmt(n(sale['total']))}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('${tr('receipt_grand')} ${fmt(prior + n(sale['total']))}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: red)),
            ])),
      ],
    ]),
  ));
  return doc;
}

Future<pw.Document> buildReportPdf() async {
  final doc = await _newDoc();
  final cs = store.cashStats();
  final debtors = store.customerStats().where((c) => n(c['debt']) > 0).toList();
  final totalDebt = debtors.fold<double>(0, (a, c) => a + n(c['debt']));
  final owed = store.suppliers.fold<double>(0, (a, s) => a + store.supplierDebt(s_(s['name'])));
  final stockValue = store.products.fold<double>(0, (a, p) => a + n(p['price']) * ni(p['stock']));
  final totalQty = store.products.fold<int>(0, (a, p) => a + ni(p['stock']));

  pw.Widget h(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
  pw.Widget l(String t, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Text(t,
          style: pw.TextStyle(fontSize: 10.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (ctx) => [
      pw.Text(s_(store.settings['shopName']), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text('${tr('tab_report')} · ${fmtDate(nowISO())}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
      l('${tr('cash_on_hand')}: ${fmt(cs['onHand']!)}', bold: true),
      l('${tr('total_debt')}: ${fmt(totalDebt)} (${debtors.length} ${tr('debtors')})'),
      l('${tr('owed_suppliers')}: ${fmt(owed)}'),
      h(tr('inv_title')),
      l('${tr('total_qty')}: $totalQty ${tr('pcs')} · ${tr('sell_value')}: ${fmt(stockValue)}'),
      pw.SizedBox(height: 4),
      for (final p in store.products)
        l('${p['name']} — ${fmt(n(p['price']))} · ${tr('stock_lbl')}: ${ni(p['stock'])}'),
      if (debtors.isNotEmpty) h(tr('overall_debt')),
      for (final c in debtors) l('${c['name']} — ${fmt(n(c['debt']))}'),
    ],
  ));
  return doc;
}
