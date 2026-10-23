# 1.3 medya prototipi (Adım 0)

`docs/pastronaut/PLAN-1.3.md` Adım 0 için atılacak bir prototip; ana uygulamaya kod taşınmaz. Sonuçlar planda
("Adım 0 sonuçları"). Gerçek Pastronaut'tan ayrı paket kimlikleri kullanır, iCloud'da yalnızca Development ortamında
kendi `ProtoMedia13` bölgesine yazar.

```sh
xcodegen generate
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
for t in MediaProto MediaProtoReader; do env -u SDKROOT xcodebuild -project MediaProto.xcodeproj -scheme $t \
  -configuration Debug -derivedDataPath build -destination 'platform=macOS' -allowProvisioningUpdates build; done
P=build/Build/Products/Debug
open -W -n $P/MediaProto.app --args send 10 25 50        # A: şifreli dosyaları gönderir
open -W -n $P/MediaProtoReader.app --args fetch           # B: ayrı uygulamada indirir ve doğrular
open -W -n $P/MediaProto.app --args write container       # gelen dosyayı kaydedip panoya koyar
open -W -n $P/MediaProtoReader.app --args read            # panodaki dosyayı korumalı alandan okur
open -W -n $P/MediaProto.app --args cleanup               # test bölgesini siler
open -W -n $P/MediaProto.app --args purge                 # kendi önbelleğini boşaltır (Reader için de)
/usr/bin/log show --last 10m --predicate 'subsystem == "com.xkbxyberk.pastronaut.mediaproto"' --style compact
```
Uygulamaları `open` ile çalıştır: böylece korumalı alan ve gizlilik izinleri uygulamanın kendisine uygulanır, kabuğa
değil. Mac'te pano testlerinden önce gerçek Pastronaut'u kapat (test kopyaları geçmişe düşmesin), sonra yeniden aç.
Yeni bir paket kimliğinin iCloud'da tanınması 10–15 dakika sürebilir ("Invalid bundle ID for container").
