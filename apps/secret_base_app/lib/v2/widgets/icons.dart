import 'package:flutter/material.dart';

/// The 2.0 icon vocabulary. Always rounded Material Symbols
/// (`Icons.*_rounded`), 24px, `currentColor` via [IconTheme].
///
/// Never use emoji as UI icons. Emoji are content only (감정, 반응).
/// If you need an icon that is not listed here, use the `_rounded` variant
/// of the Material icon and consider adding it here.
abstract final class V2Icons {
  // Tabs
  static const home = Icons.home_rounded;
  static const record = Icons.auto_stories_rounded;
  static const map = Icons.map_rounded;
  static const play = Icons.sports_esports_rounded;
  static const more = Icons.more_horiz_rounded;

  // Navigation
  static const back = Icons.arrow_back_ios_new_rounded;
  static const close = Icons.close_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const expand = Icons.expand_more_rounded;
  static const menu = Icons.more_vert_rounded;

  // Actions
  static const add = Icons.add_rounded;
  static const edit = Icons.edit_rounded;
  static const delete = Icons.delete_outline_rounded;
  static const share = Icons.ios_share_rounded;
  static const copy = Icons.content_copy_rounded;
  static const send = Icons.send_rounded;
  static const search = Icons.search_rounded;
  static const refresh = Icons.refresh_rounded;
  static const settings = Icons.settings_rounded;
  static const filter = Icons.tune_rounded;
  static const download = Icons.download_rounded;
  static const logout = Icons.logout_rounded;

  // Media / content
  static const camera = Icons.photo_camera_rounded;
  static const gallery = Icons.photo_library_rounded;
  static const image = Icons.image_rounded;
  static const video = Icons.videocam_rounded;
  static const text = Icons.notes_rounded;
  static const heart = Icons.favorite_rounded;
  static const heartOutline = Icons.favorite_border_rounded;
  static const calendar = Icons.calendar_month_rounded;
  static const event = Icons.cake_rounded;
  static const location = Icons.place_rounded;
  static const myLocation = Icons.my_location_rounded;
  static const bell = Icons.notifications_rounded;
  static const bellOff = Icons.notifications_off_rounded;
  static const chat = Icons.chat_bubble_rounded;
  static const star = Icons.star_rounded;
  static const sparkle = Icons.auto_awesome_rounded;
  static const person = Icons.person_rounded;
  static const couple = Icons.people_alt_rounded;
  static const link = Icons.link_rounded;
  static const lock = Icons.lock_rounded;
  static const visibility = Icons.visibility_rounded;
  static const visibilityOff = Icons.visibility_off_rounded;
  static const phone = Icons.call_rounded;
  static const help = Icons.help_rounded;
  static const shop = Icons.storefront_rounded;
  static const care = Icons.spa_rounded;
  static const base = Icons.cottage_rounded;

  // Status
  static const info = Icons.info_rounded;
  static const ok = Icons.check_circle_rounded;
  static const warn = Icons.warning_rounded;
  static const error = Icons.error_rounded;
  static const check = Icons.check_rounded;
  static const offline = Icons.cloud_off_rounded;
  static const shield = Icons.shield_rounded;
}
