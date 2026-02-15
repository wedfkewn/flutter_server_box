import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/container/container.dart';
import 'package:server_box/view/page/server/detail/dashboard.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/widget/floating_bottom_nav.dart';

class ServerDetailPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const ServerDetailPage({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<ServerDetailPage> createState() => _ServerDetailPageState();

  static const route =
      AppRouteArg(page: ServerDetailPage.new, path: '/server/detail');
}

class _ServerDetailPageState extends ConsumerState<ServerDetailPage> {
  int _currentIndex = 0;
  late final _pageController = PageController(initialPage: _currentIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We want the floating nav bar to be at the bottom, and the pages to
    // have enough padding at the bottom so that their content (or their own
    // bottom bars) are not covered by the floating nav bar.
    // The floating nav bar is approx 80 height (64 container + 16 padding).
    // We add some extra buffer.
    const bottomNavPadding = 80.0;

    return Scaffold(
      // Prevent the scaffold from resizing when keyboard opens.
      // This allows the SSHPage to handle keyboard via viewInsets without
      // the whole layout jumping around, and keeps the floating nav bar
      // at the bottom (behind the keyboard).
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Bottom layer: The pages
          Positioned.fill(
            child: Builder(
              builder: (context) {
                // We modify the MediaQuery to inform children that there is a
                // "system" padding at the bottom (our floating nav bar).
                // This ensures SafeAreas in children (like SftpPage's bottom bar)
                // push their content up effectively.
                final mediaQuery = MediaQuery.of(context);
                final newPadding = mediaQuery.padding.copyWith(
                  bottom: mediaQuery.padding.bottom + bottomNavPadding,
                );
                // Also update viewPadding for consistency
                final newViewPadding = mediaQuery.viewPadding.copyWith(
                  bottom: mediaQuery.viewPadding.bottom + bottomNavPadding,
                );

                return MediaQuery(
                  data: mediaQuery.copyWith(
                    padding: newPadding,
                    viewPadding: newViewPadding,
                  ),
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    physics: const NeverScrollableScrollPhysics(), // Disable swipe to avoid conflict with horizontal scroll in terminal/sftp
                    children: [
                      ServerDashboard(args: widget.args),
                      SftpPage(args: SftpPageArgs(spi: widget.args.spi)),
                      ContainerPage(args: widget.args),
                      const SnippetListPage(),
                    ],
                  ),
                );
              },
            ),
          ),
          // Top layer: Floating Nav Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                _pageController.jumpToPage(index);
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
