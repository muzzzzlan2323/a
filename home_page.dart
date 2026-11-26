import 'package:flutter/material.dart';
import 'api.dart';
import 'create_post_page.dart';
import 'detail_page.dart';
import 'my_page.dart';

/// Главная страница с вкладками Explore и Following (Модуль A1 - Пункты 2 и 3)
class HomePage extends StatefulWidget {
  final Map<String, dynamic> currentUser; // Авторизованный пользователь
  const HomePage({super.key, required this.currentUser});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoose = false; // Режим отображения: false = Default (2 колонки), true = Loose (1 колонка)
  final List<Map<String, dynamic>> _posts = []; // Все публикации
  final Map<String, String> _followMap = {}; // Карта подписок: followingId -> recordId
  final Map<String, Map<String, dynamic>> _usersMap = {}; // userId -> объект пользователя

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Загрузка постов и подписок с сервера
  Future<void> _loadData() async {
    final myId = widget.currentUser['id'].toString();

    // 1. Загружаем пользователей и собираем все посты
    final users = await fetchUsers();
    final List<Map<String, dynamic>> allPosts = [];
    _usersMap.clear();

    for (var u in users) {
      if (u is! Map<String, dynamic>) continue;
      final uid = u['id'].toString();
      _usersMap[uid] = u;

      final authorName = (u['nickname'] ?? u['username'] ?? 'User').toString();
      final authorAvatar = (u['avatar'] ?? '').toString();
      final discoveries = (u['discoveries'] as List?) ?? [];

      for (var d in discoveries) {
        if (d is Map) {
          final post = Map<String, dynamic>.from(d);
          post['authorId'] = uid;
          post['author'] = authorName;
          post['avatar'] = authorAvatar;
          allPosts.add(post);
        }
      }
    }

    // 2. Загружаем подписки текущего пользователя
    final follows = await fetchFollows();
    _followMap.clear();
    for (var f in follows) {
      if (f is Map && f['userId'].toString() == myId) {
        _followMap[f['followingId'].toString()] = f['id'].toString();
      }
    }

    if (mounted) {
      setState(() {
        _posts
          ..clear()
          ..addAll(allPosts);
      });
    }
  }

  // Переключение подписки / отписки (Follow / Following)
  Future<void> _toggleFollow(String targetUserId) async {
    final myId = widget.currentUser['id'].toString();

    if (_followMap.containsKey(targetUserId)) {
      // Отписываемся: удаляем запись на сервере
      final recordId = _followMap[targetUserId]!;
      final ok = await unfollowUser(recordId);
      if (ok && mounted) {
        setState(() => _followMap.remove(targetUserId));
      }
    } else {
      // Подписываемся: создаем запись
      final createdId = await followUser(myId, targetUserId);
      if (createdId != null && mounted) {
        setState(() => _followMap[targetUserId] = createdId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Две вкладки: Explore и Following
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Colors.white,
          elevation: 0,
          // Верхняя панель навигации (п. 2 общих требований)
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            unselectedLabelStyle: TextStyle(fontSize: 16),
            indicatorColor: Colors.black,
            indicatorWeight: 2,
            tabs: [
              Tab(text: 'Explore'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildExploreTab(),
            _buildFollowingTab(),
          ],
        ),
        // Нижняя панель навигации (п. 3 общих требований)
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 0,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) async {
            if (index == 1) {
              // Нажатие на "+" -> переход на страницу добавления
              final newPost = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostPage(currentUser: widget.currentUser),
                ),
              );

              // Если был опубликован новый пост -> он отображается ПЕРВЫМ в списке
              if (newPost != null) {
                setState(() => _posts.insert(0, newPost));
              }
            } else if (index == 2) {
              // Нажатие на "My" -> переход в профиль
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyPage(currentUser: widget.currentUser),
                ),
              );
              _loadData(); // обновляем данные после возвращения из профиля
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline, size: 28),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'My',
            ),
          ],
        ),
      ),
    );
  }

  // --- ВКЛАДКА 1: EXPLORE (ОБЗОР) ---
  Widget _buildExploreTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Кнопки переключения режима: Default (2 колонки) / Loose (1 колонка)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _modeBtn('Default', !_isLoose, () => setState(() => _isLoose = false)),
              const SizedBox(width: 8),
              _modeBtn('Loose', _isLoose, () => setState(() => _isLoose = true)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoose
                ? ListView.separated(
                    itemCount: _posts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (_, i) => _buildLooseCard(_posts[i]),
                  )
                : GridView.builder(
                    itemCount: _posts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // По умолчанию 2 колонки
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (_, i) => _buildDefaultCard(_posts[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _modeBtn(String text, bool active, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.grey.shade400 : Colors.grey.shade200,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: onTap,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  // Карточка для 2-колоночного режима (Default)
  Widget _buildDefaultCard(Map<String, dynamic> post) {
    final media = (post['media'] as List?) ?? [];
    final authorId = post['authorId'].toString();
    final myId = widget.currentUser['id'].toString();
    final isFollowing = _followMap.containsKey(authorId);

    return GestureDetector(
      onTap: () => _openDetail(post, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Превью первого медиафайла
          Expanded(
            child: media.isNotEmpty
                ? _mediaBox(media[0], onTap: () => _openDetail(post, 0))
                : Container(color: Colors.grey.shade300),
          ),
          const SizedBox(height: 6),
          // Заголовок
          Text(
            post['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          // Аватар, имя автора и кнопка подписки
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 14, color: Colors.black54),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  post['author'] ?? 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (authorId != myId) _followBtn(authorId, isFollowing),
            ],
          ),
        ],
      ),
    );
  }

  // Карточка для 1-колоночного режима (Loose)
  Widget _buildLooseCard(Map<String, dynamic> post) {
    final media = (post['media'] as List?) ?? [];
    final authorId = post['authorId'].toString();
    final myId = widget.currentUser['id'].toString();
    final isFollowing = _followMap.containsKey(authorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Шапка поста: аватар и имя
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 16, color: Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(post['author'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),

        // Область медиа с правилами раскладки (п. 8 задания)
        SizedBox(
          height: 200,
          child: _buildLooseMediaGrid(post, media),
        ),
        const SizedBox(height: 8),

        // Заголовок и кнопка подписки под медиа
        Row(
          children: [
            Expanded(
              child: Text(
                post['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (authorId != myId) _followBtn(authorId, isFollowing),
          ],
        ),
      ],
    );
  }

  // Реализация правил раскладки медиафайлов для Loose режима:
  // (a) 1 медиа — на всю область
  // (b) 2 медиа — бок о бок (2 колонки)
  // (c) 3 медиа — левое на всю высоту, справа 2 вертикально
  // (d) 4 медиа — сетка 2x2
  // (e) >4 медиа — сетка 2x2, а на 4-м элементе надпись "+N"
  Widget _buildLooseMediaGrid(Map<String, dynamic> post, List media) {
    if (media.isEmpty) return Container(color: Colors.grey.shade300);

    if (media.length == 1) {
      return _mediaBox(media[0], onTap: () => _openDetail(post, 0));
    }

    if (media.length == 2) {
      return Row(
        children: [
          Expanded(child: _mediaBox(media[0], onTap: () => _openDetail(post, 0))),
          const SizedBox(width: 4),
          Expanded(child: _mediaBox(media[1], onTap: () => _openDetail(post, 1))),
        ],
      );
    }

    if (media.length == 3) {
      return Row(
        children: [
          Expanded(child: _mediaBox(media[0], onTap: () => _openDetail(post, 0))),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _mediaBox(media[1], onTap: () => _openDetail(post, 1))),
                const SizedBox(height: 4),
                Expanded(child: _mediaBox(media[2], onTap: () => _openDetail(post, 2))),
              ],
            ),
          ),
        ],
      );
    }

    // 4 и более медиа: сетка 2х2 с бейджем "+N"
    final extra = media.length - 4;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _mediaBox(media[0], onTap: () => _openDetail(post, 0))),
              const SizedBox(width: 4),
              Expanded(child: _mediaBox(media[1], onTap: () => _openDetail(post, 1))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _mediaBox(media[2], onTap: () => _openDetail(post, 2))),
              const SizedBox(width: 4),
              Expanded(
                child: _mediaBox(
                  media[3],
                  badge: extra > 0 ? '+$extra' : null,
                  onTap: () => _openDetail(post, 3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- ВКЛАДКА 2: FOLLOWING (ПОДПИСКИ) ---
  Widget _buildFollowingTab() {
    final followedUserIds = _followMap.keys.toList();
    // Фильтруем посты только тех авторов, на которых подписаны
    final followingPosts = _posts
        .where((p) => _followMap.containsKey(p['authorId'].toString()))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Горизонтальный список аватаров и никнеймов подписанных авторов
          SizedBox(
            height: 80,
            child: followedUserIds.isEmpty
                ? const Center(child: Text('Нет подписок', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: followedUserIds.length,
                    itemBuilder: (_, i) {
                      final uid = followedUserIds[i];
                      final user = _usersMap[uid];
                      final name = user?['nickname'] ?? user?['username'] ?? 'User';

                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey.shade300,
                              child: const Icon(Icons.person, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(name, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),

          // Сетка постов подписанных пользователей (2 колонки)
          Expanded(
            child: GridView.builder(
              itemCount: followingPosts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (_, i) => _buildDefaultCard(followingPosts[i]),
            ),
          ),
        ],
      ),
    );
  }

  // Плитка отображения медиа (Image или Video со значком Play)
  Widget _mediaBox(dynamic item, {String? badge, VoidCallback? onTap}) {
    final isVideo = item is Map && item['type'] == 'video';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.grey.shade300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                isVideo ? 'Video' : 'Image',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ),
            // Значок Play для видеофайлов (п. 4(b) общих требований)
            if (isVideo)
              const Positioned(
                right: 8,
                bottom: 8,
                child: Icon(Icons.play_circle_outline, color: Colors.black87, size: 24),
              ),
            // Затемнение с надписью "+N" для лишних фото (п. 8(e))
            if (badge != null)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Кнопка Follow / Following
  Widget _followBtn(String authorId, bool isFollowing) {
    return GestureDetector(
      onTap: () => _toggleFollow(authorId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  // Открытие страницы сведений с передачей индекса выбранного медиа
  void _openDetail(Map<String, dynamic> post, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(
          post: post,
          currentUser: widget.currentUser,
          initialMediaIndex: initialIndex,
          allPosts: _posts, // передаем список всех постов для поиска совпадений по тегам
        ),
      ),
    );
  }
}
