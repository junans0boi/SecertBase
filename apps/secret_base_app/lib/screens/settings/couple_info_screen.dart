import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/socket_service.dart';
import '../../v2/v2.dart';
import '../auth/partner_screen.dart';
import '../home/anniversaries_screen.dart';
import 'profile_edit_screen.dart';
import 'settings_common.dart';

/// 커플·기념일: 기준일, 기념일 목록 진입, 연결 해제(안내 → 문구 입력 2단).
class CoupleInfoScreen extends StatefulWidget {
  const CoupleInfoScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<CoupleInfoScreen> createState() => _CoupleInfoScreenState();
}

class _CoupleInfoScreenState extends State<CoupleInfoScreen> {
  final _auth = AuthService();
  late final ApiClient _api = widget.apiClient ?? _auth.apiClient;

  CoupleInfo? _info;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  bool _disconnecting = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_rebuild);
    _load();
  }

  @override
  void dispose() {
    _auth.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final info = await fetchCoupleInfo(_api);
      if (mounted) {
        setState(() {
          _info = info;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final current = _info?.startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: '처음 만난 날을 골라 주세요',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked == null || !mounted || picked == current) return;
    setState(() => _saving = true);
    try {
      await _api.patchJson(
        '/api/couple/info',
        body: {'start_date': isoDate(picked)},
      );
      await _load();
      if (mounted) showV2Snack(context, '기준일을 바꿨어요');
    } catch (_) {
      if (mounted) {
        showV2Snack(context, '기준일을 바꾸지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disconnect() async {
    final partner = partnerDisplayName(_auth.user) ?? '파트너';
    final first = await showV2Confirm(
      context,
      title: '${withWaGwa(partner)}의 연결을 해제할까요?',
      message: '해제하면 함께 보던 기록과 지도 공유가 멈춰요. 내가 남긴 기록은 지워지지 않고 개인 보관함에 남아요.',
      confirmLabel: '계속하기',
      cancelLabel: '취소',
    );
    if (!first || !mounted) return;
    final second = await showTypedConfirmSheet(
      context,
      title: '마지막으로 확인할게요',
      message: '$partner에게도 연결이 해제됐다는 알림이 가요. 다시 연결하려면 새 코드를 주고받아야 해요.',
      phrase: '연결 해제',
      confirmLabel: '연결 해제하기',
    );
    if (!second || !mounted) return;
    setState(() => _disconnecting = true);
    final ok = await _auth.disconnectPartner();
    if (ok) SocketService().disconnect();
    if (!mounted) return;
    setState(() => _disconnecting = false);
    if (ok) {
      showV2Snack(context, '${withWaGwa(partner)}의 연결을 해제했어요');
      Navigator.of(context).pop();
    } else {
      showV2Snack(context, '연결을 해제하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.user;
    final paired = isPaired(user);
    final me = myDisplayName(user);
    final partner = partnerDisplayName(user) ?? _info?.partnerName ?? '파트너';
    final p = V2Palette.of(context);

    Widget body;
    if (!paired) {
      body = V2EmptyState.unpaired(
        onAction: () => pushMorePage<void>(context, const PartnerScreen()),
      );
    } else if (_loading && _info == null) {
      body = const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 4),
      );
    } else if (_failed && _info == null) {
      body = V2ErrorState(onRetry: _load);
    } else {
      final start = _info?.startDate;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          V2Card(
            gradient: V2Gradients.hero,
            child: Column(
              children: [
                V2AvatarPair(me: me, partner: partner, size: V2AvatarSize.lg),
                const SizedBox(height: 12),
                Text(
                  '$me · $partner',
                  style: V2Text.head.copyWith(color: Colors.white),
                ),
                if (_info?.dDayText.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    _info!.dDayText,
                    style: V2Text.serif(size: 40, color: Colors.white),
                  ),
                ],
                if (start != null)
                  Text(
                    '${koreanDate(start)}부터 함께해요',
                    style: V2Text.cap.copyWith(color: Colors.white),
                  ),
              ],
            ),
          ),
          V2Section(
            title: '우리 커플',
            padding: EdgeInsets.zero,
            child: V2List(
              children: [
                V2ListTile(
                  icon: V2Icons.heart,
                  title: '처음 만난 날',
                  subtitle: start == null ? '기준일을 정해 주세요' : koreanDate(start),
                  trailing: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '바꾸기',
                          style: V2Text.cap.copyWith(color: p.primary),
                        ),
                  onTap: _saving ? null : _pickStartDate,
                ),
                V2ListTile(
                  icon: V2Icons.event,
                  tone: V2Tone.honey,
                  title: '기념일',
                  subtitle: _nextAnniversaryText(),
                  onTap: () =>
                      pushMorePage<void>(context, const AnniversariesScreen()),
                ),
                V2ListTile(
                  icon: V2Icons.person,
                  tone: V2Tone.lilac,
                  title: '내 프로필',
                  subtitle: '닉네임, 생일',
                  onTap: () =>
                      pushMorePage<void>(context, const ProfileEditScreen()),
                ),
              ],
            ),
          ),
          V2Section(
            title: '연결 관리',
            padding: EdgeInsets.zero,
            child: V2List(
              children: [
                V2ListTile(
                  icon: V2Icons.link,
                  destructive: true,
                  title: '${withWaGwa(partner)} 연결 해제',
                  subtitle: _disconnecting ? '해제하는 중이에요' : '함께 쓰는 기록 공유가 멈춰요',
                  onTap: _disconnecting ? null : _disconnect,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '커플 정보'),
        body: body,
      ),
    );
  }

  String _nextAnniversaryText() {
    final label = _info?.nextAnniversaryLabel;
    final days = _info?.nextAnniversaryDays;
    if (label == null || label.isEmpty || days == null) {
      return '소중한 날을 챙겨 보세요';
    }
    return days <= 0 ? '$label 오늘이에요' : '$label까지 $days일';
  }
}
