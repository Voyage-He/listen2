import 'package:flutter/material.dart';

class AppStyle {
  static const background = Color(0xFFF1EFE7);
  static const accent = Color(0xFF657052);
  static const ink = Color(0xFF262923);
  static const muted = Color(0xFF7E8475);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
        textTheme: const TextTheme(
          headlineMedium:
              TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink),
          titleLarge:
              TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
          titleMedium:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
          bodyLarge: TextStyle(fontSize: 16, color: ink),
          bodyMedium: TextStyle(fontSize: 14, color: muted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
        ),
      );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
        child: Row(children: [
          IconButton(
              tooltip: '返回',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          if (action != null) action!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: AppStyle.accent),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}
