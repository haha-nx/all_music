package com.example.all_music

import com.ryanheise.audioservice.AudioServiceFragmentActivity

/// audio_service 官方推荐的方式：直接继承 AudioServiceFragmentActivity
/// 这样 audio_service 插件可以自动管理 FlutterEngine 的提供
class MainActivity : AudioServiceFragmentActivity()
