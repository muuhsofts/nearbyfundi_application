import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/portfolio.dart';
import '../../providers/portfolio_provider.dart';
import '../../config/app_theme.dart';
import '../../utils/image_utils.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_routes.dart';

class FundiPortfolioScreen extends StatefulWidget {
  const FundiPortfolioScreen({super.key});

  @override
  State<FundiPortfolioScreen> createState() => _FundiPortfolioScreenState();
}

class _FundiPortfolioScreenState extends State<FundiPortfolioScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortfolioProvider>().loadPortfolio();
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<PortfolioItem> get _filteredItems {
    final items = context.read<PortfolioProvider>().items;
    if (_filterQuery.isEmpty) return items;
    return items.where((item) =>
    (item.description?.toLowerCase().contains(_filterQuery.toLowerCase()) ??
        false)).toList();
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                ImageUtils.getFullImageUrl(imageUrl),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surface,
                  child: Icon(Icons.broken_image, size: 60,
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final filteredItems = _filteredItems;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.portfolio),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showPortfolioForm(context),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.items.isEmpty
          ? _buildEmptyState(context)
          : Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: filteredItems.length,
              itemBuilder: (ctx, i) {
                final item = filteredItems[i];
                return _PortfolioPostCard(
                  item: item,
                  onImageTap: () =>
                      _showImageDialog(context, item.image),
                  onEdit: () =>
                      _showPortfolioForm(context, item: item),
                  onDelete: () => _deleteItem(context, item.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noPortfolio,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showPortfolioForm(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.addPortfolio),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: TextField(
          controller: _filterController,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: l10n.filterByDescription,
            hintStyle: theme.textTheme.bodySmall,
            prefixIcon: Icon(Icons.search_rounded,
                color: theme.colorScheme.primary),
            suffixIcon: _filterQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
              onPressed: () {
                _filterController.clear();
                setState(() => _filterQuery = '');
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          onChanged: (value) => setState(() => _filterQuery = value),
        ),
      ),
    );
  }

  void _showPortfolioForm(BuildContext context, {PortfolioItem? item}) {
    final _formKey = GlobalKey<FormState>();
    final _descController = TextEditingController(text: item?.description ?? '');
    String? _imagePath;
    final picker = ImagePicker();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: theme.colorScheme.surface,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item == null
                                      ? Icons.add_photo_alternate
                                      : Icons.edit_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item == null
                                    ? l10n.addPortfolioItem
                                    : l10n.editPortfolioItem,
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5)),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Image Picker
                      GestureDetector(
                        onTap: () async {
                          final XFile? file = await picker.pickImage(
                              source: ImageSource.gallery);
                          if (file != null) setState(() => _imagePath = file.path);
                        },
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surface,
                          ),
                          child: _imagePath == null && item?.image == null
                              ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 48,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5)),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to select image',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          )
                              : Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_imagePath != null)
                                Image.file(File(_imagePath!),
                                    fit: BoxFit.cover)
                              else if (item?.image != null)
                                Image.network(
                                  ImageUtils.getFullImageUrl(item!.image),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(
                                        color: theme.colorScheme.surface,
                                        child: const Icon(
                                            Icons.broken_image, size: 50),
                                      ),
                                ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius:
                                    BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _descController,
                        maxLines: 5,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: l10n.description,
                          labelStyle: theme.textTheme.bodySmall,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              text: item == null ? l10n.add : l10n.update,
                              onPressed: () async {
                                if (item == null && _imagePath == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please select an image')),
                                  );
                                  return;
                                }

                                final provider =
                                context.read<PortfolioProvider>();
                                bool success;

                                if (item == null) {
                                  success = await provider.addPortfolio({
                                    'image': _imagePath,
                                    'description':
                                    _descController.text.trim(),
                                  });
                                } else {
                                  final data = <String, dynamic>{};
                                  if (_imagePath != null)
                                    data['image'] = _imagePath;
                                  if (_descController.text.trim() !=
                                      (item.description ?? '')) {
                                    data['description'] =
                                        _descController.text.trim();
                                  }
                                  if (data.isEmpty) {
                                    Navigator.pop(dialogContext);
                                    return;
                                  }
                                  success = await provider.updatePortfolio(
                                      item.id, data);
                                }

                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(item == null
                                          ? l10n.itemAdded
                                          : l10n.itemUpdated),
                                      backgroundColor:
                                      theme.colorScheme.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                              isLoading:
                              context.watch<PortfolioProvider>().isLoading,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteItem(BuildContext context, int id) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.deletePortfolioItem,
          style: theme.textTheme.titleMedium,
        ),
        content: Text(l10n.areYouSure, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await context.read<PortfolioProvider>().deletePortfolio(id);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.itemDeleted),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _PortfolioPostCard extends StatefulWidget {
  final PortfolioItem item;
  final VoidCallback onImageTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PortfolioPostCard({
    required this.item,
    required this.onImageTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PortfolioPostCard> createState() => _PortfolioPostCardState();
}

class _PortfolioPostCardState extends State<_PortfolioPostCard> {
  bool _expanded = false;

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7)
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = widget.item.description ?? '';
    final shouldShowReadMore = description.length > 120;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.darkCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.photo_library, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Portfolio Item',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Text(
                        _formatDate(widget.item.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: theme.colorScheme.primary,
                  onPressed: widget.onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppTheme.error,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),

          if (widget.item.image.isNotEmpty)
            GestureDetector(
              onTap: widget.onImageTap,
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.surface,
                child: Image.network(
                  ImageUtils.getFullImageUrl(widget.item.image),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: theme.colorScheme.surface,
                    child: Icon(Icons.broken_image, size: 50,
                        color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: shouldShowReadMore
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  child: Text(
                    description,
                    maxLines: _expanded ? null : 4,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (shouldShowReadMore)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Read less' : 'Read more',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}