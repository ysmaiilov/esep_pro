import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'auth.dart';
import 'lang.dart';
import 'pdf_gen.dart';
import 'store.dart';
import 'ui.dart';

String _today() => DateTime.now().toIso8601String().substring(0, 10);

// =====================================================================
//  PICK CLIENT
// =====================================================================
void openPickClientSheet(BuildContext c, void Function(String name) onPick) {
  final list = store.customerStats().where((x) => x['key'] != '__anon__').toList();
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('pick_customer'), children: [
            if (list.isEmpty)
              EmptyBlock(tr('no_clients'), tr('no_clients_desc'))
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                    children: divided(
                        ctx,
                        list.map((x) => ListTile(
                              title: Text(s_(x['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${s_(x['phone']).isNotEmpty ? '${x['phone']} · ' : ''}${x['count']} ${tr('purchases')}'),
                              trailing: n(x['debt']) > 0 ? Pill(tr('badge_debt'), kind: PillKind.debt) : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                onPick(s_(x['name']));
                              },
                            )))),
              ),
          ]));
}

// =====================================================================
//  PRODUCT
// =====================================================================
void openProductSheet(BuildContext c, [M? ex]) {
  final name = TextEditingController(text: s_(ex?['name']));
  final cat = TextEditingController(text: s_(ex?['category']));
  final cost = TextEditingController(text: ex != null && n(ex['costPrice']) > 0 ? numStr(n(ex['costPrice'])) : '');
  final price = TextEditingController(text: ex != null && n(ex['price']) > 0 ? numStr(n(ex['price'])) : '');
  final stock = TextEditingController(text: ex != null ? ni(ex['stock']).toString() : '');
  final supText = TextEditingController(text: s_(ex?['supplier']));
  var payment = s_(ex?['payment']).isEmpty ? 'cash' : s_(ex?['payment']);
  var supplier = s_(ex?['supplier']);
  final names = store.suppliers.map((x) => s_(x['name'])).toList();

  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            final cv = pnum(cost.text), pv = pnum(price.text), sv = pnum(stock.text).round();
            final margin = (cv > 0 && pv > 0) ? ((pv - cv) / cv * 100).round() : 0;
            final changes = ex == null
                ? <M>[]
                : (store.priceChanges.where((x) => x['productId'] == ex['id']).toList()
                  ..sort((a, b) => s_(b['date']).compareTo(s_(a['date']))));
            return SheetBody(title: ex == null ? tr('product_new') : tr('product_edit'), children: [
              AppField(label: tr('name'), controller: name),
              AppField(label: tr('category'), controller: cat),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: AppField(label: tr('cost_price'), controller: cost, number: true, onChanged: (_) => setS(() {}))),
                const SizedBox(width: 10),
                Expanded(child: AppField(label: tr('sell_price'), controller: price, number: true, onChanged: (_) => setS(() {}))),
              ]),
              if (cv > 0 && pv > 0)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('${tr('profit_prefix')} ${margin >= 0 ? '+' : ''}$margin% (${fmt(pv - cv)})',
                        style: TextStyle(fontWeight: FontWeight.w700, color: margin >= 0 ? ctx.cs.primary : ctx.debt))),
              AppField(label: tr('stock_lbl'), controller: stock, number: true, onChanged: (_) => setS(() {})),
              if (cv > 0 && sv > 0)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TotalCard(tr('total_cost'), '${fmt(cv)} × $sv = ${fmt(cv * sv)}')),
              Text(tr('supplier_payment'), style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 8),
              OptionTile(icon: Icons.payments_rounded, label: tr('paid_cash'), selected: payment == 'cash', onTap: () => setS(() => payment = 'cash')),
              OptionTile(icon: Icons.attach_money_rounded, label: tr('taken_credit'), selected: payment == 'debt', onTap: () => setS(() => payment = 'debt')),
              const SizedBox(height: 4),
              if (names.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: names.contains(supplier) ? supplier : '',
                      decoration: InputDecoration(labelText: tr('supplier_opt')),
                      items: [
                        DropdownMenuItem(value: '', child: Text(tr('no_supplier'))),
                        ...names.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                      ],
                      onChanged: (v) => supplier = v ?? '',
                    ))
              else
                AppField(label: tr('supplier_opt'), controller: supText),
              if (ex != null) ...[
                SectionHead(tr('price_history')),
                AppCard(
                  child: changes.isEmpty
                      ? Text(tr('no_price_history'), style: TextStyle(color: ctx.muted))
                      : Column(
                          children: divided(
                              ctx,
                              changes.take(5).map((ch) {
                                final up = n(ch['newPrice']) > n(ch['oldPrice']);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(fmtDate(s_(ch['date'])), style: TextStyle(color: ctx.muted, fontSize: 12)),
                                    if (n(ch['newPrice']) != n(ch['oldPrice']))
                                      Text('${tr('price_sell')}: ${fmt(n(ch['oldPrice']))} → ${fmt(n(ch['newPrice']))}',
                                          style: TextStyle(fontWeight: FontWeight.w700, color: up ? ctx.debt : ctx.cs.primary)),
                                    if (n(ch['newCostPrice']) != n(ch['oldCostPrice']))
                                      Text('${tr('price_cost')}: ${fmt(n(ch['oldCostPrice']))} → ${fmt(n(ch['newCostPrice']))}',
                                          style: TextStyle(color: ctx.muted, fontSize: 12.5)),
                                  ]),
                                );
                              }))),
                ),
                const SizedBox(height: 14),
              ],
              BigButton(tr('save'), icon: Icons.check_rounded, onPressed: () async {
                final nm = name.text.trim();
                if (nm.isEmpty) {
                  toast(tr('enter_name'));
                  return;
                }
                final category = cat.text.trim().isEmpty ? tr('other') : cat.text.trim();
                final costPrice = pnum(cost.text), pr = pnum(price.text), st = pnum(stock.text).round();
                final sup = names.isNotEmpty ? supplier : supText.text.trim();
                if (ex != null) {
                  if (pr != n(ex['price']) || costPrice != n(ex['costPrice'])) {
                    store.priceChanges.add({
                      'id': uid(), 'date': nowISO(), 'productId': ex['id'], 'productName': nm,
                      'oldPrice': n(ex['price']), 'newPrice': pr,
                      'oldCostPrice': n(ex['costPrice']), 'newCostPrice': costPrice,
                    });
                  }
                  ex['name'] = nm;
                  ex['category'] = category;
                  ex['costPrice'] = costPrice;
                  ex['price'] = pr;
                  ex['stock'] = st;
                  ex['supplier'] = sup;
                  ex['payment'] = payment;
                } else {
                  final id = uid();
                  store.products.add({
                    'id': id, 'name': nm, 'category': category, 'costPrice': costPrice, 'price': pr,
                    'stock': st, 'supplier': sup, 'payment': payment,
                  });
                  if (costPrice > 0 && st > 0) {
                    store.purchases.add({
                      'id': uid(), 'date': nowISO(), 'productId': id, 'productName': nm, 'qty': st,
                      'costPrice': costPrice, 'totalCost': costPrice * st, 'paidAmount': 0.0,
                      'supplier': sup, 'payment': payment, 'status': payment == 'debt' ? 'debt' : 'paid',
                    });
                  }
                }
                await store.save();
                if (ctx.mounted) Navigator.pop(ctx);
                toast(tr('saved'));
              }),
              if (ex != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: ctx.debt),
                    onPressed: () async {
                      if (!await confirmDialog(ctx, tr('delete_product_confirm'))) return;
                      await store.deleteProduct(s_(ex['id']));
                      await store.save();
                      if (ctx.mounted) Navigator.pop(ctx);
                      toast(tr('product_deleted'));
                    },
                    child: Text(tr('delete_product'))),
              ],
            ]);
          }));
}

// =====================================================================
//  STOCK IN
// =====================================================================
void openStockInSheet(BuildContext c) {
  if (store.products.isEmpty) {
    toast(tr('first_add_product'));
    return;
  }
  var pid = s_(store.products.first['id']);
  final qty = TextEditingController(), cost = TextEditingController(), price = TextEditingController();
  final supText = TextEditingController();
  var payment = 'cash';
  var supplier = '';
  final names = store.suppliers.map((x) => s_(x['name'])).toList();
  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            final q = pnum(qty.text).round(), cv = pnum(cost.text);
            return SheetBody(title: tr('stockin_title'), icon: Icons.move_to_inbox_rounded, children: [
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: pid,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('product')),
                    items: store.products
                        .map((p) => DropdownMenuItem(
                            value: s_(p['id']), child: Text('${p['name']} (${tr('current')} ${p['stock']})', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => pid = v ?? pid,
                  )),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: AppField(label: tr('qty_received'), controller: qty, number: true, onChanged: (_) => setS(() {}))),
                const SizedBox(width: 10),
                Expanded(child: AppField(label: tr('cost_price'), controller: cost, number: true, hint: tr('keep_price'), onChanged: (_) => setS(() {}))),
              ]),
              if (q > 0 && cv > 0)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: TotalCard(tr('total_cost'), '${fmt(cv)} × $q = ${fmt(cv * q)}')),
              AppField(label: tr('sell_price'), controller: price, number: true, hint: tr('keep_price')),
              OptionTile(icon: Icons.payments_rounded, label: tr('paid_cash'), selected: payment == 'cash', onTap: () => setS(() => payment = 'cash')),
              OptionTile(icon: Icons.attach_money_rounded, label: tr('taken_credit'), selected: payment == 'debt', onTap: () => setS(() => payment = 'debt')),
              const SizedBox(height: 4),
              if (names.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: names.contains(supplier) ? supplier : '',
                      decoration: InputDecoration(labelText: tr('supplier_opt')),
                      items: [
                        DropdownMenuItem(value: '', child: Text(tr('no_supplier'))),
                        ...names.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                      ],
                      onChanged: (v) => setS(() => supplier = v ?? ''),
                    ))
              else
                AppField(label: tr('supplier_opt'), controller: supText, hint: tr('supplier_name_ph')),
              BigButton(tr('register_stockin'), icon: Icons.check_rounded, onPressed: () async {
                final qn = pnum(qty.text).round();
                if (qn <= 0) {
                  toast(tr('enter_qty'));
                  return;
                }
                final p = store.product(pid);
                if (p == null) return;
                final oldPrice = n(p['price']), oldCost = n(p['costPrice']);
                final newPrice = pnum(price.text) > 0 ? pnum(price.text) : oldPrice;
                final newCost = pnum(cost.text) > 0 ? pnum(cost.text) : oldCost;
                p['stock'] = ni(p['stock']) + qn;
                p['price'] = newPrice;
                p['costPrice'] = newCost;
                if (newPrice != oldPrice || newCost != oldCost) {
                  store.priceChanges.add({
                    'id': uid(), 'date': nowISO(), 'productId': p['id'], 'productName': p['name'],
                    'oldPrice': oldPrice, 'newPrice': newPrice, 'oldCostPrice': oldCost, 'newCostPrice': newCost,
                  });
                }
                final sup = names.isNotEmpty ? supplier : supText.text.trim();
                store.stockIns.add({'id': uid(), 'date': nowISO(), 'productId': pid, 'productName': p['name'], 'qty': qn, 'supplier': sup});
                if (sup.isNotEmpty && newCost > 0) {
                  store.purchases.add({
                    'id': uid(), 'date': nowISO(), 'productId': pid, 'productName': p['name'], 'qty': qn,
                    'costPrice': newCost, 'totalCost': newCost * qn, 'paidAmount': 0.0, 'supplier': sup,
                    'payment': payment, 'status': payment == 'debt' ? 'debt' : 'paid',
                  });
                }
                await store.save();
                if (ctx.mounted) Navigator.pop(ctx);
                toast('${tr('stockin_done')}$qn ${tr('pcs')}');
              }),
            ]);
          }));
}

// =====================================================================
//  RECEIPT
// =====================================================================
String buildReceiptText(M sale, double prior) {
  final client = s_(sale['customer']).isEmpty
      ? null
      : store.clients.where((c) => s_(c['name']).trim() == s_(sale['customer']).trim()).firstOrNull;
  final grand = prior + store.saleOutstanding(sale);
  final shop = store.settings;
  final l = <String>[];
  l.add('${tr('invoice_prefix')}${sale['orderNumber']}');
  l.add(s_(shop['shopPhone']).isNotEmpty ? '${shop['shopName']} (${shop['shopPhone']})' : s_(shop['shopName']));
  if (s_(sale['customer']).isNotEmpty) l.add('${tr('buyer')} ${sale['customer']}');
  if (client != null && s_(client['phone']).isNotEmpty) l.add('${tr('phone_number')} ${client['phone']}');
  l.add('${tr('comment')} ${grand > 0 ? '${tr('comment_debt')} ${fmt(grand)}' : tr('comment_paid')}');
  if (sale['status'] == 'debt' && n(sale['paidAmount']) > 0) l.add('${tr('paid_lbl')} ${fmt(n(sale['paidAmount']))}');
  l.add('${tr('order_number')} №${sale['orderNumber']} ${tr('date_join')} ${fmtDate(s_(sale['date']))}');
  l.add('');
  var i = 0;
  for (final it in its(sale)) {
    i++;
    l.add('$i. ${it['name']} — ${it['qty']} ${tr('pcs')} x ${fmt(n(it['price']))} = ${fmt(n(it['price']) * ni(it['qty']))}');
  }
  l.add('');
  if (n(sale['discountAmount']) > 0) {
    l.add('${tr('subtotal')}: ${fmt(n(sale['subtotal']))}');
    final dl = sale['discountType'] == 'percent' ? '${numStr(n(sale['discountValue']))}%' : fmt(n(sale['discountValue']));
    l.add('${tr('discount')} ($dl): −${fmt(n(sale['discountAmount']))}');
  }
  l.add('${tr('grand_total')}: ${fmt(n(sale['total']))}');
  final pay = sale['payment'] == 'cash' ? tr('cash') : sale['payment'] == 'card' ? tr('card') : tr('on_credit');
  l.add('${tr('payment_prefix')} $pay');
  final qty = its(sale).fold<int>(0, (a, x) => a + ni(x['qty']));
  l.add('');
  l.add(tr('invoice_summary', {'q': '$qty', 'a': fmt(n(sale['total']))}));
  if (prior > 0) {
    l.add('');
    l.add('${tr('receipt_prior')} ${fmt(prior)}');
    l.add('${tr('receipt_new')} ${fmt(n(sale['total']))}');
    l.add('${tr('receipt_grand')} ${fmt(prior + n(sale['total']))}');
  }
  return l.join('\n');
}

void openReceiptSheet(BuildContext c, M sale, double prior) {
  final text = buildReceiptText(sale, prior);
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('sale_registered'), icon: Icons.receipt_long_rounded, children: [
            AppCard(child: SelectableText(text, style: mono(size: 12.5, w: FontWeight.w500).copyWith(height: 1.6))),
            const SizedBox(height: 16),
            Text(tr('choose_format'), style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    final doc = await buildInvoicePdf(sale, prior);
                    await Printing.sharePdf(bytes: await doc.save(), filename: 'nakladnaya-${sale['orderNumber']}.pdf');
                  } catch (_) {
                    toast(tr('generic_error'));
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(tr('fmt_pdf'))),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
                onPressed: () => Share.share(text, subject: s_(store.settings['shopName'])),
                icon: const Icon(Icons.share_rounded),
                label: Text(tr('fmt_text'))),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    await Printing.layoutPdf(onLayout: (_) async => (await buildInvoicePdf(sale, prior)).save());
                  } catch (_) {
                    toast(tr('generic_error'));
                  }
                },
                icon: const Icon(Icons.print_rounded),
                label: Text(tr('fmt_print'))),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
          ]));
}

// =====================================================================
//  EDIT SALE
// =====================================================================
void openEditSaleSheet(BuildContext c, String saleId) {
  final s = store.saleById(saleId);
  if (s == null) return;
  final editCart = <String, int>{for (final i in its(s)) s_(i['productId']): ni(i['qty'])};
  final orig = Map<String, int>.from(editCart);
  var payment = ['cash', 'card', 'debt'].contains(s['payment']) ? s_(s['payment']) : 'cash';
  var pm = s_(s['paidMethod']).isEmpty ? 'cash' : s_(s['paidMethod']);
  final cust = TextEditingController(text: s_(s['customer']));
  final paid = TextEditingController(text: s['payment'] == 'debt' ? numStr(n(s['paidAmount'])) : '');

  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            var total = 0.0;
            editCart.forEach((id, q) {
              final p = store.product(id);
              if (p != null && q > 0) total += n(p['price']) * q;
            });
            final paidNow = pnum(paid.text).clamp(0.0, total).toDouble();
            return SheetBody(title: tr('edit_sale'), icon: Icons.edit_rounded, children: [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                    children: divided(
                        ctx,
                        store.products.map((p) {
                          final id = s_(p['id']);
                          final q = editCart[id] ?? 0;
                          final max = ni(p['stock']) + (orig[id] ?? 0);
                          return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s_(p['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('${fmt(n(p['price']))} · ${tr('available')} $max', style: TextStyle(color: ctx.muted, fontSize: 12)),
                                ])),
                                QtyStepper(
                                    qty: q,
                                    onDec: () => setS(() => editCart[id] = (q > 0 ? q - 1 : 0)),
                                    onInc: () {
                                      if (q < max) {
                                        setS(() => editCart[id] = q + 1);
                                      } else {
                                        toast(tr('low_stock_toast'));
                                      }
                                    }),
                              ]));
                        }))),
              ),
              SectionHead(tr('customer_opt')),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: AppField(label: tr('customer_ph'), controller: cust)),
                const SizedBox(width: 8),
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filledTonal(
                        onPressed: () => openPickClientSheet(ctx, (nm) => setS(() => cust.text = nm)),
                        icon: const Icon(Icons.people_alt_rounded))),
              ]),
              SectionHead(tr('payment_method')),
              OptionTile(icon: Icons.payments_rounded, label: tr('cash'), selected: payment == 'cash', onTap: () => setS(() => payment = 'cash')),
              OptionTile(icon: Icons.credit_card_rounded, label: tr('card'), selected: payment == 'card', onTap: () => setS(() => payment = 'card')),
              OptionTile(icon: Icons.attach_money_rounded, label: tr('on_credit'), selected: payment == 'debt', onTap: () => setS(() => payment = 'debt')),
              if (payment == 'debt') ...[
                const SizedBox(height: 6),
                AppField(label: tr('paid_now_opt'), controller: paid, number: true, onChanged: (_) => setS(() {})),
                if (paidNow > 0) ...[
                  OptionTile(icon: Icons.payments_rounded, label: tr('cash'), selected: pm == 'cash', onTap: () => setS(() => pm = 'cash')),
                  OptionTile(icon: Icons.credit_card_rounded, label: tr('card'), selected: pm == 'card', onTap: () => setS(() => pm = 'card')),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('${tr('remaining_after')} ${fmt(total - paidNow)}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: total - paidNow > 0 ? ctx.debt : ctx.cs.primary))),
                ],
              ],
              const SizedBox(height: 8),
              TotalCard(tr('total'), fmt(total)),
              const SizedBox(height: 14),
              BigButton(tr('save'), icon: Icons.check_rounded, onPressed: () async {
                if (!editCart.values.any((q) => q > 0)) {
                  toast(tr('choose_product_toast'));
                  return;
                }
                final r = await store.applyEditSale(s, editCart, cust.text.trim(), payment, paid.text, pm);
                if (ctx.mounted) Navigator.pop(ctx);
                toast(tr('sale_updated'));
                if (c.mounted) openReceiptSheet(c, r.sale, r.prior);
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: ctx.debt),
                  onPressed: () async {
                    if (!await confirmDialog(ctx, tr('delete_sale_confirm'))) return;
                    await store.deleteSale(saleId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    toast(tr('sale_deleted'));
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(tr('yes_delete'))),
            ]);
          }));
}

// =====================================================================
//  ORDERS
// =====================================================================
void openTakeOrderSheet(BuildContext c, [M? ex]) {
  final oc = <String, int>{if (ex != null) for (final i in its(ex)) s_(i['productId']): ni(i['qty'])};
  final cust = TextEditingController(text: s_(ex?['customer']));
  final note = TextEditingController(text: s_(ex?['note']));
  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            var total = 0.0;
            oc.forEach((id, q) {
              final p = store.product(id);
              if (p != null && q > 0) total += n(p['price']) * q;
            });
            return SheetBody(title: ex == null ? tr('take_order') : tr('edit_order'), icon: Icons.assignment_rounded, children: [
              if (store.products.isEmpty)
                EmptyBlock(tr('no_products'), tr('no_products_desc'))
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                      children: divided(
                          ctx,
                          store.products.map((p) {
                            final id = s_(p['id']);
                            final q = oc[id] ?? 0;
                            return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(children: [
                                  Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(s_(p['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(fmt(n(p['price'])), style: TextStyle(color: ctx.muted, fontSize: 12)),
                                  ])),
                                  q > 0
                                      ? QtyStepper(
                                          qty: q,
                                          onDec: () => setS(() => oc[id] = q - 1),
                                          onInc: () => setS(() => oc[id] = q + 1))
                                      : FilledButton.tonal(
                                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                                          onPressed: () => setS(() => oc[id] = 1),
                                          child: Text(tr('add'))),
                                ]));
                          }))),
                ),
              SectionHead(tr('customer_opt')),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: AppField(label: tr('customer_ph'), controller: cust)),
                const SizedBox(width: 8),
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filledTonal(
                        onPressed: () => openPickClientSheet(ctx, (nm) => setS(() => cust.text = nm)),
                        icon: const Icon(Icons.people_alt_rounded))),
              ]),
              AppField(label: tr('order_note'), controller: note),
              TotalCard(tr('total'), fmt(total)),
              const SizedBox(height: 14),
              BigButton(ex == null ? tr('save_order') : tr('save'), icon: Icons.check_rounded,
                  onPressed: !oc.values.any((q) => q > 0)
                      ? null
                      : () async {
                          final items = <M>[];
                          oc.forEach((id, q) {
                            final p = store.product(id);
                            if (p != null && q > 0) items.add({'productId': id, 'name': p['name'], 'price': n(p['price']), 'qty': q});
                          });
                          if (items.isEmpty) return;
                          if (ex != null) {
                            ex['items'] = items;
                            ex['customer'] = cust.text.trim();
                            ex['note'] = note.text.trim();
                          } else {
                            store.orders.add({'id': uid(), 'date': nowISO(), 'customer': cust.text.trim(), 'items': items, 'note': note.text.trim(), 'status': 'pending'});
                          }
                          await store.save();
                          if (ctx.mounted) Navigator.pop(ctx);
                          toast(ex != null ? tr('sale_updated') : tr('order_saved'));
                        }),
            ]);
          }));
}

// =====================================================================
//  RETURNS
// =====================================================================
void openReturnPickSheet(BuildContext c) {
  final sales = ([...store.sales]..sort((a, b) => s_(b['date']).compareTo(s_(a['date']))))
      .where((s) => its(s).any((i) => ni(i['qty']) > 0))
      .take(25)
      .toList();
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('return_pick'), icon: Icons.undo_rounded, children: [
            if (sales.isEmpty)
              EmptyBlock(tr('no_history'), tr('no_sales_return_desc'))
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                    children: divided(
                        ctx,
                        sales.map((s) => ListTile(
                              title: Text(s_(s['customer']).isEmpty ? tr('default_customer') : s_(s['customer']),
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${fmtDate(s_(s['date']))} · ${its(s).map((i) => i['name']).join(', ')}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Text(fmt(n(s['total'])), style: mono(size: 13.5)),
                              onTap: () {
                                Navigator.pop(ctx);
                                openReturnItemsSheet(c, s_(s['id']));
                              },
                            )))),
              ),
          ]));
}

void openReturnItemsSheet(BuildContext c, String saleId) {
  final s = store.saleById(saleId);
  if (s == null) return;
  final draft = <int, int>{};
  var cond = 'valid';
  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            final items = its(s);
            var total = 0.0;
            draft.forEach((idx, q) => total += q * n(items[idx]['price']));
            return SheetBody(title: tr('return_items'), icon: Icons.undo_rounded, children: [
              Text('${s_(s['customer']).isEmpty ? tr('default_customer') : s['customer']} · ${fmtDate(s_(s['date']))}',
                  style: TextStyle(color: ctx.muted)),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  for (var idx = 0; idx < items.length; idx++) ...[
                    if (idx > 0) Divider(color: ctx.line),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s_(items[idx]['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${fmt(n(items[idx]['price']))} · ${tr('sold_suffix')} ${items[idx]['qty']}',
                                style: TextStyle(color: ctx.muted, fontSize: 12)),
                          ])),
                          QtyStepper(
                              qty: draft[idx] ?? 0,
                              onDec: () => setS(() => draft[idx] = ((draft[idx] ?? 0) > 0 ? (draft[idx]! - 1) : 0)),
                              onInc: () => setS(() {
                                    if ((draft[idx] ?? 0) < ni(items[idx]['qty'])) draft[idx] = (draft[idx] ?? 0) + 1;
                                  })),
                        ])),
                  ],
                ]),
              ),
              SectionHead(tr('cond_title')),
              OptionTile(icon: Icons.check_rounded, label: '${tr('cond_valid')} — ${tr('cond_valid_desc')}', selected: cond == 'valid', onTap: () => setS(() => cond = 'valid')),
              OptionTile(icon: Icons.close_rounded, label: '${tr('cond_invalid')} — ${tr('cond_invalid_desc')}', selected: cond == 'invalid', onTap: () => setS(() => cond = 'invalid')),
              const SizedBox(height: 8),
              TotalCard(tr('return_total'), fmt(total)),
              const SizedBox(height: 14),
              BigButton(tr('confirm_return'), icon: Icons.check_rounded,
                  onPressed: draft.values.every((q) => q <= 0)
                      ? null
                      : () async {
                          final ret = <M>[];
                          var amount = 0.0;
                          for (var idx = 0; idx < items.length; idx++) {
                            final q = draft[idx] ?? 0;
                            if (q <= 0) continue;
                            final i = items[idx];
                            ret.add({'productId': i['productId'], 'name': i['name'], 'price': n(i['price']), 'qty': q});
                            amount += q * n(i['price']);
                            i['qty'] = ni(i['qty']) - q;
                            if (cond == 'valid') {
                              final p = store.product(s_(i['productId']));
                              if (p != null) p['stock'] = ni(p['stock']) + q;
                            }
                          }
                          s['items'] = items.where((i) => ni(i['qty']) > 0).toList();
                          s['total'] = (n(s['total']) - amount).clamp(0.0, double.infinity).toDouble();
                          if (its(s).isEmpty) s['status'] = 'returned';
                          store.returns.add({'id': uid(), 'date': nowISO(), 'saleId': s['id'], 'customer': s['customer'], 'items': ret, 'amount': amount, 'condition': cond});
                          await store.save();
                          if (ctx.mounted) Navigator.pop(ctx);
                          final qn = ret.fold<int>(0, (a, i) => a + ni(i['qty']));
                          toast('${tr('return_done')} ${fmt(amount)} ($qn ${tr('pcs')})');
                        }),
            ]);
          }));
}

// =====================================================================
//  CASH: expense / withdrawal
// =====================================================================
void openExpenseSheet(BuildContext c) {
  final amount = TextEditingController(), cat = TextEditingController(), note = TextEditingController();
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('expense_title'), icon: Icons.remove_circle_outline_rounded, children: [
            AppField(label: tr('amount'), controller: amount, number: true),
            AppField(label: tr('category_opt'), controller: cat, hint: tr('category_ph')),
            AppField(label: tr('note_opt'), controller: note, hint: tr('note_ph')),
            BigButton(tr('save'), icon: Icons.check_rounded, onPressed: () async {
              final a = pnum(amount.text);
              if (a <= 0) {
                toast(tr('enter_amount'));
                return;
              }
              store.expenses.add({'id': uid(), 'date': nowISO(), 'amount': a, 'category': cat.text.trim(), 'note': note.text.trim()});
              await store.save();
              if (ctx.mounted) Navigator.pop(ctx);
              toast(tr('expense_saved'));
            }),
          ]));
}

void openWithdrawalSheet(BuildContext c) {
  final amount = TextEditingController(), note = TextEditingController();
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('withdrawal_title'), icon: Icons.output_rounded, children: [
            AppField(label: tr('amount'), controller: amount, number: true),
            AppField(label: tr('note_opt'), controller: note, hint: tr('withdrawal_note_ph')),
            BigButton(tr('save'), icon: Icons.check_rounded, onPressed: () async {
              final a = pnum(amount.text);
              if (a <= 0) {
                toast(tr('enter_amount'));
                return;
              }
              store.withdrawals.add({'id': uid(), 'date': nowISO(), 'amount': a, 'note': note.text.trim()});
              await store.save();
              if (ctx.mounted) Navigator.pop(ctx);
              toast(tr('withdrawal_saved'));
            }),
          ]));
}

// =====================================================================
//  CLIENT
// =====================================================================
void openClientEditSheet(BuildContext c, [M? ex]) {
  final isEdit = ex != null && ex['id'] != null;
  final name = TextEditingController(text: s_(ex?['name']));
  final phone = TextEditingController(text: s_(ex?['phone']));
  openSheet(
      c,
      (ctx) => SheetBody(title: isEdit ? tr('client_edit') : tr('client_new'), icon: Icons.person_rounded, children: [
            AppField(label: tr('name'), controller: name),
            AppField(label: tr('phone_opt'), controller: phone, hint: '0700 00 00 00'),
            BigButton(tr('save'), icon: Icons.check_rounded, onPressed: () async {
              final nm = name.text.trim();
              if (nm.isEmpty) {
                toast(tr('enter_name'));
                return;
              }
              if (isEdit) {
                for (final x in store.clients) {
                  if (x['id'] == ex['id']) {
                    x['name'] = nm;
                    x['phone'] = phone.text.trim();
                  }
                }
              } else {
                store.clients.add({'id': uid(), 'name': nm, 'phone': phone.text.trim()});
              }
              await store.save();
              if (ctx.mounted) Navigator.pop(ctx);
              toast(tr('saved'));
            }),
            if (isEdit) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: ctx.debt),
                  onPressed: () async {
                    if (!await confirmDialog(ctx, tr('delete_client_confirm'))) return;
                    store.d['clients'] = store.clients.where((x) => x['id'] != ex['id']).toList();
                    await store.save();
                    if (ctx.mounted) Navigator.pop(ctx);
                    toast(tr('client_deleted'));
                  },
                  child: Text(tr('delete_client'))),
            ],
          ]));
}

void openClientSheet(BuildContext c, String key) {
  var showPay = false;
  var pm = 'cash';
  final payCtl = TextEditingController();
  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            final cl = store.customerStats().where((x) => x['key'] == key).firstOrNull;
            if (cl == null) return SheetBody(title: '', children: [EmptyBlock(tr('no_clients'), '')]);
            final name = s_(cl['name']);
            final cname = name.trim();
            final debt = n(cl['debt']);
            final total = n(cl['total']);
            final events = <({String type, String date, M m})>[
              for (final s in (cl['sales'] as List<M>)) (type: 'order', date: s_(s['date']), m: s),
              for (final p in store.debtPayments.where((p) => s_(p['customer']).trim() == cname)) (type: 'payment', date: s_(p['date']), m: p),
              for (final r in store.returns.where((r) => s_(r['customer']).trim() == cname)) (type: 'return', date: s_(r['date']), m: r),
            ]..sort((a, b) => b.date.compareTo(a.date));

            Widget rowWrap(Widget left, Widget right) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 8), right]));

            Widget eventRow(({String type, String date, M m}) e) {
              final m = e.m;
              if (e.type == 'return') {
                final valid = m['condition'] != 'invalid';
                return rowWrap(
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(tr('event_return'), style: TextStyle(fontWeight: FontWeight.w800, color: ctx.accent)),
                      const SizedBox(width: 6),
                      Text(fmtDate(e.date), style: TextStyle(color: ctx.muted, fontSize: 12)),
                    ]),
                    Text(its(m).map((i) => '${i['name']} · ${i['qty']} ${tr('pcs')}').join(', '), style: TextStyle(color: ctx.muted, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Pill(valid ? tr('cond_valid') : tr('cond_invalid'), icon: valid ? Icons.check_rounded : Icons.close_rounded, kind: valid ? PillKind.paid : PillKind.debt),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('−${fmt(n(m['amount']))}', style: mono(color: ctx.accent, size: 14)),
                    const SizedBox(height: 6),
                    MiniBtn(Icons.delete_outline_rounded, () async {
                      if (!await confirmDialog(ctx, tr('delete_return_confirm'))) return;
                      await store.undoReturn(s_(m['id']));
                      setS(() {});
                      toast(tr('return_deleted'));
                    }, color: ctx.debt),
                  ]),
                );
              }
              if (e.type == 'payment') {
                return rowWrap(
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fmtDate(e.date), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${tr('debt_payment')} · ${m['method'] == 'card' ? tr('card') : tr('cash')}', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('+${fmt(n(m['amount']))}', style: mono(color: ctx.cs.primary, size: 14)),
                    const SizedBox(height: 6),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      MiniBtn(Icons.edit_rounded, () async {
                        final v = await askAmount(ctx, tr('edit_payment'), n(m['amount']));
                        if (v == null || v <= 0) return;
                        await store.undoDebtPayment(s_(m['id']));
                        await store.payCustomerDebt(cname, v, s_(m['method']).isEmpty ? 'cash' : s_(m['method']));
                        setS(() {});
                        toast(tr('payment_updated'));
                      }),
                      const SizedBox(width: 6),
                      MiniBtn(Icons.delete_outline_rounded, () async {
                        if (!await confirmDialog(ctx, tr('delete_payment_confirm'))) return;
                        await store.undoDebtPayment(s_(m['id']));
                        setS(() {});
                        toast(tr('payment_deleted'));
                      }, color: ctx.debt),
                    ]),
                  ]),
                );
              }
              return rowWrap(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtDate(e.date), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(its(m).map((i) => i['name']).join(', '), style: TextStyle(color: ctx.muted, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  statusPill(s_(m['status'])),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmt(n(m['total'])), style: mono(size: 14)),
                  if (m['status'] == 'debt') ...[
                    if (n(m['paidAmount']) > 0) Text('${tr('paid_lbl')} ${fmt(n(m['paidAmount']))}', style: TextStyle(color: ctx.muted, fontSize: 11.5)),
                    Text('${tr('current_debt_inline')} ${fmt(store.saleOutstanding(m))}', style: TextStyle(color: ctx.debt, fontSize: 11.5)),
                  ],
                  const SizedBox(height: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    MiniBtn(Icons.edit_rounded, () {
                      Navigator.pop(ctx);
                      openEditSaleSheet(c, s_(m['id']));
                    }),
                    const SizedBox(width: 6),
                    MiniBtn(Icons.delete_outline_rounded, () async {
                      if (!await confirmDialog(ctx, tr('delete_sale_confirm'))) return;
                      await store.deleteSale(s_(m['id']));
                      setS(() {});
                      toast(tr('sale_deleted'));
                    }, color: ctx.debt),
                  ]),
                ]),
              );
            }

            final payAmount = pnum(payCtl.text).clamp(0.0, debt).toDouble();
            return SheetBody(title: name, icon: Icons.person_rounded, children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final rec = cl['manualId'] == null ? null : store.clients.where((x) => x['id'] == cl['manualId']).firstOrNull;
                        openClientEditSheet(c, rec ?? {'id': null, 'name': name, 'phone': s_(cl['phone'])});
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: Text(tr('client_edit')))),
              Row(children: [
                Expanded(child: StatTile(label: tr('total_purchases'), value: fmt(total))),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: tr('current_debt'), value: fmt(debt), valueColor: debt > 0 ? ctx.debt : null)),
              ]),
              const SizedBox(height: 10),
              StatTile(label: tr('total_paid'), value: fmt((total - debt).clamp(0.0, double.infinity)), valueColor: ctx.cs.primary),
              const SizedBox(height: 14),
              if (debt > 0)
                showPay
                    ? AppCard(
                        border: ctx.cs.primary.withAlpha(120),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          AppField(label: tr('pay_amount_q'), controller: payCtl, number: true, hint: '${debt.round()}', onChanged: (_) => setS(() {})),
                          OptionTile(icon: Icons.payments_rounded, label: tr('cash'), selected: pm == 'cash', onTap: () => setS(() => pm = 'cash')),
                          OptionTile(icon: Icons.credit_card_rounded, label: tr('card'), selected: pm == 'card', onTap: () => setS(() => pm = 'card')),
                          if (payAmount > 0)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text('${tr('remaining_after')} ${fmt(debt - payAmount)}',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: debt - payAmount > 0 ? ctx.debt : ctx.cs.primary))),
                          Row(children: [
                            Expanded(
                                child: BigButton(tr('record_payment'), onPressed: () async {
                              if (payAmount <= 0) {
                                toast(tr('enter_amount'));
                                return;
                              }
                              await store.payCustomerDebt(name, payAmount, pm);
                              showPay = false;
                              payCtl.clear();
                              setS(() {});
                              toast(tr('payment_recorded'));
                            })),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton(onPressed: () => setS(() => showPay = false), child: Text(tr('no')))),
                          ]),
                        ]))
                    : BigButton(tr('close_debt'), icon: Icons.check_rounded, onPressed: () => setS(() => showPay = true)),
              SectionHead(tr('history')),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: events.isEmpty ? EmptyBlock(tr('no_sales'), '') : Column(children: divided(ctx, events.map(eventRow))),
              ),
            ]);
          }));
}

// =====================================================================
//  SUPPLIER
// =====================================================================
void openSupplierSheet(BuildContext c, [M? ex]) {
  final name = TextEditingController(text: s_(ex?['name']));
  final phone = TextEditingController(text: s_(ex?['phone']));
  final note = TextEditingController(text: s_(ex?['note']));
  final payCtl = TextEditingController();
  var showPay = false;
  var pm = 'cash';
  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            final sname = s_(ex?['name']);
            final debt = ex != null ? store.supplierDebt(sname) : 0.0;
            final payAmount = pnum(payCtl.text).clamp(0.0, debt).toDouble();
            final purchases = ex == null ? <M>[] : store.purchases.where((p) => p['supplier'] == sname).toList();
            final payments = ex == null ? <M>[] : store.supplierPayments.where((p) => p['supplier'] == sname).toList();
            final totalGoods = purchases.fold<double>(0, (a, p) => a + n(p['totalCost']));
            final events = <({String type, String date, M m})>[
              for (final p in purchases) (type: 'purchase', date: s_(p['date']), m: p),
              for (final p in payments) (type: 'payment', date: s_(p['date']), m: p),
            ]..sort((a, b) => a.date.compareTo(b.date));
            final numbered = <int, ({String type, String date, M m})>{for (var i = 0; i < events.length; i++) i + 1: events[i]};
            final shown = numbered.entries.toList().reversed.toList();

            Widget badge(int pos) => Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: BoxDecoration(color: ctx.line, borderRadius: BorderRadius.circular(99)),
                  child: Text('$pos', style: mono(size: 10.5, color: ctx.muted)),
                );

            Widget eventRow(int pos, ({String type, String date, M m}) e) {
              final m = e.m;
              if (e.type == 'payment') {
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      badge(pos),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fmtDate(e.date), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${tr('supplier_payment_event')} · ${m['method'] == 'card' ? tr('card') : tr('cash')}', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
                      ])),
                      Text('−${fmt(n(m['amount']))}', style: mono(color: ctx.cs.primary, size: 14)),
                    ]));
              }
              final isDebt = m['status'] == 'debt';
              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    badge(pos),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(tr('event_stockin'), style: TextStyle(fontWeight: FontWeight.w800, color: ctx.accent)),
                        const SizedBox(width: 6),
                        Text(fmtDate(e.date), style: TextStyle(color: ctx.muted, fontSize: 12)),
                      ]),
                      Text('${m['productName']} · ${m['qty']} ${tr('pcs')}', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      GestureDetector(
                          onTap: () async {
                            if (isDebt) {
                              m['status'] = 'paid';
                              m['payment'] = 'cash';
                              m['paidAmount'] = n(m['totalCost']);
                            } else {
                              m['status'] = 'debt';
                              m['payment'] = 'debt';
                              m['paidAmount'] = 0.0;
                            }
                            await store.save();
                            setS(() {});
                            toast(tr('payment_status_changed'));
                          },
                          child: Pill(isDebt ? tr('taken_credit') : tr('paid_cash'),
                              icon: isDebt ? Icons.attach_money_rounded : Icons.check_rounded,
                              kind: isDebt ? PillKind.debt : PillKind.paid)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmt(n(m['totalCost'])), style: mono(size: 14)),
                      const SizedBox(height: 6),
                      MiniBtn(Icons.delete_outline_rounded, () async {
                        if (!await confirmDialog(ctx, tr('delete_purchase_confirm'))) return;
                        await store.deletePurchase(s_(m['id']));
                        setS(() {});
                        toast(tr('purchase_deleted'));
                      }, color: ctx.debt),
                    ]),
                  ]));
            }

            return SheetBody(title: ex == null ? tr('supplier_new') : tr('supplier_edit'), icon: Icons.local_shipping_rounded, children: [
              AppField(label: tr('name_org'), controller: name, hint: tr('name_org_ph')),
              AppField(label: tr('phone_opt'), controller: phone, hint: '0700 00 00 00'),
              AppField(label: tr('delivers_opt'), controller: note, hint: tr('delivers_ph')),
              if (ex != null && debt > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: ctx.debtBg.withAlpha(90),
                    border: ctx.debt.withAlpha(90),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('we_owe_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(tr('unpaid_amount_desc'), style: TextStyle(color: ctx.muted, fontSize: 12)),
                        ])),
                        Text(fmt(debt), style: mono(color: ctx.debt, size: 17, w: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 10),
                      if (showPay) ...[
                        AppField(label: tr('pay_amount_q'), controller: payCtl, number: true, hint: '${debt.round()}', onChanged: (_) => setS(() {})),
                        OptionTile(icon: Icons.payments_rounded, label: tr('cash'), selected: pm == 'cash', onTap: () => setS(() => pm = 'cash')),
                        OptionTile(icon: Icons.credit_card_rounded, label: tr('card'), selected: pm == 'card', onTap: () => setS(() => pm = 'card')),
                        if (payAmount > 0)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text('${tr('remaining_after')} ${fmt(debt - payAmount)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        Row(children: [
                          Expanded(
                              child: BigButton(tr('record_payment'), onPressed: () async {
                            if (payAmount <= 0) {
                              toast(tr('enter_amount'));
                              return;
                            }
                            await store.paySupplierDebt(sname, payAmount, pm);
                            showPay = false;
                            payCtl.clear();
                            setS(() {});
                            toast(tr('payment_recorded'));
                          })),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton(onPressed: () => setS(() => showPay = false), child: Text(tr('no')))),
                        ]),
                      ] else
                        BigButton(tr('mark_supplier_paid'), onPressed: () => setS(() => showPay = true)),
                    ]),
                  ),
                ),
              if (ex != null) ...[
                if (totalGoods > 0) StatTile(label: tr('total_goods'), value: fmt(totalGoods)),
                SectionHead(tr('history')),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: shown.isEmpty
                      ? EmptyBlock(tr('no_history'), '')
                      : Column(children: divided(ctx, shown.map((e) => eventRow(e.key, e.value)))),
                ),
                const SizedBox(height: 14),
              ],
              BigButton(tr('save'), icon: Icons.check_rounded, onPressed: () async {
                final nm = name.text.trim();
                if (nm.isEmpty) {
                  toast(tr('enter_name'));
                  return;
                }
                final dup = store.suppliers.where((x) => s_(x['name']).trim().toLowerCase() == nm.toLowerCase() && (ex == null || x['id'] != ex['id'])).isNotEmpty;
                if (dup) {
                  toast(tr('dup_supplier'));
                  return;
                }
                if (ex != null) {
                  ex['name'] = nm;
                  ex['phone'] = phone.text.trim();
                  ex['note'] = note.text.trim();
                } else {
                  store.suppliers.add({'id': uid(), 'name': nm, 'phone': phone.text.trim(), 'note': note.text.trim()});
                }
                await store.save();
                if (ctx.mounted) Navigator.pop(ctx);
                toast(tr('saved'));
              }),
              if (ex != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: ctx.debt),
                    onPressed: () async {
                      if (!await confirmDialog(ctx, tr('delete_supplier_confirm'))) return;
                      store.d['suppliers'] = store.suppliers.where((x) => x['id'] != ex['id']).toList();
                      await store.save();
                      if (ctx.mounted) Navigator.pop(ctx);
                      toast(tr('supplier_deleted'));
                    },
                    child: Text(tr('delete_supplier'))),
              ],
            ]);
          }));
}

// =====================================================================
//  MENU, SETTINGS, SUPPORT, SUBSCRIBE, EXPORT, IMPORT, RESET
// =====================================================================
/// Колдонуучунун профили: Google сүрөтү, аты жана email.
Widget _profileCard(BuildContext ctx) {
  final u = currentUser;
  if (u == null) return const SizedBox.shrink();
  final photo = u.photoURL;
  return AppCard(
    child: Row(children: [
      CircleAvatar(
          radius: 26,
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null ? const Icon(Icons.person_rounded) : null),
      const SizedBox(width: 12),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(u.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(u.email ?? '', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
      ])),
    ]),
  );
}

Future<void> _confirmLogout(BuildContext c) async {
  final ok = await confirmDialog(c, tr('logout_confirm'), yes: tr('logout'), danger: false);
  if (!ok) return;
  await signOut();
}

void openMenuSheet(BuildContext c) {
  Widget item(BuildContext ctx, IconData ic, String t, String d, VoidCallback f) => ListTile(
        leading: IconBox(ic, size: 40),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(d, style: TextStyle(color: ctx.muted, fontSize: 12.5)),
        trailing: Icon(Icons.chevron_right_rounded, color: ctx.muted),
        onTap: () {
          Navigator.pop(ctx);
          f();
        },
      );
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('menu'), icon: Icons.menu_rounded, children: [
            _profileCard(ctx),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                  children: divided(ctx, [
                item(ctx, Icons.settings_rounded, tr('settings'), tr('settings_desc'), () => openSettingsSheet(c)),
                item(ctx, Icons.favorite_rounded, tr('support'), tr('support_desc'), () => openSupportSheet(c)),
                item(ctx, Icons.star_rounded, tr('subscribe'), tr('subscribe_desc'), () => openSubscribeSheet(c)),
                item(ctx, Icons.download_rounded, tr('export'), tr('export_desc'), () => openExportSheet(c)),
                item(ctx, Icons.upload_rounded, tr('import'), tr('import_desc'), () => _importFlow(c)),
                item(ctx, Icons.warning_amber_rounded, tr('reset'), tr('reset_desc'), () => openResetSheet(c)),
                item(ctx, Icons.logout_rounded, tr('logout'), tr('logout_desc'), () => _confirmLogout(c)),
              ])),
            ),
            const SizedBox(height: 14),
            Center(child: Text('${tr('app_version')} 1.0', style: TextStyle(color: ctx.muted, fontSize: 12))),
          ]));
}

void openSettingsSheet(BuildContext c) {
  final s = store.settings;
  final name = TextEditingController(text: s_(s['shopName']));
  final sub = TextEditingController(text: s_(s['shopSubtitle']));
  final phone = TextEditingController(text: s_(s['shopPhone']));
  var lang = s_(s['language']);
  var theme = s_(s['theme']);
  openSheet(
      c,
      (ctx) => StatefulBuilder(builder: (ctx, setS) {
            return SheetBody(title: tr('settings'), icon: Icons.settings_rounded, children: [
              AppField(label: tr('shop_name'), controller: name),
              AppField(label: tr('shop_subtitle'), controller: sub),
              AppField(label: tr('shop_phone'), controller: phone, hint: '+996 XXX XXX XXX'),
              Text(tr('language'), style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in kLangNames.entries)
                  ChoiceChip(label: Text(e.value), selected: lang == e.key, onSelected: (_) => setS(() => lang = e.key)),
              ]),
              const SizedBox(height: 16),
              Text(tr('theme'), style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'system', icon: const Icon(Icons.brightness_auto_rounded), label: Text(tr('theme_system'))),
                  ButtonSegment(value: 'light', icon: const Icon(Icons.light_mode_rounded), label: Text(tr('theme_light'))),
                  ButtonSegment(value: 'dark', icon: const Icon(Icons.dark_mode_rounded), label: Text(tr('theme_dark'))),
                ],
                selected: {theme},
                onSelectionChanged: (v) => setS(() => theme = v.first),
              ),
              const SizedBox(height: 20),
              BigButton(tr('save'), icon: Icons.check_rounded, onPressed: () async {
                s['shopName'] = name.text.trim().isEmpty ? 'ЭСЕП' : name.text.trim();
                s['shopSubtitle'] = sub.text.trim().isEmpty ? 'Дүкөн эсеби' : sub.text.trim();
                s['shopPhone'] = phone.text.trim();
                s['language'] = lang;
                s['theme'] = theme;
                await store.save();
                if (ctx.mounted) Navigator.pop(ctx);
                toast(tr('saved'));
              }),
            ]);
          }));
}

void openSupportSheet(BuildContext c) {
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('support_heading'), icon: Icons.favorite_rounded, children: [
            AppCard(child: Text(tr('support_message'), style: const TextStyle(height: 1.6))),
            const SizedBox(height: 16),
            BigButton(tr('share_app'), icon: Icons.share_rounded, onPressed: () => Share.share(tr('share_app_text'))),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
          ]));
}

void openSubscribeSheet(BuildContext c) {
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('subscribe_heading'), icon: Icons.star_rounded, children: [
            AppCard(
                border: ctx.cs.primary.withAlpha(100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(tr('free_plan'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    Pill(tr('current_plan'), icon: Icons.check_rounded, kind: PillKind.paid),
                  ]),
                  const SizedBox(height: 4),
                  Text(tr('free_plan_desc'), style: TextStyle(color: ctx.muted)),
                ])),
            const SizedBox(height: 12),
            AppCard(
                color: ctx.accentBg,
                border: Colors.transparent,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(tr('pro_plan'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                    Icon(Icons.star_rounded, color: ctx.accent),
                  ]),
                  Text(tr('pro_plan_desc'), style: TextStyle(color: ctx.muted)),
                  const SizedBox(height: 8),
                  for (final k in ['pro_f1', 'pro_f2', 'pro_f3', 'pro_f4'])
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.star_rounded, size: 16, color: ctx.accent),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tr(k))),
                        ])),
                ])),
            const SizedBox(height: 14),
            BigButton(tr('upgrade'), icon: Icons.star_rounded, bg: ctx.accent, fg: ctx.cs.onTertiary, onPressed: () => toast(tr('coming_soon'))),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
          ]));
}

void openExportSheet(BuildContext c) {
  Widget row(BuildContext ctx, IconData ic, String t, String d, VoidCallback f) => ListTile(
        leading: IconBox(ic, size: 40),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(d, style: TextStyle(color: ctx.muted, fontSize: 12.5)),
        onTap: () {
          Navigator.pop(ctx);
          f();
        },
      );
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('export_choice'), icon: Icons.download_rounded, children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: divided(ctx, [
                row(ctx, Icons.data_object_rounded, tr('export_json'), tr('export_json_desc'), _exportJson),
                row(ctx, Icons.picture_as_pdf_rounded, tr('export_pdf'), tr('export_pdf_desc'), _exportPdf),
              ])),
            ),
          ]));
}

Future<void> _exportJson() async {
  try {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/esep-backup-${_today()}.json');
    await f.writeAsString(store.exportJson());
    await Share.shareXFiles([XFile(f.path)], subject: 'ESEP backup');
  } catch (_) {
    toast(tr('export_error'));
  }
}

Future<void> _exportPdf() async {
  try {
    final doc = await buildReportPdf();
    await Printing.sharePdf(bytes: await doc.save(), filename: 'esep-report-${_today()}.pdf');
  } catch (_) {
    toast(tr('export_error'));
  }
}

Future<void> _importFlow(BuildContext c) async {
  try {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (r == null || r.files.isEmpty) return;
    final bytes = r.files.first.bytes;
    if (bytes == null) {
      toast(tr('read_error'));
      return;
    }
    dynamic parsed;
    try {
      parsed = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      toast(tr('bad_format'));
      return;
    }
    if (parsed is! Map || parsed['products'] is! List) {
      toast(tr('not_backup'));
      return;
    }
    if (!c.mounted) return;
    final pc = (parsed['products'] as List).length;
    final sc = parsed['sales'] is List ? (parsed['sales'] as List).length : 0;
    final ok = await confirmDialog(
        c,
        tr('import_warning', {'a': '${store.products.length}', 'b': '${store.sales.length}', 'c': '$pc', 'd': '$sc'}),
        yes: tr('replace_yes'),
        danger: true);
    if (!ok) return;
    // Тастыктоо диалогунан кийин экран жабылып калышы мүмкүн
    if (!c.mounted) return;
    await store.replaceData(Map<String, dynamic>.from(parsed));
    toast(tr('data_restored'));
  } catch (_) {
    toast(tr('read_error'));
  }
}

void openResetSheet(BuildContext c) {
  openSheet(
      c,
      (ctx) => SheetBody(title: tr('reset_title'), icon: Icons.warning_amber_rounded, children: [
            AppCard(
                color: ctx.debtBg.withAlpha(90),
                border: ctx.debt.withAlpha(90),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('irreversible'), style: TextStyle(color: ctx.debt, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(tr('reset_text')),
                ])),
            const SizedBox(height: 16),
            BigButton(tr('reset_yes'), icon: Icons.warning_amber_rounded, bg: ctx.debt, fg: ctx.cs.onError, onPressed: () async {
              await store.resetAll();
              if (ctx.mounted) Navigator.pop(ctx);
              toast(tr('data_cleared'));
            }),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel_stop'))),
          ]));
}
