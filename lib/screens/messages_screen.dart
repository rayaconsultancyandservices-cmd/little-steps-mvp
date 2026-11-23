import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/page_app_bar.dart';

class _Parent {
  _Parent({
    required this.studentId,
    required this.name,
    required this.child,
    required this.message,
    required this.time,
    this.unread = 0,
    this.online = false,
  });

  final String studentId; // thread key (Firestore students/{id})
  final String name;
  final String child;
  String message;
  String time;
  int unread;
  final bool online;
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const Color _primary = Color(0xFF2F8877);
  static const Color _dark = Color(0xFF24313D);
  static const Color _muted = Color(0xFF7B8794);

  static const List<Color> _avatarColors = [
    Color(0xFFFFE0D9),
    Color(0xFFFFF0D9),
    Color(0xFFDDF2EC),
    Color(0xFFE6E0FA),
    Color(0xFFDDEBFF),
  ];

  final TextEditingController _search = TextEditingController();

  int _filter = 0;

  // खऱ्या Firestore data मधून parent list: class चे students + त्यांचे threads.
  // ज्या पालकांनी / teacher ने अजून chat सुरू केली नाही त्यांचाही row दिसतो.
  List<_Parent> get _parents {
    final app = AppState.instance;
    final rows = <_Parent>[];
    final times = <String, DateTime?>{};

    for (final st in app.students) {
      final meta = app.metaFor(st.id);
      final parentName = st.parentName.isNotEmpty
          ? st.parentName
          : (meta?.parentName ?? '');
      rows.add(_Parent(
        studentId: st.id,
        name: parentName.isEmpty ? 'Parent of ${st.name}' : parentName,
        child: 'Parent of ${st.name}',
        message: meta?.lastText.isNotEmpty == true
            ? meta!.lastText
            : 'No messages yet',
        time: meta?.lastAt == null ? '' : AppState.timeLabel(meta!.lastAt!),
        unread: meta?.teacherUnread ?? 0,
      ));
      times[st.id] = meta?.lastAt;
    }

    // शेवटचा संदेश असलेले वर, बाकी rollNo क्रमाने.
    rows.sort((a, b) {
      final ta = times[a.studentId];
      final tb = times[b.studentId];
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return rows;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _initials(String name) {
    return name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  void _open(_Parent parent) {
    AppState.instance.markThreadRead(parent.studentId);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          studentId: parent.studentId,
          parentName: parent.name,
          childLabel: parent.child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Parent ने नवीन संदेश पाठवला की ही यादी आपोआप refresh होते.
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final all = _parents;
    final query = _search.text.trim().toLowerCase();

    final filtered = all.where((parent) {
      final matchesSearch =
          parent.name.toLowerCase().contains(query) ||
              parent.child.toLowerCase().contains(query) ||
              parent.message.toLowerCase().contains(query);

      final matchesFilter = _filter == 0 ||
          (_filter == 1 && parent.unread > 0) ||
          (_filter == 2 && parent.unread == 0);

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: buildPageAppBar(
        title: 'Messages',
        subtitle: 'Parents of ${AppState.instance.className}',
        onBack: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        children: [
          // SEARCH
          const Text(
            'Parent Conversations',
            style: TextStyle(
              color: _dark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Find and open a parent conversation',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search parent, child or message...',
              hintStyle: const TextStyle(
                color: Color(0xFFA1AAA6),
                fontSize: 11,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _primary,
              ),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  _search.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE5ECE9),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE5ECE9),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: _primary,
                  width: 1.4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // FILTERS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 0),
                const SizedBox(width: 7),
                _filterChip('Unread', 1),
                const SizedBox(width: 7),
                _filterChip('Read', 2),
              ],
            ),
          ),

          const SizedBox(height: 13),

          // PARENT LIST
          if (filtered.isEmpty)
            _emptyState()
          else
            for (var i = 0; i < filtered.length; i++)
              _parentTile(filtered[i], i),

          const SizedBox(height: 12),

          // REPLY HOURS INFO
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFD9E7F8),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: Color(0xFF2B6CB0),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teacher Reply Hours',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2B6CB0),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Parents see your reply hours (12:00 – 3:00 PM). '
                            'Turn off chat notifications after hours in Settings.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2B6CB0),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int value) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: const Color(0xFFDDF2EC),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected
            ? _primary
            : const Color(0xFFE5ECE9),
      ),
      labelStyle: TextStyle(
        color: selected ? _primary : _dark,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _parentTile(_Parent parent, int index) {
    final hasUnread = parent.unread > 0;
    final avatarColor =
    _avatarColors[index % _avatarColors.length];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _open(parent),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: hasUnread
                ? const Color(0xFFFBFEFC)
                : Colors.white,
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
                    backgroundColor: avatarColor,
                    child: Text(
                      _initials(parent.name),
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (parent.online)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        height: 12,
                        width: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF35B779),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
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
                      parent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _dark,
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      parent.child,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      parent.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread ? _dark : _muted,
                        fontSize: 10,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
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
                    parent.time,
                    style: TextStyle(
                      color: hasUnread ? _primary : _muted,
                      fontSize: 9,
                      fontWeight: hasUnread
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasUnread)
                    Container(
                      height: 21,
                      width: 21,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${parent.unread}',
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
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE7EEEA),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.mark_chat_unread_outlined,
            size: 38,
            color: Color(0xFF9BAAA4),
          ),
          const SizedBox(height: 10),
          const Text(
            'No conversations found',
            style: TextStyle(
              color: _dark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Try another search or filter.',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
            ),
          ),
          if (_search.text.isNotEmpty || _filter != 0) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _search.clear();
                setState(() => _filter = 0);
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// ONE-TO-ONE CHAT SCREEN
// ============================================================

class _Msg {
  const _Msg(
      this.text,
      this.mine,
      this.time,
      );

  final String text;
  final bool mine;
  final String time;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.studentId,
    required this.parentName,
    this.childLabel = '',
  });

  final String studentId; // thread key
  final String parentName;
  final String childLabel;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _primary = Color(0xFF2F8877);
  static const Color _dark = Color(0xFF24313D);
  static const Color _muted = Color(0xFF7B8794);

  static const List<String> _quickReplies = [
    'Thank you!',
    'Okay, noted.',
    'I will check and update you.',
    'Please send a note.',
    'School is closed that day.',
  ];

  final TextEditingController _controller =
  TextEditingController();

  final ScrollController _scroll = ScrollController();

  // FIX 6: Chat आता AppState च्या shared thread मधून येतो
  // (Parent app चा ParentMessageScreen हाच thread वापरतो).

  List<_Msg> get _messages {
    final thread = AppState.instance.thread(widget.studentId);
    return thread
        .map((m) => _Msg(m.text, m.fromTeacher, m.time))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Chat उघडल्यावर unread 0 करा आणि शेवटच्या संदेशाकडे जा.
    AppState.instance.markThreadRead(widget.studentId);
    AppState.instance.addListener(_onStateChange);
    _scrollToBottom();
  }

  int _seen = 0;

  // chat उघडी असताना नवीन parent message आला तर तो लगेच "read" होतो.
  void _onStateChange() {
    final n = AppState.instance.thread(widget.studentId).length;
    if (n != _seen) {
      _seen = n;
      AppState.instance.markThreadRead(widget.studentId);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? quickReply]) {
    final text = (quickReply ?? _controller.text).trim();

    if (text.isEmpty) return;

    // FIX 6: संदेश AppState मध्ये save होतो -> Parent ला लगेच दिसतो.
    AppState.instance
        .sendMessage(
      widget.studentId,
      text,
      fromTeacher: true,
    )
        .catchError((Object e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message not sent: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
    _controller.clear();
    setState(() {});

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _initials(String name) {
    return name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F6),
      appBar: buildPageAppBar(
        title: widget.parentName,
        subtitle: widget.childLabel.isEmpty
            ? 'Parent conversation'
            : widget.childLabel,
        onBack: () => Navigator.pop(context),
        actions: [
          IconButton(
            tooltip: 'Chat information',
            onPressed: _showChatInfo,
            icon: const Icon(
              Icons.info_outline_rounded,
              color: _primary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // CHAT HEADER
          Container(
            width: double.infinity,
            color: const Color(0xFFEAF2FC),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 9,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: Color(0xFF2B6CB0),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Teacher reply hours: 12:00 – 3:00 PM',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF2B6CB0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // CONVERSATION DATE
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EFEB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppState.dateLabel(DateTime.now()),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // CHAT MESSAGES
          Expanded(
            // FIX 6: Parent ने नवीन संदेश पाठवला तर इथे आपोआप refresh होतो.
            child: AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final messages = _messages;
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _messageBubble(messages[index]),
                );
              },
            ),
          ),

          // QUICK REPLIES
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 9, bottom: 7),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'QUICK REPLIES',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 37,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: _quickReplies.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: 7),
                    itemBuilder: (_, index) {
                      return ActionChip(
                        label: Text(
                          _quickReplies[index],
                          style: const TextStyle(
                            fontSize: 10,
                            color: _primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor:
                        const Color(0xFFEAF4F0),
                        side: BorderSide.none,
                        onPressed: () =>
                            _send(_quickReplies[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // MESSAGE COMPOSER
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE7EEEA),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization:
                      TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(
                          color: Color(0xFFA1AAA6),
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F7F5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(23),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(23),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(23),
                          borderSide: const BorderSide(
                            color: _primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    width: 46,
                    child: IconButton.filled(
                      onPressed: () => _send(),
                      style: IconButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(
                        Icons.send_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(_Msg message) {
    return Align(
      alignment: message.mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
        decoration: BoxDecoration(
          color: message.mine
              ? const Color(0xFFDDF2EC)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(message.mine ? 15 : 4),
            bottomRight: Radius.circular(message.mine ? 4 : 15),
          ),
          border: Border.all(
            color: message.mine
                ? const Color(0xFFCBE5DA)
                : const Color(0xFFE7EEEA),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: _dark,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                  ),
                ),
                if (message.mine) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: _primary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChatInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Conversation Details',
          style: TextStyle(
            color: _dark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Parent: ${widget.parentName}\n'
              '${widget.childLabel}\n\n'
              'Reply hours: 12:00 – 3:00 PM',
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}