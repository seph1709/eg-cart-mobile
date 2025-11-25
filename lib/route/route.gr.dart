// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i13;
import 'package:egcart_mobile/models/product_model.dart' as _i15;
import 'package:egcart_mobile/views/about_view.dart' as _i1;
import 'package:egcart_mobile/views/camera_view.dart' as _i2;
import 'package:egcart_mobile/views/cart_view.dart' as _i3;
import 'package:egcart_mobile/views/category_view.dart' as _i4;
import 'package:egcart_mobile/views/edit_name_view.dart' as _i5;
import 'package:egcart_mobile/views/home_view.dart' as _i6;
import 'package:egcart_mobile/views/map_view.dart' as _i7;
import 'package:egcart_mobile/views/ordered_history_view.dart' as _i8;
import 'package:egcart_mobile/views/product_details_view.dart' as _i9;
import 'package:egcart_mobile/views/profile_view.dart' as _i10;
import 'package:egcart_mobile/views/Scan_view.dart' as _i11;
import 'package:egcart_mobile/views/search_view.dart' as _i12;
import 'package:flutter/material.dart' as _i14;

/// generated route for
/// [_i1.AboutView]
class AboutView extends _i13.PageRouteInfo<void> {
  const AboutView({List<_i13.PageRouteInfo>? children})
    : super(AboutView.name, initialChildren: children);

  static const String name = 'AboutView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutView();
    },
  );
}

/// generated route for
/// [_i2.CameraView]
class CameraView extends _i13.PageRouteInfo<void> {
  const CameraView({List<_i13.PageRouteInfo>? children})
    : super(CameraView.name, initialChildren: children);

  static const String name = 'CameraView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i2.CameraView();
    },
  );
}

/// generated route for
/// [_i3.CartView]
class CartView extends _i13.PageRouteInfo<void> {
  const CartView({List<_i13.PageRouteInfo>? children})
    : super(CartView.name, initialChildren: children);

  static const String name = 'CartView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i3.CartView();
    },
  );
}

/// generated route for
/// [_i4.CategoryView]
class CategoryView extends _i13.PageRouteInfo<CategoryViewArgs> {
  CategoryView({
    _i14.Key? key,
    required String categoryName,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         CategoryView.name,
         args: CategoryViewArgs(key: key, categoryName: categoryName),
         initialChildren: children,
       );

  static const String name = 'CategoryView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CategoryViewArgs>();
      return _i4.CategoryView(key: args.key, categoryName: args.categoryName);
    },
  );
}

class CategoryViewArgs {
  const CategoryViewArgs({this.key, required this.categoryName});

  final _i14.Key? key;

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
class EditNameView extends _i13.PageRouteInfo<void> {
  const EditNameView({List<_i13.PageRouteInfo>? children})
    : super(EditNameView.name, initialChildren: children);

  static const String name = 'EditNameView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i5.EditNameView();
    },
  );
}

/// generated route for
/// [_i6.HomeView]
class HomeView extends _i13.PageRouteInfo<void> {
  const HomeView({List<_i13.PageRouteInfo>? children})
    : super(HomeView.name, initialChildren: children);

  static const String name = 'HomeView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i6.HomeView();
    },
  );
}

/// generated route for
/// [_i7.MapView]
class MapView extends _i13.PageRouteInfo<void> {
  const MapView({List<_i13.PageRouteInfo>? children})
    : super(MapView.name, initialChildren: children);

  static const String name = 'MapView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i7.MapView();
    },
  );
}

/// generated route for
/// [_i8.OrderedHistoryView]
class OrderedHistoryView extends _i13.PageRouteInfo<void> {
  const OrderedHistoryView({List<_i13.PageRouteInfo>? children})
    : super(OrderedHistoryView.name, initialChildren: children);

  static const String name = 'OrderedHistoryView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i8.OrderedHistoryView();
    },
  );
}

/// generated route for
/// [_i9.ProductDetailsView]
class ProductDetailsView extends _i13.PageRouteInfo<ProductDetailsViewArgs> {
  ProductDetailsView({
    _i14.Key? key,
    required _i15.Product selectedProduct,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         ProductDetailsView.name,
         args: ProductDetailsViewArgs(
           key: key,
           selectedProduct: selectedProduct,
         ),
         initialChildren: children,
       );

  static const String name = 'ProductDetailsView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProductDetailsViewArgs>();
      return _i9.ProductDetailsView(
        key: args.key,
        selectedProduct: args.selectedProduct,
      );
    },
  );
}

class ProductDetailsViewArgs {
  const ProductDetailsViewArgs({this.key, required this.selectedProduct});

  final _i14.Key? key;

  final _i15.Product selectedProduct;

  @override
  String toString() {
    return 'ProductDetailsViewArgs{key: $key, selectedProduct: $selectedProduct}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProductDetailsViewArgs) return false;
    return key == other.key && selectedProduct == other.selectedProduct;
  }

  @override
  int get hashCode => key.hashCode ^ selectedProduct.hashCode;
}

/// generated route for
/// [_i10.ProfileView]
class ProfileView extends _i13.PageRouteInfo<void> {
  const ProfileView({List<_i13.PageRouteInfo>? children})
    : super(ProfileView.name, initialChildren: children);

  static const String name = 'ProfileView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i10.ProfileView();
    },
  );
}

/// generated route for
/// [_i11.ScanView]
class ScanView extends _i13.PageRouteInfo<void> {
  const ScanView({List<_i13.PageRouteInfo>? children})
    : super(ScanView.name, initialChildren: children);

  static const String name = 'ScanView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i11.ScanView();
    },
  );
}

/// generated route for
/// [_i12.SearchView]
class SearchView extends _i13.PageRouteInfo<void> {
  const SearchView({List<_i13.PageRouteInfo>? children})
    : super(SearchView.name, initialChildren: children);

  static const String name = 'SearchView';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i12.SearchView();
    },
  );
}
