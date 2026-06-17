import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

const defaultSocketUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'http://localhost:4100',
);

void main() {
  runApp(const SecretBaseApp());
}

class SecretBaseApp extends StatelessWidget {
  const SecretBaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secret Base',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
      ),
      home: const RealtimeLobbyPage(),
    );
  }
}

class RealtimeLobbyPage extends StatefulWidget {
  const RealtimeLobbyPage({super.key});

  @override
  State<RealtimeLobbyPage> createState() => _RealtimeLobbyPageState();
}

class _RealtimeLobbyPageState extends State<RealtimeLobbyPage> {
  final _serverController = TextEditingController(text: defaultSocketUrl);
  final _roomController = TextEditingController(text: 'secret-room');
  final _secretController = TextEditingController(text: 'secretbase');

  final _rouletteOptions = const ['야식', '벌칙', '결제자', '면제권'];
  final _telepathyOptions = const ['치킨', '피자', '족발', '회'];
  final List<String> _logs = [];
  final List<String> _presenceUsers = [];

  String _selectedUser = 'jun';
  io.Socket? _socket;
  bool _isConnected = false;
  String _status = '대기 중';
  int? _lastDice;
  String? _lastRoulette;
  int? _lastPingMs;
  String? _rpsChoice;
  String? _rpsResult;
  String? _telepathyChoice;
  String? _telepathyResult;
  int? _pirateSlot;

  // Phase 2 게임 상태
  String? _yutGameId;
  String? _yutTurn;
  List<dynamic>? _yutP1Pieces;
  List<dynamic>? _yutP2Pieces;
  
  String? _unoGameId;
  String? _unoTurn;
  int? _unoP1Count;
  int? _unoP2Count;
  List<dynamic>? _unoHand;
  String? _unoTopCard;
  
  String? _bombGameId;
  String? _bombHolder;
  int? _bombTimer;

  @override
  void dispose() {
    _socket?.dispose();
    _serverController.dispose();
    _roomController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _appendLog(String message) {
    setState(() {
      _logs.insert(0, message);
      if (_logs.length > 60) {
        _logs.removeLast();
      }
    });
  }

  void _connect() {
    _socket?.dispose();
    setState(() {
      _isConnected = false;
      _status = '연결 시도 중...';
    });

    final socket = io.io(
      _serverController.text.trim(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _appendLog('Socket 연결 성공');
      socket.emitWithAck(
        'session:join',
        {
          'userId': _selectedUser,
          'roomCode': _roomController.text.trim(),
          'roomSecret': _secretController.text.trim(),
        },
        ack: (response) {
          final map = _asMap(response);
          if (map['ok'] == true) {
            setState(() {
              _isConnected = true;
              _status = '입장 완료';
            });
            _appendLog('방 입장 완료');
            
            // 재접속 시 게임 세션 복원
            socket.emitWithAck(
              'session:restore',
              {},
              ack: (restoreResponse) {
                final restoreMap = _asMap(restoreResponse);
                if (restoreMap['ok'] == true) {
                  final activeGames = restoreMap['activeGames'];
                  if (activeGames is Map) {
                    _restoreGameState(_asMap(activeGames));
                  }
                }
              },
            );
            return;
          }
          final reason = map['reason'] ?? 'unknown';
          setState(() {
            _status = '입장 실패: $reason';
            _isConnected = false;
          });
          _appendLog('방 입장 실패: $reason');
        },
      );
    });

    socket.onConnectError((error) {
      setState(() {
        _status = '연결 실패';
        _isConnected = false;
      });
      _appendLog('연결 오류: $error');
    });

    socket.onDisconnect((_) {
      setState(() {
        _isConnected = false;
        _status = '연결 끊김';
      });
      _appendLog('연결 해제');
    });

    socket.on('room:presence', (payload) {
      final users = _asMap(payload)['users'];
      if (users is! List) {
        return;
      }
      setState(() {
        _presenceUsers
          ..clear()
          ..addAll(users.map((e) => '$e'));
      });
      _appendLog('현재 접속: ${_presenceUsers.join(", ")}');
    });

    socket.on('game:dice:result', (payload) {
      final value = _asMap(payload)['value'];
      if (value is int) {
        setState(() {
          _lastDice = value;
        });
        _appendLog('주사위 결과: $value');
      }
    });

    socket.on('game:roulette:result', (payload) {
      final selected = _asMap(payload)['selected'];
      if (selected is String) {
        setState(() {
          _lastRoulette = selected;
        });
        _appendLog('룰렛 결과: $selected');
      }
    });

    socket.on('game:rps:result', (payload) {
      final map = _asMap(payload);
      final winner = map['winner'];
      final choices = map['choices'];
      setState(() {
        _rpsResult = winner == 'draw'
            ? '무승부'
            : winner == _selectedUser
            ? '승리!'
            : '패배';
      });
      _appendLog('가위바위보 결과: $_rpsResult (선택: $choices)');
    });

    socket.on('game:telepathy:result', (payload) {
      final map = _asMap(payload);
      final success = map['success'] == true;
      final selected = map['selected'];
      setState(() {
        _telepathyResult = success ? '텔레파시 성공! ($selected)' : '실패';
      });
      _appendLog('텔레파시 결과: $_telepathyResult');
    });

    socket.on('game:pirate:result', (payload) {
      final map = _asMap(payload);
      final bombSlot = map['bombSlot'];
      if (bombSlot is int) {
        setState(() {
          _pirateSlot = bombSlot;
        });
        _appendLog('해적 룰렛 폭탄 위치: $bombSlot');
      }
    });

    // Phase 2 게임 리스너
    socket.on('game:yut:created', (data) {
      final map = _asMap(data);
      setState(() {
        _yutGameId = map['gameId'] as String?;
        _yutTurn = map['turn'] as String?;
      });
      _appendLog('윷놀이 시작! 턴: $_yutTurn');
    });

    socket.on('game:yut:threw', (data) {
      final map = _asMap(data);
      final player = map['player'];
      final result = map['result'];
      _appendLog('$player 윷 던짐: $result');
    });

    socket.on('game:yut:moved', (data) {
      final map = _asMap(data);
      setState(() {
        _yutP1Pieces = map['p1Pieces'] as List<dynamic>?;
        _yutP2Pieces = map['p2Pieces'] as List<dynamic>?;
        _yutTurn = map['turn'] as String?;
      });
      _appendLog('말 이동 완료, 다음 턴: $_yutTurn');
    });

    socket.on('game:yut:won', (data) {
      final map = _asMap(data);
      final winner = map['winner'];
      _appendLog('🎉 윷놀이 승리: $winner');
      setState(() {
        _yutGameId = null;
      });
    });

    socket.on('game:uno:created', (data) {
      final map = _asMap(data);
      setState(() {
        _unoGameId = map['gameId'] as String?;
        _unoTurn = map['turn'] as String?;
        _unoHand = map['hand'] as List<dynamic>?;
        _unoTopCard = map['topCard'] as String?;
      });
      _appendLog('UNO 시작! 핸드: ${_unoHand?.length}장');
    });

    socket.on('game:uno:played', (data) {
      final map = _asMap(data);
      setState(() {
        _unoTurn = map['turn'] as String?;
        _unoP1Count = map['p1Count'] as int?;
        _unoP2Count = map['p2Count'] as int?;
        _unoTopCard = map['topCard'] as String?;
      });
      _appendLog('카드 플레이: ${map['player']} → $_unoTopCard');
    });

    socket.on('game:uno:drew', (data) {
      final map = _asMap(data);
      setState(() {
        _unoHand = map['newHand'] as List<dynamic>?;
      });
      _appendLog('카드 뽑기: +${map['count']}장');
    });

    socket.on('game:uno:won', (data) {
      final map = _asMap(data);
      final winner = map['winner'];
      _appendLog('🎉 UNO 승리: $winner');
      setState(() {
        _unoGameId = null;
      });
    });

    socket.on('game:bomb:created', (data) {
      final map = _asMap(data);
      setState(() {
        _bombGameId = map['gameId'] as String?;
        _bombHolder = map['holder'] as String?;
        _bombTimer = map['timer'] as int?;
      });
      _appendLog('폭탄 돌리기 시작! 홀더: $_bombHolder');
    });

    socket.on('game:bomb:question', (data) {
      final map = _asMap(data);
      final question = map['question'];
      _appendLog('❓ $question');
    });

    socket.on('game:bomb:passed', (data) {
      final map = _asMap(data);
      setState(() {
        _bombHolder = map['newHolder'] as String?;
      });
      _appendLog('폭탄 패스! 새 홀더: $_bombHolder');
    });

    socket.on('game:bomb:exploded', (data) {
      final map = _asMap(data);
      final loser = map['loser'];
      _appendLog('💣 폭탄 터짐! 패배: $loser');
      setState(() {
        _bombGameId = null;
      });
    });

    socket.connect();
    _socket = socket;
  }

  void _restoreGameState(Map<String, dynamic> activeGames) {
    setState(() {
      // 윷놀이 복원
      if (activeGames.containsKey('yut')) {
        final yut = _asMap(activeGames['yut']);
        _yutGameId = yut['gameId'] as String?;
        _yutTurn = yut['turn'] as String?;
        _yutP1Pieces = yut['p1Pieces'] as List<dynamic>?;
        _yutP2Pieces = yut['p2Pieces'] as List<dynamic>?;
        _appendLog('✅ 윷놀이 게임 복원: $_yutGameId, 턴: $_yutTurn');
      }

      // UNO 복원
      if (activeGames.containsKey('uno')) {
        final uno = _asMap(activeGames['uno']);
        _unoGameId = uno['gameId'] as String?;
        _unoTurn = uno['turn'] as String?;
        _unoTopCard = uno['topCard'] as String?;
        _unoP1Count = uno['p1Count'] as int?;
        _unoP2Count = uno['p2Count'] as int?;
        _unoHand = uno['hand'] as List<dynamic>?;
        _appendLog('✅ UNO 게임 복원: $_unoGameId, 핸드: ${_unoHand?.length}장');
      }

      // 폭탄 복원
      if (activeGames.containsKey('bomb')) {
        final bomb = _asMap(activeGames['bomb']);
        _bombGameId = bomb['gameId'] as String?;
        _bombHolder = bomb['holder'] as String?;
        _bombTimer = bomb['timer'] as int?;
        _appendLog('✅ 폭탄 게임 복원: $_bombGameId, 홀더: $_bombHolder');
      }
    });
  }

  void _sendPing() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _socket?.emitWithAck(
      'sync:ping',
      {'clientTs': now},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          return;
        }
        final serverTs = map['serverTs'];
        if (serverTs is int) {
          final latency = DateTime.now().millisecondsSinceEpoch - now;
          setState(() {
            _lastPingMs = latency;
          });
          _appendLog('Ping 성공 (RTT ${latency}ms, serverTs: $serverTs)');
        }
      },
    );
  }

  void _rollDice() {
    _socket?.emitWithAck(
      'game:dice:roll',
      {},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('주사위 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  void _spinRoulette() {
    _socket?.emitWithAck(
      'game:roulette:spin',
      {'options': _rouletteOptions},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('룰렛 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  void _playRps(String choice) {
    setState(() {
      _rpsChoice = choice;
    });
    _socket?.emitWithAck(
      'game:rps:select',
      {'choice': choice},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('가위바위보 실패: ${map['reason'] ?? "unknown"}');
        } else if (map['waiting'] == true) {
          _appendLog('가위바위보 선택 완료, 상대방 대기 중...');
        }
      },
    );
  }

  void _playTelepathy(String choice) {
    setState(() {
      _telepathyChoice = choice;
    });
    _socket?.emitWithAck(
      'game:telepathy:select',
      {'choice': choice, 'options': _telepathyOptions},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('텔레파시 실패: ${map['reason'] ?? "unknown"}');
        } else if (map['waiting'] == true) {
          _appendLog('텔레파시 선택 완료, 상대방 대기 중...');
        }
      },
    );
  }

  void _spinPirate() {
    _socket?.emitWithAck(
      'game:pirate:spin',
      {'slots': 8},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('해적 룰렛 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  // Phase 2 게임 핸들러
  void _newYutGame() {
    _socket?.emitWithAck(
      'game:yut:new',
      {},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('윷놀이 시작 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  void _throwYut() {
    _socket?.emitWithAck(
      'game:yut:throw',
      {},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('윷 던지기 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  void _newUnoGame() {
    _socket?.emitWithAck(
      'game:uno:new',
      {},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('UNO 시작 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  void _drawUnoCard() {
    _socket?.emitWithAck(
      'game:uno:draw',
      {},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('카드 뽑기 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  void _newBombGame() {
    _socket?.emitWithAck(
      'game:bomb:new',
      {'category': 'general'},
      ack: (response) {
        final map = _asMap(response);
        if (map['ok'] != true) {
          _appendLog('폭탄 게임 시작 실패: ${map['reason'] ?? "unknown"}');
        }
      },
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    log('Unexpected payload: $value');
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secret Base · Realtime MVP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(labelText: 'Socket URL'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: 'Room Code'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _secretController,
              decoration: const InputDecoration(labelText: 'Room Secret'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedUser,
              items: const [
                DropdownMenuItem(value: 'jun', child: Text('jun')),
                DropdownMenuItem(value: 'gf', child: Text('gf')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedUser = value;
                });
              },
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: _connect, child: const Text('연결/재연결')),
                FilledButton.tonal(
                  onPressed: _isConnected ? _sendPing : null,
                  child: const Text('Ping'),
                ),
                FilledButton.tonal(
                  onPressed: _isConnected ? _rollDice : null,
                  child: const Text('주사위'),
                ),
                FilledButton.tonal(
                  onPressed: _isConnected ? _spinRoulette : null,
                  child: const Text('룰렛'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const Text('가위바위보', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _isConnected ? () => _playRps('rock') : null,
                  child: const Text('바위'),
                ),
                FilledButton.tonal(
                  onPressed: _isConnected ? () => _playRps('paper') : null,
                  child: const Text('보'),
                ),
                FilledButton.tonal(
                  onPressed: _isConnected ? () => _playRps('scissors') : null,
                  child: const Text('가위'),
                ),
              ],
            ),
            if (_rpsResult != null) Text('결과: $_rpsResult'),
            const SizedBox(height: 8),
            const Divider(),
            const Text('텔레파시', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _telepathyOptions
                  .map(
                    (opt) => FilledButton.tonal(
                      onPressed: _isConnected
                          ? () => _playTelepathy(opt)
                          : null,
                      child: Text(opt),
                    ),
                  )
                  .toList(),
            ),
            if (_telepathyResult != null) Text('결과: $_telepathyResult'),
            const SizedBox(height: 8),
            const Divider(),
            FilledButton.tonal(
              onPressed: _isConnected ? _spinPirate : null,
              child: const Text('해적 룰렛'),
            ),
            if (_pirateSlot != null) Text('폭탄 위치: $_pirateSlot'),
            const SizedBox(height: 8),
            const Divider(),
            
            // Phase 2: 윷놀이
            const Text('윷놀이', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _isConnected && _yutGameId == null ? _newYutGame : null,
                  child: const Text('새 게임'),
                ),
                FilledButton.tonal(
                  onPressed: _isConnected && _yutGameId != null && _yutTurn == _selectedUser 
                    ? _throwYut : null,
                  child: const Text('윷 던지기'),
                ),
              ],
            ),
            if (_yutGameId != null) Text('게임 ID: $_yutGameId, 턴: $_yutTurn'),
            const SizedBox(height: 8),
            const Divider(),
            
            // Phase 2: UNO
            const Text('UNO', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _isConnected && _unoGameId == null ? _newUnoGame : null,
                  child: const Text('새 게임'),
                ),
                FilledButton.tonal(
                  onPressed: _isConnected && _unoGameId != null && _unoTurn == _selectedUser 
                    ? _drawUnoCard : null,
                  child: const Text('카드 뽑기'),
                ),
              ],
            ),
            if (_unoGameId != null) 
              Text('핸드: ${_unoHand?.length ?? 0}장, 탑카드: $_unoTopCard'),
            const SizedBox(height: 8),
            const Divider(),
            
            // Phase 2: 폭탄 돌리기
            const Text('폭탄 돌리기', style: TextStyle(fontWeight: FontWeight.bold)),
            FilledButton.tonal(
              onPressed: _isConnected && _bombGameId == null ? _newBombGame : null,
              child: const Text('새 게임'),
            ),
            if (_bombGameId != null) 
              Text('폭탄 홀더: $_bombHolder, 타이머: ${_bombTimer ?? 0}초'),
            
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text('상태: $_status'),
                subtitle: Text(
                  '접속자: ${_presenceUsers.isEmpty ? "-" : _presenceUsers.join(", ")}\n'
                  '주사위: ${_lastDice ?? "-"} / 룰렛: ${_lastRoulette ?? "-"} / Ping: ${_lastPingMs ?? "-"}ms',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _logs.isEmpty
                    ? const Text('로그가 없습니다.')
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) => Text(
                          _logs[index],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
