import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kRed = Color(0xFFF14635);
const kRedDark = Color(0xFFD9301F);
const kBg = Color(0xFFF2F2F7);
const kGreen = Color(0xFF34C759);
const kGray = Color(0xFF8E8E93);

const expCats = <String, IconData>{
  'Еда': CupertinoIcons.cart,
  'Транспорт': CupertinoIcons.car,
  'Дом': CupertinoIcons.house,
  'Покупки': CupertinoIcons.bag,
  'Здоровье': CupertinoIcons.heart,
  'Отдых': CupertinoIcons.game_controller,
  'Связь': CupertinoIcons.phone,
  'Другое': CupertinoIcons.ellipsis,
};
const incCats = <String, IconData>{
  'Зарплата': CupertinoIcons.money_dollar_circle,
  'Подработка': CupertinoIcons.briefcase,
  'Подарок': CupertinoIcons.gift,
  'Другое': CupertinoIcons.ellipsis,
};
const months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
const monthsNom = ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
const weekShort = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'];

String fmt(double v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u00A0');
    b.write(s[i]);
  }
  return '${v < 0 ? '−' : ''}$b ₸';
}

class Tx {
  final String id;
  final double amount;
  final bool income;
  final String category;
  final String note;
  final DateTime date;
  Tx(this.id, this.amount, this.income, this.category, this.note, this.date);
  Map<String, dynamic> toJson() => {
        'id': id, 'a': amount, 'i': income, 'c': category, 'n': note,
        'd': date.toIso8601String(),
      };
  factory Tx.fromJson(Map<String, dynamic> j) => Tx(j['id'], (j['a'] as num).toDouble(),
      j['i'], j['c'], j['n'] ?? '', DateTime.parse(j['d']));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Мой бюджет',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: kRed,
          scaffoldBackgroundColor: kBg,
          splashFactory: NoSplash.splashFactory,
        ),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Tx> txs = [];
  int period = 0;
  DateTime anchor = DateTime.now();
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    final s = prefs!.getString('txs');
    if (s != null) {
      setState(() => txs = (jsonDecode(s) as List).map((e) => Tx.fromJson(e)).toList());
    }
  }

  void _save() => prefs?.setString('txs', jsonEncode(txs.map((e) => e.toJson()).toList()));

  DateTime get start {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    switch (period) {
      case 0: return d;
      case 1: return DateTime(d.year, d.month, d.day - (d.weekday - 1));
      case 2: return DateTime(d.year, d.month);
      default: return DateTime(d.year);
    }
  }

  DateTime get end {
    final s = start;
    switch (period) {
      case 0: return DateTime(s.year, s.month, s.day + 1);
      case 1: return DateTime(s.year, s.month, s.day + 7);
      case 2: return DateTime(s.year, s.month + 1);
      default: return DateTime(s.year + 1);
    }
  }

  void shift(int k) => setState(() {
        switch (period) {
          case 0: anchor = DateTime(anchor.year, anchor.month, anchor.day + k); break;
          case 1: anchor = DateTime(anchor.year, anchor.month, anchor.day + 7 * k); break;
          case 2: anchor = DateTime(anchor.year, anchor.month + k, 1); break;
          default: anchor = DateTime(anchor.year + k, 1, 1);
        }
      });

  String get title {
    final s = start;
    switch (period) {
      case 0: return '${s.day} ${months[s.month - 1]} ${s.year}';
      case 1:
        final e = end.subtract(const Duration(days: 1));
        return '${s.day} ${months[s.month - 1].substring(0, 3)} – ${e.day} ${months[e.month - 1].substring(0, 3)}';
      case 2: return '${monthsNom[s.month - 1]} ${s.year}';
      default: return '${s.year}';
    }
  }

  int get bucketCount => period == 0 ? 6 : period == 1 ? 7 : period == 2 ? DateTime(start.year, start.month + 1, 0).day : 12;
  int bucketOf(DateTime d) => period == 0 ? d.hour ~/ 4 : period == 1 ? d.weekday - 1 : period == 2 ? d.day - 1 : d.month - 1;
  String bucketLabel(int i) {
    if (period == 0) return '${i * 4}';
    if (period == 1) return weekShort[i];
    if (period == 2) return (i + 1) % 5 == 0 || i == 0 ? '${i + 1}' : '';
    return monthsNom[i].substring(0, 3);
  }

  Future<void> _add() async {
    final tx = await showModalBottomSheet<Tx>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSheet(initial: anchor),
    );
    if (tx != null) {
      setState(() => txs.add(tx));
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = start, e = end;
    final list = txs.where((t) => !t.date.isBefore(s) && t.date.isBefore(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    double inc = 0, exp = 0;
    final n = bucketCount;
    final bi = List<double>.filled(n, 0), be = List<double>.filled(n, 0);
    for (final t in list) {
      final k = bucketOf(t.date).clamp(0, n - 1);
      if (t.income) { inc += t.amount; bi[k] += t.amount; } else { exp += t.amount; be[k] += t.amount; }
    }
    double mx = 1;
    for (int i = 0; i < n; i++) { if (bi[i] > mx) mx = bi[i]; if (be[i] > mx) mx = be[i]; }

    final rows = <Widget>[];
    String? lastDay;
    for (final t in list) {
      final dk = '${t.date.day} ${months[t.date.month - 1]}';
      if (period != 0 && dk != lastDay) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(dk, style: const TextStyle(color: kGray, fontSize: 13, fontWeight: FontWeight.w600)),
        ));
        lastDay = dk;
      }
      rows.add(Dismissible(
        key: ValueKey(t.id),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(CupertinoIcons.trash, color: Colors.white),
        ),
        onDismissed: (_) {
          setState(() => txs.removeWhere((x) => x.id == t.id));
          _save();
        },
        child: TxTile(t),
      ));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const Icon(CupertinoIcons.plus),
        label: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text('Мой бюджет', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: period,
                children: const {
                  0: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('День')),
                  1: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Неделя')),
                  2: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Месяц')),
                  3: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Год')),
                },
                onValueChanged: (v) => setState(() => period = v ?? 0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(children: [
                IconButton(onPressed: () => shift(-1), icon: const Icon(CupertinoIcons.chevron_left, size: 20)),
                Expanded(child: Center(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
                IconButton(onPressed: () => shift(1), icon: const Icon(CupertinoIcons.chevron_right, size: 20)),
              ]),
            ),
            // Красная карточка баланса в стиле Kaspi
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kRed, kRedDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: kRed.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Баланс за период', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(fmt(inc - exp), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _pill('Доходы', fmt(inc), CupertinoIcons.arrow_down_left)),
                  const SizedBox(width: 10),
                  Expanded(child: _pill('Расходы', fmt(exp), CupertinoIcons.arrow_up_right)),
                ]),
              ]),
            ),
            // График
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(n, (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: n > 15 ? 0.5 : 3),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Expanded(child: _bar(bi[i] / mx, kGreen)),
                          const SizedBox(width: 1),
                          Expanded(child: _bar(be[i] / mx, kRed)),
                        ]),
                      ),
                    )),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: List.generate(n, (i) => Expanded(
                  child: Text(bucketLabel(i), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.visible,
                      style: const TextStyle(fontSize: 10, color: kGray)),
                ))),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Операции', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('Пока пусто.\nНажмите «Добавить»', textAlign: TextAlign.center, style: TextStyle(color: kGray))),
              )
            else
              ...rows,
          ],
        ),
      ),
    );
  }

  Widget _bar(double f, Color c) => Container(
        height: f <= 0 ? 2 : (110 * f).clamp(3.0, 110.0),
        decoration: BoxDecoration(
          color: f <= 0 ? const Color(0xFFE5E5EA) : c,
          borderRadius: BorderRadius.circular(3),
        ),
      );

  Widget _pill(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
        ]),
      );
}

class TxTile extends StatelessWidget {
  final Tx t;
  const TxTile(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final icon = (t.income ? incCats : expCats)[t.category] ?? CupertinoIcons.ellipsis;
    final time = '${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: (t.income ? kGreen : kRed).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: t.income ? kGreen : kRed, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (t.note.isNotEmpty) Text(t.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kGray, fontSize: 13)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${t.income ? '+' : '−'} ${fmt(t.amount)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.income ? kGreen : Colors.black)),
          Text(time, style: const TextStyle(color: kGray, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class AddSheet extends StatefulWidget {
  final DateTime initial;
  const AddSheet({super.key, required this.initial});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  bool income = false;
  String cat = 'Еда';
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  late DateTime date = widget.initial;

  @override
  Widget build(BuildContext context) {
    final cats = income ? incCats : expCats;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0xFFC7C7CC), borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: income,
                children: const {
                  false: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Расход')),
                  true: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Доход')),
                },
                onValueChanged: (v) => setState(() {
                  income = v ?? false;
                  cat = income ? incCats.keys.first : expCats.keys.first;
                }),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountC,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '₸',
                suffixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: income ? kGreen : kRed),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: cats.entries.map((e) => ChoiceChip(
                    avatar: Icon(e.value, size: 16, color: cat == e.key ? Colors.white : kGray),
                    label: Text(e.key),
                    selected: cat == e.key,
                    showCheckmark: false,
                    selectedColor: income ? kGreen : kRed,
                    labelStyle: TextStyle(color: cat == e.key ? Colors.white : Colors.black),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) => setState(() => cat = e.key),
                  )).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteC,
              decoration: InputDecoration(
                hintText: 'Комментарий',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(
                    context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => date = d);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(CupertinoIcons.calendar, size: 20, color: kGray),
                  const SizedBox(width: 10),
                  Text('${date.day} ${months[date.month - 1]} ${date.year}', style: const TextStyle(fontSize: 16)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  final v = double.tryParse(amountC.text.replaceAll(',', '.').replaceAll(' ', ''));
                  if (v == null || v <= 0) return;
                  final now = DateTime.now();
                  final when = DateTime(date.year, date.month, date.day, now.hour, now.minute);
                  Navigator.pop(context,
                      Tx(now.microsecondsSinceEpoch.toString(), v, income, cat, noteC.text.trim(), when));
                },
                child: const Text('Сохранить', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
