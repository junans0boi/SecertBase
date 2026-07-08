import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/main_design.dart';
import '../../core/auth_service.dart';

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _auth = AuthService();

  void _linkPartner() async {
    if (_loading) return;
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _auth.setPartner(code);

    if (success) {
      await _auth.getProfile(); // Refresh profile
    } else {
      setState(() {
        _loading = false;
        _error = '유효하지 않은 회원코드이거나 연결할 수 없습니다.';
      });
    }
  }

  void _copyMyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원코드가 복사되었습니다. 상대방에게 전달해 주세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myCode = _auth.user?['UserCode'] ?? '??????';

    return Scaffold(
      backgroundColor: kMainBg,
      body: CozyPage(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    const CozyMascot(size: 80),
                    const SizedBox(height: 20),
                    Text('애인 연결하기', style: mainTitle(size: 32)),
                    const SizedBox(height: 12),
                    Text(
                      '두 분 중 한 분만 코드를 입력하면\n자동으로 서로 연결됩니다.',
                      style: mainBody(size: 14, color: kMainSub),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _myCodeCard(myCode),
                    const SizedBox(height: 24),
                    const Divider(color: kMainLine),
                    const SizedBox(height: 24),
                    _partnerForm(),
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () => _auth.logout(),
                      child: Text('다른 계정으로 로그인', style: mainBody(size: 13, color: kMainMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _myCodeCard(String code) {
    return MainCard(
      padding: const EdgeInsets.all(20),
      color: kMainSageSoft,
      child: Column(
        children: [
          Text('내 회원코드', style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            code,
            style: mainTitle(size: 40, color: kMainInk, weight: FontWeight.w800, letterSpacing: 4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _copyMyCode(code),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('내 코드 복사하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kMainInk,
                side: const BorderSide(color: kMainSage),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerForm() {
    return MainCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('상대방의 코드 입력', style: mainBody(size: 13, color: kMainSub, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: mainTitle(size: 26, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'ABC123',
              filled: true,
              fillColor: kMainPaperSoft,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Center(child: Text(_error!, style: mainBody(size: 13, color: kError))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _linkPartner,
              style: FilledButton.styleFrom(
                backgroundColor: kMainInk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('연결하기', style: mainBody(size: 16, color: Colors.white, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
