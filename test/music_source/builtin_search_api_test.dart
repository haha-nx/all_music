import 'package:all_music/music_source/builtin/kugou_search_api.dart';
import 'package:all_music/music_source/builtin/kuwo_search_api.dart';
import 'package:all_music/music_source/builtin/migu_search_api.dart';
import 'package:all_music/music_source/builtin/netease_search_api.dart';
import 'package:all_music/music_source/builtin/tencent_search_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('builtin search api parsers', () {
    test('netease parses songs', () {
      final api = NeteaseSearchApi(sourceId: 'builtin_wy', dio: Dio());
      final tracks = api.parseResponse('''
      {
        "result": {
          "songs": [
            {
              "id": 5257138,
              "name": "屋顶",
              "duration": 319039,
              "artists": [{"name": "周杰伦"}],
              "album": {"name": "男女情歌对唱冠军全记录", "picUrl": "https://p1.music.126.net/cover.jpg"}
            }
          ]
        }
      }
      ''');

      expect(tracks, hasLength(1));
      expect(tracks.first.id, '5257138');
      expect(tracks.first.title, '屋顶');
      expect(tracks.first.artist, '周杰伦');
      expect(tracks.first.durationMs, 319039);
      expect(tracks.first.coverUrl, 'https://p1.music.126.net/cover.jpg');
      expect(tracks.first.sourceKey, 'wy');
    });

    test('tencent parses songs and builds cover url', () {
      final api = TencentSearchApi(sourceId: 'builtin_tx', dio: Dio());
      final tracks = api.parseResponse('''
      {
        "code": 0,
        "data": {
          "song": {
            "list": [
              {
                "songmid": "0039MnYb0qxYhV",
                "songname": "晴天",
                "interval": 269,
                "albumname": "叶惠美",
                "albummid": "000MkMni19ClKG",
                "singer": [{"name": "周杰伦"}]
              }
            ]
          }
        }
      }
      ''');

      expect(tracks, hasLength(1));
      expect(tracks.first.id, '0039MnYb0qxYhV');
      expect(tracks.first.title, '晴天');
      expect(tracks.first.artist, '周杰伦');
      expect(tracks.first.durationMs, 269000);
      expect(
        tracks.first.coverUrl,
        'https://y.gtimg.cn/music/photo_new/T002R300x300M000000MkMni19ClKG.jpg',
      );
    });

    test('kugou parses songs', () {
      final api = KugouSearchApi(sourceId: 'builtin_kg', dio: Dio());
      final tracks = api.parseResponse('''
      {
        "error_code": 0,
        "data": {
          "lists": [
            {
              "Audioid": 20505418,
              "SongName": "晴天",
              "Duration": 269,
              "AlbumName": "叶惠美",
              "Singers": [{"name": "周杰伦"}],
              "Image": "https://img.example.com/cover.jpg"
            }
          ]
        }
      }
      ''');

      expect(tracks, hasLength(1));
      expect(tracks.first.id, '20505418');
      expect(tracks.first.title, '晴天');
      expect(tracks.first.artist, '周杰伦');
      expect(tracks.first.durationMs, 269000);
      expect(tracks.first.coverUrl, 'https://img.example.com/cover.jpg');
    });

    test('kuwo parses songs and normalizes rid', () {
      final api = KuwoSearchApi(sourceId: 'builtin_kw', dio: Dio());
      final tracks = api.parseResponse('''
      {
        "abslist": [
          {
            "MUSICRID": "MUSIC_228908",
            "SONGNAME": "晴天",
            "ARTIST": "周杰伦",
            "ALBUM": "叶惠美",
            "DURATION": 269,
            "web_albumpic_short": "/star/albumcover/1.jpg"
          }
        ]
      }
      ''');

      expect(tracks, hasLength(1));
      expect(tracks.first.id, '228908');
      expect(tracks.first.title, '晴天');
      expect(tracks.first.artist, '周杰伦');
      expect(tracks.first.coverUrl, 'https://img1.kuwo.cn/star/albumcover/1.jpg');
    });

    test('migu parses nested result list', () {
      final api = MiguSearchApi(sourceId: 'builtin_mg', dio: Dio());
      final tracks = api.parseResponse('''
      {
        "code": "000000",
        "songResultData": {
          "resultList": [
            [
              {
                "songId": "1140505222",
                "name": "圣诞星（feat. 杨瑞代）",
                "singers": [{"name": "周杰伦"}],
                "albums": [{"name": "圣诞星"}],
                "imgItems": [{"img": "https://d.musicapp.migu.cn/a.jpg"}]
              }
            ]
          ]
        }
      }
      ''');

      expect(tracks, hasLength(1));
      expect(tracks.first.id, '1140505222');
      expect(tracks.first.title, '圣诞星（feat. 杨瑞代）');
      expect(tracks.first.artist, '周杰伦');
      expect(tracks.first.album, '圣诞星');
      expect(tracks.first.coverUrl, 'https://d.musicapp.migu.cn/a.jpg');
    });
  });
}
