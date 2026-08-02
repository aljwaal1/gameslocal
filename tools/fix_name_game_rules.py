from pathlib import Path

path = Path('lib/games/name_animal_object/name_animal_object_game.dart')
text = path.read_text(encoding='utf-8')

old_normalize = """  String _normalize(String v) => v
      .trim()
      .replaceAll(RegExp(r'[إأآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase();
  bool _isValid(String a) =>
      a.trim().isNotEmpty && _normalize(a).startsWith(_normalize(_letter));
"""

new_normalize = """  String _normalize(String v) => v
      .trim()
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\\s+'), '')
      .toLowerCase();

  bool _isValid(String answer, String category) {
    final normalized = _normalize(answer);
    const shortWordsByCategory = <String, Set<String>>{
      'اسم': <String>{'مي'},
      'حيوان': <String>{'دب', 'قط', 'بط'},
      'جماد': <String>{'زر'},
      'نبات': <String>{'رز', 'بن'},
      'بلاد': <String>{},
    };
    final acceptedTwoLetterWord =
        shortWordsByCategory[category]?.contains(normalized) ?? false;
    final validLength = normalized.length >= 3 || acceptedTwoLetterWord;
    return validLength && normalized.startsWith(_normalize(_letter));
  }
"""

if old_normalize not in text:
    raise SystemExit('Could not find old normalization/validation block')
text = text.replace(old_normalize, new_normalize)
text = text.replace('if (!_isValid(a)) return 0;', 'if (!_isValid(a, c)) return 0;')

old_proposal = """      'newPoints': value,
      'approvals': <String>{_myId},
    };
"""
new_proposal = """      'newPoints': value,
      'approvals': <String>{},
      'voters': <String>{},
    };
"""
if old_proposal not in text:
    raise SystemExit('Could not find proposal approvals block')
text = text.replace(old_proposal, new_proposal)

old_vote_send = """    _network?.sendMove({
      'action': 'categories_score_vote',
      'proposalId': id,
      'approve': approve == true,
    }, senderId: _myId);
"""
new_vote_send = """    if (_isHost) {
      _registerVote(id, _myId, approve == true);
    } else {
      _network?.sendMove({
        'action': 'categories_score_vote',
        'proposalId': id,
        'approve': approve == true,
      }, senderId: _myId);
    }
"""
if old_vote_send not in text:
    raise SystemExit('Could not find vote send block')
text = text.replace(old_vote_send, new_vote_send)

old_register = """  void _registerVote(String proposalId, String voterId, bool approve) {
    final p = _proposals[proposalId];
    if (p == null || !approve) return;
    final approvals = p['approvals'] as Set<String>;
    approvals.add(voterId);
    if (approvals.length < 2) return;
"""
new_register = """  void _registerVote(String proposalId, String voterId, bool approve) {
    final p = _proposals[proposalId];
    if (p == null) return;
    final voters = p['voters'] as Set<String>;
    if (!voters.add(voterId)) return;
    if (!approve) return;
    final approvals = p['approvals'] as Set<String>;
    approvals.add(voterId);
    if (approvals.length < 2) return;
"""
if old_register not in text:
    raise SystemExit('Could not find vote registration block')
text = text.replace(old_register, new_register)

old_snackbar = "تم إرسال طلب التعديل ويحتاج موافقة لاعبين على الأقل"
new_snackbar = "تم إرسال طلب التعديل ويحتاج موافقة صريحة من لاعبين مختلفين"
text = text.replace(old_snackbar, new_snackbar)

path.write_text(text, encoding='utf-8')
