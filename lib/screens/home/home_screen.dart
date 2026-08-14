import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../chat/chat_list_screen.dart';
import '../favorites/favorites_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import 'home_tab.dart';

/// Coque de navigation principale.
///
/// Les onglets sont conservés dans un [IndexedStack] pour que revenir sur la
/// carte ne relance pas le chargement des marqueurs ni ne perde la position de
/// défilement de la liste.
class HomeScreen extends StatefulWidget {
  final int initialTab;

  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex = widget.initialTab.clamp(0, 4);

  final List<Widget> _screens = const [
    HomeTab(),
    MapScreen(),
    FavoritesScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Carte',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favoris',
          ),
          BottomNavigationBarItem(
            icon: _MessagesIcon(
              uid: auth.uid,
              icon: Icons.chat_bubble_outline,
            ),
            activeIcon: _MessagesIcon(
              uid: auth.uid,
              icon: Icons.chat_bubble,
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// Icône « Messages » surmontée du nombre de conversations non lues.
///
/// Le compteur n'est branché que pour un utilisateur connecté : en mode
/// visiteur, il n'y a pas de conversation et la requête échouerait sur les
/// règles de sécurité.
class _MessagesIcon extends StatelessWidget {
  final String? uid;
  final IconData icon;

  const _MessagesIcon({required this.uid, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (uid == null) return Icon(icon);

    return StreamBuilder<int>(
      stream: ChatService.instance.watchUnreadTotal(uid!),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return Icon(icon);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon),
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 17),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
