// screens/technicians/technician_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/service.dart';
import '../../providers/technician_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/location_provider.dart';
import '../../utils/image_utils.dart';
import '../../models/technician.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';

// ──────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ──────────────────────────────────────────────────────────────────────────
class TechnicianDetailScreen extends StatefulWidget {
  final int technicianId;
  const TechnicianDetailScreen({super.key, required this.technicianId});

  @override
  State<TechnicianDetailScreen> createState() => _TechnicianDetailScreenState();
}

class _TechnicianDetailScreenState extends State<TechnicianDetailScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<TechnicianProvider>();

      await provider.fetchTechnicianWithPortfolios(widget.technicianId);

      await Future.wait([
        context.read<RequestProvider>().loadMyRequests(),
        context.read<ServiceProvider>().fetchServices(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showRequestModal(Technician tech) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RequestDialog(technician: tech),
    );
  }

  void _showPortfolioModal(PortfolioItem item, List<PortfolioItem> items, int initialIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortfolioModal(items: items, initialIndex: initialIndex),
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
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('whatsapp://send?phone=$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallbackUri = Uri.parse('https://wa.me/$cleanNumber');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _launchSocialUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
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

    if (_isLoading || provider.isLoading) {
      return Scaffold(
        appBar: _buildAppBar(l10n, theme),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || provider.error != null || tech == null) {
      return Scaffold(
        appBar: _buildAppBar(l10n, theme),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.error),
                const SizedBox(height: 16),
                Text(
                  provider.error ?? _error ?? l10n.technicianNotFound,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(l10n, theme, techName: tech.name),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroProfile(tech, l10n, theme),
              const SizedBox(height: 20),
              _buildContactChips(tech, theme, l10n),
              const SizedBox(height: 20),
              if (tech.bio != null && tech.bio!.isNotEmpty) _buildBioSection(tech.bio!, l10n, theme),
              if (tech.bio != null && tech.bio!.isNotEmpty) const SizedBox(height: 20),
              _buildServicesSection(tech, l10n, theme),
              const SizedBox(height: 20),
              _buildPortfolioSection(tech, portfolioColumns, l10n, theme, _showPortfolioModal),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: reqProvider.hasActiveRequest(tech.id)
              ? _buildAlreadySentWidget(l10n, theme)
              : ElevatedButton.icon(
            onPressed: () => _showRequestModal(tech),
            icon: Icon(Icons.handyman_rounded, color: Colors.white, size: 20),
            label: Text(
              l10n.requestThisFundi,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(AppLocalizations l10n, ThemeData theme, {String? techName}) {
    return AppBar(
      title: Text(
        techName ?? l10n.technician,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadData,
          tooltip: l10n.refresh,
        ),
      ],
      backgroundColor: AppTheme.primary,
      elevation: 0,
    );
  }

  // ─── Hero Profile ──────────────────────────────────────────────────────
  Widget _buildHeroProfile(Technician tech, AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: tech.profilePhoto != null
                    ? NetworkImage(ImageUtils.getFullImageUrl(tech.profilePhoto!))
                    : null,
                child: tech.profilePhoto == null
                    ? Text(
                  tech.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                )
                    : null,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: tech.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tech.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (tech.area != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  tech.area!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem(Icons.star_rounded, tech.rating.toStringAsFixed(1), l10n.rating, Colors.amber),
                Container(width: 1, height: 28, color: Colors.white24),
                _statItem(Icons.work_history_rounded, tech.completedJobsCount.toString(), l10n.jobsCompleted, Colors.white70),
                Container(width: 1, height: 28, color: Colors.white24),
                _statItem(Icons.work_outline_rounded, '${tech.experience} ${l10n.years}', l10n.experience, Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (tech.verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade700.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white54, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Verified', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  // ─── Contact Chips ──────────────────────────────────────────────────
  Widget _buildContactChips(Technician tech, ThemeData theme, AppLocalizations l10n) {
    final hasPhone = tech.phone != null && tech.phone!.isNotEmpty;
    final hasEmail = tech.email != null && tech.email!.isNotEmpty;

    if (!hasPhone && !hasEmail) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (hasPhone)
          _contactChip(
            icon: Icons.phone_rounded,
            label: l10n.call,
            color: Colors.green.shade700,
            onTap: () => _makePhoneCall(tech.phone!),
          ),
        if (hasPhone)
          _contactChip(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: Colors.green.shade600,
            onTap: () => _launchWhatsApp(tech.phone!),
          ),
        if (hasEmail)
          _contactChip(
            icon: Icons.email_rounded,
            label: l10n.email,
            color: Colors.blue.shade700,
            onTap: () => launchUrl(Uri.parse('mailto:${tech.email}')),
          ),
      ],
    );
  }

  Widget _contactChip({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: color),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      onPressed: onTap,
    );
  }

  // ─── Bio ──────────────────────────────────────────────────────────────
  Widget _buildBioSection(String bio, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.about,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            bio,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ─── Services with min/max prices ──────────────────────────────────
  Widget _buildServicesSection(Technician tech, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.servicesAndRate,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        if (tech.servicePrices.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              children: tech.servicePrices.map((sp) {
                final hasPrice = sp.minPrice > 0 || sp.maxPrice > 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.construction_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sp.name,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasPrice
                              ? '${sp.minPrice.toStringAsFixed(0)} - ${sp.maxPrice.toStringAsFixed(0)} ${l10n.tzs}'
                              : 'No fixed price',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hasPrice ? AppTheme.primary : theme.hintColor,
                            fontWeight: hasPrice ? FontWeight.bold : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        else if (tech.services.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tech.services.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.primary,
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
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.hourlyRate,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: theme.hintColor.withOpacity(0.3)),
                const SizedBox(width: 8),
                Text(
                  '${l10n.tzs} ${tech.hourlyRate!.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── PORTFOLIO SECTION ──────────────────────────────────────────────
  Widget _buildPortfolioSection(
      Technician tech,
      int columns,
      AppLocalizations l10n,
      ThemeData theme,
      Function(PortfolioItem, List<PortfolioItem>, int) onTap,
      ) {
    final items = tech.portfolios;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.portfolio,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Spacer(),
            if (items.isNotEmpty)
              Text(
                '${items.length} ${l10n.items}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 48, color: theme.hintColor.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noPortfolioItems,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (ctx, i) {
              final item = items[i];
              return PortfolioGridCard(
                item: item,
                onTap: () => onTap(item, items, i),
                theme: theme,
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
            l10n.requestAlreadySent,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PORTFOLIO GRID CARD – FIXED HEIGHT (prevents layout errors)
// ──────────────────────────────────────────────────────────────────────────
class PortfolioGridCard extends StatefulWidget {
  final PortfolioItem item;
  final VoidCallback onTap;
  final ThemeData theme;

  const PortfolioGridCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.theme,
  });

  @override
  State<PortfolioGridCard> createState() => _PortfolioGridCardState();
}

class _PortfolioGridCardState extends State<PortfolioGridCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = widget.theme;
    final desc = item.description ?? '';
    final shouldShowReadMore = desc.length > 60;

    return GestureDetector(
      onTap: widget.onTap,
      child: Hero(
        tag: 'portfolio_${item.id}',
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: theme.shadowColor.withOpacity(0.15),
          color: theme.cardColor,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Image with fixed height ────────────────────────────
                SizedBox(
                  height: 120,
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
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                      // Social icons overlay (top-right)
                      if (item.hasSocialLinks)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (item.instagram != null)
                                _socialIcon(FontAwesomeIcons.instagram, Colors.pink, item.instagram!),
                              if (item.facebook != null)
                                _socialIcon(FontAwesomeIcons.facebook, Colors.blue.shade700, item.facebook!),
                              if (item.tiktok != null)
                                _socialIcon(FontAwesomeIcons.tiktok, Colors.white, item.tiktok!),
                              if (item.twitter != null)
                                _socialIcon(FontAwesomeIcons.twitter, Colors.blue.shade400, item.twitter!),
                              if (item.telegram != null)
                                _socialIcon(FontAwesomeIcons.telegram, Colors.lightBlue, item.telegram!),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // ─── Description and actions ────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (desc.isNotEmpty) ...[
                        Text(
                          desc,
                          maxLines: _isExpanded ? null : 2,
                          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            height: 1.3,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (shouldShowReadMore)
                          GestureDetector(
                            onTap: () => setState(() => _isExpanded = !_isExpanded),
                            child: Text(
                              _isExpanded ? 'Read less' : 'Read more',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 6),
                      // View button
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              size: 14,
                              color: theme.hintColor.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'View',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: theme.hintColor.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(FaIconData icon, Color color, String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: FaIcon(icon, size: 14, color: color),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// PORTFOLIO MODAL
// ──────────────────────────────────────────────────────────────────────────
class PortfolioModal extends StatefulWidget {
  final List<PortfolioItem> items;
  final int initialIndex;

  const PortfolioModal({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<PortfolioModal> createState() => _PortfolioModalState();
}

class _PortfolioModalState extends State<PortfolioModal> {
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
    final currentItem = widget.items[_currentIndex];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF0D1F1F) : Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
                  child: Hero(
                    tag: 'portfolio_${item.id}',
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
                  ),
                );
              },
            ),
          ),
          if (currentItem.description != null || currentItem.hasSocialLinks) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentItem.description != null) ...[
                    Text(
                      'Description',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentItem.description!,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                    ),
                  ],
                  if (currentItem.hasSocialLinks) ...[
                    if (currentItem.description != null) const SizedBox(height: 12),
                    Text(
                      'Social Links',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (currentItem.instagram != null)
                          _modalSocialIcon(FontAwesomeIcons.instagram, currentItem.instagram!, Colors.pink),
                        if (currentItem.facebook != null)
                          _modalSocialIcon(FontAwesomeIcons.facebook, currentItem.facebook!, Colors.blue.shade700),
                        if (currentItem.tiktok != null)
                          _modalSocialIcon(FontAwesomeIcons.tiktok, currentItem.tiktok!, Colors.white),
                        if (currentItem.twitter != null)
                          _modalSocialIcon(FontAwesomeIcons.twitter, currentItem.twitter!, Colors.blue.shade400),
                        if (currentItem.telegram != null)
                          _modalSocialIcon(FontAwesomeIcons.telegram, currentItem.telegram!, Colors.lightBlue),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
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

  Widget _modalSocialIcon(FaIconData icon, String url, Color color) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: FaIcon(icon, size: 20, color: color),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// REQUEST DIALOG – with auto‑category selection
// ──────────────────────────────────────────────────────────────────────────
class RequestDialog extends StatefulWidget {
  final Technician technician;

  const RequestDialog({super.key, required this.technician});

  @override
  State<RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<RequestDialog> {
  final TextEditingController _descController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int? _selectedServiceId;
  int? _selectedCategoryId;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _errorMessage;
  List<ServiceCategory> _availableCategories = [];
  bool _isInitialized = false;
  String _locale = 'en';

  List<TechnicianService> get _serviceList {
    if (widget.technician.servicePrices.isNotEmpty) {
      return widget.technician.servicePrices
          .map((sp) => TechnicianService(id: sp.id, name: sp.name))
          .toList();
    }
    if (widget.technician.serviceObjects.isNotEmpty) {
      return widget.technician.serviceObjects;
    }
    return widget.technician.services
        .map((name) => TechnicianService(id: DateTime.now().millisecondsSinceEpoch + name.hashCode, name: name))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isInitialized) {
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _locale = Localizations.localeOf(context).languageCode;
      _isInitialized = true;
    }
  }

  void _loadData() {
    if (mounted) {
      context.read<ServiceProvider>().fetchServices(locale: _locale);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _updateCategories(int? serviceId) {
    if (serviceId == null) {
      setState(() {
        _availableCategories = [];
        _selectedCategoryId = null;
      });
      return;
    }

    final serviceProvider = context.read<ServiceProvider>();
    final categories = serviceProvider.getCategoriesForService(serviceId);
    setState(() {
      _availableCategories = categories;
      if (categories.length == 1) {
        _selectedCategoryId = categories.first.id;
      } else {
        _selectedCategoryId = null;
      }
    });
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

    final locProvider = context.read<LocationProvider>();
    final position = locProvider.position;
    double? lat, lng;
    if (position != null) {
      lat = position.latitude;
      lng = position.longitude;
    }

    final success = await context.read<RequestProvider>().createRequest(
      technicianId: widget.technician.id,
      serviceId: _selectedServiceId!,
      description: _descController.text.trim(),
      categoryId: _selectedCategoryId,
      latitude: lat,
      longitude: lng,
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
    final services = _serviceList;
    final hasServices = services.isNotEmpty;
    final showCategoryDropdown = _availableCategories.length > 1;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.cardColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.handyman_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.requestThisFundi,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
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
                        l10n.selectService,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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
                                  l10n.noServicesSelected,
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
                            hintText: l10n.selectService,
                            hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                            prefixIcon: Icon(Icons.construction_rounded, color: AppTheme.primary, size: 20),
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
                              borderSide: BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('Select a service'),
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
                              _updateCategories(value);
                            });
                          },
                          validator: (value) => value == null ? l10n.pleaseSelectService : null,
                        ),

                      if (_errorMessage != null && _errorMessage!.contains('service'))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.error, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),

                      if (showCategoryDropdown) ...[
                        Text(
                          l10n.category,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedCategoryId,
                              isExpanded: true,
                              hint: Text(
                                l10n.selectService,
                                style: TextStyle(color: theme.hintColor, fontSize: 14),
                              ),
                              items: [
                                DropdownMenuItem<int>(
                                  value: null,
                                  child: Text(l10n.all),
                                ),
                                ..._availableCategories.map((category) {
                                  return DropdownMenuItem<int>(
                                    value: category.id,
                                    child: Text(category.getDisplayName(_locale)),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategoryId = value;
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l10n.describeIssue,
                          hintText: l10n.describeHint,
                          hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_outlined, color: AppTheme.primary, size: 20),
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
                            borderSide: BorderSide(color: AppTheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          labelStyle: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 5) {
                            return l10n.describeIssue;
                          }
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
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          child: Text(
                            l10n.submitRequest,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
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
                  child: Text(
                    l10n.sendingToTechnician,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
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
                        l10n.requestSent,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.awaitingResponse,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _closeDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            l10n.done,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!_isSubmitting && !_isSuccess &&
                  _errorMessage != null &&
                  !_errorMessage!.contains('service')) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppTheme.error, fontSize: 14),
                        ),
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
                    child: Text(
                      l10n.retry,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}