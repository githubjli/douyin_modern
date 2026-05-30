import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/shop_dao.dart';
import '../../core/network/api_client.dart';
import '../shipping/presentation/address_list_page.dart';
import 'data/mock_shop_repository.dart';
import 'data/remote_shop_repository.dart';
import 'domain/shop_models.dart';
import 'domain/shop_repository.dart';
import 'order_list_page.dart';
import 'product_detail_page.dart';

part 'widgets/shop_top_bar.dart';
part 'widgets/shop_banner.dart';
part 'widgets/shop_filter_chips.dart';
part 'widgets/product_card.dart';
part 'widgets/product_grid.dart';
part 'widgets/shop_state_widgets.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({
    super.key,
    this.useRemote = true,
    this.repository,
  });

  final bool useRemote;
  final ShopRepository? repository;

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  late final ShopRepository _repo;
  final PageController _bannerController = PageController();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  List<ShopBanner> _banners = const <ShopBanner>[];
  List<ShopCategory> _categories = const <ShopCategory>[];
  List<ShopProduct> _products = const <ShopProduct>[];

  int _activeBannerIndex = 0;
  int _selectedCategoryIndex = 0;
  int _page = 1;
  int _totalCount = 0;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        (widget.useRemote
            ? RemoteShopRepository(apiClient: ApiClient())
            : const MockShopRepository());
    _load();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _selectedSlug {
    if (_categories.isEmpty) return null;
    final int index = _selectedCategoryIndex.clamp(0, _categories.length - 1).toInt();
    final String slug = _categories[index].slug;
    return slug == 'all' ? null : slug;
  }

  Future<void> _load() async {
    final ShopDao shopDao = ref.read(shopDaoProvider);

    // Step 1: show SQLite cache instantly (if within TTL).
    final ShopSnapshot? cached = await shopDao.load();
    if (cached != null && mounted) {
      setState(() {
        _banners = cached.banners;
        _categories = cached.categories;
        _products = cached.productPage.items;
        _totalCount = cached.productPage.count;
        _page = cached.productPage.page;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = true);
    }

    List<ShopBanner> banners = const <ShopBanner>[];
    List<ShopCategory> categories = const <ShopCategory>[];
    ShopProductPage productPage = const ShopProductPage(
      items: <ShopProduct>[],
      count: 0,
      page: 1,
      pageSize: 20,
    );

    try {
      final results = await Future.wait(<Future<dynamic>>[
        _repo.getBanners(),
        _repo.getCategories(),
        _repo.getProducts(page: 1, category: _selectedSlug),
      ]);
      banners = results[0] as List<ShopBanner>;
      categories = results[1] as List<ShopCategory>;
      productPage = results[2] as ShopProductPage;
      // Persist fresh data.
      await shopDao.save(ShopSnapshot(
        banners: banners,
        categories: categories,
        productPage: productPage,
      ));
    } catch (_) {
      if (!widget.useRemote) rethrow;
      // Offline: stale cache → in-memory → mock.
      final ShopSnapshot? stale = await shopDao.loadStale();
      if (stale != null) {
        banners = stale.banners;
        categories = stale.categories;
        productPage = stale.productPage;
      } else if (_banners.isNotEmpty || _products.isNotEmpty) {
        banners = _banners;
        categories = _categories;
        productPage = ShopProductPage(
          items: _products,
          count: _totalCount,
          page: _page,
          pageSize: 20,
        );
      } else {
        try {
          const MockShopRepository mock = MockShopRepository();
          final results = await Future.wait(<Future<dynamic>>[
            mock.getBanners(),
            mock.getCategories(),
            mock.getProducts(page: 1),
          ]);
          banners = results[0] as List<ShopBanner>;
          categories = results[1] as List<ShopCategory>;
          productPage = results[2] as ShopProductPage;
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _banners = banners;
      _categories = categories;
      _products = productPage.items;
      _page = 1;
      _totalCount = productPage.count;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    _searchController.clear();
    setState(() {
      _selectedCategoryIndex = 0;
      _page = 1;
    });
    await _load();
  }

  Future<void> _selectCategory(int index) async {
    setState(() {
      _selectedCategoryIndex = index;
      _products = const <ShopProduct>[];
      _page = 1;
      _loading = true;
    });

    try {
      final ShopProductPage page = await _repo.getProducts(
        page: 1,
        category: _selectedSlug,
        query: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _products = page.items;
        _totalCount = page.count;
        _page = 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    setState(() {
      _products = const <ShopProduct>[];
      _page = 1;
      _loading = true;
    });

    try {
      final ShopProductPage page = await _repo.getProducts(
        page: 1,
        category: _selectedSlug,
        query: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _products = page.items;
        _totalCount = page.count;
        _page = 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    await _search();
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final int nextPage = _page + 1;
    setState(() => _loadingMore = true);

    try {
      final ShopProductPage page = await _repo.getProducts(
        page: nextPage,
        category: _selectedSlug,
        query: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _products = <ShopProduct>[..._products, ...page.items];
        _page = nextPage;
        _totalCount = page.count;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool get _hasMore => _page * 20 < _totalCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandGold,
          backgroundColor: AppColors.cardBackground,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              _ShopTopBar(
                searchController: _searchController,
                onSearchSubmitted: _search,
                onSearchCleared: _clearSearch,
                onMenuSelected: (_ShopMenuAction action) {
                  switch (action) {
                    case _ShopMenuAction.orders:
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OrderListPage(repo: _repo),
                        ),
                      );
                    case _ShopMenuAction.addresses:
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AddressListPage(),
                        ),
                      );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...<Widget>[
                if (_banners.isNotEmpty) ...<Widget>[
                  _ShopBannerCarousel(
                    banners: _banners,
                    controller: _bannerController,
                    onPageChanged: (int i) =>
                        setState(() => _activeBannerIndex = i),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _ShopBannerDots(
                    count: _banners.length,
                    activeIndex: _activeBannerIndex,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_categories.isNotEmpty) ...<Widget>[
                  _ShopCategoryChips(
                    categories: _categories,
                    selectedIndex: _selectedCategoryIndex,
                    onSelected: _selectCategory,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_products.isEmpty)
                  const _ShopEmptyCard(message: 'No products found.')
                else
                  _ProductGrid(products: _products),
                if (_hasMore) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _ShopLoadMoreButton(
                    loading: _loadingMore,
                    onPressed: _loadMore,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
