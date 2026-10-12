import 'moment.dart';

class MomentEditItem {
  final Moment? post;
  final MomentMedia? media;
  const MomentEditItem.existing(Moment value) : post = value, media = null;
  const MomentEditItem.added(MomentMedia value) : media = value, post = null;
}

/// The original group supplies immutable identity and author information.
class MomentEdit {
  final List<Moment> original;
  final MomentDraft fields;
  final List<MomentEditItem> items;
  const MomentEdit({
    required this.original,
    required this.fields,
    required this.items,
  });
}
