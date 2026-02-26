import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkTimerApp());
}

class WorkTimerApp extends StatefulWidget {
  const WorkTimerApp({super.key});

  @override
  State<WorkTimerApp> createState() => _WorkTimerAppState();
}

class _WorkTimerAppState extends State<WorkTimerApp> {
  String _appLang = "ar";

  void _changeLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
    setState(() => _appLang = lang);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(_appLang),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', ''), Locale('en', '')],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), 
        primaryColor: Colors.blueAccent,
        useMaterial3: true,
      ),
      home: HomeScreen(onLangChange: _changeLanguage, currentLang: _appLang),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Function(String) onLangChange;
  final String currentLang;
  const HomeScreen({super.key, required this.onLangChange, required this.currentLang});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _checkInTime;
  DateTime? _breakStartTime;
  double _totalBreakMinutes = 0;
  List<String> _history = [];
  int _workTargetHours = 6;
  int _offDayIndex = 0; // سنستخدم الـ index للتحكم في الترتيب المخصص
  bool _isLoading = true;
  String _userName = "";
  final TextEditingController _nameController = TextEditingController();

  // ترتيب الأيام يبدأ من السبت وينتهي بالجمعة كما طلبت
  final List<String> _weekDaysAr = ["السبت", "الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"];
  final List<String> _weekDaysEn = ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
  
  // خريطة لتحويل ترتيبنا المخصص إلى رقم اليوم الحقيقي في نظام DateTime (حيث الاثنين = 1 والأحد = 7)
  final List<int> _realDayValues = [6, 7, 1, 2, 3, 4, 5];

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'نظام الدوام',
      'settings': 'الإعدادات',
      'target': 'الهدف اليومي:',
      'offDay': 'يوم الإجازة:',
      'checkIn': 'تسجيل دخول',
      'checkOut': 'تسجيل خروج',
      'break': 'استراحة',
      'endBreak': 'إنهاء الاستراحة',
      'onDuty': 'قيد العمل...',
      'onBreak': 'في استراحة... ☕',
      'offDuty': 'خارج الدوام',
      'isOffDay': 'اليوم يوم إجازتك 🌴',
      'history': 'السجل الأخير',
      'entry': 'دخول',
      'exit': 'خروج',
      'hours': 'ساعة',
      'close': 'إغلاق',
      'rights': 'جميع الحقوق محفوظة لـ Sadiq',
      'welcome': 'مرحباً، ',
      'nameLabel': 'الاسم الشخصي',
      'enterName': 'اكتب اسمك هنا',
    },
    'en': {
      'title': 'Work Timer',
      'settings': 'Settings',
      'target': 'Daily Target:',
      'offDay': 'Weekly Off-Day:',
      'checkIn': 'Check In',
      'checkOut': 'Check Out',
      'break': 'Break',
      'endBreak': 'End Break',
      'onDuty': 'On Duty...',
      'onBreak': 'On Break... ☕',
      'offDuty': 'Off Duty',
      'isOffDay': 'Today is your off-day 🌴',
      'history': 'History',
      'entry': 'In',
      'exit': 'Out',
      'hours': 'h',
      'close': 'Close',
      'rights': 'All rights reserved to Sadiq',
      'welcome': 'Hello, ',
      'nameLabel': 'Name:',
      'enterName': 'Enter your name',
    }
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workTargetHours = prefs.getInt('targetHours') ?? 6;
      _offDayIndex = prefs.getInt('offDayIndex') ?? 6; // افتراضياً الجمعة (آخر يوم في القائمة)
      _history = prefs.getStringList('history') ?? [];
      _totalBreakMinutes = prefs.getDouble('totalBreak') ?? 0;
      _userName = prefs.getString('userName') ?? "";
      _nameController.text = _userName;
      String? checkInStr = prefs.getString('checkIn');
      if (checkInStr != null) _checkInTime = DateTime.tryParse(checkInStr);
      String? breakStr = prefs.getString('breakStart');
      if (breakStr != null) _breakStartTime = DateTime.tryParse(breakStr);
      _isLoading = false;
    });
  }

  String t(String key) => _texts[widget.currentLang]![key] ?? key;

  void _handleCheckOut() async {
    if (_checkInTime == null) return;
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    double totalMinutes = now.difference(_checkInTime!).inMinutes.toDouble();
    double netMinutes = totalMinutes - _totalBreakMinutes;
    double ot = (netMinutes - (_workTargetHours * 60)) / 60;
    if (ot < 0) ot = 0;

    String record = "${DateFormat('yyyy-MM-dd').format(now)} | ${t('entry')}:${DateFormat('HH:mm').format(_checkInTime!)} | ${t('exit')}:${DateFormat('HH:mm').format(now)} | +${ot.toStringAsFixed(1)}${t('hours')}";

    setState(() {
      _history.insert(0, record);
      _checkInTime = null;
      _breakStartTime = null;
      _totalBreakMinutes = 0;
    });

    await prefs.remove('checkIn');
    await prefs.remove('breakStart');
    await prefs.setDouble('totalBreak', 0);
    await prefs.setStringList('history', _history);
  }

  void _deleteItem(int index) async {
    setState(() => _history.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CupertinoActivityIndicator()));

    // التحقق هل اليوم الحالي هو يوم الإجازة المختار
    bool isTodayOff = DateTime.now().weekday == _realDayValues[_offDayIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(t('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        leadingWidth: 120,
        leading: Center(
          child: Text(
            _userName.isNotEmpty ? "${t('welcome')}$_userName" : "",
            style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings)
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(children: [
                  _buildStatusCard(isTodayOff),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _iosButton(t('checkIn'), Colors.green, _checkInTime == null ? () async {
                      final now = DateTime.now();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('checkIn', now.toIso8601String());
                      setState(() => _checkInTime = now);
                    } : null)),
                    const SizedBox(width: 8),
                    Expanded(child: _iosButton(_breakStartTime == null ? t('break') : t('endBreak'), Colors.orange, _checkInTime != null ? () async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() {
                        if (_breakStartTime == null) {
                          _breakStartTime = DateTime.now();
                          prefs.setString('breakStart', _breakStartTime!.toIso8601String());
                        } else {
                          _totalBreakMinutes += DateTime.now().difference(_breakStartTime!).inMinutes;
                          _breakStartTime = null;
                          prefs.remove('breakStart');
                          prefs.setDouble('totalBreak', _totalBreakMinutes);
                        }
                      });
                    } : null)),
                    const SizedBox(width: 8),
                    Expanded(child: _iosButton(t('checkOut'), Colors.red, (_checkInTime != null && _breakStartTime == null) ? _handleCheckOut : null)),
                  ]),
                  const SizedBox(height: 25),
                  Align(alignment: AlignmentDirectional.centerStart, child: Text(t('history'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, i) => Dismissible(
                        key: Key(_history[i] + i.toString()),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _deleteItem(i),
                        child: Card(
                          color: const Color(0xFF1E293B),
                          child: ListTile(
                            leading: const Icon(Icons.history, color: Colors.blueAccent),
                            title: Text(_history[i], style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _deleteItem(i)
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(t('rights'), style: const TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isTodayOff) {
    String statusText;
    if (_checkInTime != null) {
      statusText = _breakStartTime != null ? t('onBreak') : t('onDuty');
    } else {
      statusText = isTodayOff ? t('isOffDay') : t('offDuty');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: _breakStartTime != null 
            ? [Colors.orange.shade700, Colors.orange.shade900]
            : (isTodayOff && _checkInTime == null 
                ? [Colors.blueGrey.shade700, Colors.blueGrey.shade900]
                : [const Color(0xFF1E40AF), const Color(0xFF3B82F6)])
        ),
      ),
      child: Column(children: [
        Text("${t('target')} $_workTargetHours ${t('hours')}", style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),
        Text(statusText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        if (_checkInTime != null) 
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("${t('entry')}: ${DateFormat('HH:mm').format(_checkInTime!)}", style: const TextStyle(fontSize: 18, color: Colors.white)),
          ),
      ]),
    );
  }

  void _showSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStepState) => CupertinoActionSheet(
        title: Text(t('settings')),
        message: Material(
          color: Colors.transparent,
          child: Column(children: [
            CupertinoSegmentedControl<String>(
              groupValue: widget.currentLang,
              children: const {'ar': Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("العربية")), 'en': Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("English"))},
              onValueChanged: (val) { widget.onLangChange(val); Navigator.pop(context); },
            ),
            const SizedBox(height: 20),
            CupertinoTextField(
              controller: _nameController,
              placeholder: t('enterName'),
              style: const TextStyle(color: Colors.white),
              prefix: const Padding(padding: EdgeInsets.only(left: 10), child: Icon(Icons.person, color: Colors.grey)),
              onChanged: (val) async {
                setState(() => _userName = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('userName', val);
              },
            ),
            const SizedBox(height: 20),
            Text("${t('target')} $_workTargetHours", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            CupertinoSlider(
              value: _workTargetHours.toDouble(),
              min: 1, max: 12, divisions: 11,
              onChanged: (val) async {
                setState(() => _workTargetHours = val.toInt());
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('targetHours', val.toInt());
                setStepState(() {});
              },
            ),
            const SizedBox(height: 15),
            // شريط اختيار الأيام: يبدأ من السبت (0) إلى الجمعة (6)
            Text("${t('offDay')} ${widget.currentLang == 'ar' ? _weekDaysAr[_offDayIndex] : _weekDaysEn[_offDayIndex]}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            CupertinoSlider(
              value: _offDayIndex.toDouble(),
              min: 0, max: 6, divisions: 6,
              onChanged: (val) async {
                setState(() => _offDayIndex = val.toInt());
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('offDayIndex', val.toInt());
                setStepState(() {});
              },
            ),
          ]),
        ),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(t('close'))),
        ],
      )),
    );
  }

  Widget _iosButton(String label, Color color, VoidCallback? action) {
    return Opacity(
      opacity: action == null ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: action,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
        ),
      ),
    );
  }
}