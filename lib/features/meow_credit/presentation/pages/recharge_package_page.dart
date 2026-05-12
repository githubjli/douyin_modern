import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/widgets/back_nav_header.dart';
import '../../application/meow_credit_providers.dart';
import '../../data/meow_credit_repository.dart';
import '../../domain/meow_credit_wallet.dart';
import 'meow_credit_recharge_page.dart';

// ---------------------------------------------------------------------------
// Fallback packages shown when the API is unavailable
// ---------------------------------------------------------------------------

const List<MeowCreditPackage> _fallbackPackages = <MeowCreditPackage>[
  MeowCreditPackage(
    code: 'credit_100',
    name: '100 Credits',
    creditAmount: 100,
    bonusCredit: 0,
    totalCredit: 100,
    priceAmount: '100.00',
    priceCurrency: 'THB-LTT',
    description: 'Starter pack',
  ),
  MeowCreditPackage(
    code: 'credit_500',
    name: '500 Credits',
    creditAmount: 500,
    bonusCredit: 50,
    totalCredit: 550,
    priceAmount: '500.00',
    priceCurrency: 'THB-LTT',
    description: '+50 bonus credits',
  ),
  MeowCreditPackage(
    code: 'credit_1000',
    name: '1000 Credits',
    creditAmount: 1000,
    bonusCredit: 200,
    totalCredit: 1200,
    priceAmount: '1000.00',
    priceCurrency: 'THB-LTT',
    description: '+200 bonus credits — best value',
  ),
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class RechargePackagePage extends ConsumerStatefulWidget {
  const RechargePackagePage({super.key});

  @override
  ConsumerState<RechargePackagePage> createState() =>
      _RechargePackagePageState();
}

class _RechargePackagePageState extends ConsumerState<RechargePackagePage> {
  bool _creating = false;

  Future<void> _selectPackage(MeowCreditPackage pkg) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final info = await ref
          .read(meowCreditRepositoryProvider)
          .getRechargeInfo(pkg.code);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MeowCreditRechargePage(
          package: pkg,
          rechargeInfo: info,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load recharge info.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(meowCreditPackagesProvider);

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: BackNavHeader(title: 'Recharge Meow Credit'),
            ),

            Expanded(
              child: packagesAsync.when(
                data: (packages) => _list(
                  packages.isEmpty ? _fallbackPackages : packages,
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brandGold),
                ),
                error: (_, __) => _list(_fallbackPackages),
              ),
            ),

            if (_creating)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandGold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<MeowCreditPackage> packages) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      itemCount: packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _PackageCard(
        package: packages[i],
        onTap: _creating ? null : () => _selectPackage(packages[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Package card
// ---------------------------------------------------------------------------

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.onTap});

  final MeowCreditPackage package;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasBonusCredit = package.bonusCredit > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.softBorder),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(package.name,
                          style: AppTextStyles.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      if (hasBonusCredit) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${package.bonusCredit} Bonus',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.brandGold, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasBonusCredit
                        ? '${package.totalCredit} credits total'
                        : '${package.creditAmount} credits',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white54),
                  ),
                  if (package.description != null &&
                      package.description!.isNotEmpty)
                    Text(package.description!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.brandGold, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(package.priceAmount,
                    style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.brandGold, fontSize: 24)),
                Text(package.priceCurrency,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.brandGold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
