# Faz 5: yayın kontrol listesi (2026-10-17)

Durum işaretleri: ✅ bitti · ⏳ onay ya da kullanıcı adımı bekliyor · ⬜ yapılmadı.

## A. Yerelde hazırlananlar
- ✅ iPhone gizlilik bildirimi (`PrivacyInfo.xcprivacy`): uygulama, klavye, widget, Paylaş. Veri toplanmıyor, izleme yok.
  Gerekçeli API'ler: UserDefaults (CA92.1 uygulama, 1C8F.1 App Group), dosya tarihi (C617.1, App Group'taki anlık
  görüntü dosyası).
- ✅ Release derlemeleri: Mac ve iOS Release yapılandırmasında hatasız derleniyor (yalnızca DEBUG'daki test kancaları
  çıkıyor).
- ✅ Gizlilik politikası ve tanıtım sayfası: `docs/site/` (Türkçe + İngilizce, açık/koyu, telefona uygun).
- ✅ README Pastronaut'a göre yeniden yazıldı; "Maccy'ye dayanır, bağlantılı değildir" notu var. LICENSE'a telif
  satırımız eklendi (Maccy satırı korunuyor).
- ✅ İmza: anahtar zincirinde "Developer ID Application" sertifikası var (Mac'i App Store dışında dağıtmak için).

## B. Onay ya da kullanıcı adımı gerekenler (dışa dönük)
1. ⏳ **GitHub depo bilgileri:** açıklama hâlâ Maccy'nin ("Lightweight clipboard manager for macOS"), ana sayfa
   `maccy.app`, varsayılan dal `master`. Öneri: açıklama Pastronaut'a, ana sayfa Pages adresine, varsayılan dal
   `pastronaut` (`gh repo edit`).
2. ⏳ **GitHub Pages:** `gh-pages` dalında Maccy'nin sitesi ve `CNAME = maccy.app` duruyor; bu haliyle açmak Maccy'yi
   taklit etmek olur. Öneri: dalın içeriğini `docs/site/` ile değiştirmek (CNAME yok), Pages'i açmak.
   Adres: `https://xkbxyberk.github.io/pastronaut/` ve `…/privacy.html` (App Store'un istediği gizlilik adresi).
3. ⏳ **CloudKit Production şeması:** App Store, TestFlight ve Developer ID sürümleri Production ortamını kullanır;
   şema oraya gönderilmeden bu sürümlerde eşitleme çalışmaz. CloudKit Console › Pastronaut kapsayıcısı › "Deploy
   Schema Changes" (tarayıcıdan, senin hesabınla). Geri alınamaz: Production'a giden alan ve tür silinemez.
4. ⏳ **Sparkle güncelleme anahtarı:** Mac güncellemelerini imzalamak için EdDSA anahtar çifti (`generate_keys`).
   Gizli anahtar anahtar zincirine yazılır ve **yedeklenmelidir** (kaybolursa eski sürümler güncelleme alamaz);
   açık anahtar `Info.plist`'e `SUPublicEDKey` olarak girer.
5. ⏳ **Notarization bilgileri:** `xcrun notarytool store-credentials pastronaut --apple-id <e-posta> --team-id
   V88QY49A4T` (Apple Hesabı'nda üretilen uygulamaya özel parola ile; parolayı yalnızca sen girersin).
6. ⬜ **Mac sürümü 0.1.0:** arşivle → Developer ID ile dışa aktar → notarize et → staple → zip/dmg → Sparkle imzası →
   `pastronaut-appcast.xml` girdisi → GitHub Release. Homebrew tap sonra.
7. ⬜ **App Store Connect:** uygulama kaydı (iOS; Mac App Store sonra), gizlilik etiketi "Veri Toplanmıyor",
   gizlilik adresi (madde 2), kategori, yaş derecesi, açıklama ve ekran görüntüleri (TR/EN).
8. ⬜ **TestFlight:** iOS arşivi yükle, iç test.
9. ⏳ **Şifreleme beyanı:** `ITSAppUsesNonExemptEncryption = false` yazıyor. Uygulama alanları CryptoKit ile
   şifreliyor (standart algoritma, Apple'ın kitaplığı). Bu genellikle muafiyet kapsamında sayılır ama beyanı App
   Store Connect'te gözden geçirmek gerekir. Hukuki görüş değildir.
10. ⬜ **Ad kontrolü:** "Pastronaut" için marka araması (TÜRKPATENT, EUIPO, USPTO, App Store'da aynı ad).

## C. Sonra
- Mac App Store yapılandırması (Sparkle'sız, ayrı yetkiler) ve Mac için gizlilik bildirimi.
- Homebrew tap.
