import 'package:flutter/material.dart';

/// The 2.0 icon vocabulary. Light outlined Material icons (stroke style like the mockup), 24px, `currentColor` via [IconTheme].
///
/// Never use emoji as UI icons. Emoji are content only (감정, 반응).
/// If you need an icon that is not listed here, use the `_rounded` variant
/// of the Material icon and consider adding it here.
abstract final class V2Icons {
  // Tabs
  static const home = Icons.home_outlined;
  static const record = Icons.auto_stories_outlined;
  static const map = Icons.map_outlined;
  static const play = Icons.sports_esports_outlined;
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
  static const settings = Icons.settings_outlined;
  static const filter = Icons.tune_rounded;
  static const download = Icons.download_rounded;
  static const logout = Icons.logout_rounded;

  // Media / content
  static const camera = Icons.photo_camera_outlined;
  static const gallery = Icons.photo_library_outlined;
  static const image = Icons.image_outlined;
  static const video = Icons.videocam_outlined;
  static const text = Icons.notes_rounded;
  static const heart = Icons.favorite_border_rounded;
  static const heartOutline = Icons.favorite_border_rounded;
  static const calendar = Icons.calendar_month_outlined;
  static const event = Icons.cake_outlined;
  static const location = Icons.place_outlined;
  static const myLocation = Icons.my_location_outlined;
  static const bell = Icons.notifications_none_rounded;
  static const bellOff = Icons.notifications_off_outlined;
  static const chat = Icons.chat_bubble_outline_rounded;
  static const star = Icons.star_border_rounded;
  static const sparkle = Icons.wb_sunny_outlined;
  static const person = Icons.person_outline_rounded;
  static const couple = Icons.people_alt_outlined;
  static const link = Icons.link_rounded;
  static const lock = Icons.lock_outline_rounded;
  static const visibility = Icons.visibility_outlined;
  static const visibilityOff = Icons.visibility_off_outlined;
  static const phone = Icons.call_outlined;
  static const help = Icons.help_outline_rounded;
  static const shop = Icons.storefront_outlined;
  static const care = Icons.spa_outlined;
  static const base = Icons.cottage_outlined;

  // Status
  static const info = Icons.info_outline_rounded;
  static const ok = Icons.check_circle_outline_rounded;
  static const warn = Icons.warning_amber_rounded;
  static const error = Icons.error_outline_rounded;
  static const check = Icons.check_rounded;
  static const offline = Icons.cloud_off_outlined;
  static const shield = Icons.shield_outlined;
}
