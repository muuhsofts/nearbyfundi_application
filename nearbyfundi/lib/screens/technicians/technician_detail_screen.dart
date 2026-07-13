import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/technician_provider.dart';
import '../../providers/request_provider.dart';
import '../../utils/image_utils.dart';
import '../../models/technician.dart';
import '../../l10n/app_localizations.dart';

class TechnicianDetailScreen extends StatefulWidget {
  final int technicianId;
  const TechnicianDetailScreen({super.key, required this.technicianId});

  @override
  State<TechnicianDetailScreen> createState() => _TechnicianDetailScreenState();
}

class _TechnicianDetailScreenState extends State<TechnicianDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechnicianProvider>().fetchTechnicianDetail(widget.technicianId);
      context.read<RequestProvider>().loadMyRequests();
    });
  }

  void _showRequestModal(Technician tech) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestDialog(technician: tech),
    );
  }

  void _showPortfolioModal(PortfolioItem item, List<PortfolioItem> items, int initialIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PortfolioModal(items: items, initialIndex: initialIndex),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  void _launchWhatsApp(String phoneNumber) async {
    // Clean number: remove all non-digit characters
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    // Try the WhatsApp app deep link
    final Uri uri = Uri.parse('whatsapp://send?phone=$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to WhatsApp Web
      final Uri fallbackUri = Uri.parse('https://wa.me/$cleanNumber');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TechnicianProvider>();
    final reqProvider = context.watch<RequestProvider>();
    final tech = provider.currentTechnician;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 16.0;
    final portfolioColumns = isTablet ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tech?.name ?? l10n.technician,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onPrimary),
            onPressed: () => provider.fetchTechnicianDetail(widget.technicianId),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: provider.isLoading
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : provider.error != null || tech == null
            ? _buildErrorView(provider, l10n, theme)
            : _buildContent(tech, horizontalPadding, portfolioColumns, l10n, theme),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: reqProvider.hasActiveRequest(tech?.id ?? 0)
              ? _buildAlreadySentWidget(l10n, theme)
              : ElevatedButton.icon(
            onPressed: tech != null ? () => _showRequestModal(tech) : null,
            icon: Icon(Icons.handyman_rounded, color: theme.colorScheme.onPrimary, size: 20),
            label: Text(
              l10n.requestThisFundi,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(TechnicianProvider provider, AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 56, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              provider.error ?? l10n.technicianNotFound,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => provider.fetchTechnicianDetail(widget.technicianId),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Technician tech, double hPadding, int portfolioColumns, AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(tech, l10n, theme),
          const SizedBox(height: 16),
          _buildContactSection(tech, theme),
          const SizedBox(height: 16),
          if (tech.bio != null && tech.bio!.isNotEmpty) _buildBioSection(tech.bio!, l10n, theme),
          const SizedBox(height: 16),
          _buildServicesSection(tech, l10n, theme),
          const SizedBox(height: 16),
          _buildPortfolioSection(tech, portfolioColumns, l10n, theme, _showPortfolioModal),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ============================================================
  // CONTACT SECTION – Phone Call + WhatsApp Chat
  // ============================================================
  Widget _buildContactSection(Technician tech, ThemeData theme) {
    final hasPhone = tech.phone != null && tech.phone!.isNotEmpty;
    final hasEmail = tech.email != null && tech.email!.isNotEmpty;

    if (!hasPhone && !hasEmail) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      shadowColor: theme.shadowColor.withOpacity(0.05),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.contact_phone_rounded, size: 18, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Contact',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Phone actions (Call + WhatsApp)
            if (hasPhone)
              Row(
                children: [
                  // Phone Call button
                  Expanded(
                    child: InkWell(
                      onTap: () => _makePhoneCall(tech.phone!),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.phone_rounded, size: 24, color: theme.primaryColor),
                            const SizedBox(height: 4),
                            Text(
                              'Call',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // WhatsApp Chat button
                  Expanded(
                    child: InkWell(
                      onTap: () => _launchWhatsApp(tech.phone!),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.chat_rounded, size: 24, color: Colors.green),
                            const SizedBox(height: 4),
                            Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            if (hasPhone && hasEmail) const SizedBox(height: 12),

            // Email row (if available)
            if (hasEmail)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_rounded, size: 18, color: theme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tech.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE CARD (unchanged)
  // ============================================================
  Widget _buildProfileCard(Technician tech, AppLocalizations l10n, ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      shadowColor: theme.shadowColor.withOpacity(0.1),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: theme.primaryColor.withOpacity(0.08),
                  backgroundImage: tech.profilePhoto != null
                      ? NetworkImage(ImageUtils.getFullImageUrl(tech.profilePhoto!))
                      : null,
                  child: tech.profilePhoto == null
                      ? Text(
                    tech.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: theme.primaryColor),
                  )
                      : null,
                ),
                if (tech.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tech.name,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            if (tech.area != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(tech.area!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  tech.rating.toStringAsFixed(1),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: theme.hintColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Icon(Icons.work_outline_rounded, size: 16, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  '${tech.experience} yrs',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: tech.isOnline ? Colors.green.withOpacity(0.12) : theme.hintColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: tech.isOnline ? Colors.green : theme.hintColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tech.isOnline ? l10n.online : l10n.offline,
                    style: TextStyle(
                      color: tech.isOnline ? Colors.green : theme.hintColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BIO SECTION
  // ============================================================
  Widget _buildBioSection(String bio, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          shadowColor: theme.shadowColor.withOpacity(0.05),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              bio,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SERVICES SECTION
  // ============================================================
  Widget _buildServicesSection(Technician tech, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services & Rates',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          shadowColor: theme.shadowColor.withOpacity(0.05),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tech.services.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tech.services.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    )).toList(),
                  ),
                if (tech.hourlyRate != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hourly Rate',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 20, color: theme.hintColor.withOpacity(0.3)),
                        const SizedBox(width: 8),
                        Text(
                          'TZS ${tech.hourlyRate!.toStringAsFixed(0)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PORTFOLIO SECTION
  // ============================================================
  Widget _buildPortfolioSection(
      Technician tech,
      int columns,
      AppLocalizations l10n,
      ThemeData theme,
      Function(PortfolioItem, List<PortfolioItem>, int) onTap,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Portfolio',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Spacer(),
            if (tech.portfolios.isNotEmpty)
              Text(
                '${tech.portfolios.length} items',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (tech.portfolios.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 48, color: theme.hintColor.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'No portfolio items yet',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tech.portfolios.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (ctx, i) {
              final item = tech.portfolios[i];
              return GestureDetector(
                onTap: () => onTap(item, tech.portfolios, i),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  shadowColor: theme.shadowColor.withOpacity(0.05),
                  color: theme.cardColor,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          ImageUtils.getFullImageUrl(item.image),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image, size: 40, color: theme.hintColor),
                          ),
                        ),
                        if (item.description != null)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                ),
                              ),
                              child: Text(
                                item.description!,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAlreadySentWidget(AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 20, color: theme.hintColor),
          const SizedBox(width: 8),
          Text(
            'Request already sent',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Portfolio Modal (unchanged – already dark‑compatible)
// ============================================================
class _PortfolioModal extends StatefulWidget {
  final List<PortfolioItem> items;
  final int initialIndex;
  const _PortfolioModal({required this.items, required this.initialIndex});

  @override
  State<_PortfolioModal> createState() => _PortfolioModalState();
}

class _PortfolioModalState extends State<_PortfolioModal> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalItems = widget.items.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF0D1F1F) : Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  '${_currentIndex + 1} / $totalItems',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 24),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // Image Carousel
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.items.length,
              itemBuilder: (ctx, index) {
                final item = widget.items[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    ImageUtils.getFullImageUrl(item.image),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade900,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text('Failed to load image', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Description
          if (widget.items[_currentIndex].description != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.items[_currentIndex].description!,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          // Thumbnails
          if (totalItems > 1)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.grey.shade900,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.items.length,
                itemBuilder: (ctx, index) {
                  final isSelected = index == _currentIndex;
                  final item = widget.items[index];
                  return GestureDetector(
                    onTap: () => _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ImageUtils.getFullImageUrl(item.image),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Request Dialog (unchanged – already themed)
// ============================================================
class _RequestDialog extends StatefulWidget {
  final Technician technician;
  const _RequestDialog({required this.technician});

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final TextEditingController _descController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int? _selectedServiceId;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceId == null) {
      setState(() => _errorMessage = l10n.pleaseSelectService);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await context.read<RequestProvider>().createRequest(
      widget.technician.id,
      _selectedServiceId!,
      _descController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      setState(() {
        _isSuccess = true;
        _isSubmitting = false;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) context.read<RequestProvider>().loadMyRequests();
    } else {
      final err = context.read<RequestProvider>().error ?? l10n.failed;
      setState(() {
        _isSubmitting = false;
        _errorMessage = err;
      });
    }
  }

  void _closeDialog() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final services = widget.technician.serviceObjects;
    final hasServices = services.isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.cardColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.handyman_rounded, color: theme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Request ${widget.technician.name}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
                if (!_isSubmitting && !_isSuccess)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 22),
                    onPressed: _closeDialog,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isSubmitting && !_isSuccess) ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Service',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (!hasServices)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This technician has no services listed',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedServiceId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select a service...',
                          hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                          prefixIcon: Icon(Icons.construction_rounded, color: theme.primaryColor, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Select a service...'),
                          ),
                          ...services.map((service) => DropdownMenuItem<int>(
                            value: service.id,
                            child: Text(service.name),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedServiceId = value;
                            _errorMessage = null;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a service' : null,
                      ),
                    if (_errorMessage != null && _errorMessage!.contains('service'))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Describe your issue',
                        hintText: 'Briefly describe what you need help with...',
                        hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description_outlined, color: theme.primaryColor, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 5) return 'Please describe your issue (min 5 chars)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: Text('Submit Request', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isSubmitting) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Center(
                child: Text('Sending request...', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
              ),
            ],

            if (_isSuccess) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Request Sent!',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The fundi will review your request',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _closeDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (!_isSubmitting && !_isSuccess && _errorMessage != null && !_errorMessage!.contains('service')) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 14)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _errorMessage = null;
                    _isSubmitting = false;
                  }),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.hintColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Try Again', style: TextStyle(color: theme.colorScheme.onSurface)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}