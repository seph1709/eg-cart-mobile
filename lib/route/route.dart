import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/route/route.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => RouteType.material();

  @override
  List<AutoRoute> get routes => [
    /// routes go here
    ///
    CustomRoute(
      page: CartView.page,
      transitionsBuilder: TransitionsBuilders.noTransition,
    ),
    CustomRoute(
      page: ProfileView.page,
      transitionsBuilder: TransitionsBuilders.noTransition,
    ),
    CustomRoute(
      page: HomeView.page,
      initial: false,
      transitionsBuilder: TransitionsBuilders.noTransition,
    ),
    CustomRoute(
      page: ScanView.page,
      initial: true,
      transitionsBuilder: TransitionsBuilders.noTransition,
    ),
    CustomRoute(
      page: MapView.page,
      initial: false,
      transitionsBuilder: TransitionsBuilders.noTransition,
    ),
    AutoRoute(page: SearchView.page),
    AutoRoute(page: HistoryView.page),
    AutoRoute(page: ProductDetailsView.page),
    AutoRoute(page: CategoryView.page),
    AutoRoute(page: EditNameView.page),
    AutoRoute(page: AboutView.page),
    AutoRoute(page: OrderedHistoryView.page),
    AutoRoute(page: CameraView.page),
  ];
  @override
  List<AutoRouteGuard> get guards => [
    // optionally add root guards here
  ];
}
