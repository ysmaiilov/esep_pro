import 'package:flutter/material.dart';
import 'sheets.dart';
import 'store.dart';
import 'ui.dart';

const _pad = EdgeInsets.fromLTRB(16, 12, 16, 28);
const _bold = TextStyle(fontWeight: FontWeight.w700);

// =====================================================================
//  shared rows
// =====================================================================
class SaleRow extends StatelessWidget {
  final M s;
  const SaleRow(this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    final label = its(s).map((i) => s_(i['name'])).join(', ');
    return InkWell(
      onTap: () => openEditSaleSheet(c, s_(s['id'])),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s_(s['customer']).isEmpty ? tr('default_customer') : s_(s['customer']), style: _bold),
            Text(label.isEmpty ? '—' : label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            statusPill(s_(s['status'])),
          ])),
          const SizedBox(width: 8),
          Text(fmt(n(s['total'])), style: mono(size: 14)),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ]),
      ),
    );
  }
}

// =====================================================================
//  DASHBOARD
// =====================================================================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final st = store.stats();
    final recent = ([...store.sales]..sort((a, b) => s_(b['date']).compareTo(s_(a['date'])))).take(5).toList();
    return ListView(padding: _pad, children: [
      FadeIn(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: c.isDark ? const [Color(0xFF1F6B43), Color(0xFF14532D)] : const [Color(0xFF14532D), Color(0xFF1F7A45)]),
            boxShadow: const [BoxShadow(color: Color(0x3314532D), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.trending_up_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(tr('today_sales'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: st.today),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(fmt(v), style: mono(color: Colors.white, size: 36, w: FontWeight.w800))),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .16), borderRadius: BorderRadius.circular(99)),
              child: Text('${tr('this_month')} ${fmt(st.month)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      FadeIn(
        i: 1,
        child: Row(children: [
          Expanded(child: StatTile(label: tr('total_debt'), value: fmt(st.debt), foot: '${st.debtCount} ${tr('unpaid_bills')}', valueColor: c.debt, icon: Icons.account_balance_wallet_rounded)),
          const SizedBox(width: 12),
          Expanded(child: StatTile(label: tr('inv_value'), value: fmt(st.invValue), foot: '${store.products.length} ${tr('items_count')}', icon: Icons.inventory_2_rounded)),
        ]),
      ),
      const SizedBox(height: 12),
      FadeIn(
        i: 2,
        child: Row(children: [
          Expanded(
              child: SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                      onPressed: () {
                        store.tab = 2;
                        store.salesSub = 0;
                        store.notify();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('new_sale'))))),
          const SizedBox(width: 12),
          Expanded(
              child: SizedBox(
                  height: 64,
                  child: FilledButton.tonalIcon(
                      onPressed: () => openProductSheet(c),
                      icon: const Icon(Icons.inventory_2_rounded),
                      label: Text(tr('add_product'))))),
        ]),
      ),
      FadeIn(
        i: 3,
        child: Column(children: [
          SectionHead(tr('recent_sales'), action: tr('view_all'), onAction: () {
            store.tab = 2;
            store.salesSub = 2;
            store.notify();
          }),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: recent.isEmpty
                ? EmptyBlock(tr('no_sales_title'), tr('no_sales_desc'), icon: Icons.receipt_long_rounded)
                : Column(children: divided(c, recent.map((s) => SaleRow(s)))),
          ),
        ]),
      ),
      if (st.lowStock > 0) ...[
        SectionHead(tr('attention')),
        AppCard(
          color: c.accentBg.withAlpha(110),
          border: c.accent.withAlpha(120),
          onTap: () {
            store.tab = 1;
            store.notify();
          },
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${st.lowStock} ${tr('low_stock_warn')}', style: _bold),
              Text(tr('check_inventory'), style: TextStyle(color: c.muted, fontSize: 12.5)),
            ])),
          ]),
        ),
      ],
    ]);
  }
}

// =====================================================================
//  INVENTORY
// =====================================================================
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final q = TextEditingController();
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final query = q.text.trim().toLowerCase();
    final list = store.products.where((p) => s_(p['name']).toLowerCase().contains(query) || s_(p['category']).toLowerCase().contains(query)).toList();
    final totalQty = store.products.fold<int>(0, (a, p) => a + ni(p['stock']));
    final cost = store.products.fold<double>(0, (a, p) => a + n(p['costPrice']) * ni(p['stock']));
    final sell = store.products.fold<double>(0, (a, p) => a + n(p['price']) * ni(p['stock']));
    return ListView(padding: _pad, children: [
      ScreenHeader(tr('inv_title'), tr('inv_subtitle')),
      Row(children: [
        Expanded(child: StatTile(label: tr('total_qty'), value: '$totalQty ${tr('pcs')}', foot: '${store.products.length} ${tr('items_count')}')),
        const SizedBox(width: 12),
        Expanded(child: StatTile(label: tr('cost_value'), value: fmt(cost))),
      ]),
      const SizedBox(height: 12),
      StatTile(label: tr('sell_value'), value: fmt(sell), foot: '${tr('expected_profit')} ${fmt(sell - cost)}', valueColor: c.cs.primary),
      const SizedBox(height: 14),
      TextField(
          controller: q,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: tr('search_product'), prefixIcon: const Icon(Icons.search_rounded))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SizedBox(height: 56, child: FilledButton.icon(onPressed: () => openStockInSheet(c), icon: const Icon(Icons.move_to_inbox_rounded), label: Text(tr('stock_in'))))),
        const SizedBox(width: 12),
        Expanded(child: SizedBox(height: 56, child: FilledButton.tonalIcon(onPressed: () => openProductSheet(c), icon: const Icon(Icons.add_rounded), label: Text(tr('new_product'))))),
      ]),
      const SizedBox(height: 14),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: list.isEmpty
            ? EmptyBlock(tr('nothing_found'), tr('try_other'), icon: Icons.search_off_rounded)
            : Column(children: divided(c, list.map((p) => _ProductTile(p)))),
      ),
    ]);
  }
}

class _ProductTile extends StatelessWidget {
  final M p;
  const _ProductTile(this.p);
  @override
  Widget build(BuildContext c) {
    final stock = ni(p['stock']);
    Color dot = c.cs.primary;
    var text = '$stock ${tr('pcs')}';
    if (stock == 0) {
      dot = c.debt;
      text = tr('out_of_stock');
    } else if (stock <= 5) {
      dot = c.accent;
      text = '$stock ${tr('low_stock')}';
    }
    final cost = n(p['costPrice']);
    final margin = cost > 0 ? ((n(p['price']) - cost) / cost * 100).round() : null;
    return InkWell(
      onTap: () => openProductSheet(c, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          const IconBox(Icons.inventory_2_rounded),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s_(p['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: _bold),
            Text('${p['category']}${cost > 0 ? ' · ${tr('cost_prefix')} ${fmt(cost)}' : ''}${s_(p['supplier']).isNotEmpty ? ' · ${p['supplier']}' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11.5)),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(text, style: TextStyle(color: c.muted, fontSize: 11)),
            ]),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt(n(p['price'])), style: mono(size: 13.5)),
            if (margin != null) Text('${margin >= 0 ? '+' : ''}$margin%', style: mono(size: 10.5, color: margin >= 0 ? c.cs.primary : c.debt)),
          ]),
        ]),
      ),
    );
  }
}

// =====================================================================
//  SALES
// =====================================================================
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final pending = store.orders.where((o) => (s_(o['status']).isEmpty ? 'pending' : o['status']) == 'pending').length;
    return ListView(padding: _pad, children: [
      ScreenHeader(tr('nav_sales'), tr('sales_subtitle')),
      Row(children: [
        Expanded(
            child: PillTabs(
                labels: [tr('tab_new'), '${tr('tab_orders')}${pending > 0 ? ' ($pending)' : ''}', tr('tab_history')],
                index: store.salesSub,
                onChanged: (i) {
                  store.salesSub = i;
                  store.notify();
                })),
        const SizedBox(width: 8),
        IconButton.filledTonal(
            tooltip: tr('return_btn'),
            style: IconButton.styleFrom(backgroundColor: c.accentBg, foregroundColor: c.accent, minimumSize: const Size(52, 52)),
            onPressed: () => openReturnPickSheet(c),
            icon: const Icon(Icons.undo_rounded)),
      ]),
      const SizedBox(height: 16),
      if (store.salesSub == 0)
        NewSaleView()
      else if (store.salesSub == 1)
        _OrdersView()
      else
        _HistoryView(),
    ]);
  }
}

class _HistoryView extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    final list = [...store.sales]..sort((a, b) => s_(b['date']).compareTo(s_(a['date'])));
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: list.isEmpty
          ? EmptyBlock(tr('no_history'), tr('no_history_desc'), icon: Icons.receipt_long_rounded)
          : Column(children: divided(c, list.map((s) => SaleRow(s)))),
    );
  }
}

class NewSaleView extends StatefulWidget {
  const NewSaleView({super.key});
  @override
  State<NewSaleView> createState() => _NewSaleViewState();
}

class _NewSaleViewState extends State<NewSaleView> {
  late final TextEditingController cust = TextEditingController(text: store.customerDraft);
  late final TextEditingController disc = TextEditingController(text: store.discountValue > 0 ? numStr(store.discountValue) : '');
  late final TextEditingController paid = TextEditingController(text: store.paidNowValue);
  bool showSug = false;

  @override
  void dispose() {
    cust.dispose();
    disc.dispose();
    paid.dispose();
    super.dispose();
  }

  void _inc(M p) {
    final id = s_(p['id']);
    final cur = store.cart[id] ?? 0;
    if (cur < ni(p['stock'])) {
      store.cart[id] = cur + 1;
      store.notify();
    } else {
      toast(tr('low_stock_toast'));
    }
  }

  void _dec(String id) {
    final v = (store.cart[id] ?? 0) - 1;
    store.cart[id] = v < 0 ? 0 : v;
    store.notify();
  }

  List<String> get _sugs {
    final q = cust.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    final names = store.customerStats().where((x) => x['key'] != '__anon__').map((x) => s_(x['name'])).toSet();
    return names.where((x) => x.toLowerCase().contains(q) && x.toLowerCase() != q).take(6).toList();
  }

  @override
  Widget build(BuildContext c) {
    final t = store.cartTotals();
    final hasItems = store.cart.values.any((q) => q > 0);
    final paidNow = pnum(store.paidNowValue).clamp(0.0, t.total).toDouble();
    final sugs = showSug ? _sugs : <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(tr('choose_products')),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: store.products.isEmpty
            ? EmptyBlock(tr('no_products'), tr('no_products_desc'))
            : Column(
                children: divided(
                    c,
                    store.products.map((p) {
                      final id = s_(p['id']);
                      final q = store.cart[id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(children: [
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s_(p['name']), style: _bold),
                            Text('${fmt(n(p['price']))} · ${tr('in_stock')} ${ni(p['stock']) - q}',
                                style: TextStyle(fontSize: 12, color: q > 0 ? c.accent : c.muted, fontWeight: q > 0 ? FontWeight.w700 : FontWeight.w400)),
                          ])),
                          q > 0
                              ? QtyStepper(qty: q, onDec: () => _dec(id), onInc: () => _inc(p))
                              : FilledButton.tonal(
                                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                                  onPressed: ni(p['stock']) <= 0 ? null : () => _inc(p),
                                  child: Text(tr('add'))),
                        ]),
                      );
                    }))),
      ),
      SectionHead(tr('customer_opt')),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: AppField(
                label: tr('customer_ph'),
                controller: cust,
                onChanged: (v) {
                  store.customerDraft = v;
                  setState(() => showSug = true);
                })),
        const SizedBox(width: 8),
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton.filledTonal(
                tooltip: tr('pick'),
                onPressed: () => openPickClientSheet(c, (nm) {
                      cust.text = nm;
                      store.customerDraft = nm;
                      setState(() => showSug = false);
                    }),
                icon: const Icon(Icons.people_alt_rounded))),
      ]),
      if (sugs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
                children: divided(
                    c,
                    sugs.map((nm) => ListTile(
                        dense: true,
                        title: Text(nm),
                        onTap: () {
                          cust.text = nm;
                          store.customerDraft = nm;
                          setState(() => showSug = false);
                        })))),
          ),
        ),
      SectionHead(tr('discount_opt')),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: AppField(
                label: tr('discount'),
                controller: disc,
                number: true,
                onChanged: (v) {
                  store.discountValue = pnum(v);
                  store.notify();
                })),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [ButtonSegment(value: 'percent', label: const Text('%')), ButtonSegment(value: 'amount', label: Text(tr('som')))],
            selected: {store.discountType},
            onSelectionChanged: (v) {
              store.discountType = v.first;
              store.notify();
            },
          ),
        ),
      ]),
      SectionHead(tr('payment_method')),
      OptionTile(icon: Icons.payments_rounded, label: tr('cash'), selected: store.payMethod == 'cash', onTap: () { store.payMethod = 'cash'; store.notify(); }),
      OptionTile(icon: Icons.credit_card_rounded, label: tr('card'), selected: store.payMethod == 'card', onTap: () { store.payMethod = 'card'; store.notify(); }),
      OptionTile(icon: Icons.attach_money_rounded, label: tr('on_credit'), selected: store.payMethod == 'debt', onTap: () { store.payMethod = 'debt'; store.notify(); }),
      if (store.payMethod == 'debt') ...[
        const SizedBox(height: 6),
        AppField(
            label: tr('paid_now_opt'),
            controller: paid,
            number: true,
            onChanged: (v) {
              store.paidNowValue = v;
              store.notify();
            }),
        if (paidNow > 0) ...[
          OptionTile(icon: Icons.payments_rounded, label: tr('cash'), selected: store.paidNowMethod == 'cash', onTap: () { store.paidNowMethod = 'cash'; store.notify(); }),
          OptionTile(icon: Icons.credit_card_rounded, label: tr('card'), selected: store.paidNowMethod == 'card', onTap: () { store.paidNowMethod = 'card'; store.notify(); }),
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${tr('remaining_after')} ${fmt(t.total - paidNow)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.total - paidNow > 0 ? c.debt : c.cs.primary))),
        ],
      ],
      const SizedBox(height: 10),
      TotalCard(tr('total'), fmt(t.total), extra: [
        if (t.disc > 0) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(tr('subtotal'), style: TextStyle(color: c.muted)), Text(fmt(t.sub), style: mono(size: 13, color: c.muted))]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(tr('discount'), style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)), Text('−${fmt(t.disc)}', style: mono(size: 13, color: c.accent))]),
          const SizedBox(height: 8),
        ],
      ]),
      const SizedBox(height: 14),
      BigButton(tr('confirm_sale'), icon: Icons.check_rounded,
          onPressed: !hasItems
              ? null
              : () async {
                  final host = Navigator.of(context).overlay!.context;
                  final r = await store.confirmSale(cust.text.trim());
                  if (r == null) return;
                  cust.clear();
                  disc.clear();
                  paid.clear();
                  openReceiptSheet(host, r.sale, r.prior);
                }),
    ]);
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();
  @override
  Widget build(BuildContext c) {
    final all = [...store.orders]..sort((a, b) => s_(b['date']).compareTo(s_(a['date'])));
    String st(M o) => s_(o['status']).isEmpty ? 'pending' : s_(o['status']);
    final pending = all.where((o) => st(o) == 'pending').toList();
    final history = all.where((o) => st(o) != 'pending').toList();

    Widget row(M o) {
      final isPending = st(o) == 'pending';
      final total = its(o).fold<double>(0, (a, i) => a + n(i['price']) * ni(i['qty']));
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s_(o['customer']).isEmpty ? tr('default_customer') : s_(o['customer']), style: _bold),
              Text(its(o).map((i) => '${i['name']} · ${i['qty']} ${tr('pcs')}').join(', '), style: TextStyle(color: c.muted, fontSize: 12.5)),
              if (s_(o['note']).isNotEmpty) Text(s_(o['note']), style: TextStyle(color: c.muted, fontSize: 12, fontStyle: FontStyle.italic)),
              Text(fmtDate(s_(o['date'])), style: TextStyle(color: c.muted, fontSize: 11.5)),
              if (!isPending) ...[
                const SizedBox(height: 4),
                Pill(st(o) == 'fulfilled' ? tr('fulfilled') : tr('cancelled'), kind: st(o) == 'fulfilled' ? PillKind.paid : PillKind.debt),
              ],
            ])),
            Text(fmt(total), style: mono(size: 14)),
          ]),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () async {
                        store.cart = {for (final i in its(o)) s_(i['productId']): ni(i['qty'])};
                        store.customerDraft = s_(o['customer']);
                        o['status'] = 'fulfilled';
                        o['fulfilledDate'] = nowISO();
                        store.salesSub = 0;
                        await store.save();
                        toast(tr('order_taken'));
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(tr('fulfill')))),
              const SizedBox(width: 8),
              MiniBtn(Icons.edit_rounded, () => openTakeOrderSheet(c, o)),
              const SizedBox(width: 8),
              MiniBtn(Icons.delete_outline_rounded, () async {
                if (!await confirmDialog(c, tr('confirm_cancel_order'), yes: tr('cancel_order'))) return;
                o['status'] = 'cancelled';
                o['cancelledDate'] = nowISO();
                await store.save();
                toast(tr('order_cancelled'));
              }, color: c.debt),
            ]),
          ],
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BigButton(tr('take_order'), icon: Icons.add_rounded, onPressed: () => openTakeOrderSheet(c)),
      const SizedBox(height: 14),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: pending.isEmpty ? EmptyBlock(tr('no_orders'), tr('no_orders_desc'), icon: Icons.assignment_rounded) : Column(children: divided(c, pending.map(row))),
      ),
      if (history.isNotEmpty) ...[
        SectionHead(tr('order_history')),
        AppCard(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: divided(c, history.map(row)))),
      ],
    ]);
  }
}

// =====================================================================
//  CLIENTS & SUPPLIERS
// =====================================================================
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  int sub = 0;
  final q = TextEditingController();
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return ListView(padding: _pad, children: [
      ScreenHeader(tr('nav_clients'), tr('clients_subtitle')),
      Row(children: [
        Expanded(child: SizedBox(height: 56, child: FilledButton.icon(onPressed: () => openClientEditSheet(c), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(tr('add_client'))))),
        const SizedBox(width: 12),
        Expanded(child: SizedBox(height: 56, child: FilledButton.tonalIcon(onPressed: () => openSupplierSheet(c), icon: const Icon(Icons.local_shipping_rounded), label: Text(tr('add_supplier'))))),
      ]),
      const SizedBox(height: 14),
      PillTabs(
          labels: [tr('tab_clients'), tr('tab_suppliers')],
          index: sub,
          onChanged: (i) => setState(() {
                sub = i;
                q.clear();
              })),
      const SizedBox(height: 14),
      if (sub == 0) _clients(c) else _suppliers(c),
    ]);
  }

  Widget _search(String hint) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: q, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded))));

  Widget _clients(BuildContext c) {
    final all = store.customerStats();
    final query = q.text.trim().toLowerCase();
    final list = query.isEmpty ? all : all.where((x) => s_(x['name']).toLowerCase().contains(query)).toList();
    final totalAll = all.fold<double>(0, (a, x) => a + n(x['total']));
    final debtAll = all.fold<double>(0, (a, x) => a + n(x['debt']));
    final debtors = all.where((x) => n(x['debt']) > 0).length;
    final paidPct = totalAll > 0 ? (((totalAll - debtAll).clamp(0.0, totalAll)) / totalAll * 100).round() : 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (all.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${tr('total_clients')} ${all.length}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5))),
      if (totalAll > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(tr('overall_debt'), style: _bold)),
              if (debtAll > 0)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmt(debtAll), style: mono(color: c.debt, size: 15)),
                  Text('$debtors ${tr('debtors')}', style: TextStyle(color: c.muted, fontSize: 11.5)),
                ]),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: paidPct / 100, minHeight: 10, backgroundColor: c.debt.withAlpha(110), color: c.cs.primary)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${tr('paid_share')}: $paidPct%', style: TextStyle(color: c.cs.primary, fontWeight: FontWeight.w700, fontSize: 11.5)),
              Text('${tr('unpaid_share')}: ${100 - paidPct}%', style: TextStyle(color: c.debt, fontWeight: FontWeight.w700, fontSize: 11.5)),
            ]),
          ])),
        ),
      _search(tr('search_client')),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: list.isEmpty
            ? EmptyBlock(tr('no_clients'), tr('no_clients_desc'), icon: Icons.people_alt_rounded)
            : Column(
                children: divided(
                    c,
                    list.map((x) => InkWell(
                          onTap: () => openClientSheet(c, s_(x['key'])),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(children: [
                              CircleAvatar(
                                  backgroundColor: c.cs.primaryContainer,
                                  foregroundColor: c.cs.primary,
                                  child: Text(s_(x['name']).isEmpty ? '?' : s_(x['name'])[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s_(x['name']), style: _bold),
                                Text('${s_(x['phone']).isNotEmpty ? '${x['phone']} · ' : ''}${x['count']} ${tr('purchases')}${s_(x['lastDate']).isNotEmpty ? ' · ${tr('last')} ${fmtDate(s_(x['lastDate']))}' : ''}',
                                    style: TextStyle(color: c.muted, fontSize: 11.5)),
                                const SizedBox(height: 4),
                                n(x['debt']) > 0 ? Pill(tr('has_debt'), icon: Icons.attach_money_rounded, kind: PillKind.debt) : Pill(tr('no_debt'), icon: Icons.check_rounded, kind: PillKind.paid),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(fmt(n(x['total'])), style: mono(size: 14)),
                                if (n(x['debt']) > 0) Text('${tr('debt_lbl')} ${fmt(n(x['debt']))}', style: TextStyle(color: c.debt, fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ]),
                            ]),
                          ),
                        )))),
      ),
    ]);
  }

  Widget _suppliers(BuildContext c) {
    final query = q.text.trim().toLowerCase();
    var list = [...store.suppliers]..sort((a, b) => s_(a['name']).compareTo(s_(b['name'])));
    if (query.isNotEmpty) list = list.where((x) => s_(x['name']).toLowerCase().contains(query)).toList();
    final names = store.suppliers.map((x) => s_(x['name']).trim()).toSet();
    final owed = names.fold<double>(0, (a, nm) => a + store.supplierDebt(nm));
    final creditors = names.where((nm) => store.supplierDebt(nm) > 0).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (owed > 0)
        Padding(padding: const EdgeInsets.only(bottom: 14), child: StatTile(label: tr('owed_suppliers'), value: fmt(owed), foot: '$creditors ${tr('suppliers_cnt')}', valueColor: c.debt)),
      _search(tr('search_supplier')),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: list.isEmpty
            ? EmptyBlock(tr('no_suppliers'), tr('no_suppliers_desc'), icon: Icons.local_shipping_rounded)
            : Column(
                children: divided(
                    c,
                    list.map((x) {
                      final debt = store.supplierDebt(s_(x['name']));
                      return InkWell(
                        onTap: () => openSupplierSheet(c, x),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(children: [
                            const IconBox(Icons.local_shipping_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s_(x['name']), style: _bold),
                              Text([s_(x['phone']), s_(x['note'])].where((e) => e.isNotEmpty).join(' · ').isEmpty ? tr('no_extra') : [s_(x['phone']), s_(x['note'])].where((e) => e.isNotEmpty).join(' · '),
                                  style: TextStyle(color: c.muted, fontSize: 11.5)),
                              if (debt > 0) ...[const SizedBox(height: 4), Pill(tr('we_owe'), icon: Icons.attach_money_rounded, kind: PillKind.debt)],
                            ])),
                            if (debt > 0) Text(fmt(debt), style: mono(color: c.debt, size: 14)),
                          ]),
                        ),
                      );
                    }))),
      ),
    ]);
  }
}

// =====================================================================
//  KASSA
// =====================================================================
class KassaScreen extends StatefulWidget {
  const KassaScreen({super.key});
  @override
  State<KassaScreen> createState() => _KassaScreenState();
}

class _KassaScreenState extends State<KassaScreen> {
  int sub = 0, rep = 0;
  final expanded = <String>{};

  @override
  Widget build(BuildContext c) {
    final debtors = store.customerStats().where((x) => n(x['debt']) > 0).toList()..sort((a, b) => n(b['debt']).compareTo(n(a['debt'])));
    final debtTotal = debtors.fold<double>(0, (a, x) => a + n(x['debt']));
    final cs = store.cashStats();
    final plus = <(String, double)>[(tr('cash_sales'), cs['cashSales']!), (tr('debt_in_cash'), cs['dpCash']!), (tr('upfront_cash'), cs['upCash']!)];
    final minus = <(String, double)>[(tr('expenses'), cs['expenses']!), (tr('withdrawals'), cs['withdrawals']!), (tr('supplier_out_cash'), cs['spCash']!)];
    final cards = <(String, double)>[(tr('card_sales'), cs['cardSales']!), (tr('debt_in_card'), cs['dpCard']!), (tr('upfront_card'), cs['upCard']!), (tr('supplier_out_card'), cs['spCard']!)].where((r) => r.$2 > 0).toList();

    Widget line(String l, double v, Color col, String sign) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(l, style: TextStyle(color: col, fontSize: 12.5))),
          Text('$sign${fmt(v)}', style: mono(size: 12.5, color: col)),
        ]));

    return ListView(padding: _pad, children: [
      ScreenHeader(tr('nav_kassa'), tr('kassa_subtitle')),
      Row(children: [
        Expanded(child: StatTile(label: tr('cash_on_hand'), value: fmt(cs['onHand']!), icon: Icons.point_of_sale_rounded, valueColor: c.cs.primary)),
        const SizedBox(width: 12),
        Expanded(child: StatTile(label: tr('total_debt'), value: fmt(debtTotal), foot: '${debtors.length} ${tr('debtors')}', valueColor: c.debt, icon: Icons.account_balance_wallet_rounded)),
      ]),
      const SizedBox(height: 12),
      AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('full_breakdown'), style: _bold),
        const SizedBox(height: 6),
        for (final r in plus) line(r.$1, r.$2, c.cs.primary, '+'),
        for (final r in minus) line(r.$1, r.$2, c.debt, '−'),
        if (cards.isNotEmpty) ...[Divider(color: c.line), for (final r in cards) line(r.$1, r.$2, c.muted, '')],
      ])),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SizedBox(height: 56, child: FilledButton.tonalIcon(style: FilledButton.styleFrom(backgroundColor: c.accentBg, foregroundColor: c.accent), onPressed: () => openExpenseSheet(c), icon: const Icon(Icons.remove_circle_outline_rounded), label: Text(tr('expense'))))),
        const SizedBox(width: 12),
        Expanded(child: SizedBox(height: 56, child: FilledButton.tonalIcon(style: FilledButton.styleFrom(backgroundColor: c.accentBg, foregroundColor: c.accent), onPressed: () => openWithdrawalSheet(c), icon: const Icon(Icons.output_rounded), label: Text(tr('withdrawal'))))),
      ]),
      const SizedBox(height: 14),
      PillTabs(labels: [tr('tab_debts'), tr('tab_cash_history'), tr('tab_report')], index: sub, onChanged: (i) => setState(() => sub = i)),
      const SizedBox(height: 14),
      if (sub == 0)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: debtors.isEmpty
              ? EmptyBlock(tr('no_debts'), tr('no_debts_desc'), icon: Icons.celebration_rounded)
              : Column(
                  children: divided(
                      c,
                      debtors.map((x) => InkWell(
                            onTap: () => openClientSheet(c, s_(x['key'])),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s_(x['name']), style: _bold),
                                  Text('${x['count']} ${tr('purchases')}${s_(x['lastDate']).isNotEmpty ? ' · ${tr('last')} ${fmtDate(s_(x['lastDate']))}' : ''}', style: TextStyle(color: c.muted, fontSize: 11.5)),
                                ])),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(fmt(n(x['debt'])), style: mono(color: c.debt, size: 14)),
                                  Text(tr('close_debt'), style: TextStyle(color: c.cs.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                                ]),
                              ]),
                            ),
                          )))),
        )
      else if (sub == 1)
        _history(c)
      else
        _report(c),
    ]);
  }

  Widget _history(BuildContext c) {
    final items = <({String kind, M m})>[
      for (final e in store.expenses) (kind: 'expense', m: e),
      for (final e in store.withdrawals) (kind: 'withdrawal', m: e),
      for (final e in store.debtPayments) (kind: 'debtIn', m: e),
      for (final e in store.supplierPayments) (kind: 'supplierOut', m: e),
    ]..sort((a, b) => s_(b.m['date']).compareTo(s_(a.m['date'])));
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: items.isEmpty
          ? EmptyBlock(tr('no_cash_history'), tr('no_cash_history_desc'), icon: Icons.history_rounded)
          : Column(
              children: divided(
                  c,
                  items.map((it) {
                    final m = it.m;
                    final isIn = it.kind == 'debtIn';
                    final method = m['method'] == 'card' ? tr('card') : tr('cash');
                    String label;
                    switch (it.kind) {
                      case 'expense':
                        label = s_(m['category']).isEmpty ? tr('expense_default') : s_(m['category']);
                      case 'withdrawal':
                        label = tr('withdrawal');
                      case 'debtIn':
                        label = '${tr('debt_payment')}${s_(m['customer']).isNotEmpty ? ' · ${m['customer']}' : ''} · $method';
                      default:
                        label = '${tr('supplier_payment')}${s_(m['supplier']).isNotEmpty ? ' · ${m['supplier']}' : ''} · $method';
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(label, style: _bold),
                          Text('${fmtDate(s_(m['date']))}${s_(m['note']).isNotEmpty ? ' · ${m['note']}' : ''}', style: TextStyle(color: c.muted, fontSize: 11.5)),
                        ])),
                        Text('${isIn ? '+' : '−'}${fmt(n(m['amount']))}', style: mono(size: 14, color: isIn ? c.cs.primary : c.debt)),
                        const SizedBox(width: 8),
                        MiniBtn(Icons.delete_outline_rounded, () async {
                          if (!await confirmDialog(c, tr('delete_cash_confirm'))) return;
                          final id = s_(m['id']);
                          if (it.kind == 'expense') {
                            store.d['expenses'] = store.expenses.where((x) => x['id'] != id).toList();
                            await store.save();
                          } else if (it.kind == 'withdrawal') {
                            store.d['withdrawals'] = store.withdrawals.where((x) => x['id'] != id).toList();
                            await store.save();
                          } else if (it.kind == 'debtIn') {
                            await store.undoDebtPayment(id);
                          } else {
                            await store.undoSupplierPayment(id);
                          }
                          toast(tr('cash_deleted'));
                        }, color: c.debt),
                      ]),
                    );
                  }))),
    );
  }

  Widget _report(BuildContext c) {
    final valid = store.sales.where((s) => s['status'] != 'returned').toList();
    final sold = <String, int>{};
    for (final s in valid) {
      for (final i in its(s)) {
        sold[s_(i['productId'])] = (sold[s_(i['productId'])] ?? 0) + ni(i['qty']);
      }
    }
    final invalid = <String, int>{};
    for (final r in store.returns.where((r) => r['condition'] == 'invalid')) {
      for (final i in its(r)) {
        invalid[s_(i['productId'])] = (invalid[s_(i['productId'])] ?? 0) + ni(i['qty']);
      }
    }
    final units = sold.values.fold<int>(0, (a, b) => a + b);
    final revenue = valid.fold<double>(0, (a, s) => a + n(s['total']));
    var cost = 0.0;
    for (final s in valid) {
      for (final i in its(s)) {
        final p = store.product(s_(i['productId']));
        if (p != null) cost += n(p['costPrice']) * ni(i['qty']);
      }
    }
    final rows = [...store.products]..sort((a, b) => (sold[s_(b['id'])] ?? 0).compareTo(sold[s_(a['id'])] ?? 0));

    // by client
    final byClient = <String, Map<String, int>>{};
    for (final s in valid) {
      final nm = s_(s['customer']).trim().isEmpty ? tr('no_name') : s_(s['customer']).trim();
      final m = byClient.putIfAbsent(nm, () => {});
      for (final i in its(s)) {
        m[s_(i['name'])] = (m[s_(i['name'])] ?? 0) + ni(i['qty']);
      }
    }
    int tot(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
    final names = byClient.keys.toList()..sort((a, b) => tot(byClient[b]!).compareTo(tot(byClient[a]!)));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: StatTile(label: tr('units_sold'), value: '$units ${tr('pcs')}')),
        const SizedBox(width: 12),
        Expanded(child: StatTile(label: tr('sold_value'), value: fmt(revenue))),
      ]),
      const SizedBox(height: 12),
      StatTile(label: tr('profit'), value: fmt(revenue - cost), valueColor: c.cs.primary),
      const SizedBox(height: 14),
      PillTabs(labels: [tr('tab_products'), tr('tab_customers')], index: rep, onChanged: (i) => setState(() => rep = i)),
      const SizedBox(height: 14),
      if (rep == 0)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: rows.isEmpty
              ? EmptyBlock(tr('nothing_found'), '')
              : Column(
                  children: divided(
                      c,
                      rows.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(children: [
                              const IconBox(Icons.inventory_2_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s_(p['name']), style: _bold),
                                Text(fmt(n(p['price'])), style: TextStyle(color: c.muted, fontSize: 11.5)),
                                const SizedBox(height: 3),
                                Wrap(spacing: 10, children: [
                                  Text('${tr('left')}: ${ni(p['stock'])}', style: mono(size: 11.5, color: c.debt)),
                                  Text('${tr('sold')}: ${sold[s_(p['id'])] ?? 0}', style: mono(size: 11.5, color: c.cs.primary)),
                                  if ((invalid[s_(p['id'])] ?? 0) > 0) Text('${tr('cond_invalid')}: ${invalid[s_(p['id'])]}', style: mono(size: 11.5, color: c.accent)),
                                ]),
                              ])),
                            ]),
                          )))),
        )
      else
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: names.isEmpty
              ? EmptyBlock(tr('no_sales'), '')
              : Column(
                  children: divided(
                      c,
                      names.map((nm) {
                        final open = expanded.contains(nm);
                        final prods = byClient[nm]!;
                        return InkWell(
                          onTap: () => setState(() => open ? expanded.remove(nm) : expanded.add(nm)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(children: [
                              Row(children: [
                                AnimatedRotation(turns: open ? .25 : 0, duration: const Duration(milliseconds: 180), child: Icon(Icons.chevron_right_rounded, color: c.muted)),
                                const SizedBox(width: 4),
                                Expanded(child: Text(nm, style: _bold)),
                                Text('${tot(prods)} ${tr('pcs')}', style: mono(size: 12, color: c.cs.primary)),
                              ]),
                              if (open)
                                Padding(
                                  padding: const EdgeInsets.only(left: 28, top: 8),
                                  child: Column(children: [
                                    for (final e in (prods.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                                      Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                            Expanded(child: Text(e.key, style: TextStyle(color: c.muted, fontSize: 12.5))),
                                            Text('${e.value} ${tr('pcs')}', style: mono(size: 12, color: c.muted, w: FontWeight.w600)),
                                          ])),
                                  ]),
                                ),
                            ]),
                          ),
                        );
                      }))),
        ),
    ]);
  }
}
