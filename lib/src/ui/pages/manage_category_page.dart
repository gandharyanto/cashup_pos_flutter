import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pos_repository.dart';
import '../../models/pos_category.dart';
import '../../state/pos_providers.dart';
import '../widgets/async_view.dart';
import '../widgets/pos_scaffold.dart';

final managedCategoriesProvider = FutureProvider<List<PosCategory>>(
  (ref) async =>
      (await ref.watch(posRepositoryProvider).categoryList(size: 100000)).items,
);

String? validateCategoryName(String? value) =>
    value?.trim().isEmpty ?? true ? 'Nama kategori wajib diisi' : null;

class ManageCategoryPage extends ConsumerWidget {
  const ManageCategoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PosScaffold(
    title: 'Manajemen kategori',
    actions: [
      IconButton(
        tooltip: 'Tambah kategori',
        icon: const Icon(Icons.add),
        onPressed: () => _edit(context, ref),
      ),
    ],
    body: AsyncView<List<PosCategory>>(
      value: ref.watch(managedCategoriesProvider),
      onRetry: () => ref.invalidate(managedCategoriesProvider),
      data: (categories) => RefreshIndicator(
        onRefresh: () => ref.refresh(managedCategoriesProvider.future),
        child: ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              title: Text(category.name),
              subtitle: category.description?.isNotEmpty == true
                  ? Text(category.description!)
                  : null,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageCategoryDetailPage(category: category),
                ),
              ).then((_) => ref.invalidate(managedCategoriesProvider)),
            );
          },
        ),
      ),
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    PosCategory? category,
  ]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CategoryEditorPage(category: category)),
    );
    if (saved == true) ref.invalidate(managedCategoriesProvider);
  }
}

class ManageCategoryDetailPage extends ConsumerWidget {
  const ManageCategoryDetailPage({super.key, required this.category});

  final PosCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PosScaffold(
    title: 'Detail kategori',
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(category.name, style: Theme.of(context).textTheme.headlineSmall),
        if (category.description?.isNotEmpty == true)
          Text(category.description!),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () async {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryEditorPage(category: category),
              ),
            );
            if (saved == true && context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.edit),
          label: const Text('Edit kategori'),
        ),
        OutlinedButton.icon(
          onPressed: () => _delete(context, ref),
          icon: const Icon(Icons.delete),
          label: const Text('Hapus kategori'),
        ),
      ],
    ),
  );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text('Kategori “${category.name}” akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(posRepositoryProvider).categoryDelete(category.id);
      ref.invalidate(managedCategoriesProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      // PosException.toString preserves the backend's message, including the
      // category-in-use explanation.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class CategoryEditorPage extends ConsumerStatefulWidget {
  const CategoryEditorPage({super.key, this.category});

  final PosCategory? category;

  @override
  ConsumerState<CategoryEditorPage> createState() => _CategoryEditorPageState();
}

class _CategoryEditorPageState extends ConsumerState<CategoryEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name);
    _description = TextEditingController(text: widget.category?.description);
    _image = TextEditingController(text: widget.category?.imageUrl);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PosScaffold(
    title: widget.category == null ? 'Tambah kategori' : 'Edit kategori',
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            validator: validateCategoryName,
            decoration: const InputDecoration(labelText: 'Nama kategori'),
          ),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
            maxLines: 3,
          ),
          TextFormField(
            controller: _image,
            decoration: const InputDecoration(labelText: 'URL gambar'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final draft = PosCategoryDraft(
      name: _name.text.trim(),
      description: _description.text.trim(),
      image: _image.text.trim(),
    );
    try {
      final category = widget.category;
      final repository = ref.read(posRepositoryProvider);
      if (category == null) {
        await repository.categoryCreate(draft);
      } else {
        await repository.categoryUpdate(category.id, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _saving = false);
    }
  }
}
