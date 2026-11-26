import 'package:flutter/material.dart';
import 'api.dart';

/// Страница сведений о посте (Модуль A1 - Пункт 4)
class DetailPage extends StatefulWidget {
  final Map<String, dynamic> post; // Данные поста
  final Map<String, dynamic> currentUser; // Текущий пользователь
  final int initialMediaIndex; // Выбранный индекс медиафайла
  final List<Map<String, dynamic>> allPosts; // Все посты (для подсчета тегов)

  const DetailPage({
    super.key,
    required this.post,
    required this.currentUser,
    this.initialMediaIndex = 0,
    this.allPosts = const [],
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final PageController _pageController;
  int _currentMediaIndex = 0; // Текущий индекс в карусели

  bool _showFloating = false; // Видимость плавающего окна
  dynamic _floatingMedia; // Зафиксированный медиафайл в плавающем окне

  final TextEditingController _commentCtrl = TextEditingController();
  final List<Map<String, dynamic>> _comments = []; // Все комментарии поста

  @override
  void initState() {
    super.initState();
    _currentMediaIndex = widget.initialMediaIndex;
    _pageController = PageController(initialPage: widget.initialMediaIndex);
    _loadComments();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // Загрузка комментариев
  Future<void> _loadComments() async {
    final postId = widget.post['id'].toString();
    final data = await fetchComments(postId);
    if (mounted) {
      setState(() {
        _comments.clear();
        for (var c in data) {
          if (c is Map) _comments.add(Map<String, dynamic>.from(c));
        }
      });
    }
  }

  // 1. Отправка основного комментария
  Future<void> _sendMainComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Комментарий не может быть пустым')),
      );
      return;
    }

    final author = widget.currentUser['nickname'] ?? widget.currentUser['username'] ?? 'User';
    final newComment = await sendComment(
      postId: widget.post['id'].toString(),
      author: author,
      text: text,
      parentId: null, // Основной комментарий без родителя
    );

    if (newComment != null && mounted) {
      _commentCtrl.clear();
      setState(() => _comments.add(newComment));
    }
  }

  // 2. Отправка ответа на комментарий через диалог (п. 10 задания)
  void _openReplyDialog(Map<String, dynamic> parentComment) {
    final replyCtrl = TextEditingController();
    final parentAuthor = parentComment['author'] ?? 'User';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Ответ пользователю $parentAuthor'),
          content: TextField(
            controller: replyCtrl,
            decoration: const InputDecoration(hintText: 'Введите ответ...'),
          ),
          actions: [
            // Кнопка «Нет»: закрыть диалог
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Нет'),
            ),
            // Кнопка «Да»: отправить ответ
            TextButton(
              onPressed: () async {
                final text = replyCtrl.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ответ не может быть пустым')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                final author = widget.currentUser['nickname'] ?? widget.currentUser['username'] ?? 'User';
                final newReply = await sendComment(
                  postId: widget.post['id'].toString(),
                  author: author,
                  text: text,
                  parentId: parentComment['id'].toString(), // ID родительского комментария
                );

                if (newReply != null && mounted) {
                  setState(() => _comments.add(newReply));
                }
              },
              child: const Text('Да'),
            ),
          ],
        );
      },
    );
  }

  // Извлечение 3 высокочастотных слов из описания (п. 4 задания)
  List<String> _extractTopTags(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3) // отсекаем короткие слова
        .toList();

    final counts = <String, int>{};
    for (var w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
    }

    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return sorted.take(3).toList();
  }

  // Нажатие на тег: диалог со списком заголовков и числом вхождений (п. 5 задания)
  void _onTagClick(String tag) {
    final lowerTag = tag.toLowerCase();
    final matchedTitles = <String>[];

    for (var p in widget.allPosts) {
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final title = (p['title'] ?? '').toString();
      if (desc.contains(lowerTag)) {
        matchedTitles.add(title);
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Тег: #$tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Всего вхождений: ${matchedTitles.length}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Публикации с этим тегом:'),
            const SizedBox(height: 4),
            ...matchedTitles.map((t) => Text('• $t')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  // Переключение плавающего окна (п. 6 и 7 задания):
  // При открытии окно фиксирует текущее медиа и не обновляется при свайпе карусели!
  void _toggleFloating(List media) {
    setState(() {
      _showFloating = !_showFloating;
      if (_showFloating && media.isNotEmpty) {
        _floatingMedia = media[_currentMediaIndex];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final author = (widget.post['author'] ?? 'User').toString();
    final title = (widget.post['title'] ?? '').toString();
    final subtitle = (widget.post['subtitle'] ?? '').toString();
    final description = (widget.post['description'] ?? '').toString();
    final publishTime = (widget.post['publishTime'] ?? '').toString();
    final media = (widget.post['media'] as List?) ?? [];
    final tags = _extractTopTags(description);

    // Группируем комментарии: основные (parentId == null) и ответы к ним
    final mainComments = _comments.where((c) => c['parentId'] == null).toList();
    final replyMap = <String, List<Map<String, dynamic>>>{};
    for (var c in _comments) {
      if (c['parentId'] != null) {
        final pId = c['parentId'].toString();
        replyMap.putIfAbsent(pId, () => []).add(c);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Основное прокручиваемое содержимое
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Верхняя панель: кнопка Назад, аватар и никнейм автора
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey.shade300,
                          child: const Icon(Icons.person, color: Colors.black54),
                        ),
                        const SizedBox(width: 8),
                        Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),

                  // 2. Область медиаконтента со свайпом (PageView)
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: media.isEmpty
                        ? Container(color: Colors.black12, child: const Center(child: Text('Нет медиа')))
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: media.length,
                            onPageChanged: (i) => setState(() => _currentMediaIndex = i),
                            itemBuilder: (_, i) => _buildMediaSlide(media[i]),
                          ),
                  ),

                  // 3. Блок информации: теги, заголовок, плавающее окно, описание
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Теги (3 самых частых слова)
                        Wrap(
                          spacing: 8,
                          children: tags.map((t) {
                            return ActionChip(
                              label: Text('#$t'),
                              backgroundColor: Colors.grey.shade200,
                              onPressed: () => _onTagClick(t),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),

                        // Заголовок и кнопка "Floating window"
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () => _toggleFloating(media),
                              child: const Text('Floating window', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        ],
                        const SizedBox(height: 8),
                        Text(description, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 12),
                        Text(publishTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),

                        const Divider(height: 28),

                        // 4. Секция комментариев
                        // Точный подсчет общего количества (п. 8)
                        Text(
                          '${_comments.length} comments',
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Поле ввода и кнопка "Send"
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Would you like to leave a comment?',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _sendMainComment,
                              child: const Text('Send'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Список комментариев с вложенными ответами
                        ...mainComments.map((comment) {
                          final cId = comment['id'].toString();
                          final replies = replyMap[cId] ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Основной комментарий (без отступа)
                              _buildCommentTile(comment, isReply: false),

                              // Ответы на него (с отступом 32px)
                              ...replies.map((reply) => _buildCommentTile(
                                    reply,
                                    isReply: true,
                                    replyTo: comment['author'] ?? 'User',
                                  )),
                              const SizedBox(height: 8),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 5. Плавающее окно в правом нижнем углу (п. 6 и 7)
            if (_showFloating && _floatingMedia != null)
              Positioned(
                right: 16,
                bottom: 20,
                child: Container(
                  width: 140,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          _floatingMedia['type'] == 'video' ? 'Video' : 'Image',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _showFloating = false),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Отрисовка медиа слайда в основном PageView
  Widget _buildMediaSlide(dynamic item) {
    final isVideo = item is Map && item['type'] == 'video';
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            isVideo ? 'Video' : 'Image',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (isVideo)
            const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
        ],
      ),
    );
  }

  // Отрисовка одного комментария / ответа
  Widget _buildCommentTile(Map<String, dynamic> c, {required bool isReply, String? replyTo}) {
    return GestureDetector(
      onTap: () => _openReplyDialog(c), // Нажатие открывает диалог ответа
      child: Container(
        margin: EdgeInsets.only(left: isReply ? 32.0 : 0.0, bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isReply ? Colors.grey.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 14, color: Colors.black54),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c['author'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (isReply && replyTo != null) ...[
                        const SizedBox(width: 4),
                        Text('Reply @$replyTo',
                            style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(c['text'] ?? '', style: const TextStyle(fontSize: 14)),
                  if (c['publishTime'] != null)
                    Text(c['publishTime'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
