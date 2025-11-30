// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i14;
import 'package:egcart_mobile/models/product_model.dart' as _i16;
import 'package:egcart_mobile/views/about_view.dart' as _i1;
import 'package:egcart_mobile/views/camera_view.dart' as _i2;
import 'package:egcart_mobile/views/cart_view.dart' as _i3;
import 'package:egcart_mobile/views/category_view.dart' as _i4;
import 'package:egcart_mobile/views/edit_name_view.dart' as _i5;
import 'package:egcart_mobile/views/history_view.dart' as _i6;
import 'package:egcart_mobile/views/home_view.dart' as _i7;
import 'package:egcart_mobile/views/map_view.dart' as _i8;
import 'package:egcart_mobile/views/ordered_history_view.dart' as _i9;
import 'package:egcart_mobile/views/product_details_view.dart' as _i10;
import 'package:egcart_mobile/views/profile_view.dart' as _i11;
import 'package:egcart_mobile/views/scan_view.dart' as _i12;
import 'package:egcart_mobile/views/search_view.dart' as _i13;
import 'package:flutter/material.dart' as _i15;

/// generated route for
/// [_i1.AboutView]
class AboutView extends _i14.PageRouteInfo<void> {
  const AboutView({List<_i14.PageRouteInfo>? children})
    : super(AboutView.name, initialChildren: children);

  static const String name = 'AboutView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutView();
    },
  );
}

/// generated route for
/// [_i2.CameraView]
class CameraView extends _i14.PageRouteInfo<void> {
  const CameraView({List<_i14.PageRouteInfo>? children})
    : super(CameraView.name, initialChildren: children);

  static const String name = 'CameraView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i2.CameraView();
    },
  );
}

/// generated route for
/// [_i3.CartView]
class CartView extends _i14.PageRouteInfo<void> {
  const CartView({List<_i14.PageRouteInfo>? children})
    : super(CartView.name, initialChildren: children);

  static const String name = 'CartView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i3.CartView();
    },
  );
}

/// generated route for
/// [_i4.CategoryView]
class CategoryView extends _i14.PageRouteInfo<CategoryViewArgs> {
  CategoryView({
    _i15.Key? key,
    required String categoryName,
    List<_i14.PageRouteInfo>? children,
  }) : super(
         CategoryView.name,
         args: CategoryViewArgs(key: key, categoryName: categoryName),
         initialChildren: children,
       );

  static const String name = 'CategoryView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CategoryViewArgs>();
      return _i4.CategoryView(key: args.key, categoryName: args.categoryName);
    },
  );
}

class CategoryViewArgs {
  const CategoryViewArgs({this.key, required this.categoryName});

  final _i15.Key? key;

  final String categoryName;

  @override
  String toString() {
    return 'CategoryViewArgs{key: $key, categoryName: $categoryName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CategoryViewArgs) return false;
    return key == other.key && categoryName == other.categoryName;
  }

  @override
  int get hashCode => key.hashCode ^ categoryName.hashCode;
}

/// generated route for
/// [_i5.EditNameView]
class EditNameView extends _i14.PageRouteInfo<void> {
  const EditNameView({List<_i14.PageRouteInfo>? children})
    : super(EditNameView.name, initialChildren: children);

  static const String name = 'EditNameView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i5.EditNameView();
    },
  );
}

/// generated route for
/// [_i6.HistoryView]
class HistoryView extends _i14.PageRouteInfo<void> {
  const HistoryView({List<_i14.PageRouteInfo>? children})
    : super(HistoryView.name, initialChildren: children);

  static const String name = 'HistoryView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i6.HistoryView();
    },
  );
}

/// generated route for
/// [_i7.HomeView]
class HomeView extends _i14.PageRouteInfo<void> {
  const HomeView({List<_i14.PageRouteInfo>? children})
    : super(HomeView.name, initialChildren: children);

  static const String name = 'HomeView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i7.HomeView();
    },
  );
}

/// generated route for
/// [_i8.MapView]
class MapView extends _i14.PageRouteInfo<void> {
  const MapView({List<_i14.PageRouteInfo>? children})
    : super(MapView.name, initialChildren: children);

  static const String name = 'MapView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i8.MapView();
    },
  );
}

/// generated route for
/// [_i9.OrderedHistoryView]
class OrderedHistoryView extends _i14.PageRouteInfo<void> {
  const OrderedHistoryView({List<_i14.PageRouteInfo>? children})
    : super(OrderedHistoryView.name, initialChildren: children);

  static const String name = 'OrderedHistoryView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i9.OrderedHistoryView();
    },
  );
}

/// generated route for
/// [_i10.ProductDetailsView]
class ProductDetailsView extends _i14.PageRouteInfo<ProductDetailsViewArgs> {
  ProductDetailsView({
    _i15.Key? key,
    required _i16.Product selectedProduct,
    bool fromMapView = false,
    List<_i14.PageRouteInfo>? children,
  }) : super(
         ProductDetailsView.name,
         args: ProductDetailsViewArgs(
           key: key,
           selectedProduct: selectedProduct,
           fromMapView: fromMapView,
         ),
         initialChildren: children,
       );

  static const String name = 'ProductDetailsView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProductDetailsViewArgs>();
      return _i10.ProductDetailsView(
        key: args.key,
        selectedProduct: args.selectedProduct,
        fromMapView: args.fromMapView,
      );
    },
  );
}

class ProductDetailsViewArgs {
  const ProductDetailsViewArgs({
    this.key,
    required this.selectedProduct,
    this.fromMapView = false,
  });

  final _i15.Key? key;

  final _i16.Product selectedProduct;

  final bool fromMapView;

  @override
  String toString() {
    return 'ProductDetailsViewArgs{key: $key, selectedProduct: $selectedProduct, fromMapView: $fromMapView}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProductDetailsViewArgs) return false;
    return key == other.key &&
        selectedProduct == other.selectedProduct &&
        fromMapView == other.fromMapView;
  }

  @override
  int get hashCode =>
      key.hashCode ^ selectedProduct.hashCode ^ fromMapView.hashCode;
}

/// generated route for
/// [_i11.ProfileView]
class ProfileView extends _i14.PageRouteInfo<void> {
  const ProfileView({List<_i14.PageRouteInfo>? children})
    : super(ProfileView.name, initialChildren: children);

  static const String name = 'ProfileView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i11.ProfileView();
    },
  );
}

/// generated route for
/// [_i12.ScanView]
class ScanView extends _i14.PageRouteInfo<void> {
  const ScanView({List<_i14.PageRouteInfo>? children})
    : super(ScanView.name, initialChildren: children);

  static const String name = 'ScanView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i12.ScanView();
    },
  );
}

/// generated route for
/// [_i13.SearchView]
class SearchView extends _i14.PageRouteInfo<void> {
  const SearchView({List<_i14.PageRouteInfo>? children})
    : super(SearchView.name, initialChildren: children);

  static const String name = 'SearchView';

  static _i14.PageInfo page = _i14.PageInfo(
    name,
    builder: (data) {
      return const _i13.SearchView();
    },
  );
}
