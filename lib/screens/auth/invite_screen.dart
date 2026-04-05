import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _myCode;

  @override
  void initState() {
    super.initState();
    // 이미 coupleId가 있거나 연결되는 순간 캘린더로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen(currentUserModelProvider, (_, next) {
        final coupleId = next.valueOrNull?.coupleId ?? '';
        if (coupleId.isNotEmpty && mounted) {
          context.go('/calendar');
        }
      });
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCouple() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid = ref.read(authStateProvider).valueOrNull!.uid;
      final couple = await ref.read(firestoreServiceProvider).createCouple(uid);
      setState(() => _myCode = couple.inviteCode);
    } catch (e) {
      setState(() => _error = '코드 생성에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinCouple() async {
    if (_codeCtrl.text.trim().length != 6) {
      setState(() => _error = '6자리 코드를 입력하세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final uid = ref.read(authStateProvider).valueOrNull!.uid;
      final couple = await ref.read(firestoreServiceProvider)
          .joinByInviteCode(_codeCtrl.text.trim(), uid);
      if (couple == null) {
        setState(() => _error = '유효하지 않은 코드입니다.');
      } else {
        if (mounted) context.go('/calendar');
      }
    } catch (e) {
      setState(() => _error = '연결에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('파트너 연결')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link, size: 56, color: Color(0xFF42A5F5)),
              const SizedBox(height: 16),
              Text(
                '파트너와 캘린더를 연결하세요',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 40),

              // 내 초대 코드 생성
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('초대 코드 만들기',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('코드를 만들어서 파트너에게 공유하세요.',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      if (_myCode != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _myCode!,
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _myCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('코드가 복사되었습니다')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('파트너가 이 코드를 입력하면 연결됩니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ] else
                        OutlinedButton(
                          onPressed: _loading ? null : _createCouple,
                          child: const Text('내 초대 코드 생성'),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('또는', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),

              // 코드 입력
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('파트너 코드 입력',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('파트너가 공유한 6자리 코드를 입력하세요.',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeCtrl,
                        decoration: const InputDecoration(
                          hintText: '예) AB12CD',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                      ),
                      if (_error != null)
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loading ? null : _joinCouple,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('연결하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
