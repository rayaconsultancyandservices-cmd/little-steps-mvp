import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primary = Color(0xFF168C80);
  static const Color primaryDark = Color(0xFF105F59);
  static const Color dark = Color(0xFF183B45);
  static const Color background = Color(0xFFF4F7F8);
  static const Color muted = Color(0xFF82918D);

  static const List<Color> headerColors = [
    Color(0xFF104F58),
    Color(0xFF087F79),
    Color(0xFF27B69B),
  ];

  void _go(int index) => widget.onNavigate(index);

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _greetingIcon() {
    return DateTime.now().hour < 17
        ? Icons.wb_sunny_rounded
        : Icons.nights_stay_rounded;
  }

  String _initial(String name) {
    final clean = name.replaceFirst(RegExp(r'^(Ms|Mrs|Mr)\.?\s*'), '').trim();
    return clean.isEmpty ? 'T' : clean[0].toUpperCase();
  }

  Future<void> _logout() async {
    // Firebase session + live streams खऱ्या अर्थाने बंद (आधी फक्त screen बदलत होता).
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Logout?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: dark,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your teacher account?',
          style: TextStyle(fontSize: 13, height: 1.5, color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) _logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AppState.instance,
          builder: (context, _) {
            final s = AppState.instance;
            final now = DateTime.now();

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(s),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _buildQuickAccess(s),
                            const SizedBox(height: 25),
                            _buildAttendance(s, now),
                            const SizedBox(height: 25),
                            _buildEvents(s, now),
                            const SizedBox(height: 25),
                            _buildDiary(s),
                            const SizedBox(height: 25),
                            _buildMessages(s),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppState s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 9, 12, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: headerColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -65, child: _circle(180, 0.08)),
          Positioned(right: 90, bottom: -75, child: _circle(145, 0.07)),
          Positioned(left: -45, bottom: 30, child: _circle(105, 0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 19, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _go(6), // नवीन: avatar दाबल्यावर My Profile
                      child: Container(
                        height: 49,
                        width: 49,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initial(s.teacherName),
                          style: const TextStyle(
                            color: primaryDark,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_greetingIcon(),
                                  size: 14, color: const Color(0xFFFFDE85)),
                              const SizedBox(width: 5),
                              Text(
                                _greeting(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Teacher Dashboard',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _headerButton(
                      onTap: () => _go(5),
                      child: Badge(
                        isLabelVisible: s.unreadMessages > 0,
                        label: Text('${s.unreadMessages}'),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _headerButton(
                      onTap: _confirmLogout,
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.white, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                Container(height: 1,
                    color: Colors.white.withValues(alpha: 0.18)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.school_rounded,
                        color: Color(0xFFFFE39A), size: 17),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Class Teacher  •  ${s.className}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double alpha) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _headerButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 39,
          width: 39,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.23),
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildQuickAccess(AppState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Quick Access', 'Everything you need in one place'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 11.0;
            final width = (constraints.maxWidth - gap * 2) / 3;

            final tiles = <Widget>[
              _tile(
                width: width,
                icon: Icons.fact_check_rounded,
                label: 'Attendance',
                color: const Color(0xFF168C80),
                light: const Color(0xFFE5F5F0),
                dot: !s.attendanceSaved,
                onTap: () => _go(1),
              ),
              _tile(
                width: width,
                icon: Icons.photo_library_rounded,
                label: 'Photos',
                color: const Color(0xFFD18B37),
                light: const Color(0xFFFFF3E3),
                onTap: () => _go(2),
              ),
              _tile(
                width: width,
                icon: Icons.menu_book_rounded,
                label: 'Class Diary',
                color: const Color(0xFF7963C9),
                light: const Color(0xFFF0ECFF),
                dot: !s.diaryPublished,
                onTap: () => _go(3),
              ),
              _tile(
                width: width,
                icon: Icons.campaign_rounded,
                label: 'Circulars',
                color: const Color(0xFF4786C7),
                light: const Color(0xFFEAF2FF),
                onTap: () => _go(4),
              ),
              _tile(
                width: width,
                icon: Icons.chat_bubble_rounded,
                label: 'Messages',
                color: const Color(0xFFCA6B91),
                light: const Color(0xFFFFEDF3),
                count: s.unreadMessages,
                onTap: () => _go(5),
              ),
              // नवीन: My Profile (माहिती, password बदल, logout)
              _tile(
                width: width,
                icon: Icons.account_circle_rounded,
                label: 'My Profile',
                color: const Color(0xFF5A7D8C),
                light: const Color(0xFFE8F0F3),
                onTap: () => _go(6),
              ),
              // नवीन: Fees — fees जोडणं / Paid करणं (Parent ला लगेच दिसतं)
              _tile(
                width: width,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Fees',
                color: const Color(0xFF2E9B5E),
                light: const Color(0xFFE6F6EC),
                onTap: () => _go(7),
              ),
              // नवीन: Events — Parent च्या Calendar मध्ये दिसणारे events
              _tile(
                width: width,
                icon: Icons.event_rounded,
                label: 'Events',
                color: const Color(0xFFD5604B),
                light: const Color(0xFFFFEDE9),
                onTap: () => _go(8),
              ),
              // नवीन: Leave — Parent चे रजेचे अर्ज (बाकी अर्जांची संख्या दिसते)
              _tile(
                width: width,
                icon: Icons.event_busy_rounded,
                label: 'Leave',
                color: const Color(0xFF8066C8),
                light: const Color(0xFFF0ECFF),
                count: s.pendingLeaveCount,
                onTap: () => _go(9),
              ),
            ];

            return Wrap(spacing: gap, runSpacing: gap, children: tiles);
          },
        ),
      ],
    );
  }

  Widget _tile({
    required double width,
    required IconData icon,
    required String label,
    required Color color,
    required Color light,
    required VoidCallback onTap,
    bool dot = false,
    int count = 0,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: light,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (count > 0)
                      Positioned(
                        top: -7,
                        right: -7,
                        child: _notificationBadge('$count'),
                      )
                    else if (dot)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          height: 11,
                          width: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5484D),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildAttendance(AppState s, DateTime now) {
    final total = s.presentCount + s.absentCount;
    final progress = total > 0 ? s.presentCount / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Attendance Overview',
          'Track your classroom performance',
          trailing: 'View all',
          onTrailingTap: () => _go(1),
        ),
        const SizedBox(height: 14),
        _card(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Today's Attendance",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F5F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.attendanceSaved ? 'Completed' : 'Pending',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statBox(
                      'Students',
                      '${s.totalChildren}',
                      Icons.groups_rounded,
                      const Color(0xFF4779C8),
                      const Color(0xFFEAF1FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statBox(
                      'Present',
                      s.attendanceSaved ? '${s.presentCount}' : '--',
                      Icons.check_circle_rounded,
                      const Color(0xFF269C75),
                      const Color(0xFFE4F6ED),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statBox(
                      'Absent',
                      s.attendanceSaved ? '${s.absentCount}' : '--',
                      Icons.cancel_rounded,
                      const Color(0xFFE27865),
                      const Color(0xFFFFEFEC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Attendance Progress',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),
                  ),
                  Text(
                    s.attendanceSaved
                        ? '${(progress * 100).round()}%'
                        : 'Not marked',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: s.attendanceSaved
                        ? progress.clamp(0.0, 1.0)
                        : 0,
                  ),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEDF1EF),
                    valueColor: const AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Weekly Performance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),
                  ),
                  Icon(Icons.bar_chart_rounded,
                      size: 17, color: primary.withValues(alpha: 0.8)),
                ],
              ),
              const SizedBox(height: 12),
              _weeklyChart(s, now),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    s.attendanceSaved
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: s.attendanceSaved
                        ? const Color(0xFF269C75)
                        : Colors.orange,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      s.attendanceSaved
                          ? 'Attendance has been saved successfully.'
                          : 'Attendance is waiting to be marked.',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _go(1),
                    child: const Text(
                      'Open',
                      style: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(
      String title,
      String value,
      IconData icon,
      Color color,
      Color light,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
      decoration: BoxDecoration(
        color: light,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyChart(AppState s, DateTime now) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final todayIndex = now.weekday - 1;
    final total = s.presentCount + s.absentCount;
    final todayValue = s.attendanceSaved && total > 0
        ? (s.presentCount * 100 ~/ total)
        : 0;
    const maxBar = 65.0;

    return SizedBox(
      height: 103,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(days.length, (i) {
          final isToday = i == todayIndex;
          // खरा attendance (Firestore) – डेटा नसेल तर 0 (म्हणजे '-')
          int value;

          if (isToday) {
            value = todayValue;
          } else if (todayIndex <= 4 && i > todayIndex) {
            value = 0;
          } else {
            value = s.weeklyPercent(i);
          }

          final color = isToday ? primary : const Color(0xFFBFE3DA);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  value == 0 ? '-' : '$value%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isToday ? primary : muted,
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  height: value == 0 ? 4 : maxBar * value / 100,
                  width: 25,
                  decoration: BoxDecoration(
                    color: value == 0
                        ? const Color(0xFFEDF1EF)
                        : color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  days[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                    isToday ? FontWeight.w900 : FontWeight.w500,
                    color: isToday ? dark : muted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEvents(AppState s, DateTime now) {
    final events = <_EventItem>[];

    // खरे upcoming events: Firestore events + event date असलेले circulars
    final today = DateTime(now.year, now.month, now.day);
    for (final e in s.events) {
      if (e.date.isBefore(today)) continue;
      events.add(_EventItem(title: e.title, date: e.date, tag: e.category));
      if (events.length >= 4) break;
    }

    const palette = [
      [Color(0xFF4786C7), Color(0xFFE9F2FF)],
      [Color(0xFFD18B37), Color(0xFFFFF3E1)],
      [Color(0xFF7761C5), Color(0xFFF0ECFF)],
      [Color(0xFFCA6B91), Color(0xFFFFECF3)],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Upcoming Events',
          'Important dates and school activities',
          trailing: 'Circulars',
          onTrailingTap: () => _go(4),
        ),
        const SizedBox(height: 11),
        Column(
          children: events.isEmpty
              ? [_emptyNote('No upcoming events yet.')]
              : List.generate(events.length, (i) {
            final e = events[i];
            final color = palette[i % palette.length][0];
            final light = palette[i % palette.length][1];

            return Padding(
              padding: EdgeInsets.only(
                bottom: i == events.length - 1 ? 0 : 9,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: () => _go(4),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 7,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 43,
                          height: 45,
                          decoration: BoxDecoration(
                            color: light,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${e.date.day}',
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                AppState.shortDate(e.date).split(' ').last,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: dark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: light,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  e.tag,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: muted.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDiary(AppState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Class Diary',
          'Your classroom daily updates',
          trailing: 'View diary',
          onTrailingTap: () => _go(3),
        ),
        const SizedBox(height: 14),
        _statusCard(
          icon: Icons.auto_stories_rounded,
          title: "Today's Class Diary",
          subtitle: s.diaryPublished
              ? 'Your diary has been published successfully.'
              : 'Share today\'s classroom activities with parents.',
          status: s.diaryPublished ? 'Published' : 'Not Published',
          color: const Color(0xFF7963C9),
          light: const Color(0xFFF0ECFF),
          onTap: () => _go(3),
        ),
      ],
    );
  }

  static const List<Color> _msgColors = [
    Color(0xFFFFE0D9),
    Color(0xFFFFF0D9),
    Color(0xFFDDF2EC),
    Color(0xFFE6E0FA),
  ];

  Widget _emptyNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: muted),
      ),
    );
  }

  // खऱ्या Firestore threads मधून शेवटचे दोन parent संवाद.
  Widget _buildMessages(AppState s) {
    final latest = s.threadList.take(2).toList();
    final messages = <_HomeMessage>[
      for (var i = 0; i < latest.length; i++)
        _HomeMessage(
          name: latest[i].parentName.isEmpty
              ? 'Parent'
              : latest[i].parentName,
          child: 'Parent of ${latest[i].studentName}',
          message: latest[i].lastText,
          time: latest[i].lastAt == null
              ? ''
              : AppState.timeLabel(latest[i].lastAt!),
          unread: latest[i].teacherUnread,
          avatarColor: _msgColors[i % _msgColors.length],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Parent Communication',
          'Messages from your students’ families',
          trailing: 'View messages',
          onTrailingTap: () => _go(5),
        ),
        const SizedBox(height: 14),
        if (messages.isEmpty)
          _emptyNote('No messages from parents yet.')
        else
          for (var i = 0; i < messages.length; i++)
            _messageTile(messages[i], isLast: i == messages.length - 1),
      ],
    );
  }

  String _messageInitials(String name) {
    return name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  Widget _messageTile(_HomeMessage m, {bool isLast = false}) {
    final hasUnread = m.unread > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _go(5),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: hasUnread ? const Color(0xFFFBFEFC) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasUnread
                    ? const Color(0xFFCDE6DC)
                    : const Color(0xFFE7EEEA),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: m.avatarColor,
                      child: Text(
                        _messageInitials(m.name),
                        style: const TextStyle(
                          color: dark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (m.online)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          height: 12,
                          width: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF35B779),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark,
                          fontSize: 12,
                          fontWeight:
                          hasUnread ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m.child,
                        style: const TextStyle(color: muted, fontSize: 9),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread ? dark : muted,
                          fontSize: 10,
                          fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      m.time,
                      style: TextStyle(
                        color: hasUnread ? primary : muted,
                        fontSize: 9,
                        fontWeight:
                        hasUnread ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasUnread)
                      Container(
                        height: 21,
                        width: 21,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${m.unread}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: Color(0xFFADB8B2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color color,
    required Color light,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 49,
                width: 49,
                decoration: BoxDecoration(
                  color: light,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: dark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: light,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: muted,
                  size: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(
      String title,
      String subtitle, {
        String? trailing,
        VoidCallback? onTrailingTap,
      }) {
    return Row(
      children: [
        Container(
          height: 37,
          width: 4,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: dark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(fontSize: 10, color: muted)),
            ],
          ),
        ),
        if (trailing != null)
          TextButton(
            onPressed: onTrailingTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing,
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded,
                    size: 13, color: primary),
              ],
            ),
          ),
      ],
    );
  }
}

class _EventItem {
  const _EventItem({
    required this.title,
    required this.date,
    required this.tag,
  });

  final String title;
  final DateTime date;
  final String tag;
}

class _HomeMessage {
  const _HomeMessage({
    required this.name,
    required this.child,
    required this.message,
    required this.time,
    required this.avatarColor,
    this.unread = 0,
    this.online = false,
  });


  final String name;
  final String child;
  final String message;
  final String time;
  final Color avatarColor;
  final int unread;
  final bool online;

  _HomeMessage copyWith({int? unread}) => _HomeMessage(
    name: name,
    child: child,
    message: message,
    time: time,
    avatarColor: avatarColor,
    unread: unread ?? this.unread,
    online: online,
  );
}