import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'category_editor_page.dart';

const _tabs = [TxType.expense, TxType.income];

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: _tabs.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [for (final t in _tabs) Tab(text: txTypeLabel(t))],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            openCategoryEditor(context, type: _tabs[_tabController.index]),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [for (final t in _tabs) _CategoryList(t)],
        ),
      ),
    );
  }
}

/// Membuka editor dan menampilkan pesan hasilnya (bila ada) di halaman ini.
Future<void> openCategoryEditor(
  BuildContext context, {
  required TxType type,
  Category? category,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => CategoryEditorPage(type: type, category: category),
    ),
  );
  if (message != null) notify(messenger, message);
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList(this.type);

  final TxType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider(type));
    return AsyncBody<List<Category>>(
      value: categories,
      builder: (list) {
        final active = list.where((c) => !c.archived).toList();
        final archived = list.where((c) => c.archived).toList();
        // Sub-kategori (satu tingkat) dikelompokkan langsung di bawah induknya.
        final topLevel = active.where((c) => c.parentId == null);
        final childrenOf = <String, List<Category>>{};
        for (final c in active) {
          if (c.parentId != null) {
            childrenOf.putIfAbsent(c.parentId!, () => []).add(c);
          }
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final c in topLevel) ...[
              _CategoryTile(c),
              for (final child in childrenOf[c.id] ?? const [])
                _CategoryTile(child, indented: true),
            ],
            if (archived.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                child: Text(
                  'Diarsipkan',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              for (final c in archived) _CategoryTile(c),
            ],
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.category, {this.indented = false});

  final Category category;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return Opacity(
      opacity: c.archived ? 0.55 : 1,
      child: Padding(
        padding: EdgeInsets.only(left: indented ? 28 : 0),
        child: GlassCard(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: ListTile(
            onTap: () => openCategoryEditor(context, type: c.type, category: c),
            leading: CategoryBadge(
              icon: categoryIcon(c.icon),
              color: Color(c.color),
              size: indented ? 36 : 44,
            ),
            title: Text(c.name),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ),
    );
  }
}
