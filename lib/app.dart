import 'package:flutter/material.dart';

import 'features/recorder/recorder_screen.dart';

class MikroApp extends StatelessWidget {
  const MikroApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mikro',
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: [
          const RecorderScreen(),
          const Center(child: Text('Biblioteka — Task 11')),
          const Center(child: Text('Ustawienia — Task 13')),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mic), label: 'Nagrywaj'),
            NavigationDestination(icon: Icon(Icons.library_music), label: 'Biblioteka'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Ustawienia'),
          ],
        ),
      );
}
