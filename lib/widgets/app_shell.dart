import 'package:flutter/material.dart';

import '../controllers/sidebar_controller.dart';
import 'app_sidebar.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) {
            return ListenableBuilder(
              listenable: SidebarController.instance,
              builder: (context, _) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isDesktop = screenWidth >= 750;

                if (!isDesktop) {
                  return child;
                }

                final isCollapsed = SidebarController.instance.isCollapsed;

                return Material(
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      AppSidebar(isCollapsed: isCollapsed),
                      Expanded(
                        child: ClipRect(
                          child: child,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
