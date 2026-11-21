import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// P7 · Message Teacher
/// Teacher app च्या ChatScreen शी एकच thread share करतो (AppState.thread).
///
/// Features:
///  - Back arrow (same as the other screens) + teacher info button
///  - Dismissible "reply hours" banner
///  - Blue sent bubbles with double-tick, white received bubbles
///  - Long-press a message to copy it
///  - Quick reply chips (tap to fill the message box)
///  - Send button that is active only when there is text
///  - "Jump to latest" button when scrolled up
///  - Empty-state when there are no messages
class ParentMessageScreen extends StatefulWidget {
  const ParentMessageScreen({super.key, this.onBack});

  /// Back arrow action. By default it closes this screen.
  final VoidCallback? onBack;

  @override
  State<ParentMessageScreen> createState() => _ParentMessageScreenState();
}

class _ParentMessageScreenState extends State<ParentMessageScreen> {
  static const _quickReplies = [
    'Thank you ma’am!',
    'Please call me when free',
    'Running late for pickup',
    'Is there any homework today?',
    'Aarav will be absent tomorrow',
  ];

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  bool _showBanner = true;
  bool _showJump = false;
  int _lastCount = 0;

  String get _key => AppState.instance.child.parentName;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom(animate: false));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final away = _scroll.position.maxScrollExtent - _scroll.offset > 160;
    if (away != _showJump) setState(() => _showJump = away);
  }

  void _toBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    AppState.instance.sendMessage(_key, text, fromTeacher: false);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  void _useQuickReply(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  Future<void> _copyMessage(ChatMessage m) async {
    await Clipboard.setData(ClipboardData(text: m.text));
    if (mounted) showSnack(context, 'Message copied');
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final hasText = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: ParentColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(s),
            if (_showBanner) _banner(),
            Expanded(
              child: AnimatedBuilder(
                animation: s,
                builder: (context, _) {
                  final msgs = s.thread(_key);

                  // New message arrived -> keep the chat at the bottom.
                  if (msgs.length != _lastCount) {
                    _lastCount = msgs.length;
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _toBottom());
                  }

                  return Stack(
                    children: [
                      if (msgs.isEmpty)
                        _emptyState(s)
                      else
                        ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          itemCount: msgs.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) return _dayLabel('Today');
                            return _bubble(msgs[i - 1]);
                          },
                        ),
                      if (_showJump)
                        Positioned(
                          right: 16,
                          bottom: 10,
                          child: GestureDetector(
                            onTap: _toBottom,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: ParentColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F2B8FDB),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: ParentColors.primary),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (!hasText) _quickReplyRow(),
            _inputBar(hasText),
          ],
        ),
      ),
    );
  }

  // ---------- header (back arrow + teacher + info) ----------
  Widget _roundBtn(IconData icon, VoidCallback? onTap, {String? tooltip}) {
    final enabled = onTap != null;
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ParentColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x142B8FDB),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: ParentColors.dark),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _header(AppState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          _roundBtn(
            Icons.arrow_back_ios_new_rounded,
            widget.onBack ?? () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ParentColors.primary, ParentColors.primaryLight],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332B8FDB),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(s.teacherName.replaceFirst('Ms. ', '')),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Class teacher · ${s.className}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _roundBtn(
            Icons.info_outline_rounded,
                () => setState(() => _showBanner = !_showBanner),
            tooltip: 'Reply hours',
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: ParentColors.tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParentColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              size: 17, color: ParentColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Teacher replies between 12:00 and 3:00 PM on school days.',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: ParentColors.dark),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showBanner = false),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded,
                  size: 16, color: ParentColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- messages ----------
  Widget _dayLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ParentColors.border),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: ParentColors.muted)),
        ),
      ),
    );
  }

  Widget _emptyState(AppState s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: ParentColors.tintStrong,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 32, color: ParentColors.primary),
            ),
            const SizedBox(height: 14),
            const Text('No messages yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark)),
            const SizedBox(height: 4),
            Text('Say hello to ${s.teacherName}.',
                textAlign: TextAlign.center,
                style:
                const TextStyle(fontSize: 12.5, color: ParentColors.muted)),
          ],
        ),
      ),
    );
  }

  /// Parent चे message उजवीकडे (निळे), teacher चे डावीकडे (पांढरे).
  Widget _bubble(ChatMessage m) {
    final mine = !m.fromTeacher;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _copyMessage(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.fromLTRB(13, 10, 12, 7),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ParentColors.primary, ParentColors.primaryLight],
            )
                : null,
            color: mine ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            border: mine ? null : Border.all(color: ParentColors.border),
            boxShadow: [
              BoxShadow(
                color: mine
                    ? const Color(0x262B8FDB)
                    : const Color(0x0F14375A),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(m.text,
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: mine ? Colors.white : AppColors.text)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.time,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: mine
                              ? const Color(0xFFEAF5FD)
                              : ParentColors.muted)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all_rounded,
                        size: 13, color: Color(0xFFEAF5FD)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- quick replies ----------
  Widget _quickReplyRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _quickReplies[i];
          return GestureDetector(
            onTap: () => _useQuickReply(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ParentColors.border),
              ),
              child: Text(t,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ParentColors.primary)),
            ),
          );
        },
      ),
    );
  }

  // ---------- input ----------
  Widget _inputBar(bool hasText) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ParentColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => showSnack(
                    context, 'Photo attachments will be added later.'),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: ParentColors.tint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.image_outlined,
                      size: 20, color: ParentColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ParentColors.border),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(
                        fontSize: 14, color: ParentColors.dark),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                      TextStyle(fontSize: 14, color: ParentColors.muted),
                      counterText: '',
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: hasText ? _send : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: hasText ? ParentColors.primary : ParentColors.tintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.send_rounded,
                      size: 19,
                      color: hasText ? Colors.white : ParentColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}