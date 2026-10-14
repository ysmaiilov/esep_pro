import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lang.dart';

typedef M = Map<String, dynamic>;

double n(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);
int ni(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
String s_(dynamic v) => v == null ? '' : v.toString();
double pnum(String v) =>
    double.tryParse(v.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '')) ?? 0.0;
String numStr(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();
String uid() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    math.Random().nextInt(1 << 20).toRadixString(36);
String nowISO() => DateTime.now().toUtc().toIso8601String();
DateTime? parseD(String iso) => DateTime.tryParse(iso)?.toLocal();

String fmtDate(String iso) {
  final d = parseD(iso);
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String fmt(num v) {
  final r = v.round();
  final s = r.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u00A0');
    b.write(s[i]);
  }
  return '${r < 0 ? '−' : ''}$b\u00A0сом';
}

List<M> its(M s) => s['items'] as List<M>;
List<M> bdOf(M p) => p['breakdown'] as List<M>;

// Мезгил фильтри: 0 = жума (7 күн), 1 = ай (30 күн), 2 = жыл (365 күн), 3 = баары
const kPeriodKeys = ['period_week', 'period_month', 'period_year', 'period_all'];
const kPeriodDays = [7, 30, 365];

bool inPeriod(String iso, int period) {
  if (period >= kPeriodDays.length) return true;
  final d = parseD(iso);
  if (d == null) return false;
  return !d.isBefore(DateTime.now().subtract(Duration(days: kPeriodDays[period])));
}

String tr(String k, [Map<String, String>? args]) {
  final ky = kStrings['ky']!;
  var v = (kStrings[store.lang] ?? ky)[k] ?? ky[k] ?? k;
  args?.forEach((a, b) => v = v.replaceAll('{$a}', b));
  return v;
}

List<M> _ml(dynamic v) => v is List
    ? List<M>.from(v.map((e) => Map<String, dynamic>.from(e as Map)))
    : <M>[];

const _arrays = [
  'products', 'sales', 'clients', 'suppliers', 'stockIns', 'returns', 'expenses',
  'withdrawals', 'purchases', 'debtPayments', 'supplierPayments', 'priceChanges', 'orders'
];

class Store extends ChangeNotifier {
  Store() {
    normalize();
  }

  M d = {};
  bool loaded = false;
  int tab = 0;
  int salesSub = 0; // 0 new, 1 orders, 2 history

  // --- draft of the sale being built ---
  Map<String, int> cart = {};
  String customerDraft = '';
  String payMethod = 'cash';
  String discountType = 'percent';
  double discountValue = 0;
  String paidNowValue = '';
  String paidNowMethod = 'cash';

  void notify() => notifyListeners();

  List<M> list(String k) => d[k] as List<M>;
  List<M> get products => list('products');
  List<M> get sales => list('sales');
  List<M> get clients => list('clients');
  List<M> get suppliers => list('suppliers');
  List<M> get stockIns => list('stockIns');
  List<M> get returns => list('returns');
  List<M> get expenses => list('expenses');
  List<M> get withdrawals => list('withdrawals');
  List<M> get purchases => list('purchases');
  List<M> get debtPayments => list('debtPayments');
  List<M> get supplierPayments => list('supplierPayments');
  List<M> get priceChanges => list('priceChanges');
  List<M> get orders => list('orders');
  M get settings => d['settings'] as M;
  String get lang => s_(settings['language']);

  ThemeMode get themeMode {
    switch (settings['theme']) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  M? product(String id) {
    for (final p in products) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  M? saleById(String id) {
    for (final s in sales) {
      if (s['id'] == id) return s;
    }
    return null;
  }

  // ---------------- persistence ----------------
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('esep-data');
    try {
      d = raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
    } catch (_) {
      d = {};
    }
    normalize();
    loaded = true;
    await save();
  }

  Future<void> save() async {
    d['updatedAt'] = nowISO();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('esep-data', jsonEncode(d));
    } catch (_) {}
    notifyListeners();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(d);

  Future<void> replaceData(M parsed) async {
    d = parsed;
    normalize();
    await save();
  }

  Future<void> resetAll() async {
    final lang = s_(settings['language']);
    final theme = s_(settings['theme']);
    d = {};
    normalize();
    settings['language'] = lang;
    settings['theme'] = theme;
    cart = {};
    tab = 0;
    await save();
  }

  /// Makes sure every collection/field the app relies on exists
  /// (older backups, web backups, partial imports…).
  void normalize() {
    for (final k in _arrays) {
      d[k] = _ml(d[k]);
    }
    final st = d['settings'] is Map ? Map<String, dynamic>.from(d['settings'] as Map) : <String, dynamic>{};
    if (s_(st['shopName']).isEmpty) st['shopName'] = 'ЭСЕП';
    if (s_(st['shopSubtitle']).isEmpty) st['shopSubtitle'] = 'Дүкөн эсеби';
    st['shopPhone'] = s_(st['shopPhone']);
    if (!kStrings.containsKey(st['language'])) st['language'] = 'ky';
    if (!['system', 'light', 'dark'].contains(st['theme'])) st['theme'] = 'system';
    d['settings'] = st;

    for (final p in products) {
      p['name'] = s_(p['name']);
      p['category'] = s_(p['category']);
      p['supplier'] = s_(p['supplier']);
      p['price'] = n(p['price']);
      p['costPrice'] = n(p['costPrice']);
      p['stock'] = ni(p['stock']);
    }
    for (final s in sales) {
      s['items'] = _ml(s['items']);
      s['total'] = n(s['total']);
      s['paidAmount'] = n(s['paidAmount']).clamp(0.0, n(s['total'])).toDouble();
    }
    for (final pu in purchases) {
      pu['totalCost'] = n(pu['totalCost']);
      pu['paidAmount'] = n(pu['paidAmount']).clamp(0.0, n(pu['totalCost'])).toDouble();
    }
    for (final o in orders) {
      o['items'] = _ml(o['items']);
    }
    for (final r in returns) {
      r['items'] = _ml(r['items']);
    }
    for (final dp in debtPayments) {
      dp['breakdown'] = _ml(dp['breakdown']);
    }
    for (final sp in supplierPayments) {
      sp['breakdown'] = _ml(sp['breakdown']);
    }

    final valid = products.map((p) => p['id']).toSet();
    final orphan = purchases.where((pu) => !valid.contains(pu['productId'])).map((pu) => s_(pu['id'])).toList();
    for (final id in orphan) {
      d['purchases'] = purchases.where((pu) => pu['id'] != id).toList();
      _strip('supplierPayments', 'purchaseId', id);
    }

    // duplicate suppliers → merge
    final seen = <String, M>{};
    final uniq = <M>[];
    for (final sp in suppliers) {
      final key = s_(sp['name']).trim().toLowerCase();
      if (key.isEmpty) {
        uniq.add(sp);
        continue;
      }
      final kept = seen[key];
      if (kept != null) {
        if (s_(kept['phone']).isEmpty && s_(sp['phone']).isNotEmpty) kept['phone'] = sp['phone'];
        if (s_(kept['note']).isEmpty && s_(sp['note']).isNotEmpty) kept['note'] = sp['note'];
      } else {
        seen[key] = sp;
        uniq.add(sp);
      }
    }
    d['suppliers'] = uniq;

    var counter = ni(d['orderCounter']);
    final missing = sales.where((s) => s['orderNumber'] is! num).toList()
      ..sort((a, b) => s_(a['date']).compareTo(s_(b['date'])));
    for (final s in missing) {
      s['orderNumber'] = ++counter;
    }
    for (final s in sales) {
      counter = math.max(counter, ni(s['orderNumber']));
    }
    d['orderCounter'] = counter;
    d['version'] = 2;
  }

  // ---------------- debts & payments ----------------
  double saleOutstanding(M s) =>
      s['status'] == 'debt' ? math.max(0.0, n(s['total']) - n(s['paidAmount'])) : 0.0;
  double purchaseOutstanding(M p) =>
      p['status'] == 'debt' ? math.max(0.0, n(p['totalCost']) - n(p['paidAmount'])) : 0.0;

  void _strip(String listKey, String idKey, String id) {
    final out = <M>[];
    for (final p in list(listKey)) {
      final bd = bdOf(p);
      final removed = bd.where((b) => b[idKey] == id).fold<double>(0, (a, b) => a + n(b['amount']));
      final keep = bd.where((b) => b[idKey] != id).toList();
      final amt = n(p['amount']) - removed;
      if (keep.isNotEmpty && amt > 0.0001) {
        p['breakdown'] = keep;
        p['amount'] = amt;
        out.add(p);
      }
    }
    d[listKey] = out;
  }

  Future<double> payCustomerDebt(String customer, double amount, [String method = 'cash']) async {
    final key = customer.trim();
    var remaining = math.max(0.0, amount);
    var applied = 0.0;
    final bd = <M>[];
    final ds = sales.where((s) => s_(s['customer']).trim() == key && s['status'] == 'debt').toList()
      ..sort((a, b) => s_(a['date']).compareTo(s_(b['date'])));
    for (final s in ds) {
      if (remaining <= 0) break;
      final out = saleOutstanding(s);
      if (out <= 0) continue;
      final pay = math.min(remaining, out);
      s['paidAmount'] = n(s['paidAmount']) + pay;
      if (n(s['paidAmount']) >= n(s['total']) - 0.0001) s['status'] = 'paid';
      remaining -= pay;
      applied += pay;
      bd.add({'saleId': s['id'], 'amount': pay});
    }
    if (applied > 0) {
      debtPayments.add({
        'id': uid(), 'date': nowISO(), 'customer': key, 'amount': applied,
        'method': method, 'breakdown': bd
      });
    }
    await save();
    return applied;
  }

  Future<void> undoDebtPayment(String id) async {
    M? pay;
    for (final p in debtPayments) {
      if (p['id'] == id) pay = p;
    }
    if (pay == null) return;
    for (final b in bdOf(pay)) {
      final s = saleById(s_(b['saleId']));
      if (s != null) {
        s['paidAmount'] = math.max(0.0, n(s['paidAmount']) - n(b['amount']));
        if (n(s['paidAmount']) < n(s['total']) - 0.0001) s['status'] = 'debt';
      }
    }
    d['debtPayments'] = debtPayments.where((p) => p['id'] != id).toList();
    await save();
  }

  Future<double> paySupplierDebt(String supplier, double amount, [String method = 'cash']) async {
    var remaining = math.max(0.0, amount);
    var applied = 0.0;
    final bd = <M>[];
    final ds = purchases.where((p) => p['supplier'] == supplier && p['status'] == 'debt').toList()
      ..sort((a, b) => s_(a['date']).compareTo(s_(b['date'])));
    for (final p in ds) {
      if (remaining <= 0) break;
      final out = purchaseOutstanding(p);
      if (out <= 0) continue;
      final pay = math.min(remaining, out);
      p['paidAmount'] = n(p['paidAmount']) + pay;
      if (n(p['paidAmount']) >= n(p['totalCost']) - 0.0001) p['status'] = 'paid';
      remaining -= pay;
      applied += pay;
      bd.add({'purchaseId': p['id'], 'amount': pay});
    }
    if (applied > 0) {
      supplierPayments.add({
        'id': uid(), 'date': nowISO(), 'supplier': supplier, 'amount': applied,
        'method': method, 'breakdown': bd
      });
    }
    await save();
    return applied;
  }

  Future<void> undoSupplierPayment(String id) async {
    M? pay;
    for (final p in supplierPayments) {
      if (p['id'] == id) pay = p;
    }
    if (pay == null) return;
    for (final b in bdOf(pay)) {
      for (final p in purchases) {
        if (p['id'] == b['purchaseId']) {
          p['paidAmount'] = math.max(0.0, n(p['paidAmount']) - n(b['amount']));
          if (n(p['paidAmount']) < n(p['totalCost']) - 0.0001) p['status'] = 'debt';
        }
      }
    }
    d['supplierPayments'] = supplierPayments.where((p) => p['id'] != id).toList();
    await save();
  }

  Future<void> undoReturn(String id) async {
    M? r;
    for (final x in returns) {
      if (x['id'] == id) r = x;
    }
    if (r == null) return;
    final sale = saleById(s_(r['saleId']));
    if (sale != null) {
      for (final ri in its(r)) {
        if (r['condition'] != 'invalid') {
          final p = product(s_(ri['productId']));
          if (p != null) p['stock'] = math.max(0, ni(p['stock']) - ni(ri['qty']));
        }
        M? existing;
        for (final i in its(sale)) {
          if (i['productId'] == ri['productId']) existing = i;
        }
        if (existing != null) {
          existing['qty'] = ni(existing['qty']) + ni(ri['qty']);
        } else {
          its(sale).add({'productId': ri['productId'], 'name': ri['name'], 'price': ri['price'], 'qty': ri['qty']});
        }
      }
      sale['total'] = n(sale['total']) + n(r['amount']);
      if (sale['status'] == 'returned') sale['status'] = sale['payment'] == 'debt' ? 'debt' : 'paid';
    }
    d['returns'] = returns.where((x) => x['id'] != id).toList();
    await save();
  }

  Future<void> deleteSale(String id) async {
    final s = saleById(id);
    if (s == null) return;
    for (final i in its(s)) {
      final p = product(s_(i['productId']));
      if (p != null) p['stock'] = ni(p['stock']) + ni(i['qty']);
    }
    _strip('debtPayments', 'saleId', id);
    d['sales'] = sales.where((x) => x['id'] != id).toList();
    await save();
  }

  Future<void> deleteProduct(String id) async {
    for (final pu in purchases.where((x) => x['productId'] == id).toList()) {
      _strip('supplierPayments', 'purchaseId', s_(pu['id']));
    }
    d['purchases'] = purchases.where((x) => x['productId'] != id).toList();
    d['priceChanges'] = priceChanges.where((x) => x['productId'] != id).toList();
    d['products'] = products.where((x) => x['id'] != id).toList();
    cart.remove(id);
  }

  Future<void> deletePurchase(String id) async {
    _strip('supplierPayments', 'purchaseId', id);
    d['purchases'] = purchases.where((x) => x['id'] != id).toList();
    await save();
  }

  // ---------------- sales ----------------
  ({double sub, double disc, double total}) cartTotals() {
    var sub = 0.0;
    cart.forEach((id, q) {
      final p = product(id);
      if (p != null && q > 0) sub += n(p['price']) * q;
    });
    final disc = discountType == 'percent'
        ? (sub * (math.min(discountValue, 100.0) / 100)).roundToDouble()
        : math.min(discountValue, sub);
    return (sub: sub, disc: disc, total: math.max(0.0, sub - disc));
  }

  double priorDebtOf(String customer, {String? exceptSaleId}) {
    final c = customer.trim();
    if (c.isEmpty) return 0;
    return sales
        .where((x) => x['id'] != exceptSaleId && s_(x['customer']).trim() == c && x['status'] == 'debt')
        .fold<double>(0, (a, x) => a + saleOutstanding(x));
  }

  void resetDraft() {
    cart = {};
    payMethod = 'cash';
    discountType = 'percent';
    discountValue = 0;
    paidNowValue = '';
    paidNowMethod = 'cash';
    customerDraft = '';
  }

  Future<({M sale, double prior})?> confirmSale(String customer) async {
    final items = <M>[];
    cart.forEach((id, q) {
      final p = product(id);
      if (p != null && q > 0) {
        items.add({'productId': id, 'name': p['name'], 'price': n(p['price']), 'qty': q});
      }
    });
    if (items.isEmpty) return null;
    final t = cartTotals();
    final prior = priorDebtOf(customer);
    for (final i in items) {
      final p = product(s_(i['productId']));
      if (p != null) p['stock'] = math.max(0, ni(p['stock']) - ni(i['qty']));
    }
    final paidNow = payMethod == 'debt' ? pnum(paidNowValue).clamp(0.0, t.total).toDouble() : 0.0;
    final counter = ni(d['orderCounter']) + 1;
    d['orderCounter'] = counter;
    final sale = <String, dynamic>{
      'id': uid(), 'orderNumber': counter, 'date': nowISO(), 'customer': customer, 'items': items,
      'subtotal': t.sub, 'discountType': t.disc > 0 ? discountType : null,
      'discountValue': t.disc > 0 ? discountValue : 0, 'discountAmount': t.disc,
      'total': t.total, 'paidAmount': paidNow, 'paidMethod': paidNowMethod, 'payment': payMethod,
      'status': (payMethod == 'debt' && paidNow < t.total) ? 'debt' : 'paid',
    };
    sales.add(sale);
    resetDraft();
    salesSub = 2;
    await save();
    return (sale: sale, prior: prior);
  }

  Future<({M sale, double prior})> applyEditSale(M s, Map<String, int> editCart, String customer,
      String payment, String paidNowStr, String paidNowMethod) async {
    final orig = <String, int>{for (final i in its(s)) s_(i['productId']): ni(i['qty'])};
    final newItems = <M>[];
    editCart.forEach((pid, q) {
      final p = product(pid);
      if (q > 0 && p != null) {
        newItems.add({'productId': pid, 'name': p['name'], 'price': n(p['price']), 'qty': q});
      }
    });
    final ids = {...orig.keys, ...editCart.keys};
    for (final pid in ids) {
      final p = product(pid);
      if (p == null) continue;
      p['stock'] = ni(p['stock']) + (orig[pid] ?? 0) - (editCart[pid] ?? 0);
    }
    s['items'] = newItems;
    final total = newItems.fold<double>(0, (a, i) => a + n(i['price']) * ni(i['qty']));
    s['total'] = total;
    s['subtotal'] = total;
    s['discountAmount'] = 0.0;
    s['discountType'] = null;
    s['discountValue'] = 0;
    s['customer'] = customer;
    s['payment'] = payment;
    if (payment == 'debt') {
      final paid = pnum(paidNowStr).clamp(0.0, total).toDouble();
      s['paidAmount'] = paid;
      s['paidMethod'] = paidNowMethod;
      s['status'] = paid < total ? 'debt' : 'paid';
    } else {
      s['paidAmount'] = 0.0;
      s['status'] = 'paid';
    }
    final prior = priorDebtOf(customer, exceptSaleId: s_(s['id']));
    await save();
    return (sale: s, prior: prior);
  }

  // ---------------- reports ----------------
  ({double today, double month, double debt, double invValue, int lowStock, int debtCount}) stats() {
    final now = DateTime.now();
    double today = 0, month = 0, debt = 0;
    var dc = 0;
    for (final s in sales) {
      final dt = parseD(s_(s['date']));
      if (dt != null && dt.year == now.year && dt.month == now.month) {
        month += n(s['total']);
        if (dt.day == now.day) today += n(s['total']);
      }
      if (s['status'] == 'debt') {
        debt += saleOutstanding(s);
        dc++;
      }
    }
    final inv = products.fold<double>(0, (a, p) => a + n(p['price']) * ni(p['stock']));
    final low = products.where((p) => ni(p['stock']) <= 5).length;
    return (today: today, month: month, debt: debt, invValue: inv, lowStock: low, debtCount: dc);
  }

  List<M> customerStats() {
    final map = <String, M>{};
    for (final s in sales) {
      final c = s_(s['customer']).trim();
      final key = c.isEmpty ? '__anon__' : c;
      final e = map.putIfAbsent(
          key,
          () => <String, dynamic>{
                'key': key, 'name': c.isEmpty ? tr('no_name') : c, 'total': 0.0, 'debt': 0.0,
                'count': 0, 'lastDate': s['date'], 'sales': <M>[], 'phone': '', 'manualId': null
              });
      e['total'] = n(e['total']) + n(s['total']);
      if (s['status'] == 'debt') e['debt'] = n(e['debt']) + saleOutstanding(s);
      e['count'] = (e['count'] as int) + 1;
      (e['sales'] as List<M>).add(s);
      if (s_(s['date']).compareTo(s_(e['lastDate'])) > 0) e['lastDate'] = s['date'];
    }
    for (final c in clients) {
      final key = s_(c['name']).trim();
      final e = map[key];
      if (e == null) {
        map[key] = <String, dynamic>{
          'key': key, 'name': c['name'], 'total': 0.0, 'debt': 0.0, 'count': 0, 'lastDate': '',
          'sales': <M>[], 'phone': s_(c['phone']), 'manualId': c['id']
        };
      } else {
        e['phone'] = s_(c['phone']);
        e['manualId'] = c['id'];
      }
    }
    return map.values.toList()..sort((a, b) => s_(b['lastDate']).compareTo(s_(a['lastDate'])));
  }

  double supplierDebt(String name) => purchases
      .where((p) => p['supplier'] == name && p['status'] == 'debt')
      .fold<double>(0, (a, p) => a + purchaseOutstanding(p));

  Map<String, double> cashStats() {
    double sumWhere(List<M> l, bool Function(M) f, double Function(M) v) =>
        l.where(f).fold<double>(0, (a, x) => a + v(x));
    final cashSales = sumWhere(sales, (x) => x['payment'] == 'cash', (x) => n(x['total']));
    final cardSales = sumWhere(sales, (x) => x['payment'] == 'card', (x) => n(x['total']));
    double breakdownSum(String saleId) {
      var t = 0.0;
      for (final dp in debtPayments) {
        for (final b in bdOf(dp)) {
          if (b['saleId'] == saleId) t += n(b['amount']);
        }
      }
      return t;
    }

    double upfront(M x) => math.max(0.0, n(x['paidAmount']) - breakdownSum(s_(x['id'])));
    final upCash = sumWhere(sales, (x) => x['payment'] == 'debt' && (s_(x['paidMethod']).isEmpty || x['paidMethod'] == 'cash'), upfront);
    final upCard = sumWhere(sales, (x) => x['payment'] == 'debt' && x['paidMethod'] == 'card', upfront);
    final exp = expenses.fold<double>(0, (a, x) => a + n(x['amount']));
    final wd = withdrawals.fold<double>(0, (a, x) => a + n(x['amount']));
    final dpCash = sumWhere(debtPayments, (x) => s_(x['method']).isEmpty || x['method'] == 'cash', (x) => n(x['amount']));
    final dpCard = sumWhere(debtPayments, (x) => x['method'] == 'card', (x) => n(x['amount']));
    final spCash = sumWhere(supplierPayments, (x) => s_(x['method']).isEmpty || x['method'] == 'cash', (x) => n(x['amount']));
    final spCard = sumWhere(supplierPayments, (x) => x['method'] == 'card', (x) => n(x['amount']));
    final onHand = (cashSales + cardSales) + (dpCash + dpCard) + (upCash + upCard) - exp - wd - (spCash + spCard);
    return {
      'cashSales': cashSales, 'cardSales': cardSales, 'expenses': exp, 'withdrawals': wd,
      'dpCash': dpCash, 'dpCard': dpCard, 'upCash': upCash, 'upCard': upCard,
      'spCash': spCash, 'spCard': spCard, 'onHand': onHand,
    };
  }
}

final store = Store();
