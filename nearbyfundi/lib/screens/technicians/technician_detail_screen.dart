// screens/technicians/technician_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/service.dart';
import '../../providers/technician_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/service_provider.dart';
import '../../utils/image_utils.dart';
import '../../models/technician.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';

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
        appBar: AppBar(
          title: Text(
            l10n.technician,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
          ),
          backgroundColor: AppTheme.primary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || provider.error != null || tech == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.technician,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
          ),
          backgroundColor: AppTheme.primary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.error),
                ),
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
      appBar: AppBar(
        title: Text(
          tech.name,
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
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(tech, l10n, theme),
              const SizedBox(height: 16),
              _buildContactSection(tech, theme, l10n),
              const SizedBox(height: 16),
              if (tech.bio != null && tech.bio!.isNotEmpty) _buildBioSection(tech.bio!, l10n, theme),
              const SizedBox(height: 16),
              _buildSocialLinksSection(tech, theme, l10n),
              const SizedBox(height: 16),
              _buildServicesSection(tech, l10n, theme),
              const SizedBox(height: 16),
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

  // ─── PROFILE CARD ──────────────────────────────────────────────────────
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
                  backgroundColor: AppTheme.primary.withOpacity(0.08),
                  backgroundImage: tech.profilePhoto != null
                      ? NetworkImage(ImageUtils.getFullImageUrl(tech.profilePhoto!))
                      : null,
                  child: tech.profilePhoto == null
                      ? Text(
                    tech.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                  '${tech.experience} ${l10n.years}',
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

  // ─── CONTACT SECTION ──────────────────────────────────────────────────
  Widget _buildContactSection(Technician tech, ThemeData theme, AppLocalizations l10n) {
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
            Row(
              children: [
                Icon(Icons.contact_phone_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.contact,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasPhone)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _makePhoneCall(tech.phone!),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.phone_rounded, size: 24, color: AppTheme.primary),
                            const SizedBox(height: 4),
                            Text(
                              l10n.call,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
            if (hasEmail)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_rounded, size: 18, color: AppTheme.primary),
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

  // ─── BIO SECTION ──────────────────────────────────────────────────────
  Widget _buildBioSection(String bio, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.about,
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

  // ─── SOCIAL LINKS SECTION ─────────────────────────────────────────────
  Widget _buildSocialLinksSection(Technician tech, ThemeData theme, AppLocalizations l10n) {
    final Map<String, String> socialLinks = {};
    for (final item in tech.portfolios) {
      if (item.instagram != null) socialLinks['Instagram'] = item.instagram!;
      if (item.facebook != null) socialLinks['Facebook'] = item.facebook!;
      if (item.tiktok != null) socialLinks['TikTok'] = item.tiktok!;
      if (item.twitter != null) socialLinks['Twitter'] = item.twitter!;
      if (item.telegram != null) socialLinks['Telegram'] = item.telegram!;
    }

    if (socialLinks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.socialMedia,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          shadowColor: theme.shadowColor.withOpacity(0.05),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              children: socialLinks.entries.map((entry) {
                return _buildSocialIcon(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(String label, String url) {
    FaIconData icon;
    Color color;
    switch (label) {
      case 'Instagram':
        icon = FontAwesomeIcons.instagram;
        color = Colors.pink;
        break;
      case 'Facebook':
        icon = FontAwesomeIcons.facebook;
        color = Colors.blue.shade700;
        break;
      case 'TikTok':
        icon = FontAwesomeIcons.tiktok;
        color = Colors.black;
        break;
      case 'Twitter':
        icon = FontAwesomeIcons.twitter;
        color = Colors.blue.shade400;
        break;
      case 'Telegram':
        icon = FontAwesomeIcons.telegram;
        color = Colors.lightBlue;
        break;
      default:
        icon = FontAwesomeIcons.link;
        color = AppTheme.primary;
    }
    return GestureDetector(
      onTap: () => _launchSocialUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─── SERVICES SECTION ─────────────────────────────────────────────────
  Widget _buildServicesSection(Technician tech, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.servicesAndRate,
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
            ),
          ),
        ),
      ],
    );
  }

  // ─── PORTFOLIO SECTION ─────────────────────────────────────────────────────
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
              l10n.portfolio,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Spacer(),
            if (tech.portfolios.isNotEmpty)
              Text(
                '${tech.portfolios.length} ${l10n.items}',
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
                      l10n.noPortfolioItems,
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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemBuilder: (ctx, i) {
              final item = tech.portfolios[i];
              return PortfolioGridCard(
                item: item,
                onTap: () => onTap(item, tech.portfolios, i),
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

// ─── PORTFOLIO GRID CARD ──────────────────────────────────────────────
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
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: theme.shadowColor.withOpacity(0.08),
        color: theme.cardColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                ImageUtils.getFullImageUrl(item.image),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image, size: 40, color: theme.hintColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
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
                      const SizedBox(height: 4),
                    ],
                    if (item.hasSocialLinks) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          if (item.instagram != null)
                            _miniIcon(FontAwesomeIcons.instagram, Colors.pink, 'Instagram'),
                          if (item.facebook != null)
                            _miniIcon(FontAwesomeIcons.facebook, Colors.blue.shade700, 'Facebook'),
                          if (item.tiktok != null)
                            _miniIcon(FontAwesomeIcons.tiktok, Colors.black, 'TikTok'),
                          if (item.twitter != null)
                            _miniIcon(FontAwesomeIcons.twitter, Colors.blue.shade400, 'Twitter'),
                          if (item.telegram != null)
                            _miniIcon(FontAwesomeIcons.telegram, Colors.lightBlue, 'Telegram'),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fullscreen_rounded,
                            size: 12,
                            color: theme.hintColor.withOpacity(0.4),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'View',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.hintColor.withOpacity(0.4),
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
    );
  }

  Widget _miniIcon(FaIconData icon, Color color, String label) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.all(2),
        child: FaIcon(icon, size: 13, color: color),
      ),
    );
  }
}

// ─── PORTFOLIO MODAL ─────────────────────────────────────────────────────
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
                          _buildModalSocialIcon(FontAwesomeIcons.instagram, currentItem.instagram!, Colors.pink),
                        if (currentItem.facebook != null)
                          _buildModalSocialIcon(FontAwesomeIcons.facebook, currentItem.facebook!, Colors.blue.shade700),
                        if (currentItem.tiktok != null)
                          _buildModalSocialIcon(FontAwesomeIcons.tiktok, currentItem.tiktok!, Colors.white),
                        if (currentItem.twitter != null)
                          _buildModalSocialIcon(FontAwesomeIcons.twitter, currentItem.twitter!, Colors.blue.shade400),
                        if (currentItem.telegram != null)
                          _buildModalSocialIcon(FontAwesomeIcons.telegram, currentItem.telegram!, Colors.lightBlue),
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

  Widget _buildModalSocialIcon(FaIconData icon, String url, Color color) {
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

// ─── REQUEST DIALOG ──────────────────────────────────────────────────────
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
      context.read<ServiceProvider>().fetchServices();
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
      if (_selectedCategoryId != null &&
          !categories.any((c) => c.id == _selectedCategoryId)) {
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

    final success = await context.read<RequestProvider>().createRequest(
      widget.technician.id,
      _selectedServiceId!,
      _descController.text.trim(),
      categoryId: _selectedCategoryId,
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
                            DropdownMenuItem<int>(
                              value: null,
                              child: Text(l10n.selectService),
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

                      if (_availableCategories.isNotEmpty) ...[
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