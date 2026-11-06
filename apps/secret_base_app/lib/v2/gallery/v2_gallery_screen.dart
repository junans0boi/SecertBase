// Dev-only gallery of every 2.0 component and state.
//
// Not linked from production navigation. Reachable in debug builds at the
// `/v2-gallery` route (web: http://localhost:<port>/#/v2-gallery) and from
// widget tests.
import 'package:flutter/material.dart';

import '../v2.dart';

class V2GalleryScreen extends StatefulWidget {
  const V2GalleryScreen({super.key});

  static const routeName = '/v2-gallery';

  @override
  State<V2GalleryScreen> createState() => _V2GalleryScreenState();
}

class _V2GalleryScreenState extends State<V2GalleryScreen> {
  int _tab = 0;
  int _seg = 0;
  int _filter = 0;
  bool _toggle = true;
  bool _check = false;
  bool _loading = false;
  bool _bannerVisible = true;
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      dark: _dark,
      child: Builder(
        builder: (context) {
          final p = V2Palette.of(context);
          return Scaffold(
            backgroundColor: p.bg,
            appBar: V2Header(
              title: '디자인 시스템',
              subtitle: '개발용 갤러리',
              showBack: false,
              actions: [
                V2IconButton(
                  icon: _dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  tooltip: _dark ? '밝은 화면으로' : '어두운 화면으로',
                  onPressed: () => setState(() => _dark = !_dark),
                ),
                V2IconButton(
                  icon: V2Icons.bell,
                  tooltip: '알림',
                  dot: true,
                  onPressed: () => showV2Snack(context, '알림을 열었어요'),
                ),
              ],
            ),
            bottomNavigationBar: V2BottomTabBar(
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              badges: const {1: 3},
              dots: const {4},
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _palette(context),
                _type(context),
                _buttons(context),
                _inputs(context),
                _lists(context),
                _chips(context),
                _banners(context),
                _overlays(context),
                _states(context),
                _progress(context),
                _headers(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _palette(BuildContext context) {
    final swatches = <(String, Color, Color)>[
      ('bg', V2Colors.bg, V2Colors.ink),
      ('surface', V2Colors.surface, V2Colors.ink),
      ('soft', V2Colors.soft, V2Colors.ink),
      ('soft2', V2Colors.soft2, V2Colors.ink),
      ('line', V2Colors.line, V2Colors.ink),
      ('ink', V2Colors.ink, Colors.white),
      ('sub', V2Colors.sub, Colors.white),
      ('muted', V2Colors.muted, Colors.white),
      ('rose', V2Colors.rose, V2Colors.ink),
      ('rose600', V2Colors.rose600, Colors.white),
      ('rose700', V2Colors.rose700, Colors.white),
      ('roseSoft', V2Colors.roseSoft, V2Colors.rose700),
      ('sage', V2Colors.sageSoft, V2Colors.sageText),
      ('sky', V2Colors.skySoft, V2Colors.skyText),
      ('honey', V2Colors.honeySoft, V2Colors.honeyText),
      ('lilac', V2Colors.lilacSoft, V2Colors.lilacText),
      ('peach', V2Colors.peachSoft, V2Colors.peachText),
      ('ok', V2Colors.okSoft, V2Colors.okText),
      ('warn', V2Colors.warnSoft, V2Colors.warnText),
      ('err', V2Colors.errSoft, V2Colors.errText),
    ];
    return V2Section(
      title: '색 · 대비',
      top: 8,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (name, bg, fg) in swatches)
            Container(
              width: 104,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: V2Radius.ctlAll,
                border: Border.all(color: V2Colors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: V2Text.label.copyWith(color: fg)),
                  Text(
                    '${V2Contrast.ratio(fg, bg).toStringAsFixed(2)}:1',
                    style: V2Text.cap.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            height: 72,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: V2Gradients.hero,
              borderRadius: V2Radius.cardAll,
            ),
            child: Row(
              children: [
                Text(
                  'D+412',
                  style: V2Text.serif(size: 30, color: Colors.white),
                ),
                const Spacer(),
                Text('hero', style: V2Text.cap.copyWith(color: Colors.white)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 56,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: V2Gradients.heroSoft,
              borderRadius: V2Radius.cardAll,
            ),
            child: Text('heroSoft', style: V2Text.bodyStrong),
          ),
        ],
      ),
    );
  }

  Widget _type(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Section(
      title: '타입 스케일',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'display 28 오늘도 함께',
            style: V2Text.display.copyWith(color: p.ink),
          ),
          Text('title 22 우리 이야기', style: V2Text.title.copyWith(color: p.ink)),
          Text('head 18 다음 기념일', style: V2Text.head.copyWith(color: p.ink)),
          Text(
            'body 15 서윤이 오늘의 순간을 남겼어요.',
            style: V2Text.body.copyWith(color: p.ink),
          ),
          Text('cap 13 3분 전 · 성수동', style: V2Text.cap.copyWith(color: p.sub)),
          Text('label 12 새 소식', style: V2Text.label.copyWith(color: p.ink)),
          const SizedBox(height: 8),
          Text('우리의 412번째 날', style: V2Text.serif(size: 26, color: p.ink)),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    return V2Section(
      title: '버튼',
      child: Column(
        children: [
          V2Button(label: '기록 남기기', onPressed: () {}),
          const SizedBox(height: 8),
          V2Button(
            label: '사진 고르기',
            icon: V2Icons.gallery,
            variant: V2ButtonVariant.soft,
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          V2Button(
            label: '다른 방법',
            variant: V2ButtonVariant.ghost,
            onPressed: () {},
          ),
          V2Button(
            label: '나중에',
            variant: V2ButtonVariant.text,
            onPressed: () {},
          ),
          V2Button(
            label: '탈퇴하기',
            variant: V2ButtonVariant.danger,
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          V2Button(
            label: '로그아웃',
            variant: V2ButtonVariant.dangerSoft,
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          const V2Button(label: '입력을 마쳐 주세요', onPressed: null),
          const SizedBox(height: 8),
          Row(
            children: [
              V2Button(
                label: '저장',
                size: V2ButtonSize.sm,
                loading: _loading,
                onPressed: () async {
                  setState(() => _loading = true);
                  await Future<void>.delayed(const Duration(seconds: 1));
                  if (mounted) setState(() => _loading = false);
                },
              ),
              const SizedBox(width: 8),
              V2Button(
                label: '공유',
                icon: V2Icons.share,
                size: V2ButtonSize.sm,
                variant: V2ButtonVariant.soft,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputs(BuildContext context) {
    return V2Section(
      title: '입력 · 선택',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const V2TextField(label: '이메일', hint: 'name@example.com'),
          const SizedBox(height: 16),
          const V2TextField(
            label: '비밀번호',
            password: true,
            help: '영문과 숫자를 섞어 8자 이상',
          ),
          const SizedBox(height: 16),
          const V2TextField(label: '이름', error: '이름을 입력해 주세요'),
          const SizedBox(height: 16),
          const V2TextField(
            label: '한마디',
            maxLines: 3,
            hint: '서윤에게 남길 말',
            help: '서윤에게만 보여요',
          ),
          const SizedBox(height: 16),
          V2Segmented<int>(
            segments: const [
              V2Segment(value: 0, label: '나'),
              V2Segment(value: 1, label: '우리'),
            ],
            selected: _seg,
            onChanged: (v) => setState(() => _seg = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              V2Toggle(
                value: _toggle,
                onChanged: (v) => setState(() => _toggle = v),
                semanticLabel: '알림 받기',
              ),
              const V2Toggle(
                value: false,
                onChanged: null,
                semanticLabel: '꺼짐',
              ),
            ],
          ),
          V2Check(
            value: _check,
            label: '(필수) 이용약관에 동의해요',
            onChanged: (v) => setState(() => _check = v),
          ),
        ],
      ),
    );
  }

  Widget _lists(BuildContext context) {
    return V2Section(
      title: '카드 · 리스트',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2Card(
            onTap: () => showV2Snack(context, '카드를 눌렀어요'),
            child: Row(
              children: [
                const V2AvatarPair(me: '민지', partner: '서윤'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘의 기록', style: V2Text.head),
                      Text('서윤이 먼저 남겼어요', style: V2Text.cap),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          V2Card(
            variant: V2CardVariant.soft,
            child: Text('soft 카드예요', style: V2Text.body),
          ),
          const SizedBox(height: 12),
          V2Card(
            variant: V2CardVariant.flat,
            child: Text('flat 카드예요', style: V2Text.body),
          ),
          const SizedBox(height: 12),
          V2List(
            children: [
              V2ListTile(
                icon: V2Icons.event,
                title: '기념일',
                subtitle: '다음: 500일 · 88일 남음',
                onTap: () {},
              ),
              V2ListTile(
                icon: V2Icons.bell,
                tone: V2Tone.lilac,
                title: '알림 받기',
                trailing: V2Toggle(
                  value: _toggle,
                  onChanged: (v) => setState(() => _toggle = v),
                ),
              ),
              V2ListTile(
                leading: const V2Avatar(
                  name: '서윤',
                  color: V2Avatar.partnerColor,
                ),
                title: '서윤',
                subtitle: '연결된 지 412일',
                trailing: const V2Badge(count: 2),
                onTap: () {},
              ),
              V2ListTile(
                icon: V2Icons.logout,
                title: '로그아웃',
                destructive: true,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context) {
    const filters = ['전체', '가 본 곳', '가고 싶은 곳'];
    return V2Section(
      title: '칩 · 뱃지 · 아바타',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < filters.length; i++)
                V2Chip(
                  label: filters[i],
                  selected: _filter == i,
                  onTap: () => setState(() => _filter = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              V2Chip(label: '장미', tone: V2Tone.rose),
              V2Chip(label: '연결됨', tone: V2Tone.ok, icon: V2Icons.ok),
              V2Chip(label: '확인 필요', tone: V2Tone.warn),
              V2Chip(label: '실패', tone: V2Tone.err),
              V2Chip(label: '하늘', tone: V2Tone.sky),
              V2Chip(label: '라일락', tone: V2Tone.lilac),
              V2Chip(label: '세이지', tone: V2Tone.sage),
              V2Chip(label: '복숭아', tone: V2Tone.peach),
              V2Chip(label: '꿀', tone: V2Tone.honey),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              V2Badge(count: 3),
              SizedBox(width: 8),
              V2Badge(count: 120),
              SizedBox(width: 8),
              V2Badge.dot(),
              SizedBox(width: 16),
              V2Avatar(name: '민지', size: V2AvatarSize.sm),
              SizedBox(width: 8),
              V2Avatar(name: '서윤', color: V2Avatar.partnerColor),
              SizedBox(width: 8),
              V2Avatar(name: '민지', size: V2AvatarSize.lg),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banners(BuildContext context) {
    return V2Section(
      title: '배너',
      child: Column(
        children: [
          if (_bannerVisible)
            V2Banner(
              tone: V2BannerTone.info,
              title: '새로워진 비밀기지',
              message: '홈에서 오늘 카드를 바로 눌러 기록할 수 있어요.',
              onDismiss: () => setState(() => _bannerVisible = false),
            ),
          const SizedBox(height: 8),
          const V2Banner(tone: V2BannerTone.ok, message: '서윤과 연결됐어요'),
          const SizedBox(height: 8),
          V2Banner(
            tone: V2BannerTone.warn,
            message: '위치 권한이 꺼져 있어요',
            actionLabel: '설정 열기',
            onAction: () {},
          ),
          const SizedBox(height: 8),
          const V2Banner(tone: V2BannerTone.err, message: '사진을 올리지 못했어요'),
          const SizedBox(height: 8),
          const V2Banner.offline(),
        ],
      ),
    );
  }

  Widget _overlays(BuildContext context) {
    return V2Section(
      title: '시트 · 다이얼로그 · 스낵바',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          V2Button(
            label: '시트',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.soft,
            onPressed: () => showV2Sheet<void>(
              context,
              title: '정렬',
              subtitle: '기록을 어떤 순서로 볼까요?',
              builder: (ctx) => V2List(
                children: [
                  V2ListTile(title: '최신순', onTap: () => Navigator.pop(ctx)),
                  V2ListTile(title: '오래된순', onTap: () => Navigator.pop(ctx)),
                ],
              ),
            ),
          ),
          V2Button(
            label: '다이얼로그',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.soft,
            onPressed: () => showV2Dialog<void>(
              context,
              title: '사진을 저장했어요',
              message: '앨범에서 확인할 수 있어요.',
              icon: V2Icons.ok,
              iconTone: V2Tone.ok,
              actions: const [V2DialogAction(label: '확인')],
            ),
          ),
          V2Button(
            label: '확인(위험)',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.soft,
            onPressed: () async {
              final ok = await showV2Confirm(
                context,
                title: '기록을 지울까요?',
                message: '지운 기록은 되돌릴 수 없어요.',
                confirmLabel: '지우기',
                destructive: true,
              );
              if (context.mounted) {
                showV2Snack(context, ok ? '기록을 지웠어요' : '취소했어요');
              }
            },
          ),
          V2Button(
            label: '스낵바',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.soft,
            onPressed: () => showV2Snack(
              context,
              '기록을 지웠어요',
              actionLabel: '되돌리기',
              onAction: () {},
            ),
          ),
          V2Button(
            label: '권한: 위치',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.soft,
            onPressed: () =>
                showV2PermissionSheet(context, V2PermissionKind.location),
          ),
          V2Button(
            label: '권한 거부: 카메라',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.soft,
            onPressed: () => showV2PermissionSheet(
              context,
              V2PermissionKind.camera,
              denied: true,
            ),
          ),
          V2Button(
            label: '탈퇴 시트',
            size: V2ButtonSize.sm,
            variant: V2ButtonVariant.dangerSoft,
            onPressed: () => showV2ConfirmDestructiveSheet(
              context,
              title: '정말 탈퇴할까요?',
              message: '탈퇴하면 아래 내용이 모두 사라져요.',
              consequences: const ['서윤과의 연결이 끊어져요', '기록과 사진이 모두 삭제돼요'],
              acknowledgement: '모두 삭제되는 것을 확인했어요',
              confirmLabel: '탈퇴하기',
            ),
          ),
        ],
      ),
    );
  }

  Widget _states(BuildContext context) {
    return V2Section(
      title: '빈 · 오류 · 로딩 상태',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2Card(
            variant: V2CardVariant.flat,
            padding: EdgeInsets.zero,
            child: V2EmptyState(
              illustration: const V2SceneIllustration(V2Scene.hearts),
              title: '아직 남긴 기록이 없어요',
              body: '오늘의 순간을 서윤과 나눠 보세요.',
              actionLabel: '첫 기록 남기기',
              onAction: () {},
            ),
          ),
          const SizedBox(height: 12),
          V2Card(
            variant: V2CardVariant.flat,
            padding: EdgeInsets.zero,
            child: V2ErrorState(onRetry: () {}),
          ),
          const SizedBox(height: 12),
          V2Card(
            variant: V2CardVariant.flat,
            padding: EdgeInsets.zero,
            child: V2ErrorState.offline(onRetry: () {}),
          ),
          const SizedBox(height: 12),
          V2Card(
            variant: V2CardVariant.flat,
            padding: EdgeInsets.zero,
            child: V2EmptyState.unpaired(onAction: () {}),
          ),
          const SizedBox(height: 12),
          const V2Card(
            variant: V2CardVariant.flat,
            child: V2SkeletonList(count: 3),
          ),
          const SizedBox(height: 12),
          const V2SkeletonCard(),
          const SizedBox(height: 12),
          V2Card(
            variant: V2CardVariant.flat,
            padding: const EdgeInsets.all(20),
            child: V2PermissionSheet(
              kind: V2PermissionKind.notification,
              onChoice: (_) {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context) {
    return V2Section(
      title: '진행 · 일러스트',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              V2ProgressRing(
                value: 0.7,
                semanticLabel: '이번 주 기록',
                center: Text('70%', style: V2Text.label),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: V2ProgressBar(value: 0.6, semanticLabel: '5단계 중 3단계'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              V2SceneIllustration(V2Scene.hearts, width: 100),
              V2SceneIllustration(V2Scene.couple, width: 100),
              V2SceneIllustration(V2Scene.map, width: 100),
              V2SceneIllustration(V2Scene.photo, width: 100),
              V2SceneIllustration(V2Scene.offline, width: 100),
              V2SceneIllustration(V2Scene.letter, width: 100),
              V2SceneIllustration(V2Scene.calendar, width: 100),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: V2PhotoPlaceholder(
                    seed: i,
                    aspectRatio: 1,
                    icon: i == 0 ? V2Icons.image : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _headers(BuildContext context) {
    final p = V2Palette.of(context);
    Widget frame(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: V2Radius.ctlAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    return V2Section(
      title: '상단 바 3종',
      child: Column(
        children: [
          frame(
            V2Header(
              title: '기록',
              showBack: false,
              actions: [
                V2IconButton(
                  icon: V2Icons.add,
                  tooltip: '기록 추가',
                  onPressed: () {},
                ),
              ],
            ),
          ),
          frame(V2Header(title: '알림 설정', showBack: true, onBack: () {})),
          frame(
            V2Header(
              title: '개인정보·권한',
              subtitle: '언제든 바꿀 수 있어요',
              showBack: true,
              large: true,
              onBack: () {},
            ),
          ),
        ],
      ),
    );
  }
}
